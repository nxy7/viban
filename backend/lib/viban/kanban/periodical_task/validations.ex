defmodule Viban.Kanban.PeriodicalTask.Validations do
  @moduledoc """
  Validations for PeriodicalTask resource.
  """

  use Ash.Resource.Validation

  defmodule ValidCronExpression do
    @moduledoc """
    Validates that the schedule attribute is a valid cron expression.
    """

    use Ash.Resource.Validation

    @impl true
    def init(opts), do: {:ok, opts}

    @impl true
    def validate(changeset, _opts, _context) do
      case Ash.Changeset.get_attribute(changeset, :schedule) do
        nil ->
          :ok

        schedule ->
          case Crontab.CronExpression.Parser.parse(schedule) do
            {:ok, _cron} ->
              :ok

            {:error, _reason} ->
              {:error, field: :schedule, message: "is not a valid cron expression (e.g., '0 9 * * 1-5')"}
          end
      end
    end
  end
end
