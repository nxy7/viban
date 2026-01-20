defmodule Viban.KanbanLite.Hook.Validations.RequireCommand do
  @moduledoc """
  Validates that script hooks have a command (SQLite version).
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    command = Ash.Changeset.get_attribute(changeset, :command)

    if is_nil(command) or command == "" do
      {:error, field: :command, message: "Command is required for script hooks"}
    else
      :ok
    end
  end
end
