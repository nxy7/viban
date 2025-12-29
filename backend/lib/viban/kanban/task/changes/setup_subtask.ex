defmodule Viban.Kanban.Task.Changes.SetupSubtask do
  @moduledoc """
  Ash change that sets up a subtask by inheriting column from parent
  and calculating position.

  This change:
  1. Validates the parent task exists
  2. Inherits the column_id from the parent
  3. Calculates the next position in the subtask list using an efficient count query
  """

  use Ash.Resource.Change

  require Ash.Query

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    parent_id = Ash.Changeset.get_argument(changeset, :parent_task_id)

    case Viban.Kanban.Task.get(parent_id) do
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

  # Uses count aggregate for efficiency - does not load all subtasks into memory
  @spec calculate_next_position(Ecto.UUID.t()) :: non_neg_integer()
  defp calculate_next_position(parent_id) do
    Viban.Kanban.Task
    |> Ash.Query.filter(parent_task_id == ^parent_id)
    |> Ash.count!()
  end
end
