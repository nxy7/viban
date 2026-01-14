defmodule Viban.Kanban.Task.Changes.CalculatePosition do
  @moduledoc """
  Ash change that calculates the fractional index position for a task.

  Uses the fractional_index library to generate a lexicographically sortable
  string position key between two existing tasks.

  ## Arguments

  - `before_task_id` - ID of task to insert before (nil = insert at end)
  - `after_task_id` - ID of task to insert after (nil = insert at start)

  The position is calculated based on the positions of the adjacent tasks.
  """

  use Ash.Resource.Change

  require Logger

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    before_task_id = Ash.Changeset.get_argument(changeset, :before_task_id)
    after_task_id = Ash.Changeset.get_argument(changeset, :after_task_id)

    target_column_id =
      Ash.Changeset.get_attribute(changeset, :column_id) ||
        Ash.Changeset.get_data(changeset, :column_id)

    task_id = Ash.Changeset.get_data(changeset, :id)

    case calculate_position(before_task_id, after_task_id, target_column_id, task_id) do
      {:ok, position} ->
        Ash.Changeset.change_attribute(changeset, :position, position)

      {:error, reason} ->
        Logger.error("CalculatePosition failed: #{inspect(reason)}")
        Ash.Changeset.add_error(changeset, field: :position, message: "Failed to calculate position")
    end
  end

  defp calculate_position(before_task_id, after_task_id, column_id, current_task_id) do
    before_position = get_task_position(before_task_id)
    after_position = get_task_position(after_task_id)

    case {before_position, after_position} do
      {nil, nil} ->
        # No adjacent tasks specified - check if inserting at end of column
        case get_last_task_position(column_id, current_task_id) do
          nil ->
            # Empty column, use default
            FractionalIndex.generate_key_between(nil, nil)

          last_position ->
            # Insert after the last task
            FractionalIndex.generate_key_between(last_position, nil)
        end

      {nil, after_pos} ->
        # Insert at the beginning (before the first task)
        FractionalIndex.generate_key_between(nil, after_pos)

      {before_pos, nil} ->
        # Insert at the end (after the last task)
        FractionalIndex.generate_key_between(before_pos, nil)

      {before_pos, after_pos} ->
        # Insert between two tasks
        FractionalIndex.generate_key_between(after_pos, before_pos)
    end
  end

  defp get_task_position(nil), do: nil

  defp get_task_position(task_id) do
    case Viban.Kanban.Task.get(task_id) do
      {:ok, task} -> task.position
      _ -> nil
    end
  end

  defp get_last_task_position(column_id, exclude_task_id) do
    import Ecto.Query

    Viban.Repo.one(
      from(t in "tasks",
        where: t.column_id == ^column_id and t.id != ^exclude_task_id,
        order_by: [desc: t.position],
        limit: 1,
        select: t.position
      )
    )
  end
end
