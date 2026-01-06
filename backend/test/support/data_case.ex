defmodule Viban.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Viban.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import Ash.Test
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Viban.DataCase

      alias Viban.Repo

      # Import Ash.Test helpers for better assertions
    end
  end

  setup tags do
    Viban.DataCase.setup_sandbox(tags)
    Viban.DataCase.setup_logging(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Viban.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  @doc """
  Sets up logging based on test tags.

  By default, logging is disabled (set to :none in test.exs).
  Use `@tag :log` or `@tag log: :info` to enable logging for specific tests.

  ## Examples

      @tag :log
      test "my test with default logging" do
        # Logs at :warning level
      end

      @tag log: :debug
      test "my test with debug logging" do
        # Logs at :debug level
      end
  """
  def setup_logging(tags) do
    case tags[:log] do
      nil ->
        # No logging tag, keep default :none
        :ok

      true ->
        # @tag :log - enable warning level
        Logger.configure(level: :warning)
        on_exit(fn -> Logger.configure(level: :none) end)

      level when is_atom(level) ->
        # @tag log: :info - enable specific level
        Logger.configure(level: level)
        on_exit(fn -> Logger.configure(level: :none) end)
    end
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @doc """
  Creates a test user with default values.
  """
  def create_test_user(attrs \\ %{}) do
    default_attrs = %{
      provider: :github,
      provider_uid: "test-uid-#{System.unique_integer([:positive])}",
      provider_login: "testuser",
      name: "Test User",
      email: "test@example.com",
      access_token: "test-token"
    }

    Viban.Accounts.User.create(Map.merge(default_attrs, attrs))
  end
end
