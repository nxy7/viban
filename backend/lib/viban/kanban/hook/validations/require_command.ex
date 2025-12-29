defmodule Viban.Kanban.Hook.Validations.RequireCommand do
  @moduledoc """
  Ash validation that ensures script hooks have a command defined.

  This validation is applied to create actions that set `hook_kind` to `:script`.
  """

  use Ash.Resource.Validation

  @impl true
  def atomic(_changeset, _opts, _context) do
    # Return :ok to skip atomic validation - will run non-atomic validate/3
    :ok
  end

  @impl true
  def validate(changeset, _opts, _context) do
    command = Ash.Changeset.get_attribute(changeset, :command)

    if is_nil(command) or command == "" do
      {:error, field: :command, message: "is required for script hooks"}
    else
      :ok
    end
  end
end
