defmodule Viban.Kanban.Task.Actions.GenerateSubtasks do
  @moduledoc """
  Enqueues an Oban job to generate subtasks for a parent task using AI.

  This action immediately sets the task's subtask_generation_status to :generating
  and enqueues a background job to perform the actual generation.
  The UI updates via Electric sync when subtasks are created.
  """

  use Ash.Resource.Actions.Implementation

  require Logger

  alias Viban.Kanban.Task
  alias Viban.Workers.SubtaskGenerationWorker

  @impl true
  def run(input, _opts, _context) do
    task_id = input.arguments.task_id

    with {:ok, task} <- fetch_task(task_id),
         {:ok, _job} <- enqueue_generation(task),
         {:ok, _} <- set_generating_status(task) do
      {:ok, %{message: "Subtask generation started", task_id: task.id}}
    end
  end

  defp fetch_task(task_id) do
    case Task.get(task_id) do
      {:ok, task} -> {:ok, task}
      {:error, _} -> {:error, "Task not found"}
    end
  end

  defp enqueue_generation(task) do
    case %{task_id: task.id}
         |> SubtaskGenerationWorker.new()
         |> Oban.insert() do
      {:ok, job} ->
        {:ok, job}

      {:error, reason} ->
        Logger.error("Failed to enqueue subtask generation: #{inspect(reason)}")
        {:error, "Failed to start subtask generation"}
    end
  end

  defp set_generating_status(task) do
    Task.set_generation_status(task, %{subtask_generation_status: :generating})
  end
end
