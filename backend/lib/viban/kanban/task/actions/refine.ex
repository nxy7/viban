defmodule Viban.Kanban.Task.Actions.Refine do
  @moduledoc """
  Action to refine a task's description using an LLM.

  This action:
  1. Retrieves the task by ID
  2. Sends the title and description to the LLM for refinement
  3. Updates the task with the refined description

  ## Return Value

  On success, returns a map with:
  - `id` - The task ID
  - `title` - The task title (unchanged)
  - `description` - The refined description
  - `refined` - Always `true` on success

  ## Errors

  Returns an error tuple if:
  - The task is not found
  - The LLM refinement fails
  - The task update fails
  """

  use Ash.Resource.Actions.Implementation

  require Logger

  @impl true
  @spec run(Ash.ActionInput.t(), keyword(), Ash.Resource.Actions.Implementation.context()) ::
          {:ok, map()} | {:error, term()}
  def run(input, _opts, _context) do
    task_id = input.arguments.task_id

    with {:ok, task} <- fetch_task(task_id),
         {:ok, refined} <- refine_description(task),
         {:ok, updated_task} <- update_task(task, refined) do
      {:ok, build_result(updated_task)}
    end
  end

  @spec fetch_task(Ecto.UUID.t()) :: {:ok, Viban.Kanban.Task.t()} | {:error, String.t()}
  defp fetch_task(task_id) do
    case Viban.Kanban.Task.get(task_id) do
      {:ok, task} ->
        {:ok, task}

      {:error, %Ash.Error.Query.NotFound{}} ->
        {:error, "Task not found: #{task_id}"}

      {:error, reason} ->
        Logger.error("Failed to fetch task #{task_id}: #{inspect(reason)}")
        {:error, "Failed to fetch task"}
    end
  end

  @spec refine_description(Viban.Kanban.Task.t()) :: {:ok, String.t()} | {:error, String.t()}
  defp refine_description(task) do
    case Viban.LLM.TaskRefiner.refine(task.title, task.description) do
      {:ok, refined} ->
        {:ok, refined}

      {:error, reason} ->
        Logger.error("LLM refinement failed for task #{task.id}: #{inspect(reason)}")
        {:error, "Failed to refine description: #{inspect(reason)}"}
    end
  end

  @spec update_task(Viban.Kanban.Task.t(), String.t()) ::
          {:ok, Viban.Kanban.Task.t()} | {:error, String.t()}
  defp update_task(task, refined_description) do
    case Viban.Kanban.Task.update(task, %{description: refined_description}) do
      {:ok, updated} ->
        {:ok, updated}

      {:error, reason} ->
        Logger.error("Failed to update task #{task.id} with refined description: #{inspect(reason)}")

        {:error, "Failed to save refined description"}
    end
  end

  @spec build_result(Viban.Kanban.Task.t()) :: map()
  defp build_result(task) do
    %{
      id: task.id,
      title: task.title,
      description: task.description,
      refined: true
    }
  end
end
