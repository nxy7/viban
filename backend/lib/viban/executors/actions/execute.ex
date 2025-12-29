defmodule Viban.Executors.Actions.Execute do
  @moduledoc """
  Action module for starting an executor for a task.

  This action:
  1. Verifies the executor type is available on the system
  2. Updates the task status to executing
  3. Starts the executor runner process
  4. Returns the runner information
  """

  use Ash.Resource.Actions.Implementation

  alias Viban.Executors.{Registry, Runner}
  alias Viban.Kanban.Task

  require Logger

  @impl true
  def run(input, _opts, _context) do
    %{
      task_id: task_id,
      prompt: prompt,
      executor_type: executor_type
    } = input.arguments

    working_directory = Map.get(input.arguments, :working_directory)
    images = Map.get(input.arguments, :images, [])

    with :ok <- verify_executor_available(executor_type),
         :ok <- update_task_status(task_id, executor_type),
         {:ok, pid} <- start_runner(task_id, executor_type, prompt, working_directory, images) do
      {:ok,
       %{
         status: :started,
         pid: inspect(pid),
         task_id: task_id,
         executor_type: executor_type
       }}
    end
  end

  defp verify_executor_available(executor_type) do
    if Registry.available?(executor_type) do
      :ok
    else
      {:error,
       Ash.Error.Invalid.exception(
         message: "Executor #{executor_type} is not available on this system"
       )}
    end
  end

  defp update_task_status(task_id, executor_type) do
    case Task.get(task_id) do
      {:ok, task} ->
        with {:ok, _} <-
               Task.update_agent_status(task, %{
                 agent_status: :executing,
                 agent_status_message: "Starting #{executor_type}..."
               }),
             {:ok, updated_task} <- Task.get(task_id),
             {:ok, _} <- Task.set_in_progress(updated_task, %{in_progress: true}) do
          :ok
        else
          {:error, reason} ->
            Logger.warning("[Execute] Failed to update task status: #{inspect(reason)}")
            # Continue anyway - task status update is not critical
            :ok
        end

      {:error, _} ->
        # Task not found, but we'll let the runner handle this
        Logger.warning("[Execute] Task #{task_id} not found during status update")
        :ok
    end
  end

  defp start_runner(task_id, executor_type, prompt, working_directory, images) do
    case Runner.start(
           task_id: task_id,
           executor_type: executor_type,
           prompt: prompt,
           working_directory: working_directory,
           images: images
         ) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, reason} ->
        {:error,
         Ash.Error.Invalid.exception(message: "Failed to start executor: #{inspect(reason)}")}
    end
  end
end
