defmodule Viban.Kanban.PeriodicalTask.Validations.ValidCronExpression do
  @moduledoc """
  Validates that the schedule is a valid cron expression (SQLite version).
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    schedule = Ash.Changeset.get_attribute(changeset, :schedule)

    if is_nil(schedule) do
      :ok
    else
      case Crontab.CronExpression.Parser.parse(schedule) do
        {:ok, _} -> :ok
        {:error, _} -> {:error, field: :schedule, message: "Invalid cron expression"}
      end
    end
  end
end
