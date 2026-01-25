defmodule Viban.Kanban.Task.Actions.RefinePreview do
  @moduledoc """
  Previews refined description without saving (SQLite version).
  """

  use Ash.Resource.Actions.Implementation

  alias Viban.Kanban.Task.Actions.RefinePreview, as: KanbanRefinePreview

  @impl true
  def run(input, opts, context) do
    KanbanRefinePreview.run(input, opts, context)
  end
end
