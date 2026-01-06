defmodule Viban.Workers.SubtaskGenerationWorker do
  @moduledoc """
  Oban worker for AI-powered subtask generation.

  This worker takes a parent task and uses Claude to break it down
  into smaller, actionable subtasks.
  """

  use Oban.Worker,
    queue: :generate_subtasks,
    max_attempts: 3

  alias Viban.Kanban.Task
  alias Viban.LLM.SubtaskGenerationService

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"task_id" => task_id}}) do
    Logger.info("[SubtaskGenerationWorker] Starting subtask generation for task #{task_id}")

    try do
      do_perform(task_id)
    rescue
      exception ->
        Logger.error(
          "[SubtaskGenerationWorker] Exception during subtask generation for task #{task_id}: #{Exception.message(exception)}"
        )

        mark_task_failed(task_id, Exception.message(exception))
        reraise exception, __STACKTRACE__
    end
  end

  defp do_perform(task_id) do
    with {:ok, task} <- Task.get(task_id),
         :ok <- update_status(task, :generating, "Breaking down task into subtasks..."),
         {:ok, subtask_ids} <- SubtaskGenerationService.generate_subtasks(task) do
      Task.set_generation_status(task, %{subtask_generation_status: :completed})
      Task.mark_as_parent(task)
      Task.update_agent_status(task, %{agent_status: :idle, agent_status_message: nil})

      Logger.info("[SubtaskGenerationWorker] Successfully generated #{length(subtask_ids)} subtasks for task #{task_id}")

      Phoenix.PubSub.broadcast(
        Viban.PubSub,
        "task:#{task_id}:subtasks",
        {:subtasks_generated, subtask_ids}
      )

      :ok
    else
      {:error, reason} ->
        Logger.error("[SubtaskGenerationWorker] Failed to generate subtasks for task #{task_id}: #{inspect(reason)}")

        mark_task_failed(task_id, inspect(reason))
        {:error, reason}
    end
  end

  defp mark_task_failed(task_id, reason) do
    case Task.get(task_id) do
      {:ok, task} ->
        Task.set_generation_status(task, %{subtask_generation_status: :failed})

        Task.update_agent_status(task, %{
          agent_status: :error,
          agent_status_message: "Failed to generate subtasks: #{reason}"
        })

      _ ->
        nil
    end
  end

  defp update_status(task, generation_status, message) do
    with {:ok, _} <-
           Task.set_generation_status(task, %{subtask_generation_status: generation_status}),
         {:ok, _} <-
           Task.update_agent_status(task, %{
             agent_status: :thinking,
             agent_status_message: message
           }) do
      :ok
    end
  end
end
