defmodule Viban.Kanban.Column.Actions.DeleteAllTasks do
  @moduledoc """
  Action to delete all tasks in a column.

  This action:
  1. Queries all tasks belonging to the specified column
  2. Destroys each task individually (to trigger cascade deletions)
  3. Returns the count of deleted tasks

  ## Return Value

  On success, returns the number of tasks deleted.

  ## Errors

  Returns an error if any task deletion fails.
  """

  use Ash.Resource.Actions.Implementation

  import Ash.Query

  alias Viban.Kanban.Task

  @impl true
  @spec run(Ash.ActionInput.t(), keyword(), Ash.Resource.Actions.Implementation.context()) ::
          {:ok, integer()} | {:error, term()}
  def run(input, _opts, _context) do
    column_id = input.arguments.column_id

    with {:ok, tasks} <- fetch_column_tasks(column_id),
         {:ok, count} <- delete_tasks(tasks) do
      {:ok, count}
    end
  end

  defp fetch_column_tasks(column_id) do
    Task
    |> filter(column_id == ^column_id)
    |> Ash.read()
  end

  defp delete_tasks(tasks) do
    results = Enum.map(tasks, &Task.destroy/1)

    case find_first_error(results) do
      nil -> {:ok, length(tasks)}
      error -> error
    end
  end

  defp find_first_error(results) do
    Enum.find_value(results, fn
      {:ok, _} -> nil
      {:error, _} = error -> error
    end)
  end
end
