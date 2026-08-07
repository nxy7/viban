defmodule Viban.Jido.Actions.RefinePrompt do
  use Jido.Action,
    name: "refine_prompt",
    description: "Refine a task description with success criteria and clear requirements using AI",
    schema: [
      task_id: [type: :string, required: true]
    ]

  alias Viban.Kanban.Task

  def run(params, _context) do
    case Task.get(params.task_id) do
      {:ok, task} ->
        if task.description && String.length(task.description) > 500 do
          {:ok, %{status: :skipped, reason: :already_detailed}}
        else
          {:ok, %{status: :queued, task_id: task.id}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
