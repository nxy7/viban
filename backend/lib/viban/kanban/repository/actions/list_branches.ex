defmodule Viban.Kanban.Repository.Actions.ListBranches do
  @moduledoc """
  Lists available branches for a repository via the task's worktree.

  Takes a task_id and returns branches from its associated repository,
  with the default branch marked.
  """

  use Ash.Resource.Actions.Implementation

  alias Viban.GitHub.Client
  alias Viban.Kanban.Task

  require Logger

  @impl true
  def run(input, _opts, _context) do
    task_id = input.arguments.task_id

    with {:ok, task} <- fetch_task(task_id),
         {:ok, _} <- validate_worktree(task) do
      Client.list_branches(task.worktree_path)
    end
  end

  defp fetch_task(task_id) do
    case Task.get(task_id) do
      {:ok, task} -> {:ok, task}
      {:error, _} -> {:error, "Task not found"}
    end
  end

  defp validate_worktree(task) do
    if task.worktree_path do
      {:ok, task}
    else
      {:error, "Task does not have a worktree"}
    end
  end
end
