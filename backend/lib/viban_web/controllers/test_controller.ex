defmodule VibanWeb.TestController do
  @moduledoc """
  Controller for E2E test support.

  Provides endpoints for:
  - Logging in as test user (bypasses OAuth)
  - Cleaning up test data

  Only available when `config :viban, :sandbox_enabled, true`
  """

  use VibanWeb, :controller

  alias Viban.TestSupport

  plug :check_sandbox_enabled

  defp check_sandbox_enabled(conn, _opts) do
    if Application.get_env(:viban, :sandbox_enabled, false) do
      conn
    else
      conn
      |> put_status(:not_found)
      |> json(%{ok: false, error: "Test endpoints not available"})
      |> halt()
    end
  end

  @doc """
  POST /api/test/login

  Logs in as the test user, setting the session.
  Returns the test user info.
  """
  def login(conn, _params) do
    case TestSupport.get_or_create_test_user() do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> json(%{
          ok: true,
          user: %{
            id: user.id,
            name: user.name,
            email: user.email,
            provider_login: user.provider_login
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{ok: false, error: inspect(reason)})
    end
  end

  @doc """
  POST /api/test/logout

  Logs out the test user, clearing the session.
  """
  def logout(conn, _params) do
    conn
    |> clear_session()
    |> json(%{ok: true})
  end

  @doc """
  DELETE /api/test/cleanup

  Deletes all boards with names starting with "E2E Test".
  """
  def cleanup(conn, _params) do
    {:ok, count} = TestSupport.cleanup_test_boards()
    json(conn, %{ok: true, deleted_boards: count})
  end

  @doc """
  GET /api/test/status

  Returns test environment status and test user info.
  """
  def status(conn, _params) do
    user_info =
      case TestSupport.find_test_user() do
        {:ok, user} -> %{id: user.id, name: user.name, exists: true}
        {:error, _} -> %{exists: false}
      end

    json(conn, %{
      ok: true,
      sandbox_enabled: true,
      test_user: user_info,
      test_board_prefix: TestSupport.test_board_prefix()
    })
  end
end
