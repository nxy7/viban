defmodule Viban.Workers.PeriodicalTaskWorker do
  @moduledoc """
  Oban worker that creates tasks from periodical task definitions.

  This worker is triggered by the PeriodicalTaskScheduler when a periodical task
  is due for execution. It:
  1. Checks if the previous execution is still in progress (skip if yes)
  2. Creates a new task in the Todo column
  3. Records the execution on the periodical task
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 60, keys: [:periodical_task_id]]

  alias Viban.Kanban.Actors.ColumnLookup
  alias Viban.Kanban.PeriodicalTask
  alias Viban.Kanban.Task

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"periodical_task_id" => periodical_task_id}}) do
    Logger.info("[PeriodicalTaskWorker] Processing periodical task #{periodical_task_id}")

    with {:ok, periodical_task} <- PeriodicalTask.get(periodical_task_id),
         :ok <- check_enabled(periodical_task),
         :ok <- check_not_running(periodical_task),
         {:ok, todo_column_id} <- find_todo_column(periodical_task.board_id),
         {:ok, task} <- create_task(periodical_task, todo_column_id),
         {:ok, _} <- PeriodicalTask.record_execution(periodical_task, task.id) do
      Logger.info("[PeriodicalTaskWorker] Created task '#{task.title}' for periodical task #{periodical_task_id}")

      :ok
    else
      {:skip, reason} ->
        Logger.info("[PeriodicalTaskWorker] Skipping periodical task #{periodical_task_id}: #{reason}")

        :ok

      {:error, reason} ->
        Logger.error(
          "[PeriodicalTaskWorker] Failed to create task for periodical task #{periodical_task_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp check_enabled(%PeriodicalTask{enabled: false}), do: {:skip, "disabled"}
  defp check_enabled(_), do: :ok

  defp check_not_running(%PeriodicalTask{last_created_task_id: nil}), do: :ok

  defp check_not_running(%PeriodicalTask{last_created_task_id: task_id}) do
    case Task.get(task_id) do
      {:ok, task} ->
        if ColumnLookup.in_progress_column?(task.column_id) do
          {:skip, "previous task still in progress"}
        else
          :ok
        end

      {:error, _} ->
        :ok
    end
  end

  defp find_todo_column(board_id) do
    case ColumnLookup.find_column_by_name(board_id, "todo") do
      {:ok, column_id} ->
        {:ok, column_id}

      {:error, :not_found} ->
        case ColumnLookup.find_column_by_name(board_id, "to do") do
          {:ok, column_id} -> {:ok, column_id}
          {:error, :not_found} -> {:error, :todo_column_not_found}
        end
    end
  end

  defp create_task(periodical_task, column_id) do
    execution_number = periodical_task.execution_count + 1
    title = "##{execution_number} #{periodical_task.title}"
    short_id = String.slice(periodical_task.id, 0..7)
    custom_branch = "periodical-#{short_id}-#{execution_number}"

    Task.create(%{
      title: title,
      description: periodical_task.description,
      column_id: column_id,
      custom_branch_name: custom_branch,
      periodical_task_id: periodical_task.id,
      auto_start: true,
      position: DateTime.utc_now() |> DateTime.to_unix(:millisecond) |> Kernel./(1.0)
    })
  end
end
