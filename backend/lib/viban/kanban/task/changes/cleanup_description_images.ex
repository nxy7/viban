defmodule Viban.Kanban.Task.Changes.CleanupDescriptionImages do
  @moduledoc """
  Ash change that cleans up description images when a task is destroyed (SQLite version).
  """

  use Ash.Resource.Change

  alias Viban.Kanban.Task.ImageManager

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &cleanup_images/2)
  end

  defp cleanup_images(_changeset, record) do
    {:ok, :deleted} = ImageManager.delete_task_images(record.id)
    {:ok, record}
  end
end
