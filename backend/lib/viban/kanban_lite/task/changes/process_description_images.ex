defmodule Viban.KanbanLite.Task.Changes.ProcessDescriptionImages do
  @moduledoc """
  Ash change that processes description images when a task is created or updated (SQLite version).
  """

  use Ash.Resource.Change

  alias Viban.KanbanLite.Task.ImageManager

  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    images_input = Ash.Changeset.get_attribute(changeset, :description_images)

    if skip_processing?(images_input) do
      changeset
    else
      process_images(changeset, images_input)
    end
  end

  defp skip_processing?(nil), do: true
  defp skip_processing?([]), do: true
  defp skip_processing?(_), do: false

  defp process_images(changeset, images_input) do
    case Ash.Changeset.get_data(changeset, :id) do
      nil ->
        Ash.Changeset.after_action(changeset, fn _changeset, record ->
          process_images_for_new_record(record, images_input)
        end)

      _id ->
        process_images_for_existing_record(changeset, images_input)
    end
  end

  defp process_images_for_new_record(record, images_input) do
    case ImageManager.save_images(record.id, images_input) do
      {:ok, saved_metadata} ->
        record
        |> Ash.Changeset.for_update(:update, %{description_images: saved_metadata})
        |> Ash.update()

      {:error, reason} ->
        Logger.error("Failed to save description images for new task #{record.id}: #{inspect(reason)}")
        {:ok, record}
    end
  end

  defp process_images_for_existing_record(changeset, images_input) do
    task_id = Ash.Changeset.get_data(changeset, :id)
    existing_images = Ash.Changeset.get_data(changeset, :description_images) || []

    case ImageManager.sync_images(task_id, images_input, existing_images) do
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
