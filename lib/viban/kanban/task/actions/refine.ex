defmodule Viban.Kanban.Task.Actions.Refine do
  @moduledoc """
  Refines task description using LLM (SQLite version).
  """

  use Ash.Resource.Actions.Implementation

  alias Viban.Kanban.Task.Actions.Refine, as: KanbanRefine

  @impl true
  def run(input, opts, context) do
    KanbanRefine.run(input, opts, context)
  end
end
