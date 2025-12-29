defmodule Viban.GitHub.PRDetector do
  @moduledoc """
  Detects PRs created by agents and links them to tasks.

  This module:
  - Parses executor output for PR URLs from `gh pr create`
  - Checks if a PR exists for a task's branch
  - Links detected PRs to tasks
  """

  require Logger

  alias Viban.GitHub.Client
  alias Viban.Kanban.Task

  @doc """
  Extract PR URL from agent output.
  Returns the PR URL if found, nil otherwise.
  """
  def extract_pr_url(output) when is_binary(output) do
    case Regex.run(~r|(https://github\.com/[^/]+/[^/]+/pull/\d+)|, output) do
      [_, url] -> url
      _ -> nil
    end
  end

  def extract_pr_url(_), do: nil

  @doc """
  Extract PR number from a URL.
  """
  def extract_pr_number(url) when is_binary(url) do
    case Regex.run(~r/\/pull\/(\d+)/, url) do
      [_, number] -> String.to_integer(number)
      _ -> nil
    end
  end

  def extract_pr_number(_), do: nil

  @doc """
  Process agent output and link any detected PR to the task.
  Called by the executor runner when parsing output.
  """
  def process_output(task_id, output) do
    with pr_url when not is_nil(pr_url) <- extract_pr_url(output),
         pr_number when not is_nil(pr_number) <- extract_pr_number(pr_url),
         {:ok, task} <- Task.get(task_id),
         # Only link if task doesn't already have a PR
         true <- is_nil(task.pr_url) do
      Logger.info("[PRDetector] Found PR URL in output for task #{task_id}: #{pr_url}")
      Task.link_pr(task, pr_url, pr_number, :open)
    else
      _ -> :ok
    end
  end

  @doc """
  Check if a PR exists for a task's branch and link it.
  Called after task execution completes or periodically.
  """
  def detect_and_link_pr(task) do
    # Use worktree_branch as the branch name
    branch = task.worktree_branch

    cond do
      is_nil(branch) ->
        {:ok, :no_branch}

      not is_nil(task.pr_url) ->
        {:ok, :already_linked}

      is_nil(task.worktree_path) ->
        {:ok, :no_worktree}

      true ->
        # Use the worktree path to run gh commands
        case Client.find_pr_for_branch(task.worktree_path, branch) do
          {:ok, nil} ->
            {:ok, :no_pr_found}

          {:ok, pr} ->
            Logger.info("[PRDetector] Found existing PR for task #{task.id}: #{pr.url}")
            Task.link_pr(task, pr.url, pr.number, pr.status)

          {:error, error} ->
            Logger.warning("[PRDetector] Failed to check for PR: #{error}")
            {:error, error}
        end
    end
  end

  @doc """
  Sync PR status for a task that has a linked PR.
  """
  def sync_pr_status(task) do
    cond do
      is_nil(task.pr_url) or is_nil(task.pr_number) ->
        {:ok, :no_pr}

      is_nil(task.worktree_path) ->
        {:ok, :no_worktree}

      true ->
        case Client.get_pr_status(task.worktree_path, task.pr_number) do
          {:ok, status} ->
            if status != task.pr_status do
              Logger.info(
                "[PRDetector] Updating PR status for task #{task.id}: #{task.pr_status} -> #{status}"
              )

              Task.update_pr_status(task, %{pr_status: status})
            else
              {:ok, :unchanged}
            end

          {:error, error} ->
            Logger.warning("[PRDetector] Failed to get PR status: #{error}")
            {:error, error}
        end
    end
  end
end
