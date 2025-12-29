defmodule VibanWeb.AuthController do
  @moduledoc """
  Handles OAuth authentication for VCS providers (GitHub, GitLab, etc.).

  This controller manages the OAuth flow using Ueberauth, including:
  - Initiating OAuth redirects to providers
  - Handling OAuth callbacks
  - Creating/updating user records
  - Session management

  ## OAuth Flow

  1. User visits `/auth/:provider` (e.g., `/auth/github`)
  2. Ueberauth redirects to the provider's OAuth page
  3. User authenticates with the provider
  4. Provider redirects back to `/auth/:provider/callback`
  5. User record is created/updated and session is established
  6. User is redirected to the frontend with `?auth=success` or `?auth=error`

  ## Endpoints

  - `GET /auth/:provider` - Initiate OAuth flow
  - `GET /auth/:provider/callback` - OAuth callback handler
  - `GET /api/auth/me` - Get current user info
  - `POST /api/auth/logout` - Log out current user
  """

  use VibanWeb, :controller

  import VibanWeb.ControllerHelpers, only: [json_ok: 2, get_user_from_session: 1]

  plug Ueberauth

  alias Viban.Accounts.User

  require Logger

  # Default frontend URL for redirects
  @default_frontend_url "https://localhost:8000"

  # Redirect query params
  @auth_success_param "?auth=success"
  @auth_error_param "?auth=error"

  @doc """
  Initiates the OAuth flow by redirecting to the provider.

  This action is handled automatically by the Ueberauth plug, which
  intercepts the request and redirects to the appropriate OAuth URL.
  """
  @spec request(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def request(conn, _params) do
    # Ueberauth handles this automatically via the plug
    conn
  end

  @doc """
  Handles the OAuth callback from the VCS provider.

  On success, creates or updates the user record and establishes a session.
  Redirects to the frontend with appropriate query parameters.
  """
  @spec callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, %{"provider" => provider_str}) do
    provider = String.to_existing_atom(provider_str)
    user_params = extract_user_params(auth, provider)

    case find_or_create_user(user_params) do
      {:ok, user} ->
        Logger.info(
          "[AuthController] User authenticated: #{user.provider_login} (#{user.provider})"
        )

        conn
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> redirect(external: frontend_url() <> @auth_success_param)

      {:error, reason} ->
        Logger.warning("[AuthController] Authentication failed: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Authentication failed: #{inspect(reason)}")
        |> redirect(external: frontend_url() <> @auth_error_param)
    end
  end

  def callback(%{assigns: %{ueberauth_failure: failure}} = conn, _params) do
    message =
      failure.errors
      |> Enum.map(& &1.message)
      |> Enum.join(", ")

    Logger.warning("[AuthController] OAuth failure: #{message}")

    conn
    |> put_flash(:error, "Authentication failed: #{message}")
    |> redirect(external: frontend_url() <> @auth_error_param)
  end

  @doc """
  Logs out the user by dropping the session.
  """
  @spec logout(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> json_ok(%{})
  end

  @doc """
  Returns the current user's info if authenticated.

  Returns `user: nil` if no user is authenticated, rather than an error.
  This allows the frontend to check auth status without error handling.
  """
  @spec me(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def me(conn, _params) do
    case get_user_from_session(conn) do
      {:ok, user} ->
        json_ok(conn, %{user: serialize_user(user)})

      {:error, :not_authenticated} ->
        # Clear any stale session data
        conn
        |> configure_session(drop: true)
        |> json_ok(%{user: nil})
    end
  end

  # ============================================================================
  # Private Functions - User Management
  # ============================================================================

  defp extract_user_params(auth, provider) do
    %{
      provider: provider,
      provider_uid: to_string(auth.uid),
      provider_login: auth.info.nickname,
      name: auth.info.name,
      email: auth.info.email,
      avatar_url: auth.info.image,
      access_token: auth.credentials.token,
      token_expires_at: parse_token_expiry(auth.credentials)
    }
  end

  defp find_or_create_user(%{provider: provider, provider_uid: provider_uid} = params) do
    case User.by_provider_uid(provider, provider_uid) do
      {:ok, nil} ->
        User.create(params)

      {:ok, user} ->
        # Update user info (token may have changed)
        update_params = Map.drop(params, [:provider, :provider_uid])
        User.update(user, update_params)

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        # Check if it's a NotFound error (user doesn't exist)
        if Enum.any?(errors, &match?(%Ash.Error.Query.NotFound{}, &1)) do
          User.create(params)
        else
          {:error, errors}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_token_expiry(%{expires_at: nil}), do: nil

  defp parse_token_expiry(%{expires_at: expires_at}) when is_integer(expires_at) do
    DateTime.from_unix!(expires_at)
  end

  defp parse_token_expiry(_), do: nil

  # ============================================================================
  # Private Functions - Serialization
  # ============================================================================

  defp serialize_user(user) do
    %{
      id: user.id,
      provider: user.provider,
      provider_login: user.provider_login,
      name: user.name,
      email: user.email,
      avatar_url: user.avatar_url
    }
  end

  # ============================================================================
  # Private Functions - Configuration
  # ============================================================================

  @spec frontend_url() :: String.t()
  defp frontend_url do
    Application.get_env(:viban, :frontend_url, @default_frontend_url)
  end
end
