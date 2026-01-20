defmodule Viban.KanbanLite.ColumnHook.Validations.ValidHookId do
  @moduledoc """
  Validates that the hook_id is a valid UUID or system hook ID (SQLite version).
  """

  use Ash.Resource.Validation

  alias Viban.KanbanLite.ColumnHook

  @impl true
  def validate(changeset, _opts, _context) do
    hook_id = Ash.Changeset.get_attribute(changeset, :hook_id)

    if ColumnHook.valid_hook_id?(hook_id) do
      :ok
    else
      {:error, field: :hook_id, message: "Invalid hook ID"}
    end
  end
end
