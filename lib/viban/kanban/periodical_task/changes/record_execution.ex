defmodule Viban.Kanban.PeriodicalTask.Changes.RecordExecution do
  @moduledoc """
  Records an execution and calculates the next run time (SQLite version).
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    task_id = Ash.Changeset.get_argument(changeset, :task_id)
    current_count = Ash.Changeset.get_data(changeset, :execution_count) || 0
    schedule = Ash.Changeset.get_data(changeset, :schedule)

    changeset
    |> Ash.Changeset.change_attribute(:execution_count, current_count + 1)
    |> Ash.Changeset.change_attribute(:last_executed_at, DateTime.utc_now())
    |> Ash.Changeset.change_attribute(:last_created_task_id, task_id)
    |> maybe_set_next_execution(schedule)
  end

  defp maybe_set_next_execution(changeset, schedule) do
    case Crontab.CronExpression.Parser.parse(schedule) do
      {:ok, cron} ->
        case Crontab.Scheduler.get_next_run_date(cron, NaiveDateTime.utc_now()) do
          {:ok, naive} ->
            next_at = DateTime.from_naive!(naive, "Etc/UTC")
            Ash.Changeset.change_attribute(changeset, :next_execution_at, next_at)

          {:error, _} ->
            changeset
        end

      {:error, _} ->
        changeset
    end
  end
end
