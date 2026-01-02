defmodule Viban.Kanban.Task.Changes.PopMessage do
  @moduledoc """
  Ash change that removes the first message from the task's message queue.

  This is called by the Execute AI hook after it processes a message.
  The hook retrieves the first message, processes it, then calls this
  action to remove it from the queue.
  """

  use Ash.Resource.Change

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
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
