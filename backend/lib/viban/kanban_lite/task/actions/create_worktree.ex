defmodule Viban.KanbanLite.Task.Actions.CreateWorktree do
  @moduledoc """
  Creates a git worktree for the task (SQLite version).

  Delegates to shared worktree management logic.
  """

  use Ash.Resource.Actions.Implementation

  alias Viban.Kanban.Task.WorktreeManager
  alias Viban.KanbanLite.Task

  @impl true
  def run(_input, opts, _context) do
    task_id = opts[:arguments][:task_id]

    with {:ok, task} <- Task.get(task_id),
         {:ok, column} <- Viban.KanbanLite.Column.get(task.column_id),
         {:ok, board} <- Viban.KanbanLite.Board.get(column.board_id) do
      WorktreeManager.create_worktree(task, board)
    end
  end
end
