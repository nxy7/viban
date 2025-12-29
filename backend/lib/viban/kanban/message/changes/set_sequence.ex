defmodule Viban.Kanban.Message.Changes.SetSequence do
  @moduledoc """
  Ash change that auto-increments the message sequence within a task.

  Each message in a task conversation gets a unique, incrementing sequence
  number to maintain ordering. The sequence is 1-indexed.

  ## Implementation

  Uses a database COUNT aggregate to efficiently determine the next sequence
  number without loading all existing messages.

  ## Concurrency Note

  This uses a count-based approach which could have race conditions under
  high concurrency. For truly concurrent message creation, consider using
  database sequences or optimistic locking. In practice, messages are
  typically created sequentially per task.
  """

  use Ash.Resource.Change

  require Ash.Query

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    task_id = Ash.Changeset.get_attribute(changeset, :task_id)

    next_seq = get_next_sequence(task_id)
    Ash.Changeset.force_change_attribute(changeset, :sequence, next_seq)
  end

  @spec get_next_sequence(Ecto.UUID.t() | nil) :: pos_integer()
  defp get_next_sequence(nil), do: 1

  defp get_next_sequence(task_id) do
    # Use aggregate count for efficiency - single query instead of loading all messages
    count =
      Viban.Kanban.Message
      |> Ash.Query.filter(task_id == ^task_id)
      |> Ash.count!()

    count + 1
  end
end
