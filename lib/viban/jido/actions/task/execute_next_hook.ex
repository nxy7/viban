defmodule Viban.Jido.Actions.Task.ExecuteNextHook do
  use Jido.Action,
    name: "execute_next_hook",
    description: "Pop and execute the next pending hook for a task",
    schema: [
      task_id: [type: :string, required: true],
      board_id: [type: :string, required: true]
    ]

  alias Viban.Kanban.HookExecution

  require Logger

  def run(params, _context) do
    task_id = params.task_id

    case HookExecution.pending_for_task(task_id) do
      {:ok, [next_execution | _]} ->
        {:ok, %{action: :execute_hook, execution_id: next_execution.id, hook_name: next_execution.hook_name}}

      {:ok, []} ->
        {:ok, %{action: :finalize, status: :all_hooks_complete}}

      {:error, reason} ->
        Logger.error("Failed to get pending hooks: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
