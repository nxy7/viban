defmodule Viban.Kanban.TaskImageManager do
  @moduledoc """
  Manages storage of images embedded in task descriptions.

  Images are stored on the file system in the user's local data directory,
  organized by task ID. This module handles saving, retrieving, syncing,
  and deleting images associated with tasks.

  ## Directory Structure

  Images are stored at:

      ~/.local/share/viban/task-images/
        <task_id>/
          <image_id>.png
          <image_id>.jpg
          ...

  ## Image Format

  Image metadata is stored as maps with the following structure:

      %{
        "id" => "img-1",
        "path" => "/path/to/file.png",
        "name" => "screenshot.png"
      }

  ## Supported Image Types

  | Format | Extension |
  |--------|-----------|
  | PNG    | `.png`    |
  | JPEG   | `.jpg`    |
  | GIF    | `.gif`    |
  | WebP   | `.webp`   |

  ## Usage

      # Save images from base64 data URLs
      {:ok, metadata} = TaskImageManager.save_images(task_id, [
        %{"id" => "img-1", "dataUrl" => "data:image/png;base64,...", "name" => "screenshot.png"}
      ])

      # Get path to a specific image
      {:ok, path} = TaskImageManager.get_image_path(task_id, "img-1")

      # Sync images (add new, keep existing, remove deleted)
      {:ok, metadata} = TaskImageManager.sync_images(task_id, new_images, existing_metadata)

      # Delete all images for a task
      {:ok, _} = TaskImageManager.delete_task_images(task_id)
  """

  require Logger

  # ---------------------------------------------------------------------------
  # Constants
  # ---------------------------------------------------------------------------

  @log_prefix "[TaskImageManager]"

  @images_dir_name "task-images"

  @supported_extensions %{
    "jpeg" => ".jpg",
    "jpg" => ".jpg",
    "png" => ".png",
    "gif" => ".gif",
    "webp" => ".webp"
  }

  @default_extension ".png"
  @default_image_name "image.png"

  # ---------------------------------------------------------------------------
  # Type Definitions
  # ---------------------------------------------------------------------------

  @type image_id :: String.t()

  @type image_metadata :: %{
          String.t() => String.t()
        }

  @type image_input :: %{
          (String.t() | atom()) => String.t()
        }

  @type save_result :: {:ok, [image_metadata()]} | {:error, term()}

  @type get_path_result :: {:ok, String.t()} | {:error, :not_found | term()}

  # ---------------------------------------------------------------------------
  # Public API - Directory Helpers
  # ---------------------------------------------------------------------------

  @doc """
  Returns the base directory for task images.

  This is typically `~/.local/share/viban/task-images`.
  """
  @spec base_dir() :: String.t()
  def base_dir do
    Path.join([System.user_home!(), ".local", "share", "viban", @images_dir_name])
  end

  @doc """
  Returns the directory for a specific task's images.

  ## Examples

      TaskImageManager.task_images_dir("550e8400-e29b-41d4-a716-446655440000")
      #=> "/home/user/.local/share/viban/task-images/550e8400-e29b-41d4-a716-446655440000"
  """
  @spec task_images_dir(String.t()) :: String.t()
  def task_images_dir(task_id) do
    Path.join(base_dir(), task_id)
  end

  # ---------------------------------------------------------------------------
  # Public API - Save Operations
  # ---------------------------------------------------------------------------

  @doc """
  Saves images for a task from base64 data URLs.

  Creates the task's image directory if it doesn't exist, then saves each
  image from its base64 data URL.

  ## Parameters

  - `task_id` - The UUID of the task
  - `images` - List of image maps with `id`, `dataUrl`, and optional `name`

  ## Returns

  - `{:ok, [metadata]}` - List of saved image metadata with file paths
  - `{:error, reason}` - If saving failed

  ## Examples

      {:ok, metadata} = TaskImageManager.save_images(task_id, [
        %{"id" => "img-1", "dataUrl" => "data:image/png;base64,iVBOR...", "name" => "screenshot.png"}
      ])
  """
  @spec save_images(String.t(), [image_input()] | nil) :: save_result()
  def save_images(_task_id, nil), do: {:ok, []}
  def save_images(_task_id, []), do: {:ok, []}

  def save_images(task_id, images) when is_list(images) do
    task_dir = task_images_dir(task_id)

    case File.mkdir_p(task_dir) do
      :ok ->
        process_image_saves(task_dir, images)

      {:error, reason} ->
        Logger.error("#{@log_prefix} Failed to create task images directory: #{inspect(reason)}")
        {:error, {:directory_creation_failed, reason}}
    end
  end

  # ---------------------------------------------------------------------------
  # Public API - Retrieval Operations
  # ---------------------------------------------------------------------------

  @doc """
  Gets the file path for a specific image by ID.

  Searches the task's image directory for a file starting with the image ID.

  ## Parameters

  - `task_id` - The task UUID
  - `image_id` - The image ID

  ## Returns

  - `{:ok, path}` - Full path to the image file
  - `{:error, :not_found}` - Image not found
  - `{:error, reason}` - Other error
  """
  @spec get_image_path(String.t(), image_id()) :: get_path_result()
  def get_image_path(task_id, image_id) do
    task_dir = task_images_dir(task_id)

    case File.ls(task_dir) do
      {:ok, files} ->
        find_image_file(task_dir, files, image_id)

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Public API - Delete Operations
  # ---------------------------------------------------------------------------

  @doc """
  Deletes all images for a task.

  Removes the entire task images directory and all its contents.

  ## Returns

  - `{:ok, deleted_files}` - List of deleted file paths
  - `{:error, reason, file}` - If deletion failed
  """
  @spec delete_task_images(String.t()) :: {:ok, [String.t()]} | {:error, term(), term()}
  def delete_task_images(task_id) do
    task_dir = task_images_dir(task_id)

    if File.exists?(task_dir) do
      File.rm_rf(task_dir)
    else
      {:ok, []}
    end
  end

  # ---------------------------------------------------------------------------
  # Public API - Sync Operations
  # ---------------------------------------------------------------------------

  @doc """
  Syncs images for a task - saves new ones, keeps existing, removes deleted.

  This handles the common case of updating a task description where some
  images are kept, some are removed, and new ones are added.

  ## Parameters

  - `task_id` - The task UUID
  - `new_images` - List of images (may include new data URLs or existing references)
  - `existing_metadata` - Current saved image metadata

  ## Returns

  - `{:ok, [metadata]}` - Combined metadata of kept and newly saved images
  - `{:error, reason}` - If saving failed
  """
  @spec sync_images(String.t(), [image_input()] | nil, [image_metadata()] | nil) :: save_result()
  def sync_images(_task_id, nil, existing), do: {:ok, existing || []}
  def sync_images(_task_id, [], _existing), do: {:ok, []}

  def sync_images(task_id, new_images, existing_metadata) when is_list(new_images) do
    task_dir = task_images_dir(task_id)
    File.mkdir_p(task_dir)

    {to_save, existing} = partition_images(new_images)
    keep_ids = build_keep_ids(existing, to_save)

    delete_removed_images(task_dir, existing_metadata, keep_ids, to_save)

    case save_images(task_id, to_save) do
      {:ok, saved_metadata} ->
        kept_metadata = filter_kept_metadata(existing_metadata, keep_ids, to_save)
        {:ok, kept_metadata ++ saved_metadata}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Image Saving
  # ---------------------------------------------------------------------------

  defp process_image_saves(task_dir, images) do
    results = Enum.map(images, &save_single_image(task_dir, &1))
    errors = Enum.filter(results, fn {status, _} -> status == :error end)

    if Enum.empty?(errors) do
      {:ok, Enum.map(results, fn {:ok, meta} -> meta end)}
    else
      {:error, {:partial_save_failure, errors}}
    end
  end

  defp save_single_image(task_dir, image) do
    id = get_image_field(image, :id)
    data_url = get_image_field(image, :dataUrl)
    name = get_image_field(image, :name) || @default_image_name

    case parse_data_url(data_url) do
      {:ok, binary, extension} ->
        write_image_file(task_dir, id, name, binary, extension)

      {:error, reason} ->
        Logger.error("#{@log_prefix} Failed to parse data URL for image #{id}: #{inspect(reason)}")

        {:error, {id, reason}}
    end
  end

  defp write_image_file(task_dir, id, name, binary, extension) do
    filename = "#{id}#{extension}"
    filepath = Path.join(task_dir, filename)

    case File.write(filepath, binary) do
      :ok ->
        {:ok, %{"id" => id, "path" => filepath, "name" => name}}

      {:error, reason} ->
        Logger.error("#{@log_prefix} Failed to write image #{id}: #{inspect(reason)}")
        {:error, {id, reason}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Image Retrieval
  # ---------------------------------------------------------------------------

  defp find_image_file(task_dir, files, image_id) do
    prefix = "#{image_id}."

    case Enum.find(files, &String.starts_with?(&1, prefix)) do
      nil -> {:error, :not_found}
      filename -> {:ok, Path.join(task_dir, filename)}
    end
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Image Sync
  # ---------------------------------------------------------------------------

  defp partition_images(images) do
    Enum.split_with(images, fn img ->
      Map.has_key?(img, "dataUrl") or Map.has_key?(img, :dataUrl)
    end)
  end

  defp build_keep_ids(existing, to_save) do
    MapSet.new(existing ++ to_save, &get_image_field(&1, :id))
  end

  defp delete_removed_images(task_dir, existing_metadata, keep_ids, _to_save) do
    existing_ids = MapSet.new(existing_metadata || [], &get_image_field(&1, :id))

    to_delete = MapSet.difference(existing_ids, keep_ids)

    Enum.each(to_delete, fn id ->
      delete_single_image(task_dir, id)
    end)
  end

  defp filter_kept_metadata(existing_metadata, keep_ids, to_save) do
    to_save_ids = MapSet.new(to_save, &get_image_field(&1, :id))

    Enum.filter(existing_metadata || [], fn img ->
      id = get_image_field(img, :id)
      id in keep_ids and id not in to_save_ids
    end)
  end

  defp delete_single_image(task_dir, image_id) do
    case File.ls(task_dir) do
      {:ok, files} ->
        prefix = "#{image_id}."

        Enum.each(files, fn f ->
          if String.starts_with?(f, prefix) do
            File.rm(Path.join(task_dir, f))
          end
        end)

      _ ->
        :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Data URL Parsing
  # ---------------------------------------------------------------------------

  defp parse_data_url(data_url) when is_binary(data_url) do
    case Regex.run(~r/^data:image\/(\w+);base64,(.+)$/, data_url) do
      [_, type, base64_data] ->
        decode_base64_image(type, base64_data)

      nil ->
        {:error, :invalid_data_url_format}
    end
  end

  defp parse_data_url(_), do: {:error, :invalid_data_url}

  defp decode_base64_image(type, base64_data) do
    extension = Map.get(@supported_extensions, type, @default_extension)

    case Base.decode64(base64_data) do
      {:ok, binary} -> {:ok, binary, extension}
      :error -> {:error, :invalid_base64_encoding}
    end
  end

  # ---------------------------------------------------------------------------
  # Private Functions - Helpers
  # ---------------------------------------------------------------------------

  defp get_image_field(image, field) when is_atom(field) do
    Map.get(image, Atom.to_string(field)) || Map.get(image, field)
  end
end
