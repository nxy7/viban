defmodule Viban.KanbanLite.Task.Changes.CleanupDescriptionImages do
  @moduledoc """
  Ash change that cleans up description images when a task is destroyed (SQLite version).
  """

  use Ash.Resource.Change

  alias Viban.KanbanLite.Task.ImageManager

  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &cleanup_images/2)
  end

  defp cleanup_images(_changeset, record) do
    case ImageManager.delete_task_images(record.id) do
      {:ok, _} ->
        {:ok, record}

      {:error, reason, _} ->
        Logger.warning("Failed to delete task images for task #{record.id}: #{inspect(reason)}")
        {:ok, record}
    end
  end
end
