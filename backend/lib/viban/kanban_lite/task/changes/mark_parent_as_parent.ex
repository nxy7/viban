defmodule Viban.KanbanLite.Task.Changes.MarkParentAsParent do
  @moduledoc """
  Ash change that marks the parent task as having subtasks (SQLite version).
  """

  use Ash.Resource.Change

  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &mark_parent/2)
  end

  defp mark_parent(_changeset, subtask) do
    if subtask.parent_task_id do
      case Viban.KanbanLite.Task.get(subtask.parent_task_id) do
        {:ok, %{is_parent: false} = parent} ->
          case Viban.KanbanLite.Task.mark_as_parent(parent) do
            {:ok, _} ->
              {:ok, subtask}

            {:error, reason} ->
              Logger.warning("Failed to mark parent task #{parent.id} as parent: #{inspect(reason)}")
              {:ok, subtask}
          end

        {:ok, _parent} ->
          {:ok, subtask}

        {:error, _} ->
          {:ok, subtask}
      end
    else
      {:ok, subtask}
    end
  end
end
