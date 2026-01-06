defmodule Viban.Kanban.Changes.ProcessDescriptionImages do
  @moduledoc """
  Ash change that processes description images when a task is created or updated.

  This change handles base64-encoded images by:
  1. Extracting base64 images from the input
  2. Saving them to the file system
  3. Updating the description_images attribute with file paths

  ## Create vs Update

  - **Create**: Images are processed in an after_action hook since we need
    the task ID to determine the storage path
  - **Update**: Images are synced inline, comparing new images with existing
    ones to determine what to add/remove

  ## Error Handling

  Image processing failures are logged but do not prevent task creation/update.
  This ensures that text content is preserved even if image storage fails.
  """

  use Ash.Resource.Change

  alias Viban.Kanban.TaskImageManager

  require Logger

  @impl true
  @spec change(Ash.Changeset.t(), keyword(), Ash.Resource.Change.context()) :: Ash.Changeset.t()
  def change(changeset, _opts, _context) do
    images_input = Ash.Changeset.get_attribute(changeset, :description_images)

    if skip_processing?(images_input) do
      changeset
    else
      process_images(changeset, images_input)
    end
  end

  @spec skip_processing?(term()) :: boolean()
  defp skip_processing?(nil), do: true
  defp skip_processing?([]), do: true
  defp skip_processing?(_), do: false

  @spec process_images(Ash.Changeset.t(), list()) :: Ash.Changeset.t()
  defp process_images(changeset, images_input) do
    case Ash.Changeset.get_data(changeset, :id) do
      nil ->
        # Create action - process after record is created
        Ash.Changeset.after_action(changeset, fn _changeset, record ->
          process_images_for_new_record(record, images_input)
        end)

      _id ->
        # Update action - process inline
        process_images_for_existing_record(changeset, images_input)
    end
  end

  @spec process_images_for_new_record(Viban.Kanban.Task.t(), list()) ::
          {:ok, Viban.Kanban.Task.t()} | {:error, term()}
  defp process_images_for_new_record(record, images_input) do
    case TaskImageManager.save_images(record.id, images_input) do
      {:ok, saved_metadata} ->
        record
        |> Ash.Changeset.for_update(:update, %{description_images: saved_metadata})
        |> Ash.update()

      {:error, reason} ->
        Logger.error("Failed to save description images for new task #{record.id}: #{inspect(reason)}")

        # Return success to not block task creation
        {:ok, record}
    end
  end

  @spec process_images_for_existing_record(Ash.Changeset.t(), list()) :: Ash.Changeset.t()
  defp process_images_for_existing_record(changeset, images_input) do
    task_id = Ash.Changeset.get_data(changeset, :id)
    existing_images = Ash.Changeset.get_data(changeset, :description_images) || []

    case TaskImageManager.sync_images(task_id, images_input, existing_images) do
      {:ok, saved_metadata} ->
        Ash.Changeset.change_attribute(changeset, :description_images, saved_metadata)

      {:error, reason} ->
        Logger.error("Failed to sync description images for task #{task_id}: #{inspect(reason)}")

        Ash.Changeset.add_error(changeset,
          field: :description_images,
          message: "Failed to save images"
        )
    end
  end
end
