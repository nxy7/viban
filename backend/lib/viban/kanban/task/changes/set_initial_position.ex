defmodule Viban.Kanban.Task.Changes.SetInitialPosition do
  @moduledoc """
  Ash change that sets the initial position for a new task.

  If position is not explicitly provided, generates a position at the end
  of the column using fractional indexing.
  """

  use Ash.Resource.Change

  require Logger

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    # Only set position if not already provided
    case Ash.Changeset.get_attribute(changeset, :position) do
      nil ->
        set_end_position(changeset)

      _position ->
        # Position was explicitly provided, keep it
        changeset
    end
  end

  defp set_end_position(changeset) do
    column_id = Ash.Changeset.get_attribute(changeset, :column_id)

    case get_last_task_position(column_id) do
      nil ->
        # Empty column, use default initial key
        case FractionalIndex.generate_key_between(nil, nil) do
          {:ok, position} ->
            Ash.Changeset.change_attribute(changeset, :position, position)

          {:error, reason} ->
            Logger.error("SetInitialPosition failed: #{inspect(reason)}")
            Ash.Changeset.change_attribute(changeset, :position, "a0")
        end

      last_position ->
        # Insert after the last task
        case FractionalIndex.generate_key_between(last_position, nil) do
          {:ok, position} ->
            Ash.Changeset.change_attribute(changeset, :position, position)

          {:error, reason} ->
            Logger.error("SetInitialPosition failed: #{inspect(reason)}")
            Ash.Changeset.change_attribute(changeset, :position, "a0")
        end
    end
  end

  defp get_last_task_position(nil), do: nil

  defp get_last_task_position(column_id) do
    import Ecto.Query

    Viban.Repo.one(
      from(t in "tasks",
        where: t.column_id == ^column_id,
        order_by: [desc: t.position],
        limit: 1,
        select: t.position
      )
    )
  end
end
