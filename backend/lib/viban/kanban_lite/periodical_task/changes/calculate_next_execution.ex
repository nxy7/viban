defmodule Viban.KanbanLite.PeriodicalTask.Changes.CalculateNextExecution do
  @moduledoc """
  Calculates the next execution time from the cron schedule (SQLite version).
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    schedule = Ash.Changeset.get_attribute(changeset, :schedule)
    enabled = Ash.Changeset.get_attribute(changeset, :enabled)

    if enabled && schedule do
      case calculate_next(schedule) do
        {:ok, next_at} ->
          Ash.Changeset.change_attribute(changeset, :next_execution_at, next_at)

        {:error, _} ->
          changeset
      end
    else
      Ash.Changeset.change_attribute(changeset, :next_execution_at, nil)
    end
  end

  defp calculate_next(schedule) do
    case Crontab.CronExpression.Parser.parse(schedule) do
      {:ok, cron} ->
        case Crontab.Scheduler.get_next_run_date(cron, NaiveDateTime.utc_now()) do
          {:ok, naive} ->
            {:ok, DateTime.from_naive!(naive, "Etc/UTC")}

          error ->
            error
        end

      error ->
        error
    end
  end
end
