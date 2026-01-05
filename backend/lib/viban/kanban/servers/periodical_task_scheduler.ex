defmodule Viban.Kanban.Servers.PeriodicalTaskScheduler do
  @moduledoc """
  GenServer that periodically checks for due periodical tasks and enqueues
  Oban jobs to create the actual tasks.

  Runs every 60 seconds and queries for enabled periodical tasks where
  `next_execution_at <= now()`.
  """

  use GenServer

  alias Viban.Kanban.PeriodicalTask
  alias Viban.Workers.PeriodicalTaskWorker

  require Logger

  @check_interval :timer.seconds(60)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("[PeriodicalTaskScheduler] Starting scheduler")
    schedule_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_due_tasks, state) do
    check_and_enqueue_due_tasks()
    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_due_tasks, @check_interval)
  end

  defp check_and_enqueue_due_tasks do
    now = DateTime.utc_now()

    case get_due_periodical_tasks(now) do
      {:ok, periodical_tasks} ->
        Enum.each(periodical_tasks, &enqueue_task/1)

        if length(periodical_tasks) > 0 do
          Logger.info(
            "[PeriodicalTaskScheduler] Enqueued #{length(periodical_tasks)} periodical tasks"
          )
        end

      {:error, reason} ->
        Logger.error(
          "[PeriodicalTaskScheduler] Failed to query periodical tasks: #{inspect(reason)}"
        )
    end
  end

  defp get_due_periodical_tasks(now) do
    import Ash.Query

    PeriodicalTask
    |> filter(enabled == true)
    |> filter(not is_nil(next_execution_at))
    |> filter(next_execution_at <= ^now)
    |> Ash.read()
  end

  defp enqueue_task(periodical_task) do
    %{periodical_task_id: periodical_task.id}
    |> PeriodicalTaskWorker.new()
    |> Oban.insert()
    |> case do
      {:ok, _job} ->
        Logger.debug(
          "[PeriodicalTaskScheduler] Enqueued job for periodical task #{periodical_task.id}"
        )

      {:error, reason} ->
        Logger.error(
          "[PeriodicalTaskScheduler] Failed to enqueue job for periodical task #{periodical_task.id}: #{inspect(reason)}"
        )
    end
  end
end
