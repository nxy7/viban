defmodule Viban.Kanban.PeriodicalTask.Changes do
  @moduledoc """
  Changes for PeriodicalTask resource.
  """

  defmodule CalculateNextExecution do
    @moduledoc """
    Calculates the next_execution_at based on the schedule cron expression.
    Only runs when schedule changes or on create.
    """

    use Ash.Resource.Change

    @impl true
    def init(opts), do: {:ok, opts}

    @impl true
    def change(changeset, _opts, _context) do
      schedule = Ash.Changeset.get_attribute(changeset, :schedule)
      enabled = Ash.Changeset.get_attribute(changeset, :enabled)

      cond do
        is_nil(schedule) ->
          changeset

        enabled == false ->
          Ash.Changeset.force_change_attribute(changeset, :next_execution_at, nil)

        true ->
          case calculate_next_run(schedule) do
            {:ok, next_run} ->
              Ash.Changeset.force_change_attribute(changeset, :next_execution_at, next_run)

            {:error, _reason} ->
              changeset
          end
      end
    end

    defp calculate_next_run(schedule) do
      with {:ok, cron} <- Crontab.CronExpression.Parser.parse(schedule),
           {:ok, next_run} <- Crontab.Scheduler.get_next_run_date(cron) do
        {:ok, DateTime.from_naive!(next_run, "Etc/UTC")}
      end
    end
  end

  defmodule RecordExecution do
    @moduledoc """
    Records that an execution occurred:
    - Increments execution_count
    - Sets last_executed_at to now
    - Stores the created task_id in last_created_task_id
    - Calculates next_execution_at
    """

    use Ash.Resource.Change

    @impl true
    def init(opts), do: {:ok, opts}

    @impl true
    def change(changeset, _opts, _context) do
      task_id = Ash.Changeset.get_argument(changeset, :task_id)
      current_count = Ash.Changeset.get_attribute(changeset, :execution_count) || 0
      schedule = Ash.Changeset.get_attribute(changeset, :schedule)
      now = DateTime.utc_now()

      changeset
      |> Ash.Changeset.force_change_attribute(:execution_count, current_count + 1)
      |> Ash.Changeset.force_change_attribute(:last_executed_at, now)
      |> Ash.Changeset.force_change_attribute(:last_created_task_id, task_id)
      |> maybe_set_next_execution(schedule)
    end

    defp maybe_set_next_execution(changeset, nil), do: changeset

    defp maybe_set_next_execution(changeset, schedule) do
      case calculate_next_run(schedule) do
        {:ok, next_run} ->
          Ash.Changeset.force_change_attribute(changeset, :next_execution_at, next_run)

        {:error, _reason} ->
          changeset
      end
    end

    defp calculate_next_run(schedule) do
      with {:ok, cron} <- Crontab.CronExpression.Parser.parse(schedule),
           {:ok, next_run} <- Crontab.Scheduler.get_next_run_date(cron) do
        {:ok, DateTime.from_naive!(next_run, "Etc/UTC")}
      end
    end
  end
end
