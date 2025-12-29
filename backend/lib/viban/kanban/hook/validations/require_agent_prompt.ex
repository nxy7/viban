defmodule Viban.Kanban.Hook.Validations.RequireAgentPrompt do
  @moduledoc """
  Ash validation that ensures agent hooks have an agent_prompt defined.

  This validation is applied to create actions that set `hook_kind` to `:agent`.
  """

  use Ash.Resource.Validation

  @impl true
  def atomic(_changeset, _opts, _context) do
    # Return :ok to skip atomic validation - will run non-atomic validate/3
    :ok
  end

  @impl true
  def validate(changeset, _opts, _context) do
    agent_prompt = Ash.Changeset.get_attribute(changeset, :agent_prompt)

    if is_nil(agent_prompt) or agent_prompt == "" do
      {:error, field: :agent_prompt, message: "is required for agent hooks"}
    else
      :ok
    end
  end
end
