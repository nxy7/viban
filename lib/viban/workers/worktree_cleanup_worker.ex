defmodule Viban.Workers.WorktreeCleanupWorker do
  @moduledoc """
  Oban worker for cleaning up expired worktrees.

  Runs periodically to remove worktrees for tasks that have been in
  Done or Cancelled columns longer than the configured TTL.
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 1

  alias Viban.Kanban.Task.WorktreeManager

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("WorktreeCleanupWorker starting cleanup run")

    WorktreeManager.cleanup_expired_worktrees()

    Logger.info("WorktreeCleanupWorker cleanup completed")
    :ok
  end
end
