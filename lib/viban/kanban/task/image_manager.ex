defmodule Viban.Kanban.Task.ImageManager do
  @moduledoc """
  Manages task description images.

  Images are stored in the filesystem under the task's data directory.
  Supports saving new images, syncing with existing images, and cleanup.
  """

  @images_dir Path.expand("~/.viban/images")

  @doc """
  Save images for a task.
  Returns {:ok, [image_info]} or {:error, reason}
  """
  def save_images(task_id, images) when is_list(images) do
    task_dir = task_images_dir(task_id)
    File.mkdir_p!(task_dir)

    saved =
      Enum.map(images, fn image ->
        save_single_image(task_dir, image)
      end)

    {:ok, Enum.filter(saved, &is_map/1)}
  end

  def save_images(_task_id, _images), do: {:ok, []}

  @doc """
  Sync images - keep existing ones that are still referenced, add new ones.
  Returns {:ok, [image_info]} or {:error, reason}
  """
  def sync_images(task_id, new_images, existing_images) when is_list(new_images) do
    task_dir = task_images_dir(task_id)
    File.mkdir_p!(task_dir)

    existing_urls = MapSet.new(Enum.map(existing_images || [], & &1["url"]))
    new_urls = MapSet.new(Enum.map(new_images, & &1["url"]))

    to_delete = MapSet.difference(existing_urls, new_urls)

    Enum.each(to_delete, fn url ->
      if String.contains?(url, "/uploads/") do
        path = url_to_path(task_id, url)
        File.rm(path)
      end
    end)

    saved =
      Enum.map(new_images, fn image ->
        if base64_image?(image) do
          save_single_image(task_dir, image)
        else
          image
        end
      end)

    {:ok, Enum.filter(saved, &is_map/1)}
  end

  def sync_images(_task_id, _new_images, _existing_images), do: {:ok, []}

  @doc """
  Get the filesystem path for a specific image.
  Returns {:ok, path} or {:error, :not_found}
  """
  def get_image_path(task_id, image_id) do
    path = Path.join(task_images_dir(task_id), image_id)

    if File.exists?(path) do
      {:ok, path}
    else
      {:error, :not_found}
    end
  end

  @doc """
  Delete all images for a task.
  """
  def delete_task_images(task_id) do
    task_dir = task_images_dir(task_id)

    if File.dir?(task_dir) do
      File.rm_rf!(task_dir)
    end

    {:ok, :deleted}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp task_images_dir(task_id) do
    Path.join(@images_dir, to_string(task_id))
  end

  defp url_to_path(task_id, url) do
    filename = Path.basename(url)
    Path.join(task_images_dir(task_id), filename)
  end

  defp base64_image?(image) do
    url = image["url"] || image[:url]
    is_binary(url) and String.starts_with?(url, "data:")
  end

  defp save_single_image(task_dir, image) do
    url = image["url"] || image[:url]

    cond do
      is_nil(url) ->
        nil

      String.starts_with?(url, "data:") ->
        save_base64_image(task_dir, url, image)

      true ->
        image
    end
  end

  defp save_base64_image(task_dir, data_url, image) do
    case decode_data_url(data_url) do
      {:ok, data, extension} ->
        filename = "#{Ash.UUID.generate()}.#{extension}"
        path = Path.join(task_dir, filename)
        File.write!(path, data)

        %{
          "url" => "/uploads/images/#{Path.basename(task_dir)}/#{filename}",
          "alt" => image["alt"] || image[:alt] || ""
        }

      :error ->
        nil
    end
  end

  defp decode_data_url(data_url) do
    case Regex.run(~r/^data:image\/(\w+);base64,(.+)$/, data_url) do
      [_, ext, base64] ->
        case Base.decode64(base64) do
          {:ok, data} -> {:ok, data, ext}
          :error -> :error
        end

      _ ->
        :error
    end
  end
end
