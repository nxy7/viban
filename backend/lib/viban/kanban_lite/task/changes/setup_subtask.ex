defmodule Viban.KanbanLite.Task.Changes.SetupSubtask do
  @moduledoc """
  Ash change that sets up a subtask by inheriting column from parent (SQLite version).
  """

  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    parent_id = Ash.Changeset.get_argument(changeset, :parent_task_id)

    case Viban.KanbanLite.Task.get(parent_id) do
      {:ok, parent} ->
        next_position = calculate_next_position(parent_id)

        changeset
        |> Ash.Changeset.change_attribute(:parent_task_id, parent_id)
        |> Ash.Changeset.change_attribute(:column_id, parent.column_id)
        |> Ash.Changeset.change_attribute(:subtask_position, next_position)

      {:error, _} ->
        Ash.Changeset.add_error(changeset,
          field: :parent_task_id,
          message: "Parent task not found"
        )
    end
  end

  defp calculate_next_position(parent_id) do
    Viban.KanbanLite.Task
    |> Ash.Query.filter(parent_task_id == ^parent_id)
    |> Ash.count!()
  end
end
