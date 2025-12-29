defmodule Viban.Kanban.Task.Changes.SetInitialPosition do
  @moduledoc """
  Ash change that sets the initial position for a new task (SQLite version).
  """

  use Ash.Resource.Change

  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :position) do
      nil ->
        set_end_position(changeset)

      _position ->
        changeset
    end
  end

  defp set_end_position(changeset) do
    column_id = Ash.Changeset.get_attribute(changeset, :column_id)

    case get_last_task_position(column_id) do
      nil ->
        case FractionalIndex.generate_key_between(nil, nil) do
          {:ok, position} ->
            Ash.Changeset.change_attribute(changeset, :position, position)

          {:error, reason} ->
            Logger.error("SetInitialPosition failed: #{inspect(reason)}")
            Ash.Changeset.change_attribute(changeset, :position, "a0")
        end

      last_position ->
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

    "tasks"
    |> from(
      where: [column_id: ^column_id],
      order_by: [desc: :position],
      limit: 1,
      select: [:position]
    )
    |> Viban.RepoSqlite.one()
    |> case do
      nil -> nil
      row -> row.position
    end
  end
end
