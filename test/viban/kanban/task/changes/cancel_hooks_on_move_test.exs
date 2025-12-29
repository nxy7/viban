defmodule Viban.Kanban.Task.Changes.CancelHooksOnMoveTest do
  @moduledoc """
  Tests for CancelHooksOnMove change behavior.

  This module tests the critical distinction between:
  1. Moving a task to a DIFFERENT column - should trigger hooks
  2. Reordering a task WITHIN the same column - should NOT trigger hooks
  """
  use Viban.DataCase, async: false

  alias Viban.Kanban.Actors.BoardSupervisor
  alias Viban.Kanban.ColumnHook
  alias Viban.Kanban.Hook
  alias Viban.Kanban.HookExecution
  alias Viban.Kanban.Task

  @async_timeout 3000

  describe "column change detection" do
    test "moving task to different column triggers hooks" do
      %{board: board, todo: todo, in_progress: in_progress} = create_board_with_columns()

      marker_file = temp_file_with_cleanup("hook_triggered_marker")

      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Trigger Test Hook",
          command: "touch #{marker_file}",
          board_id: board.id
        })

      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: in_progress.id,
          hook_id: hook.id,
          position: 0
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, _moved_task} = Task.move(task, %{column_id: in_progress.id})

      assert {:ok, _} = wait_for_hook_status(task.id, "Trigger Test Hook", :completed, @async_timeout)

      {:ok, executions} = HookExecution.history_for_task(task.id)
      hook_exec = Enum.find(executions, &(&1.hook_name == "Trigger Test Hook"))
      assert hook_exec
      assert hook_exec.status == :completed

      assert File.exists?(marker_file), "Hook should have executed and created marker file"
    end

    test "reordering task within same column does NOT trigger hooks" do
      %{board: board, todo: todo, in_progress: in_progress} = create_board_with_columns()

      marker_file = temp_file_with_cleanup("no_trigger_marker")

      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Should Not Trigger Hook",
          command: "touch #{marker_file}",
          board_id: board.id
        })

      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: in_progress.id,
          hook_id: hook.id,
          position: 0,
          execute_once: false
        })

      {task1, _worktree1} =
        create_task_with_worktree(%{
          title: "Task 1",
          column_id: todo.id
        })

      {task2, _worktree2} =
        create_task_with_worktree(%{
          title: "Task 2",
          column_id: todo.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task1.id)
      assert {:ok, _pid} = wait_for_task_server(task2.id)

      {:ok, task1} = Task.move(task1, %{column_id: in_progress.id})
      {:ok, task2} = Task.move(task2, %{column_id: in_progress.id})

      assert {:ok, _} = wait_for_hook_status(task1.id, "Should Not Trigger Hook", :completed, @async_timeout)
      assert {:ok, _} = wait_for_hook_status(task2.id, "Should Not Trigger Hook", :completed, @async_timeout)

      File.rm(marker_file)

      {:ok, executions_before} = HookExecution.history_for_task(task1.id)
      count_before = length(executions_before)

      {:ok, _reordered_task} =
        Task.move(task1, %{
          column_id: in_progress.id,
          after_task_id: task2.id
        })

      Process.sleep(500)

      {:ok, executions_after} = HookExecution.history_for_task(task1.id)
      count_after = length(executions_after)

      assert count_after == count_before,
             "Reordering should not create new hook executions. Before: #{count_before}, After: #{count_after}"

      refute File.exists?(marker_file),
             "Hook should NOT have executed when reordering within same column"
    end

    test "changing only position without changing column does NOT trigger hooks" do
      %{board: board, todo: todo, in_progress: in_progress} = create_board_with_columns()

      marker_file = temp_file_with_cleanup("position_only_marker")

      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Position Only Hook",
          command: "touch #{marker_file}",
          board_id: board.id
        })

      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: in_progress.id,
          hook_id: hook.id,
          position: 0,
          execute_once: false
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, task} = Task.move(task, %{column_id: in_progress.id})
      assert {:ok, _} = wait_for_hook_status(task.id, "Position Only Hook", :completed, @async_timeout)

      File.rm(marker_file)

      {:ok, executions_before} = HookExecution.history_for_task(task.id)
      count_before = length(executions_before)

      {:ok, _updated_task} = Task.move(task, %{column_id: in_progress.id})

      Process.sleep(500)

      {:ok, executions_after} = HookExecution.history_for_task(task.id)
      count_after = length(executions_after)

      assert count_after == count_before,
             "Moving to same column should not create new hook executions. Before: #{count_before}, After: #{count_after}"

      refute File.exists?(marker_file),
             "Hook should NOT have executed when staying in same column"
    end

    test "moving back and forth between columns triggers hooks each time" do
      %{board: board, todo: todo, in_progress: in_progress} = create_board_with_columns()

      counter_file = temp_file_with_cleanup("back_forth_counter")
      File.write!(counter_file, "0")

      {:ok, hook} =
        Hook.create_script_hook(%{
          name: "Counter Hook",
          command: "expr $(cat #{counter_file}) + 1 > #{counter_file}",
          board_id: board.id
        })

      {:ok, _column_hook} =
        ColumnHook.create(%{
          column_id: in_progress.id,
          hook_id: hook.id,
          position: 0,
          execute_once: false
        })

      {task, _worktree} =
        create_task_with_worktree(%{
          title: "Test Task",
          column_id: todo.id
        })

      start_supervised!({BoardSupervisor, board.id})
      assert {:ok, _pid} = wait_for_task_server(task.id)

      {:ok, task} = Task.move(task, %{column_id: in_progress.id})
      assert {:ok, _} = wait_for_hook_status(task.id, "Counter Hook", :completed, @async_timeout)
      assert String.trim(File.read!(counter_file)) == "1", "First move should trigger hook"

      {:ok, task} = Task.move(task, %{column_id: todo.id})
      Process.sleep(200)

      {:ok, task} = Task.move(task, %{column_id: in_progress.id})
      Process.sleep(@async_timeout)

      counter_value = String.trim(File.read!(counter_file))
      assert counter_value == "2", "Second move to in_progress should trigger hook again. Got: #{counter_value}"

      {:ok, task} = Task.move(task, %{column_id: todo.id})
      Process.sleep(200)

      {:ok, _task} = Task.move(task, %{column_id: in_progress.id})
      Process.sleep(@async_timeout)

      counter_value = String.trim(File.read!(counter_file))
      assert counter_value == "3", "Third move to in_progress should trigger hook again. Got: #{counter_value}"
    end
  end
end
