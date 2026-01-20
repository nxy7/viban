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

      alias Viban.RepoSqlite

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

  For async tests, we use an allowances-based approach where spawned processes
  can be explicitly allowed to share the test's database connection.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Viban.RepoSqlite, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    # For async integration tests, set up automatic sandbox allowances
    if tags[:async] do
      # Store the test pid for later use by allow_sandbox_access/1
      Process.put(:test_pid, self())
    end
  end

  @doc """
  Allows a spawned process to access the test's database sandbox.

  Call this from within the test after starting a supervised process
  to grant it access to the test's database connection.

  ## Example

      start_supervised!({BoardSupervisor, board.id})
      allow_sandbox_access_to_children()
  """
  def allow_sandbox_access(pid) when is_pid(pid) do
    test_pid = Process.get(:test_pid) || self()
    Sandbox.allow(Viban.RepoSqlite, test_pid, pid)
  end

  @doc """
  Allows all children of a supervisor to access the test's database sandbox.
  Useful after starting a BoardSupervisor which spawns many child processes.
  """
  def allow_sandbox_access_to_supervisor(supervisor_pid) when is_pid(supervisor_pid) do
    test_pid = Process.get(:test_pid) || self()
    Sandbox.allow(Viban.RepoSqlite, test_pid, supervisor_pid)

    # Allow all children recursively
    case Supervisor.which_children(supervisor_pid) do
      children when is_list(children) ->
        Enum.each(children, fn
          {_id, pid, :worker, _modules} when is_pid(pid) ->
            Sandbox.allow(Viban.RepoSqlite, test_pid, pid)

          {_id, pid, :supervisor, _modules} when is_pid(pid) ->
            allow_sandbox_access_to_supervisor(pid)

          _ ->
            :ok
        end)

      _ ->
        :ok
    end
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
  Generates a test user ID.

  Since KanbanLite doesn't require a User record (just a UUID), we generate
  a random UUID for testing purposes.
  """
  def create_test_user(_attrs \\ %{}) do
    user_id = Ash.UUID.generate()

    {:ok,
     %{
       id: user_id,
       provider: :github,
       provider_uid: "test-uid-#{System.unique_integer([:positive])}",
       provider_login: "testuser",
       name: "Test User",
       email: "test@example.com"
     }}
  end

  # ============================================================================
  # Constants
  # ============================================================================

  @poll_interval_ms 50
  @default_timeout_ms 5000
  @slow_hook_timeout_ms 10_000

  def poll_interval_ms, do: @poll_interval_ms
  def default_timeout_ms, do: @default_timeout_ms
  def slow_hook_timeout_ms, do: @slow_hook_timeout_ms

  # ============================================================================
  # Board and Column Helpers
  # ============================================================================

  @doc """
  Creates a test board with standard columns (TODO, In Progress, To Review, Done).
  Clears default column hooks to allow tests to add their own hooks.

  Returns a map with board, user, and column references.

  ## Example

      %{board: board, user: user, todo: todo, in_progress: in_progress} = create_board_with_columns()
  """
  def create_board_with_columns do
    {:ok, user} = create_test_user()
    {:ok, board} = Viban.Kanban.Board.create(%{name: "Test Board", user_id: user.id})

    {:ok, columns} = Viban.Kanban.Column.read()
    board_columns = Enum.filter(columns, &(&1.board_id == board.id))

    todo = Enum.find(board_columns, &(&1.name == "TODO"))
    in_progress = Enum.find(board_columns, &(&1.name == "In Progress"))
    to_review = Enum.find(board_columns, &(&1.name == "To Review"))
    done = Enum.find(board_columns, &(&1.name == "Done"))

    clear_default_column_hooks(board_columns)

    %{
      board: board,
      user: user,
      todo: todo,
      todo_column: todo,
      in_progress: in_progress,
      in_progress_column: in_progress,
      to_review: to_review,
      to_review_column: to_review,
      done: done
    }
  end

  @doc """
  Clears all column hooks for the given columns.
  Useful for tests that need a clean slate.
  """
  def clear_default_column_hooks(columns) do
    import Ecto.Query

    column_ids = Enum.map(columns, & &1.id)

    Viban.Kanban.ColumnHook
    |> where([ch], ch.column_id in ^column_ids)
    |> Viban.RepoSqlite.delete_all()
  end

  # ============================================================================
  # Task Server Helpers
  # ============================================================================

  @doc """
  Waits for a TaskServer to be registered for the given task.
  Returns `{:ok, pid}` on success, `{:error, :timeout}` on timeout.
  """
  def wait_for_task_server(task_id, timeout \\ @default_timeout_ms) do
    poll_until(timeout, fn ->
      case Registry.lookup(Viban.Kanban.ActorRegistry, {:task_server, task_id}) do
        [{pid, _}] when is_pid(pid) -> pid
        _ -> nil
      end
    end)
  end

  # ============================================================================
  # Worktree Helpers
  # ============================================================================

  @doc """
  Creates a temporary worktree directory with automatic cleanup on test exit.
  Returns the worktree path.
  """
  def create_temp_worktree do
    path =
      Path.join(System.tmp_dir!(), "viban_test_worktree_#{System.unique_integer([:positive])}")

    File.mkdir_p!(path)
    on_exit(fn -> File.rm_rf(path) end)
    path
  end

  @doc """
  Creates a task with a temporary worktree assigned.
  The worktree is automatically cleaned up on test exit.

  Returns `{task, worktree_path}`.

  ## Example

      {task, worktree} = create_task_with_worktree(%{title: "Test", column_id: column.id})
  """
  def create_task_with_worktree(attrs) do
    worktree = create_temp_worktree()
    {:ok, task} = Viban.Kanban.Task.create(attrs)

    {:ok, task} =
      Viban.Kanban.Task.assign_worktree(task, %{
        worktree_path: worktree,
        worktree_branch: "test-branch"
      })

    {task, worktree}
  end

  @doc """
  Creates a temporary file path with automatic cleanup on test exit.
  The file is deleted when the test completes, whether it exists or not.

  ## Example

      marker_file = temp_file_with_cleanup("hook_marker")
  """
  def temp_file_with_cleanup(prefix) do
    path = Path.join(System.tmp_dir!(), "#{prefix}_#{System.unique_integer()}")
    on_exit(fn -> File.rm(path) end)
    path
  end

  # ============================================================================
  # Hook Test Helpers
  # ============================================================================

  @doc """
  Waits for a specific hook execution to reach the expected status.
  Polls the database every #{@poll_interval_ms}ms until timeout.

  Returns `{:ok, execution}` on success, `{:error, :timeout}` on timeout.

  ## Examples

      {:ok, exec} = wait_for_hook_status(task.id, "My Hook", :completed)
      {:error, :timeout} = wait_for_hook_status(task.id, "My Hook", :cancelled, 100)
  """
  def wait_for_hook_status(task_id, hook_name, expected_status, timeout \\ @default_timeout_ms) do
    alias Viban.Kanban.HookExecution

    poll_until(timeout, fn ->
      {:ok, executions} = HookExecution.history_for_task(task_id)

      Enum.find(executions, fn exec ->
        exec.hook_name == hook_name && exec.status == expected_status
      end)
    end)
  end

  @doc """
  Waits for all hook executions for a task to reach a terminal state.
  Terminal states: :completed, :failed, :cancelled, :skipped

  Returns `{:ok, executions}` on success, `{:error, :timeout}` on timeout.
  """
  def wait_for_all_hooks_terminal(task_id, timeout \\ @default_timeout_ms) do
    alias Viban.Kanban.HookExecution

    poll_until(timeout, fn ->
      {:ok, active} = HookExecution.active_for_task(task_id)

      if active == [] do
        {:ok, history} = HookExecution.history_for_task(task_id)
        history
      end
    end)
  end

  @doc """
  Waits for at least one hook execution to start (status = :running).

  Returns `{:ok, execution}` on success, `{:error, :timeout}` on timeout.
  """
  def wait_for_hook_running(task_id, hook_name, timeout \\ @default_timeout_ms) do
    wait_for_hook_status(task_id, hook_name, :running, timeout)
  end

  @doc """
  Waits for no running hooks for a task.

  Returns `{:ok, :ok}` on success, `{:error, :timeout}` on timeout.
  """
  def wait_for_no_running_hooks(task_id, timeout \\ @default_timeout_ms) do
    alias Viban.Kanban.HookExecution

    poll_until(timeout, fn ->
      {:ok, active} = HookExecution.active_for_task(task_id)
      running = Enum.filter(active, &(&1.status == :running))

      if running == [] do
        :ok
      end
    end)
  end

  @doc """
  Gets the current status of all hook executions for a task.
  Useful for debugging test failures.
  """
  def get_hook_execution_statuses(task_id) do
    alias Viban.Kanban.HookExecution

    {:ok, executions} = HookExecution.history_for_task(task_id)

    Enum.map(executions, fn exec ->
      %{
        hook_name: exec.hook_name,
        status: exec.status,
        skip_reason: exec.skip_reason
      }
    end)
  end

  # ============================================================================
  # Polling Utilities
  # ============================================================================

  @doc """
  Polls a function until it returns a truthy value or timeout is reached.

  Returns `{:ok, result}` when the function returns a truthy value,
  or `{:error, :timeout}` when the timeout is reached.

  The function should return:
  - `nil` or `false` to continue polling
  - Any other value to stop and return that value

  ## Example

      {:ok, pid} = poll_until(5000, fn ->
        case Registry.lookup(MyRegistry, :key) do
          [{pid, _}] -> pid
          [] -> nil
        end
      end)
  """
  def poll_until(timeout, fun) when timeout > 0 do
    case fun.() do
      nil ->
        Process.sleep(@poll_interval_ms)
        poll_until(timeout - @poll_interval_ms, fun)

      false ->
        Process.sleep(@poll_interval_ms)
        poll_until(timeout - @poll_interval_ms, fun)

      result ->
        {:ok, result}
    end
  end

  def poll_until(_timeout, _fun), do: {:error, :timeout}
end
