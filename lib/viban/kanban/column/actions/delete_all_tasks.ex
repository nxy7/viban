defmodule Viban.Kanban.Column.Actions.DeleteAllTasks do
  @moduledoc """
  Deletes all tasks in a column and returns the count.
  """

  use Ash.Resource.Actions.Implementation

  alias Viban.Kanban.Task

  @impl true
  def run(_input, opts, _context) do
    column_id = opts[:arguments][:column_id]

    tasks = Task.for_column!(column_id)
    count = length(tasks)

    Enum.each(tasks, fn task ->
      Task.destroy!(task)
    end)

    {:ok, count}
  end
end
