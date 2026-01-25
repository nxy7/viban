defmodule Viban.Kanban.Task.Actions.CreateWorktree do
  @moduledoc """
  Creates a git worktree for the task (SQLite version).

  Delegates to shared worktree management logic.
  """

  use Ash.Resource.Actions.Implementation

  alias Viban.Kanban.Task
  alias Viban.Kanban.Task.WorktreeManager

  require Logger

  @impl true
  def run(input, opts, _context) do
    task_id = opts[:arguments][:task_id]
    Logger.info("[CreateWorktree] task_id from opts: #{inspect(task_id)}")
    Logger.info("[CreateWorktree] input: #{inspect(input)}")
    Logger.info("[CreateWorktree] opts: #{inspect(opts)}")

    with {:ok, task} <- Task.get(task_id),
         {:ok, column} <- Viban.Kanban.Column.get(task.column_id) do
      case WorktreeManager.create_worktree(column.board_id, task_id, task.custom_branch_name) do
        {:ok, worktree_path, branch_name} ->
          {:ok, %{worktree_path: worktree_path, branch_name: branch_name}}

        {:error, _} = error ->
          error
      end
    end
  end
end
