defmodule Viban.Auth.DeviceFlow do
  @moduledoc """
  GitHub Device Flow authentication.

  Device Flow allows authentication without requiring users to configure OAuth credentials.
  The app displays a code, user visits github.com/login/device, enters the code,
  and the app receives an access token.

  ## Flow
  1. Call `request_device_code/0` to get a user code and verification URL
  2. Display the code to the user and direct them to the verification URL
  3. Poll `poll_for_token/1` with the device code until success or failure
  4. On success, use `get_user_info/1` to fetch user profile
  """

  require Logger

  @github_device_url "https://github.com/login/device/code"
  @github_token_url "https://github.com/login/oauth/access_token"
  @github_api_url "https://api.github.com"

  # Public client ID - safe to embed, this is by design for device flow
  # Users will need to create their own GitHub OAuth App with device flow enabled
  # and set this via environment variable or we use a default for the official Viban app
  def client_id do
    System.get_env("GH_CLIENT_ID") || Application.get_env(:viban, :github_client_id)
  end

  @doc """
  Request a device code from GitHub.

  Returns device_code (for polling), user_code (to show user), and verification_uri.
  """
  @spec request_device_code() ::
          {:ok, map()} | {:error, String.t()}
  def request_device_code do
    case client_id() do
      nil ->
        {:error, "GitHub client ID not configured. Set GH_CLIENT_ID environment variable."}

      client_id ->
        body =
          URI.encode_query(%{
            "client_id" => client_id,
            "scope" => "user:email repo"
          })

        headers = [
          {"Accept", "application/json"},
          {"Content-Type", "application/x-www-form-urlencoded"}
        ]

        case Req.post(@github_device_url, body: body, headers: headers) do
          {:ok, %{status: 200, body: body}} ->
            {:ok,
             %{
               device_code: body["device_code"],
               user_code: body["user_code"],
               verification_uri: body["verification_uri"],
               expires_in: body["expires_in"],
               interval: body["interval"]
             }}

          {:ok, %{status: status, body: body}} ->
            Logger.error("GitHub device code request failed: #{status} - #{inspect(body)}")
            {:error, body["error_description"] || "Failed to request device code"}

          {:error, reason} ->
            Logger.error("GitHub device code request error: #{inspect(reason)}")
            {:error, "Network error requesting device code"}
        end
    end
  end

  @doc """
  Poll GitHub for an access token using the device code.

  Returns:
  - `{:ok, access_token}` - User completed authorization
  - `{:pending}` - User hasn't completed authorization yet (keep polling)
  - `{:slow_down}` - Polling too fast, increase interval by 5 seconds
  - `{:error, reason}` - Authorization failed or expired
  """
  @spec poll_for_token(String.t()) ::
          {:ok, String.t()} | :pending | :slow_down | {:error, String.t()}
  def poll_for_token(device_code) do
    body =
      URI.encode_query(%{
        "client_id" => client_id(),
        "device_code" => device_code,
        "grant_type" => "urn:ietf:params:oauth:grant-type:device_code"
      })

    headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]

    case Req.post(@github_token_url, body: body, headers: headers) do
      {:ok, %{status: 200, body: %{"access_token" => access_token}}} ->
        {:ok, access_token}

      {:ok, %{status: 200, body: %{"error" => "authorization_pending"}}} ->
        :pending

      {:ok, %{status: 200, body: %{"error" => "slow_down"}}} ->
        :slow_down

      {:ok, %{status: 200, body: %{"error" => "expired_token"}}} ->
        {:error, "Device code expired. Please start again."}

      {:ok, %{status: 200, body: %{"error" => "access_denied"}}} ->
        {:error, "Authorization denied by user."}

      {:ok, %{status: 200, body: %{"error" => error, "error_description" => desc}}} ->
        {:error, desc || error}

      {:ok, %{status: 200, body: %{"error" => error}}} ->
        {:error, error}

      {:ok, %{status: status, body: body}} ->
        Logger.error("GitHub token poll failed: #{status} - #{inspect(body)}")
        {:error, "Failed to poll for token"}

      {:error, reason} ->
        Logger.error("GitHub token poll error: #{inspect(reason)}")
        {:error, "Network error polling for token"}
    end
  end

  @doc """
  Get user info from GitHub using an access token.

  Returns user profile including id, login, name, email, and avatar_url.
  """
  @spec get_user_info(String.t()) :: {:ok, map()} | {:error, String.t()}
  def get_user_info(access_token) do
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Accept", "application/vnd.github+json"},
      {"X-GitHub-Api-Version", "2022-11-28"}
    ]

    with {:ok, %{status: 200, body: user}} <-
           Req.get("#{@github_api_url}/user", headers: headers),
         {:ok, email} <- get_primary_email(access_token) do
      {:ok,
       %{
         provider: :github,
         provider_uid: to_string(user["id"]),
         provider_login: user["login"],
         name: user["name"],
         email: email || user["email"],
         avatar_url: user["avatar_url"]
       }}
    else
      {:ok, %{status: status, body: body}} ->
        Logger.error("GitHub user info request failed: #{status} - #{inspect(body)}")
        {:error, "Failed to fetch user info"}

      {:error, reason} ->
        Logger.error("GitHub user info error: #{inspect(reason)}")
        {:error, "Network error fetching user info"}
    end
  end

  defp get_primary_email(access_token) do
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Accept", "application/vnd.github+json"},
      {"X-GitHub-Api-Version", "2022-11-28"}
    ]

    case Req.get("#{@github_api_url}/user/emails", headers: headers) do
      {:ok, %{status: 200, body: emails}} when is_list(emails) ->
        primary =
          Enum.find(emails, fn e -> e["primary"] && e["verified"] end) ||
            Enum.find(emails, fn e -> e["primary"] end) ||
            List.first(emails)

        {:ok, primary && primary["email"]}

      _ ->
        {:ok, nil}
    end
  end
end
