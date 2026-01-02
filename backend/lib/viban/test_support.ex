defmodule Viban.TestSupport do
  @moduledoc """
  Test support utilities for E2E testing.

  This module provides helpers for creating test data and managing test sessions.
  Only available when `config :viban, :sandbox_enabled, true`.

  ## Test User

  A dedicated test user is created/retrieved via `get_or_create_test_user/0`.
  This user has a fixed provider_uid so it's idempotent.

  ## Usage in E2E Tests

  1. Call `POST /api/test/login` to authenticate as the test user
  2. Create boards/tasks via normal API
  3. Call `DELETE /api/test/cleanup` to remove test data (boards matching "E2E Test")
  """

  require Ash.Query
  alias Viban.Accounts.User

  @test_user_uid "e2e-test-user-fixed-uid"
  @test_board_prefix "E2E Test"

  @doc """
  Returns the test user, creating it if it doesn't exist.
  """
  def get_or_create_test_user do
    case find_test_user() do
      {:ok, user} -> {:ok, user}
      {:error, :not_found} -> create_test_user()
    end
  end

  @doc """
  Returns the test user or raises if not found.
  """
  def get_or_create_test_user! do
    case get_or_create_test_user() do
      {:ok, user} -> user
      {:error, reason} -> raise "Failed to get test user: #{inspect(reason)}"
    end
  end

  @doc """
  Finds the test user by provider_uid.
  """
  def find_test_user do
    case User |> Ash.Query.filter(provider_uid == ^@test_user_uid) |> Ash.read_one() do
      {:ok, nil} -> {:error, :not_found}
      {:ok, user} -> {:ok, user}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Creates the test user.
  """
  def create_test_user do
    User.create(%{
      provider: :github,
      provider_uid: @test_user_uid,
      provider_login: "e2e-test-user",
      name: "E2E Test User",
      email: "e2e-test@example.com",
      access_token: "fake-test-token"
    })
  end

  @doc """
  Cleans up test boards (those with names starting with the test prefix).
  """
  def cleanup_test_boards do
    case find_test_user() do
      {:ok, user} ->
        boards =
          Viban.Kanban.Board
          |> Ash.Query.filter(user_id == ^user.id)
          |> Ash.Query.filter(contains(name, ^@test_board_prefix))
          |> Ash.read!()

        Enum.each(boards, fn board ->
          Viban.Kanban.Board.destroy!(board)
        end)

        {:ok, length(boards)}

      {:error, :not_found} ->
        {:ok, 0}
    end
  end

  @doc """
  Returns the test board name prefix for E2E tests.
  """
  def test_board_prefix, do: @test_board_prefix

  @doc """
  Generates a unique test board name.
  """
  def generate_test_board_name(suffix \\ nil) do
    timestamp = System.system_time(:millisecond)
    base = "#{@test_board_prefix} #{timestamp}"

    if suffix do
      "#{base} - #{suffix}"
    else
      base
    end
  end
end
