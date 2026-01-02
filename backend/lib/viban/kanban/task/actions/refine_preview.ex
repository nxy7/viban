defmodule Viban.Kanban.Task.Actions.RefinePreview do
  @moduledoc """
  Previews a refined task description without saving.

  This action takes a title and optional description, sends them to the LLM
  for refinement, and returns the result without creating or modifying any task.
  Used in the CreateTaskModal to preview refinements before committing.
  """

  use Ash.Resource.Actions.Implementation

  require Logger

  @impl true
  def run(input, _opts, _context) do
    title = input.arguments.title
    description = Map.get(input.arguments, :description)

    case Viban.LLM.TaskRefiner.refine(title, description) do
      {:ok, refined} ->
        {:ok, %{refined_description: refined}}

      {:error, reason} ->
        Logger.error("LLM refinement preview failed: #{inspect(reason)}")
        {:error, "Failed to refine description: #{inspect(reason)}"}
    end
  end
end
