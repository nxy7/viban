defmodule Viban.KanbanLite.Task.Actions.GenerateSubtasks do
  @moduledoc """
  Generates subtasks for a parent task using AI (SQLite version).
  """

  use Ash.Resource.Actions.Implementation

  alias Viban.Kanban.Task.Actions.GenerateSubtasks, as: KanbanGenerateSubtasks

  @impl true
  def run(input, opts, context) do
    KanbanGenerateSubtasks.run(input, opts, context)
  end
end
