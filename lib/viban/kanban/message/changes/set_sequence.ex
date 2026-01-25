defmodule Viban.Kanban.Message.Changes.SetSequence do
  @moduledoc """
  Sets the sequence number for new messages (SQLite version).
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    task_id = Ash.Changeset.get_attribute(changeset, :task_id)
    next_seq = get_next_sequence(task_id)
    Ash.Changeset.change_attribute(changeset, :sequence, next_seq)
  end

  defp get_next_sequence(nil), do: 1

  defp get_next_sequence(task_id) do
    import Ecto.Query

    "task_events"
    |> where([e], e.task_id == ^task_id and e.type == "message")
    |> select([e], max(e.sequence))
    |> Viban.RepoSqlite.one()
    |> case do
      nil -> 1
      max_seq -> max_seq + 1
    end
  end
end
