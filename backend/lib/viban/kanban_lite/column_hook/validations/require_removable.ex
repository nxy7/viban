defmodule Viban.KanbanLite.ColumnHook.Validations.RequireRemovable do
  @moduledoc """
  Validates that the column hook is removable before deletion (SQLite version).
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    removable = Ash.Changeset.get_data(changeset, :removable)

    if removable == false do
      {:error, message: "This hook cannot be removed"}
    else
      :ok
    end
  end
end
