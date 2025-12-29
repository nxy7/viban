defmodule Viban.Kanban.Task.Changes.MarkParentAsParent do
  @moduledoc """
  Ash change that marks the parent task as having subtasks
  after a subtask is created.

  This runs as an after_action callback to ensure the subtask
  is successfully created before updating the parent.
  """

  use Ash.Resource.Change

  require Logger

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &mark_parent/2)
  end

  @spec mark_parent(Ash.Changeset.t(), Viban.Kanban.Task.t()) ::
          {:ok, Viban.Kanban.Task.t()} | {:error, term()}
  defp mark_parent(_changeset, subtask) do
    if subtask.parent_task_id do
      case Viban.Kanban.Task.get(subtask.parent_task_id) do
        {:ok, %{is_parent: false} = parent} ->
          case Viban.Kanban.Task.mark_as_parent(parent) do
            {:ok, _} ->
              {:ok, subtask}

            {:error, reason} ->
              Logger.warning(
                "Failed to mark parent task #{parent.id} as parent: #{inspect(reason)}"
              )

              {:ok, subtask}
          end

        {:ok, _parent} ->
          # Already marked as parent
          {:ok, subtask}

        {:error, _} ->
          # Parent not found - this shouldn't happen as SetupSubtask validates it
          {:ok, subtask}
      end
    else
      {:ok, subtask}
    end
  end
end
