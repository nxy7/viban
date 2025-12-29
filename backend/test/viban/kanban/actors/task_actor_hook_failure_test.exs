defmodule Viban.Kanban.Actors.TaskActorHookFailureTest do
  @moduledoc """
  Tests that TaskActor properly sets error state when hooks fail.
  """
  use Viban.DataCase, async: false

  alias Viban.Kanban.{Board, Column, Task, Hook, ColumnHook}
  alias Viban.Kanban.Actors.BoardActor

  setup do
    # Create a user and board
    {:ok, user} = create_test_user()
    {:ok, board} = Board.create(%{name: "Test Board", user_id: user.id})

    # Get the columns created by default
    {:ok, columns} = Column.read()
    todo_column = Enum.find(columns, &(&1.name == "TODO" && &1.board_id == board.id))

    in_progress_column =
      Enum.find(columns, &(&1.name == "In Progress" && &1.board_id == board.id))

    # Create a failing hook - this command will exit with code 1
    {:ok, failing_hook} =
      Hook.create(%{
        name: "Failing Hook",
        command: "exit 1",
        board_id: board.id
      })

    # Attach the failing hook to In Progress column as on_entry
    {:ok, _column_hook} =
      ColumnHook.create(%{
        column_id: in_progress_column.id,
        hook_id: failing_hook.id,
        hook_type: :on_entry,
        position: 0
      })

    # Create a task in TODO column
    {:ok, task} =
      Task.create(%{
        title: "Test Task",
        column_id: todo_column.id
      })

    %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column,
      failing_hook: failing_hook,
      task: task
    }
  end

  describe "hook failure handling" do
    @tag :skip
    @tag :integration
    test "sets task to error state when on_entry hook fails", %{
      board: board,
      in_progress_column: in_progress_column,
      task: task
    } do
      # Start the board actor (which will start task actors)
      start_supervised!({BoardActor, board.id})

      # Give actors time to initialize
      Process.sleep(100)

      # Move task to In Progress column (which has the failing hook)
      {:ok, moved_task} = Task.move(task, %{column_id: in_progress_column.id})

      # Notify the board actor about the move
      BoardActor.notify_task_updated(board.id, moved_task)

      # Wait for hook to execute and fail
      Process.sleep(500)

      # Reload task to check state
      {:ok, updated_task} = Task.get(task.id)

      # Verify task is in error state
      assert updated_task.agent_status == :error
      assert updated_task.error_message != nil
      assert String.contains?(updated_task.error_message, "Failing Hook")
      assert updated_task.in_progress == false
    end

    @tag :skip
    @tag :integration
    test "error message contains hook name and exit code", %{
      board: board,
      in_progress_column: in_progress_column,
      task: task
    } do
      start_supervised!({BoardActor, board.id})
      Process.sleep(100)

      {:ok, moved_task} = Task.move(task, %{column_id: in_progress_column.id})
      BoardActor.notify_task_updated(board.id, moved_task)

      Process.sleep(500)

      {:ok, updated_task} = Task.get(task.id)

      # Error message should contain useful debug info
      assert String.contains?(updated_task.error_message, "Failing Hook")

      assert String.contains?(updated_task.error_message, "exit code 1") or
               String.contains?(updated_task.error_message, "failed")
    end

    @tag :skip
    @tag :integration
    test "task can be moved again after error is cleared", %{
      board: board,
      todo_column: todo_column,
      in_progress_column: in_progress_column,
      task: task
    } do
      start_supervised!({BoardActor, board.id})
      Process.sleep(100)

      # Move to in progress (will fail)
      {:ok, moved_task} = Task.move(task, %{column_id: in_progress_column.id})
      BoardActor.notify_task_updated(board.id, moved_task)
      Process.sleep(500)

      # Verify error state
      {:ok, errored_task} = Task.get(task.id)
      assert errored_task.agent_status == :error

      # Clear error and move back
      {:ok, cleared_task} = Task.clear_error(errored_task)
      assert cleared_task.agent_status == :idle
      assert cleared_task.error_message == nil

      # Move back to TODO (should work)
      {:ok, back_task} = Task.move(cleared_task, %{column_id: todo_column.id})
      BoardActor.notify_task_updated(board.id, back_task)
      Process.sleep(100)

      {:ok, final_task} = Task.get(task.id)
      assert final_task.column_id == todo_column.id
      assert final_task.agent_status == :idle
    end
  end
end
