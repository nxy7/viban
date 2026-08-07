defmodule Viban.Jido.Actions.ExecuteAI do
  use Jido.Action,
    name: "execute_ai",
    description: "Process queued messages for a task using an AI executor (Claude Code, Gemini CLI)",
    schema: [
      task_id: [type: :string, required: true],
      executor_type: [type: {:in, [:claude_code, :gemini_cli]}, default: :claude_code]
    ]

  alias Viban.Kanban.SystemHooks.ExecuteAIHook
  alias Viban.Kanban.Task

  def run(params, _context) do
    with {:ok, task} <- Task.get(params.task_id) do
      case ExecuteAIHook.execute(task, nil, []) do
        {:await_executor, task_id} -> {:ok, %{status: :awaiting_executor, task_id: task_id}}
        {:error, reason} -> {:error, reason}
      end
    end
  end
end
