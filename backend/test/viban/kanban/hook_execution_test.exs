defmodule Viban.Kanban.HookExecutionTest do
  use Viban.DataCase, async: true

  alias Viban.Kanban.Board
  alias Viban.Kanban.Column
  alias Viban.Kanban.HookExecution
  alias Viban.Kanban.Task

  # ============================================================================
  # Setup Helpers
  # ============================================================================

  defp create_test_task do
    {:ok, user} = create_test_user()
    {:ok, board} = Board.create(%{name: "Test Board", user_id: user.id})

    {:ok, columns} = Column.read()
    todo_column = Enum.find(columns, &(&1.board_id == board.id && &1.name == "TODO"))

    {:ok, task} =
      Task.create(%{
        title: "Test Task",
        column_id: todo_column.id
      })

    %{task: task, column: todo_column, board: board, user: user}
  end

  # ============================================================================
  # State Transition Tests
  # ============================================================================

  describe "HookExecution state transitions" do
    setup do
      create_test_task()
    end

    test "queue/1 creates execution in :pending status", %{task: task, column: column} do
      {:ok, exec} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Test Hook",
          hook_id: "test-hook-id",
          triggering_column_id: column.id
        })

      assert exec.status == :pending
      assert exec.hook_name == "Test Hook"
      assert exec.hook_id == "test-hook-id"
      assert exec.task_id == task.id
      assert exec.queued_at
      assert exec.started_at == nil
      assert exec.completed_at == nil
    end

    test "start/1 transitions :pending -> :running", %{task: task, column: column} do
      {:ok, exec} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Test Hook",
          hook_id: "test-hook-id",
          triggering_column_id: column.id
        })

      {:ok, started_exec} = HookExecution.start(exec)

      assert started_exec.status == :running
      assert started_exec.started_at
      assert started_exec.completed_at == nil
    end

    test "complete/1 transitions :running -> :completed", %{task: task, column: column} do
      {:ok, exec} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Test Hook",
          hook_id: "test-hook-id",
          triggering_column_id: column.id
        })

      {:ok, started_exec} = HookExecution.start(exec)
      {:ok, completed_exec} = HookExecution.complete(started_exec)

      assert completed_exec.status == :completed
      assert completed_exec.completed_at
      assert completed_exec.error_message == nil
    end

    test "fail/2 transitions :running -> :failed with error message", %{task: task, column: column} do
      {:ok, exec} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Test Hook",
          hook_id: "test-hook-id",
          triggering_column_id: column.id
        })

      {:ok, started_exec} = HookExecution.start(exec)

      {:ok, failed_exec} =
        HookExecution.fail(started_exec, %{error_message: "Script exited with code 1"})

      assert failed_exec.status == :failed
      assert failed_exec.completed_at
      assert failed_exec.error_message == "Script exited with code 1"
    end

    test "cancel/2 transitions active state -> :cancelled with skip_reason", %{
      task: task,
      column: column
    } do
      {:ok, exec} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Test Hook",
          hook_id: "test-hook-id",
          triggering_column_id: column.id
        })

      {:ok, started_exec} = HookExecution.start(exec)

      {:ok, cancelled_exec} =
        HookExecution.cancel(started_exec, %{skip_reason: :column_change})

      assert cancelled_exec.status == :cancelled
      assert cancelled_exec.skip_reason == :column_change
      assert cancelled_exec.completed_at
    end

    test "skip/2 transitions :pending -> :skipped with reason", %{task: task, column: column} do
      {:ok, exec} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Test Hook",
          hook_id: "test-hook-id",
          triggering_column_id: column.id
        })

      {:ok, skipped_exec} = HookExecution.skip(exec, %{skip_reason: :disabled})

      assert skipped_exec.status == :skipped
      assert skipped_exec.skip_reason == :disabled
      assert skipped_exec.completed_at
    end

    test "can cancel pending execution", %{task: task, column: column} do
      {:ok, exec} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Test Hook",
          hook_id: "test-hook-id",
          triggering_column_id: column.id
        })

      {:ok, cancelled_exec} = HookExecution.cancel(exec, %{skip_reason: :error})

      assert cancelled_exec.status == :cancelled
      assert cancelled_exec.skip_reason == :error
    end
  end

  # ============================================================================
  # Query Tests
  # ============================================================================

  describe "HookExecution queries" do
    setup do
      create_test_task()
    end

    test "active_for_task/1 returns pending and running only", %{task: task, column: column} do
      {:ok, pending_exec} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Pending Hook",
          hook_id: "pending-hook",
          triggering_column_id: column.id
        })

      {:ok, running_exec} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Running Hook",
          hook_id: "running-hook",
          triggering_column_id: column.id
        })

      {:ok, running_exec} = HookExecution.start(running_exec)

      {:ok, completed_exec} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Completed Hook",
          hook_id: "completed-hook",
          triggering_column_id: column.id
        })

      {:ok, completed_exec} = HookExecution.start(completed_exec)
      {:ok, _completed_exec} = HookExecution.complete(completed_exec)

      {:ok, active} = HookExecution.active_for_task(task.id)

      assert length(active) == 2
      active_ids = Enum.map(active, & &1.id)
      assert pending_exec.id in active_ids
      assert running_exec.id in active_ids
    end

    test "history_for_task/1 returns all executions in order", %{task: task, column: column} do
      {:ok, _exec1} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Hook 1",
          hook_id: "hook-1",
          triggering_column_id: column.id
        })

      Process.sleep(10)

      {:ok, _exec2} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Hook 2",
          hook_id: "hook-2",
          triggering_column_id: column.id
        })

      Process.sleep(10)

      {:ok, _exec3} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Hook 3",
          hook_id: "hook-3",
          triggering_column_id: column.id
        })

      {:ok, history} = HookExecution.history_for_task(task.id)

      assert length(history) == 3
      names = Enum.map(history, & &1.hook_name)
      assert names == ["Hook 3", "Hook 2", "Hook 1"]
    end

    test "for_task_and_column/2 filters by triggering_column_id", %{task: task, column: column} do
      {:ok, user} = create_test_user(%{provider_uid: "another-uid"})
      {:ok, board2} = Board.create(%{name: "Board 2", user_id: user.id})
      {:ok, columns2} = Column.read()
      other_column = Enum.find(columns2, &(&1.board_id == board2.id && &1.name == "TODO"))

      {:ok, _exec1} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Hook in Column 1",
          hook_id: "hook-col-1",
          triggering_column_id: column.id
        })

      {:ok, _exec2} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Hook in Column 2",
          hook_id: "hook-col-2",
          triggering_column_id: other_column.id
        })

      {:ok, col1_execs} = HookExecution.for_task_and_column(task.id, column.id)
      {:ok, col2_execs} = HookExecution.for_task_and_column(task.id, other_column.id)

      assert length(col1_execs) == 1
      assert hd(col1_execs).hook_name == "Hook in Column 1"

      assert length(col2_execs) == 1
      assert hd(col2_execs).hook_name == "Hook in Column 2"
    end

    test "active_for_task_and_column/2 returns only active executions for column", %{
      task: task,
      column: column
    } do
      {:ok, exec1} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Pending Hook",
          hook_id: "pending-hook",
          triggering_column_id: column.id
        })

      {:ok, exec2} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Completed Hook",
          hook_id: "completed-hook",
          triggering_column_id: column.id
        })

      {:ok, exec2} = HookExecution.start(exec2)
      {:ok, _exec2} = HookExecution.complete(exec2)

      {:ok, active} = HookExecution.active_for_task_and_column(task.id, column.id)

      assert length(active) == 1
      assert hd(active).id == exec1.id
    end
  end

  # ============================================================================
  # Skip Reason Tests
  # ============================================================================

  describe "skip reasons" do
    setup do
      create_test_task()
    end

    test "all valid skip reasons can be set", %{task: task, column: column} do
      valid_reasons = [:error, :disabled, :column_change, :server_restart, :user_cancelled]

      for {reason, idx} <- Enum.with_index(valid_reasons) do
        {:ok, exec} =
          HookExecution.queue(%{
            task_id: task.id,
            hook_name: "Hook #{idx}",
            hook_id: "hook-#{idx}",
            triggering_column_id: column.id
          })

        {:ok, cancelled} = HookExecution.cancel(exec, %{skip_reason: reason})
        assert cancelled.skip_reason == reason
      end
    end
  end

  # ============================================================================
  # Hook Settings Tests
  # ============================================================================

  describe "hook_settings" do
    setup do
      create_test_task()
    end

    test "hook_settings defaults to empty map", %{task: task, column: column} do
      {:ok, exec} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Test Hook",
          hook_id: "test-hook-id",
          triggering_column_id: column.id
        })

      assert exec.hook_settings == %{}
    end

    test "hook_settings can store arbitrary data", %{task: task, column: column} do
      settings = %{
        "execute_once" => true,
        "transparent" => false,
        "timeout" => 30_000
      }

      {:ok, exec} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Test Hook",
          hook_id: "test-hook-id",
          triggering_column_id: column.id,
          hook_settings: settings
        })

      assert exec.hook_settings == settings
    end
  end
end
