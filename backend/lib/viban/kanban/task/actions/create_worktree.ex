defmodule Viban.Kanban.Task.Actions.CreateWorktree do
  @moduledoc """
  Action to create a git worktree for a task.

  This action:
  1. Retrieves the task and validates it doesn't already have a worktree
  2. Finds the board for the task via its column
  3. Creates a worktree using WorktreeManager
  4. Assigns the worktree path and branch to the task

  ## Return Value

  On success, returns a map with:
  - `task_id` - The task ID
  - `worktree_path` - The worktree directory path
  - `worktree_branch` - The git branch created

  ## Errors

  Returns an error tuple if:
  - The task is not found
  - The task already has a worktree
  - The repository is not cloned
  - Git worktree creation fails
  """

  use Ash.Resource.Actions.Implementation

  require Logger

  alias Viban.Kanban.{Task, Column, WorktreeManager}

  @impl true
  @spec run(Ash.ActionInput.t(), keyword(), Ash.Resource.Actions.Implementation.context()) ::
          {:ok, map()} | {:error, term()}
  def run(input, _opts, _context) do
    task_id = input.arguments.task_id

    with {:ok, task} <- fetch_task(task_id),
         :ok <- validate_no_worktree(task),
         {:ok, board_id} <- get_board_id(task),
         {:ok, worktree_path, branch} <- create_worktree(board_id, task),
         {:ok, _updated} <- assign_worktree(task, worktree_path, branch) do
      {:ok, %{task_id: task_id, worktree_path: worktree_path, worktree_branch: branch}}
    end
  end

  defp fetch_task(task_id) do
    case Task.get(task_id) do
      {:ok, task} ->
        {:ok, task}

      {:error, %Ash.Error.Query.NotFound{}} ->
        {:error, "Task not found: #{task_id}"}

      {:error, reason} ->
        Logger.error("[CreateWorktree] Failed to fetch task #{task_id}: #{inspect(reason)}")
        {:error, "Failed to fetch task"}
    end
  end

  defp validate_no_worktree(task) do
    cond do
      task.worktree_path != nil and WorktreeManager.worktree_exists?(task.worktree_path) ->
        {:error, "Task already has a worktree at #{task.worktree_path}"}

      task.worktree_path != nil ->
        # Task has a worktree_path but directory doesn't exist - clear it first
        Logger.info("[CreateWorktree] Clearing stale worktree_path for task #{task.id}")
        Task.clear_worktree(task)
        :ok

      true ->
        :ok
    end
  end

  defp get_board_id(task) do
    case Column.get(task.column_id) do
      {:ok, column} ->
        {:ok, column.board_id}

      {:error, _} ->
        {:error, "Could not find column for task"}
    end
  end

  defp create_worktree(board_id, task) do
    case WorktreeManager.create_worktree(board_id, task.id, task.custom_branch_name) do
      {:ok, path, branch} ->
        Logger.info("[CreateWorktree] Created worktree for task #{task.id} at #{path}")
        {:ok, path, branch}

      {:error, :no_repository} ->
        {:error, "No repository configured for this board"}

      {:error, :repository_not_cloned} ->
        {:error, "Repository is not cloned yet. Wait for cloning to complete."}

      {:error, {:git_error, _code, output}} ->
        {:error, "Git error: #{String.trim(output)}"}

      {:error, reason} ->
        {:error, "Failed to create worktree: #{inspect(reason)}"}
    end
  end

  defp assign_worktree(task, worktree_path, branch) do
    Task.assign_worktree(task, %{worktree_path: worktree_path, worktree_branch: branch})
  end
end
