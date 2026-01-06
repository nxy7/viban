defmodule VibanWeb.DeviceAuthController do
  @moduledoc """
  Handles GitHub Device Flow authentication.

  Device Flow is an OAuth flow designed for devices without browsers or with limited input.
  It's also perfect for distributed applications where users shouldn't need to configure
  OAuth credentials.

  ## Flow

  1. Frontend calls `POST /api/auth/device/code` to start the flow
  2. Backend returns `user_code` and `verification_uri` to show the user
  3. User visits github.com/login/device and enters the code
  4. Frontend polls `POST /api/auth/device/poll` until success or failure
  5. On success, user session is established

  ## Endpoints

  - `POST /api/auth/device/code` - Start device flow, returns code for user
  - `POST /api/auth/device/poll` - Poll for token completion
  - `POST /api/auth/device/cancel` - Cancel ongoing device flow
  """

  use VibanWeb, :controller

  import VibanWeb.ControllerHelpers, only: [json_ok: 2, json_error: 3]

  alias Viban.Accounts.User
  alias Viban.Auth.DeviceFlow

  require Logger

  @doc """
  Start the device flow by requesting a device code from GitHub.

  Returns the user code and verification URI that the user needs to complete auth.
  The device code is stored in the session for polling.
  """
  def request_code(conn, _params) do
    case DeviceFlow.request_device_code() do
      {:ok, data} ->
        Logger.info("[DeviceAuth] Device code requested, user_code: #{data.user_code}")

        conn
        |> put_session(:device_code, data.device_code)
        |> put_session(:device_code_expires_at, System.system_time(:second) + data.expires_in)
        |> put_session(:device_poll_interval, data.interval)
        |> json_ok(%{
          user_code: data.user_code,
          verification_uri: data.verification_uri,
          expires_in: data.expires_in,
          interval: data.interval
        })

      {:error, reason} ->
        Logger.warning("[DeviceAuth] Failed to request device code: #{reason}")
        json_error(conn, :bad_request, reason)
    end
  end

  @doc """
  Poll GitHub for the access token.

  The frontend should call this repeatedly (respecting the interval) until
  it receives a success or error status.

  Returns:
  - `{status: "success", user: {...}}` - Auth complete, user logged in
  - `{status: "pending"}` - User hasn't completed auth yet
  - `{status: "slow_down"}` - Polling too fast, wait longer
  - `{status: "expired"}` - Device code expired, start over
  - `{status: "error", message: "..."}` - Auth failed
  """
  def poll(conn, _params) do
    device_code = get_session(conn, :device_code)
    expires_at = get_session(conn, :device_code_expires_at)

    cond do
      is_nil(device_code) ->
        json_error(
          conn,
          :bad_request,
          "No device flow in progress. Start with /api/auth/device/code"
        )

      expires_at && System.system_time(:second) > expires_at ->
        conn
        |> clear_device_session()
        |> json_ok(%{status: "expired", message: "Device code expired. Please start again."})

      true ->
        poll_for_token(conn, device_code)
    end
  end

  @doc """
  Cancel an ongoing device flow.
  """
  def cancel(conn, _params) do
    Logger.info("[DeviceAuth] Device flow cancelled")

    conn
    |> clear_device_session()
    |> json_ok(%{status: "cancelled"})
  end

  # ============================================================================
  # Private Functions - Token Polling
  # ============================================================================

  defp poll_for_token(conn, device_code) do
    case DeviceFlow.poll_for_token(device_code) do
      {:ok, access_token} ->
        handle_successful_auth(conn, access_token)

      :pending ->
        json_ok(conn, %{status: "pending"})

      :slow_down ->
        json_ok(conn, %{status: "slow_down"})

      {:error, reason} ->
        Logger.warning("[DeviceAuth] Token poll failed: #{reason}")

        conn
        |> clear_device_session()
        |> json_ok(%{status: "error", message: reason})
    end
  end

  defp handle_successful_auth(conn, access_token) do
    case DeviceFlow.get_user_info(access_token) do
      {:ok, user_info} ->
        user_params = Map.put(user_info, :access_token, access_token)

        case find_or_create_user(user_params) do
          {:ok, user} ->
            Logger.info("[DeviceAuth] User authenticated: #{user.provider_login} (#{user.provider})")

            conn
            |> clear_device_session()
            |> put_session(:user_id, user.id)
            |> configure_session(renew: true)
            |> json_ok(%{status: "success", user: serialize_user(user)})

          {:error, reason} ->
            Logger.error("[DeviceAuth] Failed to create/update user: #{inspect(reason)}")

            conn
            |> clear_device_session()
            |> json_ok(%{status: "error", message: "Failed to create user account"})
        end

      {:error, reason} ->
        Logger.error("[DeviceAuth] Failed to get user info: #{reason}")

        conn
        |> clear_device_session()
        |> json_ok(%{status: "error", message: "Failed to fetch user info from GitHub"})
    end
  end

  # ============================================================================
  # Private Functions - User Management
  # ============================================================================

  defp find_or_create_user(%{provider: provider, provider_uid: provider_uid} = params) do
    case User.by_provider_uid(provider, provider_uid) do
      {:ok, nil} ->
        User.create(params)

      {:ok, user} ->
        update_params = Map.drop(params, [:provider, :provider_uid])
        User.update(user, update_params)

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        if Enum.any?(errors, &match?(%Ash.Error.Query.NotFound{}, &1)) do
          User.create(params)
        else
          {:error, errors}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # Private Functions - Session & Serialization
  # ============================================================================

  defp clear_device_session(conn) do
    conn
    |> delete_session(:device_code)
    |> delete_session(:device_code_expires_at)
    |> delete_session(:device_poll_interval)
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
