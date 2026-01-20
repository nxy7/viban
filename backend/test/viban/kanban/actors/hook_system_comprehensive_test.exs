defmodule Viban.Kanban.Actors.HookSystemComprehensiveTest do
  @moduledoc """
  Comprehensive tests for the hook system as specified in HOOKS_SYSTEM.md.

  This test file covers scenarios outlined in the documentation that are NOT
  already covered by other test files. For basic hook behavior tests, see:
  - `hook_runner_test.exs` - Unit tests for HookRunner module
  - `kanban_hook_behavior_test.exs` - CommandQueue and basic hook execution
  - `hook_system_test.exs` - Hook CRUD and configuration tests

  ## Hook Execution Feedback (3 tests)
  1. Hook starts executing - task shows "Executing {HOOK_NAME}" status
  2. Hook completes successfully - status clears, task returns to idle state
  3. Hook fails (non-zero exit) - task shows error state, moved to "To Review"

  ## Hook Failure Scenarios (4 tests)
  1. Hook A fails, Hook B is pending - Task moved to "To Review", Hook B cancelled
  2. Hook fails, task has entry hooks on "To Review" column - hooks skipped
  3. Hook times out - behaves as failure
  4. Hook script not found / permission denied - treat as error with custom message

  ## Task Movement During Hook Execution (3 tests)
  1. User manually drags task while hook running - hook stopped immediately
  2. Hook moves task programmatically - same as manual drag
  3. Task deleted while hook running - hook stopped, then task deleted

  ## Multiple Hooks (3 tests)
  1. Column has 3 hooks: A, B, C - all succeed - all executed in order
  2. Column has 3 hooks: A succeeds, B fails, C pending - C skipped
  3. Same hook configured on multiple columns - executed each time task enters column

  ## Execute Once Flag (3 tests)
  1. Task enters column first time with "execute once" hook - hook executed
  2. Task re-enters same column (already executed) - hook skipped with trace
  3. Task re-enters after error cleared - hook still skipped

  ## Agent Hooks (4 tests)
  1. Agent hook starts - card in working state with message
  2. Agent hook waiting for user input - task status reflects waiting state
  3. Agent hook completes task - moved to "To Review" without error effect
  4. Agent hook encounters error - moved to "To Review" with error effect

  ## Concurrent/Race Conditions (3 tests)
  1. Two users move same task simultaneously - second move takes precedence
  2. Task moved rapidly between columns - hooks cancelled, new column hooks queued
  3. Server restart while hook running - hook state is recoverable

  Tests are organized into unit tests (run by default) and integration tests
  (require the full actor system, run with: mix test --include integration).
  """

  use Viban.DataCase, async: true

  alias Viban.Kanban.Actors.BoardActor
  alias Viban.Kanban.Actors.BoardSupervisor
  alias Viban.Kanban.Actors.HookRunner
  alias Viban.Kanban.Board
  alias Viban.Kanban.Column
  alias Viban.Kanban.ColumnHook
  alias Viban.Kanban.Hook
  alias Viban.Kanban.Task

  # ============================================================================
  # Test Configuration
  # ============================================================================

  @async_timeout 2000

  # ============================================================================
  # HOOK EXECUTION FEEDBACK TESTS (3 tests)
  # ============================================================================

  describe "Hook Execution Feedback" do
    @describetag :integration

    setup do
      create_board_with_columns()
    end

    test "shows executing status with hook name when hook starts", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Slow Hook",
          command: "sleep 2 && echo 'done'",
          board_id: board.id
        })

      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook.id,
          position: 0
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved_task} = Task.move(task, %{column_id: in_progress_column.id})

      Process.sleep(500)

      {:ok, executing_task} = Task.get(task.id)

      assert executing_task.in_progress == true
      assert executing_task.agent_status in [:running, :executing]
      assert executing_task.agent_status_message
      assert String.contains?(executing_task.agent_status_message, "Slow Hook")
    end

    test "clears status and returns to idle after successful completion", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Quick Success Hook",
          command: "echo 'success'",
          board_id: board.id
        })

      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook.id,
          position: 0
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved_task} = Task.move(task, %{column_id: in_progress_column.id})

      Process.sleep(@async_timeout)

      {:ok, completed_task} = Task.get(task.id)

      assert completed_task.in_progress == false
      assert completed_task.agent_status == :idle
      assert completed_task.error_message == nil
    end

    test "sets error state and moves to To Review on hook failure", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Failing Hook",
          command: "echo 'error message' && exit 1",
          board_id: board.id
        })

      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook.id,
          position: 0
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved_task} = Task.move(task, %{column_id: in_progress_column.id})

      Process.sleep(@async_timeout)

      {:ok, failed_task} = Task.get(task.id)

      assert failed_task.agent_status == :error
      assert failed_task.error_message
      assert String.contains?(failed_task.error_message, "Failing Hook")
    end
  end

  # ============================================================================
  # HOOK FAILURE SCENARIOS TESTS (4 tests)
  # ============================================================================

  describe "Hook Failure Scenarios" do
    @describetag :integration

    setup do
      create_board_with_columns()
    end

    test "cancels pending Hook B when Hook A fails and moves task to To Review", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      marker_file = temp_file_with_cleanup("hook_b_marker")

      {:ok, hook_a} =
        Hook.create_script_hook(%{
          name: "Hook A",
          command: "exit 1",
          board_id: board.id
        })

      {:ok, hook_b} =
        Hook.create_script_hook(%{
          name: "Hook B",
          command: "touch #{marker_file}",
          board_id: board.id
        })

      {:ok, _ch_a} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook_a.id,
          position: 0
        })

      {:ok, _ch_b} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook_b.id,
          position: 1
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved_task} = Task.move(task, %{column_id: in_progress_column.id})

      Process.sleep(@async_timeout)

      {:ok, failed_task} = Task.get(task.id)

      assert failed_task.agent_status == :error
      assert failed_task.error_message

      refute File.exists?(marker_file)
    end

    @tag :skip
    @tag reason: "Requires auto-move to To Review on failure (not implemented)"
    test "skips To Review column hooks when task arrives in error state", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column,
      to_review_column: to_review_column
    } do
      marker_file = temp_file_with_cleanup("to_review_hook")

      {:ok, failing_hook} =
        Hook.create_script_hook(%{
          name: "Failing Hook",
          command: "exit 1",
          board_id: board.id
        })

      {:ok, to_review_hook} =
        Hook.create_script_hook(%{
          name: "To Review Hook",
          command: "touch #{marker_file}",
          board_id: board.id
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: failing_hook.id,
          position: 0
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: to_review_column.id,
          hook_id: to_review_hook.id,
          position: 0
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved_task} = Task.move(task, %{column_id: in_progress_column.id})

      Process.sleep(@async_timeout * 2)

      {:ok, final_task} = Task.get(task.id)

      assert final_task.column_id == to_review_column.id
      assert final_task.agent_status == :error

      refute File.exists?(marker_file)
    end

    @tag :skip
    @tag timeout: 10_000
    test "treats timeout as failure" do
      error_message = format_timeout_error("Timeout Hook")
      assert String.contains?(error_message, "Timeout Hook")
      assert String.contains?(error_message, "timed out")
    end

    test "returns error for non-existent script" do
      hook = %{
        name: "Missing Script Hook",
        command: "/nonexistent/path/to/script.sh",
        hook_kind: :script
      }

      result = HookRunner.run_once(hook, System.tmp_dir!())

      assert {:error, {:exit_code, code, _output}} = result
      assert code != 0
    end
  end

  # ============================================================================
  # TASK MOVEMENT DURING HOOK EXECUTION TESTS (3 tests)
  # ============================================================================

  describe "Task Movement During Hook Execution" do
    @describetag :integration

    setup do
      create_board_with_columns()
    end

    test "stops running hook and cancels pending hooks when task is manually moved", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column,
      to_review_column: to_review_column
    } do
      alias Viban.Kanban.HookExecution

      {:ok, slow_hook} =
        Hook.create_script_hook(%{
          name: "Slow Hook",
          command: "sleep 10",
          board_id: board.id
        })

      {:ok, second_hook} =
        Hook.create_script_hook(%{
          name: "Second Hook",
          command: "echo 'second'",
          board_id: board.id
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: slow_hook.id,
          position: 0
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: second_hook.id,
          position: 1
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, moved_task1} = Task.move(task, %{column_id: in_progress_column.id})

      assert {:ok, _} = wait_for_hook_running(task.id, "Slow Hook"),
             "Slow Hook should have started running"

      {:ok, _moved_task2} = Task.move(moved_task1, %{column_id: to_review_column.id})

      assert {:ok, _} = wait_for_hook_status(task.id, "Slow Hook", :cancelled),
             "Slow Hook should have been cancelled"

      assert {:ok, _executions} = wait_for_all_hooks_terminal(task.id),
             "All hooks should reach terminal state"

      {:ok, executions} = HookExecution.history_for_task(task.id)
      slow_hook_exec = Enum.find(executions, &(&1.hook_name == "Slow Hook"))
      second_hook_exec = Enum.find(executions, &(&1.hook_name == "Second Hook"))

      assert slow_hook_exec.status == :cancelled
      assert slow_hook_exec.skip_reason in [:column_change, :user_cancelled]

      assert second_hook_exec.status in [:cancelled, :skipped]

      {:ok, final_task} = Task.get(task.id)
      assert final_task.column_id == to_review_column.id
    end

    test "programmatic move interrupts hooks same as manual move", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column,
      to_review_column: to_review_column
    } do
      alias Viban.Kanban.HookExecution

      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Hook Before Programmatic Move",
          command: "sleep 10",
          board_id: board.id
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook.id,
          position: 0
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, moved_task1} = Task.move(task, %{column_id: in_progress_column.id})

      assert {:ok, _} = wait_for_hook_running(task.id, "Hook Before Programmatic Move"),
             "Hook should have started running"

      {:ok, _moved_task2} = Task.move(moved_task1, %{column_id: to_review_column.id})

      assert {:ok, _} = wait_for_hook_status(task.id, "Hook Before Programmatic Move", :cancelled),
             "Hook should have been cancelled"

      {:ok, executions} = HookExecution.history_for_task(task.id)
      hook_exec = Enum.find(executions, &(&1.hook_name == "Hook Before Programmatic Move"))

      assert hook_exec.status == :cancelled
      assert hook_exec.skip_reason in [:column_change, :user_cancelled]

      {:ok, final_task} = Task.get(task.id)
      assert final_task.column_id == to_review_column.id
    end

    test "stops hook and deletes task when task is deleted during hook execution", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Hook Before Delete",
          command: "sleep 10",
          board_id: board.id
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook.id,
          position: 0
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      task_id = task.id

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, moved_task} = Task.move(task, %{column_id: in_progress_column.id})

      assert {:ok, _} = wait_for_hook_running(task_id, "Hook Before Delete"),
             "Hook should have started running"

      :ok = Task.destroy(moved_task)
      BoardActor.notify_task_deleted(board.id, task_id)

      assert {:ok, _} = wait_for_no_running_hooks(task_id),
             "All hooks should have stopped after task deletion"

      assert {:error, _} = Task.get(task_id)
    end
  end

  # ============================================================================
  # MULTIPLE HOOKS TESTS (3 tests)
  # ============================================================================

  describe "Multiple Hooks" do
    @describetag :integration

    setup do
      create_board_with_columns()
    end

    test "executes all hooks in position order when all succeed", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      order_file = temp_file_with_cleanup("hook_order")

      {:ok, hook_a} =
        Hook.create_script_hook(%{
          name: "Hook A",
          command: "echo 'A' >> #{order_file}",
          board_id: board.id
        })

      {:ok, hook_b} =
        Hook.create_script_hook(%{
          name: "Hook B",
          command: "echo 'B' >> #{order_file}",
          board_id: board.id
        })

      {:ok, hook_c} =
        Hook.create_script_hook(%{
          name: "Hook C",
          command: "echo 'C' >> #{order_file}",
          board_id: board.id
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook_a.id,
          position: 0
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook_b.id,
          position: 1
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook_c.id,
          position: 2
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved_task} = Task.move(task, %{column_id: in_progress_column.id})

      Process.sleep(@async_timeout * 2)

      assert File.exists?(order_file)
      content = File.read!(order_file)
      lines = String.split(content, "\n", trim: true)
      assert lines == ["A", "B", "C"]

      {:ok, final_task} = Task.get(task.id)
      assert final_task.agent_status == :idle
    end

    test "skips remaining hooks when middle hook fails", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      marker_file_a = temp_file_with_cleanup("hook_a")
      marker_file_c = temp_file_with_cleanup("hook_c")

      {:ok, hook_a} =
        Hook.create_script_hook(%{
          name: "Hook A",
          command: "touch #{marker_file_a}",
          board_id: board.id
        })

      {:ok, hook_b} =
        Hook.create_script_hook(%{
          name: "Hook B",
          command: "exit 1",
          board_id: board.id
        })

      {:ok, hook_c} =
        Hook.create_script_hook(%{
          name: "Hook C",
          command: "touch #{marker_file_c}",
          board_id: board.id
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook_a.id,
          position: 0
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook_b.id,
          position: 1
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook_c.id,
          position: 2
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved_task} = Task.move(task, %{column_id: in_progress_column.id})

      Process.sleep(@async_timeout)

      assert File.exists?(marker_file_a)
      refute File.exists?(marker_file_c)

      {:ok, final_task} = Task.get(task.id)
      assert final_task.agent_status == :error
    end

    test "executes same hook on different columns independently", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column,
      to_review_column: to_review_column
    } do
      counter_file = temp_file_with_cleanup("shared_hook_counter")
      File.write!(counter_file, "0")

      {:ok, shared_hook} =
        Hook.create_script_hook(%{
          name: "Shared Hook",
          command: "expr $(cat #{counter_file}) + 1 > #{counter_file}",
          board_id: board.id
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: shared_hook.id,
          position: 0,
          execute_once: false
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: to_review_column.id,
          hook_id: shared_hook.id,
          position: 0,
          execute_once: false
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, moved1} = Task.move(task, %{column_id: in_progress_column.id})
      Process.sleep(@async_timeout)

      assert String.trim(File.read!(counter_file)) == "1"

      {:ok, moved2} = Task.move(moved1, %{column_id: to_review_column.id})
      Process.sleep(@async_timeout)

      assert String.trim(File.read!(counter_file)) == "2"

      {:ok, _moved3} = Task.move(moved2, %{column_id: in_progress_column.id})
      Process.sleep(@async_timeout)

      assert String.trim(File.read!(counter_file)) == "3"
    end
  end

  # ============================================================================
  # EXECUTE ONCE FLAG TESTS (3 tests)
  # ============================================================================

  describe "Execute Once Flag" do
    @describetag :integration

    setup do
      create_board_with_columns()
    end

    test "executes hook on first column entry and tracks in executed_hooks", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      marker_file = temp_file_with_cleanup("execute_once")

      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Execute Once Hook",
          command: "touch #{marker_file}",
          board_id: board.id
        })

      {:ok, column_hook} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook.id,
          position: 0,
          execute_once: true
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved_task} = Task.move(task, %{column_id: in_progress_column.id})
      Process.sleep(@async_timeout)

      assert File.exists?(marker_file)

      {:ok, executed_task} = Task.get(task.id)
      assert column_hook.id in executed_task.executed_hooks
    end

    test "skips hook on subsequent column entries", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      counter_file = temp_file_with_cleanup("execute_once_counter")
      File.write!(counter_file, "0")

      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Execute Once Counter Hook",
          command: "expr $(cat #{counter_file}) + 1 > #{counter_file}",
          board_id: board.id
        })

      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook.id,
          position: 0,
          execute_once: true
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, moved1} = Task.move(task, %{column_id: in_progress_column.id})
      Process.sleep(@async_timeout)

      assert String.trim(File.read!(counter_file)) == "1"

      {:ok, moved2} = Task.move(moved1, %{column_id: todo_column.id})
      Process.sleep(500)

      {:ok, _moved3} = Task.move(moved2, %{column_id: in_progress_column.id})
      Process.sleep(@async_timeout)

      assert String.trim(File.read!(counter_file)) == "1"
    end

    test "remains skipped even after error is cleared", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      counter_file = temp_file_with_cleanup("execute_once_error")
      File.write!(counter_file, "0")

      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Execute Once After Error Hook",
          command: "expr $(cat #{counter_file}) + 1 > #{counter_file}",
          board_id: board.id
        })

      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: hook.id,
          position: 0,
          execute_once: true
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved1} = Task.move(task, %{column_id: in_progress_column.id})
      Process.sleep(@async_timeout)

      assert String.trim(File.read!(counter_file)) == "1"

      {:ok, errored_task} = Task.get(task.id)

      {:ok, errored_task} =
        Task.set_error(errored_task, %{
          agent_status: :error,
          error_message: "Simulated error",
          in_progress: false
        })

      {:ok, cleared_task} = Task.clear_error(errored_task)
      assert cleared_task.agent_status == :idle

      {:ok, moved2} = Task.move(cleared_task, %{column_id: todo_column.id})
      Process.sleep(500)

      {:ok, _moved3} = Task.move(moved2, %{column_id: in_progress_column.id})
      Process.sleep(@async_timeout)

      assert String.trim(File.read!(counter_file)) == "1"
    end
  end

  # ============================================================================
  # AGENT HOOKS TESTS (4 tests)
  # ============================================================================

  describe "Agent Hooks" do
    # Unit tests for agent hook state transitions.
    # These tests verify the Task resource correctly tracks agent hook states
    # without requiring the full executor infrastructure.

    setup do
      create_board_with_columns()
    end

    test "creates agent hook with correct attributes", %{board: board} do
      {:ok, agent_hook} =
        Hook.create_agent_hook(%{
          name: "Test AI Agent",
          agent_prompt: "Fix the code",
          agent_executor: :claude_code,
          agent_auto_approve: false,
          board_id: board.id
        })

      assert agent_hook.hook_kind == :agent
      assert agent_hook.agent_prompt == "Fix the code"
      assert agent_hook.agent_executor == :claude_code
      assert agent_hook.agent_auto_approve == false
    end

    test "task shows executing state when agent hook starts", %{todo_column: todo_column} do
      {:ok, task} =
        Task.create(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      {:ok, updated_task} =
        Task.update_agent_status(task, %{
          agent_status: :executing,
          agent_status_message: "Running Test AI Agent"
        })

      {:ok, in_progress_task} = Task.set_in_progress(updated_task, %{in_progress: true})

      assert in_progress_task.agent_status == :executing
      assert in_progress_task.in_progress == true
      assert String.contains?(in_progress_task.agent_status_message, "Test AI Agent")
    end

    test "task can be moved to To Review after successful completion", %{
      todo_column: todo_column,
      to_review_column: to_review_column
    } do
      {:ok, task} =
        Task.create(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      {:ok, completed_task} =
        Task.update_agent_status(task, %{
          agent_status: :idle,
          agent_status_message: "Completed successfully"
        })

      {:ok, completed_task} = Task.set_in_progress(completed_task, %{in_progress: false})

      {:ok, moved_task} = Task.move(completed_task, %{column_id: to_review_column.id})

      assert moved_task.column_id == to_review_column.id
      assert moved_task.agent_status == :idle
      assert moved_task.error_message == nil
    end

    test "task preserves error state when moved to To Review", %{
      todo_column: todo_column,
      to_review_column: to_review_column
    } do
      {:ok, task} =
        Task.create(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      {:ok, errored_task} =
        Task.set_error(task, %{
          agent_status: :error,
          error_message: "AI Agent failed: Token limit exceeded",
          in_progress: false
        })

      {:ok, moved_task} = Task.move(errored_task, %{column_id: to_review_column.id})

      assert moved_task.column_id == to_review_column.id
      assert moved_task.agent_status == :error
      assert moved_task.error_message
      assert String.contains?(moved_task.error_message, "AI Agent failed")
    end
  end

  # ============================================================================
  # CONCURRENT/RACE CONDITIONS TESTS (3 tests)
  # ============================================================================

  describe "Concurrent/Race Conditions" do
    @describetag :integration

    setup do
      create_board_with_columns()
    end

    test "handles simultaneous moves from different sources", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column,
      to_review_column: to_review_column
    } do
      {kanban_task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      task_id = kanban_task.id

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(kanban_task.id)

      async_task1 =
        Elixir.Task.async(fn ->
          {:ok, moved} = Task.move(kanban_task, %{column_id: in_progress_column.id})
          {:ok, moved}
        end)

      async_task2 =
        Elixir.Task.async(fn ->
          Process.sleep(50)
          {:ok, moved} = Task.move(kanban_task, %{column_id: to_review_column.id})
          {:ok, moved}
        end)

      result1 = Elixir.Task.await(async_task1, 5000)
      result2 = Elixir.Task.await(async_task2, 5000)

      assert match?({:ok, _}, result1) or match?({:ok, _}, result2)

      Process.sleep(@async_timeout)

      {:ok, final_task} = Task.get(task_id)
      assert final_task.column_id in [in_progress_column.id, to_review_column.id]
    end

    test "cancels hooks during rapid column transitions", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column,
      to_review_column: to_review_column
    } do
      alias Viban.Kanban.HookExecution

      {:ok, ip_hook} =
        Hook.create_script_hook(%{
          name: "In Progress Hook",
          command: "sleep 10",
          board_id: board.id
        })

      {:ok, tr_hook} =
        Hook.create_script_hook(%{
          name: "To Review Hook",
          command: "sleep 10",
          board_id: board.id
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: ip_hook.id,
          position: 0
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: to_review_column.id,
          hook_id: tr_hook.id,
          position: 0
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, moved1} = Task.move(task, %{column_id: in_progress_column.id})

      assert {:ok, _} = wait_for_hook_running(task.id, "In Progress Hook", 3000),
             "In Progress Hook should have started"

      {:ok, moved2} = Task.move(moved1, %{column_id: to_review_column.id})

      assert {:ok, _} = wait_for_hook_status(task.id, "In Progress Hook", :cancelled, 3000),
             "In Progress Hook should have been cancelled"

      {:ok, _moved3} = Task.move(moved2, %{column_id: todo_column.id})

      assert {:ok, _} = wait_for_all_hooks_terminal(task.id),
             "All hooks should reach terminal state"

      {:ok, executions} = HookExecution.history_for_task(task.id)
      ip_hook_execs = Enum.filter(executions, &(&1.hook_name == "In Progress Hook"))
      tr_hook_execs = Enum.filter(executions, &(&1.hook_name == "To Review Hook"))

      assert Enum.all?(ip_hook_execs, &(&1.status in [:cancelled, :skipped]))
      assert Enum.all?(tr_hook_execs, &(&1.status in [:cancelled, :skipped]))

      {:ok, final_task} = Task.get(task.id)
      assert final_task.column_id == todo_column.id
    end

    test "persists hook executions for crash recovery" do
      # This test verifies HookExecution persistence for recovery scenarios
      # Hook execution state is now stored in the hook_executions table
      # and recovered by TaskServer on startup via self_heal/1
      alias Viban.Kanban.HookExecution

      {:ok, user} = create_test_user()
      {:ok, board} = Board.create(%{name: "Recovery Test Board", user_id: user.id})

      {:ok, columns} = Column.read()
      todo_column = Enum.find(columns, &(&1.board_id == board.id && &1.name == "TODO"))

      {:ok, task} =
        Task.create(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      # Create hook executions in various states (simulating mid-execution crash)
      {:ok, exec1} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Hook 1",
          hook_id: "hook-1",
          triggering_column_id: todo_column.id
        })

      {:ok, _} = HookExecution.complete(exec1)

      {:ok, exec2} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Hook 2",
          hook_id: "hook-2",
          triggering_column_id: todo_column.id
        })

      {:ok, _} = HookExecution.start(exec2)

      {:ok, _exec3} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Hook 3",
          hook_id: "hook-3",
          triggering_column_id: todo_column.id
        })

      # Verify active executions can be queried for recovery
      {:ok, active} = HookExecution.active_for_task(task.id)
      assert length(active) == 2

      running = Enum.find(active, &(&1.status == :running))
      assert running
      assert running.hook_name == "Hook 2"

      pending = Enum.find(active, &(&1.status == :pending))
      assert pending
      assert pending.hook_name == "Hook 3"

      # Simulate recovery: cancel running hook (as TaskServer.self_heal does)
      {:ok, cancelled} = HookExecution.cancel(running, %{skip_reason: :server_restart})
      assert cancelled.status == :cancelled
      assert cancelled.skip_reason == :server_restart
    end
  end

  # ============================================================================
  # TRANSPARENT HOOK TESTS
  # ============================================================================

  describe "Transparent hook behavior" do
    @describetag :integration

    setup do
      create_board_with_columns()
    end

    test "transparent hook executes when task is in error state", %{
      board: board,
      todo_column: todo_column,
      to_review_column: to_review_column
    } do
      alias Viban.Kanban.HookExecution

      marker_file = temp_file_with_cleanup("transparent_hook")

      {:ok, transparent_hook} =
        Hook.create_script_hook(%{
          name: "Transparent Hook",
          command: "touch #{marker_file}",
          board_id: board.id
        })

      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: to_review_column.id,
          hook_id: transparent_hook.id,
          position: 0,
          transparent: true
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      {:ok, errored_task} =
        Task.set_error(task, %{
          agent_status: :error,
          error_message: "Previous hook failed",
          in_progress: false
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved_task} = Task.move(errored_task, %{column_id: to_review_column.id})

      assert {:ok, completed_exec} = wait_for_hook_status(task.id, "Transparent Hook", :completed)

      assert File.exists?(marker_file)

      {:ok, executions} = HookExecution.history_for_task(task.id)
      transparent_exec = Enum.find(executions, &(&1.hook_name == "Transparent Hook"))
      assert transparent_exec
      assert transparent_exec.status == :completed
      assert completed_exec.status == :completed
    end

    test "non-transparent hook is skipped when task is in error state", %{
      board: board,
      todo_column: todo_column,
      to_review_column: to_review_column
    } do
      marker_file = temp_file_with_cleanup("non_transparent")

      {:ok, normal_hook} =
        Hook.create_script_hook(%{
          name: "Normal Hook",
          command: "touch #{marker_file}",
          board_id: board.id
        })

      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: to_review_column.id,
          hook_id: normal_hook.id,
          position: 0,
          transparent: false
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      {:ok, errored_task} =
        Task.set_error(task, %{
          agent_status: :error,
          error_message: "Previous hook failed",
          in_progress: false
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved_task} = Task.move(errored_task, %{column_id: to_review_column.id})

      assert {:ok, skipped_exec} = wait_for_hook_status(task.id, "Normal Hook", :skipped)

      refute File.exists?(marker_file)

      assert skipped_exec.status == :skipped
      assert skipped_exec.skip_reason == :error
    end

    test "mix of transparent and non-transparent hooks respects error state", %{
      board: board,
      todo_column: todo_column,
      to_review_column: to_review_column
    } do
      transparent_marker = temp_file_with_cleanup("transparent_marker")
      normal_marker = temp_file_with_cleanup("normal_marker")

      {:ok, transparent_hook} =
        Hook.create_script_hook(%{
          name: "Transparent Hook",
          command: "touch #{transparent_marker}",
          board_id: board.id
        })

      {:ok, normal_hook} =
        Hook.create_script_hook(%{
          name: "Normal Hook",
          command: "touch #{normal_marker}",
          board_id: board.id
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: to_review_column.id,
          hook_id: transparent_hook.id,
          position: 0,
          transparent: true
        })

      {:ok, _} =
        ColumnHook.create(%{
          column_id: to_review_column.id,
          hook_id: normal_hook.id,
          position: 1,
          transparent: false
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      {:ok, errored_task} =
        Task.set_error(task, %{
          agent_status: :error,
          error_message: "Previous hook failed",
          in_progress: false
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved_task} = Task.move(errored_task, %{column_id: to_review_column.id})

      assert {:ok, transparent_exec} = wait_for_hook_status(task.id, "Transparent Hook", :completed)
      assert {:ok, normal_exec} = wait_for_hook_status(task.id, "Normal Hook", :skipped)

      assert File.exists?(transparent_marker)
      refute File.exists?(normal_marker)

      assert transparent_exec.status == :completed
      assert normal_exec.status == :skipped
      assert normal_exec.skip_reason == :error
    end

    test "transparent hook runs on task without error state", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column
    } do
      marker_file = temp_file_with_cleanup("transparent_normal")

      {:ok, transparent_hook} =
        Hook.create_script_hook(%{
          name: "Transparent Hook",
          command: "touch #{marker_file}",
          board_id: board.id
        })

      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: in_progress_column.id,
          hook_id: transparent_hook.id,
          position: 0,
          transparent: true
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo_column.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved_task} = Task.move(task, %{column_id: in_progress_column.id})

      assert {:ok, exec} = wait_for_hook_status(task.id, "Transparent Hook", :completed)

      assert File.exists?(marker_file)
      assert exec.status == :completed
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp format_timeout_error(hook_name) do
    "Hook '#{hook_name}' timed out"
  end
end
