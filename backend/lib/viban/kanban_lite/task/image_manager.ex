defmodule Viban.KanbanLite.Task.ImageManager do
  @moduledoc """
  Manages task description images for KanbanLite (SQLite version).

  Delegates to the shared Kanban ImageManager since image storage
  is independent of the database backend.
  """

  alias Viban.Kanban.Task.ImageManager

  defdelegate save_images(task_id, images), to: ImageManager
  defdelegate sync_images(task_id, new_images, existing_images), to: ImageManager
  defdelegate delete_task_images(task_id), to: ImageManager
end
