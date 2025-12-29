defmodule Viban.Kanban.SystemHooks.CreateBranchHook do
  @moduledoc """
  System hook that automatically creates a git branch from the task title.
  Useful when tasks enter a "In Progress" column.
  """

  @behaviour Viban.Kanban.SystemHooks.Behaviour

  require Logger

  @impl true
  def id, do: "system:create-branch"

  @impl true
  def name, do: "Auto-Create Git Branch"

  @impl true
  def description do
    "Automatically creates a git branch from the task title when the task enters this column. " <>
      "Formats the branch name as 'feature/task-title-slug'."
  end

  @impl true
  def execute(task, _column, _opts) do
    # Skip if task already has a worktree (branch already exists)
    if task.worktree_path && File.dir?(task.worktree_path) do
      Logger.info("[CreateBranchHook] Task #{task.id} already has a worktree, skipping")
      :ok
    else
      Logger.info(
        "[CreateBranchHook] Would create branch for task #{task.id}: #{slugify(task.title)}"
      )

      # The actual branch creation is handled by the executor/workspace setup
      # This hook is more of a marker/trigger for that process
      :ok
    end
  end

  defp slugify(title) when is_binary(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.slice(0, 50)
    |> String.trim("-")
  end

  defp slugify(_), do: "task"
end
