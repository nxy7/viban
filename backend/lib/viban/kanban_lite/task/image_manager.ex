defmodule Viban.KanbanLite.Task.ImageManager do
  @moduledoc """
  Manages task description images for KanbanLite (SQLite version).

  Delegates to the shared Kanban ImageManager since image storage
  is independent of the database backend.
  """

  defdelegate save_images(task_id, images), to: Viban.Kanban.Task.ImageManager
  defdelegate sync_images(task_id, new_images, existing_images), to: Viban.Kanban.Task.ImageManager
  defdelegate delete_task_images(task_id), to: Viban.Kanban.Task.ImageManager
end
