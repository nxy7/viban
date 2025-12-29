defmodule Viban.Kanban.Hook.Validations.ValidateHookKindAttributes do
  @moduledoc """
  Ash validation that ensures hook attributes are valid based on hook_kind.

  For updates, this validates that:
  - Script hooks maintain a non-empty command
  - Agent hooks maintain a non-empty agent_prompt
  """

  use Ash.Resource.Validation

  @impl true
  def atomic(_changeset, _opts, _context) do
    # Return :ok to skip atomic validation - will run non-atomic validate/3
    :ok
  end

  @impl true
  def validate(changeset, _opts, _context) do
    hook_kind = Ash.Changeset.get_attribute(changeset, :hook_kind)
    command = Ash.Changeset.get_attribute(changeset, :command)
    agent_prompt = Ash.Changeset.get_attribute(changeset, :agent_prompt)

    case hook_kind do
      :script ->
        if is_nil(command) or command == "" do
          {:error, field: :command, message: "is required for script hooks"}
        else
          :ok
        end

      :agent ->
        if is_nil(agent_prompt) or agent_prompt == "" do
          {:error, field: :agent_prompt, message: "is required for agent hooks"}
        else
          :ok
        end

      _ ->
        :ok
    end
  end
end
