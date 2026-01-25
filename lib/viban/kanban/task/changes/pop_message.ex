defmodule Viban.Kanban.Task.Changes.PopMessage do
  @moduledoc """
  Ash change that removes the first message from the task's message queue (SQLite version).
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    current_queue = Ash.Changeset.get_data(changeset, :message_queue) || []

    case current_queue do
      [] ->
        changeset

      [_first | rest] ->
        Ash.Changeset.change_attribute(changeset, :message_queue, rest)
    end
  end
end
