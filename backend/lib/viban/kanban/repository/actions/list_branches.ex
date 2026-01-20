defmodule Viban.Kanban.Repository.Actions.ListBranches do
  @moduledoc """
  Lists branches for a task's repository (SQLite version).
  """

  use Ash.Resource.Actions.Implementation

  alias Viban.Kanban.Repository.Actions.ListBranches, as: KanbanListBranches

  @impl true
  def run(input, opts, context) do
    KanbanListBranches.run(input, opts, context)
  end
end
