defmodule Viban.Kanban.Task.Actions.CreatePR do
  @moduledoc """
  Action to create a GitHub pull request for a task.

  This action:
  1. Retrieves the task and validates it has a worktree branch
  2. Gets the repository's default branch (or uses the provided base branch)
  3. Creates the PR via the GitHub CLI
  4. Links the PR to the task

  ## Return Value

  On success, returns a map with:
  - `id` - The task ID
  - `pr_url` - The PR URL
  - `pr_number` - The PR number
  - `pr_status` - The PR status (:open)

  ## Errors

  Returns an error tuple if:
  - The task is not found
  - The task has no worktree branch
  - The GitHub API call fails
  """

  use Ash.Resource.Actions.Implementation

  require Logger

  alias Viban.GitHub.Client
  alias Viban.Kanban.Task

  @impl true
  @spec run(Ash.ActionInput.t(), keyword(), Ash.Resource.Actions.Implementation.context()) ::
          {:ok, map()} | {:error, term()}
  def run(input, _opts, _context) do
    task_id = input.arguments.task_id
    title = input.arguments.title
    body = input.arguments.body || ""
    base_branch = input.arguments.base_branch

    with {:ok, task} <- fetch_task(task_id),
         :ok <- validate_worktree(task),
         {:ok, base} <- get_base_branch(task, base_branch),
         {:ok, pr} <- create_pr(task, base, title, body),
         {:ok, updated} <- link_pr(task, pr) do
      {:ok, build_result(updated, pr)}
    end
  end

  defp fetch_task(task_id) do
    case Task.get(task_id) do
      {:ok, task} ->
        {:ok, task}

      {:error, %Ash.Error.Query.NotFound{}} ->
        {:error, "Task not found: #{task_id}"}

      {:error, reason} ->
        Logger.error("[CreatePR] Failed to fetch task #{task_id}: #{inspect(reason)}")
        {:error, "Failed to fetch task"}
    end
  end

  defp validate_worktree(task) do
    cond do
      is_nil(task.worktree_path) ->
        {:error, "Task does not have a worktree. Run the task first to create a branch."}

      is_nil(task.worktree_branch) ->
        {:error, "Task does not have a branch set."}

      not is_nil(task.pr_url) and task.pr_status != :closed ->
        {:error, "Task already has an active pull request."}

      true ->
        :ok
    end
  end

  defp get_base_branch(task, nil) do
    case Client.get_default_branch(task.worktree_path) do
      {:ok, branch} -> {:ok, branch}
      {:error, _} -> {:ok, "main"}
    end
  end

  defp get_base_branch(_task, base_branch), do: {:ok, base_branch}

  defp create_pr(task, base_branch, title, body) do
    case Client.create_pr(task.worktree_path, base_branch, task.worktree_branch, title, body) do
      {:ok, pr} ->
        Logger.info("[CreatePR] Created PR for task #{task.id}: #{pr.url}")
        {:ok, pr}

      {:error, error} ->
        Logger.error("[CreatePR] Failed to create PR: #{error}")
        {:error, "Failed to create pull request: #{error}"}
    end
  end

  defp link_pr(task, pr) do
    Task.link_pr(task, pr.url, pr.number, pr.status)
  end

  defp build_result(task, pr) do
    %{
      id: task.id,
      pr_url: pr.url,
      pr_number: pr.number,
      pr_status: pr.status
    }
  end
end
