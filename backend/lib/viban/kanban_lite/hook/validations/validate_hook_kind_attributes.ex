defmodule Viban.KanbanLite.Hook.Validations.ValidateHookKindAttributes do
  @moduledoc """
  Validates that hook has correct attributes for its kind (SQLite version).
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    hook_kind = Ash.Changeset.get_attribute(changeset, :hook_kind)
    command = Ash.Changeset.get_attribute(changeset, :command)
    agent_prompt = Ash.Changeset.get_attribute(changeset, :agent_prompt)

    case hook_kind do
      :script ->
        if is_nil(command) or command == "" do
          {:error, field: :command, message: "Command is required for script hooks"}
        else
          :ok
        end

      :agent ->
        if is_nil(agent_prompt) or agent_prompt == "" do
          {:error, field: :agent_prompt, message: "Agent prompt is required for agent hooks"}
        else
          :ok
        end

      _ ->
        :ok
    end
  end
end
