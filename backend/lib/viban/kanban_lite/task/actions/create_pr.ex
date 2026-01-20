defmodule Viban.KanbanLite.Task.Actions.CreatePR do
  @moduledoc """
  Creates a GitHub pull request for the task (SQLite version).
  """

  use Ash.Resource.Actions.Implementation

  alias Viban.Kanban.Task.Actions.CreatePR, as: KanbanCreatePR

  @impl true
  def run(input, opts, context) do
    KanbanCreatePR.run(input, opts, context)
  end
end
