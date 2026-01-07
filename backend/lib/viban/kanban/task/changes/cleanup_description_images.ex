defmodule Viban.Kanban.Task.Changes.CleanupDescriptionImages do
  @moduledoc """
  Ash change that cleans up description images when a task is destroyed.

  This runs as an after_action callback to ensure the task is successfully
  deleted before removing the image files from storage. Image deletion
  failures are logged but do not prevent task deletion.
  """

  use Ash.Resource.Change

  alias Viban.Kanban.TaskImageManager

  require Logger

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &cleanup_images/2)
  end

  @spec cleanup_images(Ash.Changeset.t(), Viban.Kanban.Task.t()) ::
          {:ok, Viban.Kanban.Task.t()}
  defp cleanup_images(_changeset, record) do
    case TaskImageManager.delete_task_images(record.id) do
      {:ok, _} ->
        {:ok, record}

      {:error, reason, _} ->
        Logger.warning("Failed to delete task images for task #{record.id}: #{inspect(reason)}")

        # Don't fail the task deletion if image cleanup fails
        {:ok, record}
    end
  end
end
