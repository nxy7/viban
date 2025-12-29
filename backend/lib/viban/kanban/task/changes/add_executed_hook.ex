defmodule Viban.Kanban.Task.Changes.AddExecutedHook do
  @moduledoc """
  Ash change that adds a hook ID to the executed_hooks list.

  This is used for execute_once tracking - once a hook is in this list,
  it won't be executed again for this task.

  ## Idempotency

  This change is idempotent - adding the same hook ID multiple times
  will only store it once in the list.
  """

  use Ash.Resource.Change

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    column_hook_id = Ash.Changeset.get_argument(changeset, :column_hook_id)
    current_hooks = Ash.Changeset.get_data(changeset, :executed_hooks) || []

    if is_nil(column_hook_id) or column_hook_id in current_hooks do
      changeset
    else
      updated_hooks = [column_hook_id | current_hooks]
      Ash.Changeset.change_attribute(changeset, :executed_hooks, updated_hooks)
    end
  end
end
