defmodule VibanWeb.AuthController do
  @moduledoc """
  Handles session-related authentication endpoints.

  The actual authentication flow is handled by DeviceAuthController using
  GitHub Device Flow. This controller only handles session queries and logout.

  ## Endpoints

  - `GET /api/auth/me` - Get current user info
  - `POST /api/auth/logout` - Log out current user
  """

  use VibanWeb, :controller

  import VibanWeb.ControllerHelpers, only: [json_ok: 2, get_user_from_session: 1]

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
        conn
        |> configure_session(drop: true)
        |> json_ok(%{user: nil})
    end
  end

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
end
