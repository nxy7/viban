defmodule Viban.Kanban.ColumnHook.Validations.RequireRemovable do
  @moduledoc """
  Validation that prevents deletion of non-removable column hooks.

  When `removable` is `false`, the hook cannot be deleted. This is used
  for core system hooks like the AI execution hook that should always
  be present on certain columns.

  ## Error

  Returns an error on the `:removable` field with the message
  "This hook cannot be removed".
  """

  use Ash.Resource.Validation

  @impl true
  @spec validate(Ash.Changeset.t(), keyword(), Ash.Resource.Validation.Context.t()) ::
          :ok | {:error, term()}
  def validate(changeset, _opts, _context) do
    column_hook = changeset.data

    if column_hook.removable == false do
      {:error, field: :removable, message: "This hook cannot be removed"}
    else
      :ok
    end
  end
end
