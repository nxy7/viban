defmodule Viban.Kanban.HookCancellationTest do
  use Viban.DataCase, async: true

  alias Viban.Kanban.Actors.BoardSupervisor
  alias Viban.Kanban.ColumnHook
  alias Viban.Kanban.Hook
  alias Viban.Kanban.HookExecution
  alias Viban.Kanban.Task
  alias Viban.Kanban.Task.TaskServer

  # ============================================================================
  # Setup Helpers
  # ============================================================================

  defp create_slow_hook(board_id, name \\ "Slow Hook", sleep_seconds \\ 2) do
    {:ok, hook} =
      Hook.create(%{
        name: name,
        command: "sleep #{sleep_seconds}",
        board_id: board_id
      })

    hook
  end

  defp assign_hook_to_column(hook, column, opts \\ []) do
    position = Keyword.get(opts, :position, 0)

    {:ok, column_hook} =
      ColumnHook.create(%{
        column_id: column.id,
        hook_id: hook.id,
        position: position
      })

    column_hook
  end

  # ============================================================================
  # CancelHooksOnMove Tests
  # ============================================================================

  describe "CancelHooksOnMove integration" do
    test "triggers cancellation when task moves to different column" do
      %{board: board, todo: todo, in_progress: in_progress, done: done} = create_board_with_columns()

      hook = create_slow_hook(board.id, "Slow Hook", 3)
      assign_hook_to_column(hook, in_progress)

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, task} = Task.move(task, %{column_id: in_progress.id})
      assert {:ok, _} = wait_for_hook_running(task.id, "Slow Hook")

      {:ok, task} = Task.move(task, %{column_id: done.id})

      assert {:ok, cancelled} = wait_for_hook_status(task.id, "Slow Hook", :cancelled)
      assert cancelled.skip_reason in [:column_change, :user_cancelled]
    end

    test "cancels pending hooks that haven't started yet" do
      %{board: board, todo: todo, in_progress: in_progress, done: done} = create_board_with_columns()

      hook1 = create_slow_hook(board.id, "Hook 1", 2)
      hook2 = create_slow_hook(board.id, "Hook 2", 2)
      assign_hook_to_column(hook1, in_progress, position: 0)
      assign_hook_to_column(hook2, in_progress, position: 1)

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, task} = Task.move(task, %{column_id: in_progress.id})
      assert {:ok, _} = wait_for_hook_running(task.id, "Hook 1")

      {:ok, _task} = Task.move(task, %{column_id: done.id})

      assert {:ok, _} = wait_for_hook_status(task.id, "Hook 1", :cancelled)
      assert {:ok, _} = wait_for_hook_status(task.id, "Hook 2", :cancelled)
    end

    test "move after hooks complete doesn't cancel already completed hooks" do
      %{board: board, todo: todo, in_progress: in_progress, done: done} = create_board_with_columns()

      {:ok, fast_hook} =
        Hook.create(%{
          name: "Fast Hook",
          command: "echo done",
          board_id: board.id
        })

      assign_hook_to_column(fast_hook, in_progress)

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, task} = Task.move(task, %{column_id: in_progress.id})
      assert {:ok, _} = wait_for_all_hooks_terminal(task.id)

      {:ok, executions_before} = HookExecution.history_for_task(task.id)
      completed_before = Enum.filter(executions_before, &(&1.status == :completed))

      {:ok, _task} = Task.move(task, %{column_id: done.id})

      Process.sleep(200)

      {:ok, executions_after} = HookExecution.history_for_task(task.id)

      in_progress_execs =
        Enum.filter(executions_after, &(&1.triggering_column_id == in_progress.id))

      completed_after = Enum.filter(in_progress_execs, &(&1.status == :completed))
      assert length(completed_after) == length(completed_before)
    end
  end

  # ============================================================================
  # TaskServer.move/3 Tests
  # ============================================================================

  describe "TaskServer.move/3" do
    test "returns :ok and cancels hooks synchronously" do
      %{board: board, todo: todo, in_progress: in_progress, done: done} = create_board_with_columns()

      hook = create_slow_hook(board.id, "Slow Hook", 3)
      assign_hook_to_column(hook, in_progress)

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, task} = Task.move(task, %{column_id: in_progress.id})
      assert {:ok, _} = wait_for_hook_running(task.id, "Slow Hook")

      result = TaskServer.move(task.id, done.id, 0.5)
      assert result == :ok

      assert {:ok, _} = wait_for_hook_status(task.id, "Slow Hook", :cancelled)
    end

    test "returns error when TaskServer not found" do
      non_existent_task_id = Ecto.UUID.generate()

      result = TaskServer.move(non_existent_task_id, Ecto.UUID.generate(), 0.5)
      assert result == {:error, :not_found}
    end
  end

  # ============================================================================
  # TaskServer.stop_execution/1 Tests
  # ============================================================================

  describe "TaskServer.stop_execution/1" do
    test "stops running hook and cancels pending with :user_cancelled reason" do
      %{board: board, todo: todo, in_progress: in_progress} = create_board_with_columns()

      hook1 = create_slow_hook(board.id, "Hook 1", 3)
      hook2 = create_slow_hook(board.id, "Hook 2", 3)
      assign_hook_to_column(hook1, in_progress, position: 0)
      assign_hook_to_column(hook2, in_progress, position: 1)

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, task} = Task.move(task, %{column_id: in_progress.id})
      assert {:ok, _} = wait_for_hook_running(task.id, "Hook 1")

      result = TaskServer.stop_execution(task.id)
      assert result == :ok

      assert {:ok, _} = wait_for_hook_status(task.id, "Hook 1", :cancelled)
      assert {:ok, _} = wait_for_hook_status(task.id, "Hook 2", :cancelled)

      {:ok, executions} = HookExecution.history_for_task(task.id)

      Enum.each(executions, fn exec ->
        assert exec.status == :cancelled
        assert exec.skip_reason == :user_cancelled
      end)
    end

    test "clears task agent status" do
      %{board: board, todo: todo, in_progress: in_progress} = create_board_with_columns()

      hook = create_slow_hook(board.id, "Slow Hook", 3)
      assign_hook_to_column(hook, in_progress)

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, task} = Task.move(task, %{column_id: in_progress.id})
      assert {:ok, _} = wait_for_hook_running(task.id, "Slow Hook")

      {:ok, task_during} = Task.get(task.id)
      assert task_during.agent_status == :executing

      TaskServer.stop_execution(task.id)

      Process.sleep(200)
      {:ok, task_after} = Task.get(task.id)
      assert task_after.agent_status == :idle
    end

    test "is idempotent when called multiple times" do
      %{board: board, todo: todo, in_progress: in_progress} = create_board_with_columns()

      hook = create_slow_hook(board.id, "Slow Hook", 3)
      assign_hook_to_column(hook, in_progress)

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, task} = Task.move(task, %{column_id: in_progress.id})
      assert {:ok, _} = wait_for_hook_running(task.id, "Slow Hook")

      assert :ok == TaskServer.stop_execution(task.id)
      Process.sleep(100)
      assert :ok == TaskServer.stop_execution(task.id)
      assert :ok == TaskServer.stop_execution(task.id)

      {:ok, executions} = HookExecution.history_for_task(task.id)
      assert length(executions) == 1
      assert hd(executions).status == :cancelled
    end
  end

  # ============================================================================
  # HookExecution.cancel/2 Tests
  # ============================================================================

  describe "HookExecution state cancellation" do
    setup do
      %{board: board, in_progress: in_progress} = create_board_with_columns()

      {:ok, task} =
        Task.create(%{
          title: "Test Task",
          column_id: in_progress.id
        })

      %{task: task, column: in_progress, board: board}
    end

    test "cancel/2 from :pending sets completed_at timestamp", %{task: task, column: column} do
      {:ok, exec} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Test Hook",
          hook_id: "test-hook-id",
          triggering_column_id: column.id
        })

      assert exec.completed_at == nil

      {:ok, cancelled} = HookExecution.cancel(exec, %{skip_reason: :column_change})

      assert cancelled.status == :cancelled
      assert cancelled.completed_at
    end

    test "cancel/2 from :running sets completed_at timestamp", %{task: task, column: column} do
      {:ok, exec} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Test Hook",
          hook_id: "test-hook-id",
          triggering_column_id: column.id
        })

      {:ok, running} = HookExecution.start(exec)
      assert running.completed_at == nil

      {:ok, cancelled} = HookExecution.cancel(running, %{skip_reason: :column_change})

      assert cancelled.status == :cancelled
      assert cancelled.completed_at
    end

    test "cancellation preserves started_at if was running", %{task: task, column: column} do
      {:ok, exec} =
        HookExecution.queue(%{
          task_id: task.id,
          hook_name: "Test Hook",
          hook_id: "test-hook-id",
          triggering_column_id: column.id
        })

      {:ok, running} = HookExecution.start(exec)
      started_at = running.started_at

      {:ok, cancelled} = HookExecution.cancel(running, %{skip_reason: :column_change})

      assert cancelled.started_at == started_at
    end

    test "all skip reasons work correctly", %{task: task, column: column} do
      reasons = [:error, :disabled, :column_change, :server_restart, :user_cancelled]

      for {reason, idx} <- Enum.with_index(reasons) do
        {:ok, exec} =
          HookExecution.queue(%{
            task_id: task.id,
            hook_name: "Hook #{idx}",
            hook_id: "hook-#{idx}",
            triggering_column_id: column.id
          })

        {:ok, cancelled} = HookExecution.cancel(exec, %{skip_reason: reason})
        assert cancelled.status == :cancelled
        assert cancelled.skip_reason == reason
      end
    end
  end

  # ============================================================================
  # Server Restart Cancellation Tests
  # ============================================================================

  describe "server restart cancellation" do
    test "running hooks are cancelled with :server_restart reason on TaskServer init" do
      %{board: board, todo: todo, in_progress: in_progress} = create_board_with_columns()

      hook = create_slow_hook(board.id, "Slow Hook", 5)
      assign_hook_to_column(hook, in_progress)

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, task} = Task.move(task, %{column_id: in_progress.id})
      assert {:ok, _} = wait_for_hook_running(task.id, "Slow Hook")

      [{pid, _}] = Registry.lookup(Viban.Kanban.ActorRegistry, {:task_server, task.id})
      Process.exit(pid, :kill)

      Process.sleep(500)

      assert {:ok, first_exec} =
               poll_until(5000, fn ->
                 {:ok, history} = HookExecution.history_for_task(task.id)
                 Enum.find(history, &(&1.hook_name == "Slow Hook" && &1.status == :cancelled))
               end)

      assert first_exec.skip_reason == :server_restart
    end
  end

  # ============================================================================
  # Rapid Move Tests
  # ============================================================================

  describe "rapid column transitions" do
    test "multiple rapid moves cancel previous hooks correctly" do
      %{board: board, todo: todo, in_progress: in_progress, done: done} =
        create_board_with_columns()

      hook1 = create_slow_hook(board.id, "Slow Hook IP", 3)
      hook2 = create_slow_hook(board.id, "Slow Hook Done", 3)
      assign_hook_to_column(hook1, in_progress)
      assign_hook_to_column(hook2, done)

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, task} = Task.move(task, %{column_id: in_progress.id})
      Process.sleep(100)

      {:ok, task} = Task.move(task, %{column_id: done.id})
      Process.sleep(50)
      {:ok, task} = Task.move(task, %{column_id: todo.id})
      Process.sleep(50)
      {:ok, _task} = Task.move(task, %{column_id: in_progress.id})

      assert {:ok, _} = wait_for_all_hooks_terminal(task.id, slow_hook_timeout_ms())

      {:ok, executions} = HookExecution.history_for_task(task.id)

      cancelled_count =
        Enum.count(executions, fn exec ->
          exec.status == :cancelled
        end)

      assert cancelled_count >= 2
    end
  end
end
