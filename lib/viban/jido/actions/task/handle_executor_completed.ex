defmodule Viban.Jido.Actions.Task.HandleExecutorCompleted do
  use Jido.Action,
    name: "handle_executor_completed",
    description: "Handle executor completion: process remaining messages or finalize",
    schema: [
      task_id: [type: :string, required: true],
      exit_code: [type: :integer, required: true]
    ]

  alias Viban.Kanban.SystemHooks.ExecuteAIHook
  alias Viban.Kanban.Task

  require Logger

  def run(params, _context) do
    task_id = params.task_id
    exit_code = params.exit_code

    has_more_messages =
      case Task.get(task_id) do
        {:ok, task} -> (task.message_queue || []) != []
        _ -> false
      end

    if has_more_messages do
      case ExecuteAIHook.process_next_message(task_id) do
        {:await_executor, _task_id} ->
          {:ok, %{status: :processing_next_message}}

        _ ->
          finalize_executor(task_id, exit_code)
      end
    else
      finalize_executor(task_id, exit_code)
    end
  end

  defp finalize_executor(task_id, exit_code) do
    case Task.get(task_id) do
      {:ok, task} ->
        agent_status = if exit_code == 0, do: :idle, else: :error

        message =
          if exit_code == 0,
            do: "Completed successfully",
            else: "Failed with exit code #{exit_code}"

        Task.update_agent_status(task, %{agent_status: agent_status, agent_status_message: message})
        Task.set_in_progress(task, %{in_progress: false})

        {:ok, %{status: :finalized, agent_status: agent_status}}

      {:error, _} ->
        {:ok, %{status: :task_not_found}}
    end
  end
end
