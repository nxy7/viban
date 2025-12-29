defmodule Viban.Kanban.Task.Changes.AppendHookHistory do
  @moduledoc """
  Ash change that appends a hook execution entry to the hook_history list.

  This provides a persistent record of all hook executions for the task,
  which can be displayed in the activity feed.

  ## Entry Format

  Each entry is a map with:
  - `id`: The hook identifier (e.g., "column_hook_id:hook_id")
  - `name`: Human-readable hook name
  - `status`: Final status (completed, failed, cancelled, skipped)
  - `executed_at`: ISO8601 timestamp when the hook finished

  ## Usage

  Called by TaskActor when a hook completes execution (regardless of outcome).
  """

  use Ash.Resource.Change

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    hook_entry = Ash.Changeset.get_argument(changeset, :hook_entry)
    current_history = Ash.Changeset.get_data(changeset, :hook_history) || []

    if is_nil(hook_entry) do
      changeset
    else
      # Append to end of history (oldest first)
      updated_history = current_history ++ [hook_entry]
      Ash.Changeset.change_attribute(changeset, :hook_history, updated_history)
    end
  end
end
