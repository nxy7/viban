defmodule Viban.Jido.Actions.Task.StopExecution do
  use Jido.Action,
    name: "stop_execution",
    description: "Stop all hook and executor execution for a task",
    schema: [
      task_id: [type: :string, required: true]
    ]

  alias Viban.Kanban.HookExecution
  alias Viban.Kanban.Task

  require Logger

  def run(params, _context) do
    task_id = params.task_id

    cancel_pending_executions(task_id)
    clear_task_status(task_id)

    {:ok, %{status: :stopped}}
  end

  defp cancel_pending_executions(task_id) do
    case HookExecution.active_for_task(task_id) do
      {:ok, executions} ->
        Enum.each(executions, fn exec ->
          HookExecution.cancel(exec, %{skip_reason: :user_cancelled})
        end)

      {:error, _reason} ->
        :ok
    end
  end

  defp clear_task_status(task_id) do
    case Task.get(task_id) do
      {:ok, task} ->
        Task.update_agent_status(task, %{agent_status: :idle, agent_status_message: nil})
        Task.set_in_progress(task, %{in_progress: false})
        Task.clear_error(task)

      _ ->
        :ok
    end
  end
end
