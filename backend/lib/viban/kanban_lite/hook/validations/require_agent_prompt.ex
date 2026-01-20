defmodule Viban.KanbanLite.Hook.Validations.RequireAgentPrompt do
  @moduledoc """
  Validates that agent hooks have a prompt (SQLite version).
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    prompt = Ash.Changeset.get_attribute(changeset, :agent_prompt)

    if is_nil(prompt) or prompt == "" do
      {:error, field: :agent_prompt, message: "Agent prompt is required for agent hooks"}
    else
      :ok
    end
  end
end
