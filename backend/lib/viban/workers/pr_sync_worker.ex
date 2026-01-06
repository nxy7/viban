defmodule Viban.Workers.PRSyncWorker do
  @moduledoc """
  Oban worker that periodically syncs PR status for all tasks with linked PRs.

  Runs every minute to:
  1. Detect PRs created outside the system (using worktree_branch)
  2. Update PR status for tasks with existing PRs
  3. Clear PR link when PR is closed
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 3

  alias Viban.GitHub.PRDetector
  alias Viban.Kanban.Task

  require Ash.Query
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("[PRSyncWorker] Starting PR sync")

    tasks = get_tasks_with_branches()
    results = Enum.map(tasks, &sync_task_pr/1)

    log_results(results)
    :ok
  end

  defp get_tasks_with_branches do
    Task
    |> Ash.Query.filter(not is_nil(worktree_branch) and not is_nil(worktree_path))
    |> Ash.read!()
  end

  defp sync_task_pr(task) do
    result =
      cond do
        is_nil(task.pr_url) ->
          PRDetector.detect_and_link_pr(task)

        task.pr_status in [:closed, :merged] ->
          {:ok, :already_closed}

        true ->
          PRDetector.sync_pr_status(task)
      end

    {task.id, result}
  rescue
    error ->
      Logger.warning("[PRSyncWorker] Failed to sync task #{task.id}: #{inspect(error)}")
      {task.id, {:error, error}}
  end

  defp log_results(results) do
    {successes, failures} =
      Enum.split_with(results, fn
        {_id, {:ok, _}} -> true
        {_id, {:error, _}} -> false
      end)

    Logger.info("[PRSyncWorker] Sync complete: #{length(successes)} succeeded, #{length(failures)} failed")
  end
end
