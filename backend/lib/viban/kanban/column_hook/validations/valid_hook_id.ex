defmodule Viban.Kanban.ColumnHook.Validations.ValidHookId do
  @moduledoc """
  Ash validation that ensures the hook_id is valid.

  A valid hook_id is either:
  - A valid UUID referencing a custom Hook in the database
  - A system hook ID (e.g., "system:refine-prompt") that exists in the registry
  """

  use Ash.Resource.Validation

  alias Viban.Kanban.ColumnHook

  @impl true
  def atomic(_changeset, _opts, _context) do
    # Return :ok to skip atomic validation - will run non-atomic validate/3
    # Cannot be atomic because it calls ColumnHook.valid_hook_id?/1
    :ok
  end

  @impl true
  def validate(changeset, _opts, _context) do
    hook_id = Ash.Changeset.get_attribute(changeset, :hook_id)

    if ColumnHook.valid_hook_id?(hook_id) do
      :ok
    else
      {:error, field: :hook_id, message: "must be a valid UUID or system hook ID"}
    end
  end
end
