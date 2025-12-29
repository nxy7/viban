defmodule Viban.Executors.ImageHandler do
  @moduledoc """
  Handles saving and preparing images for executor sessions.

  This module is responsible for:
  - Saving base64-encoded images to the working directory
  - Building prompts with image file references
  - Sanitizing filenames for safe file system operations
  """

  require Logger

  @images_dir_name ".viban-images"

  @type image_map :: %{optional(String.t() | atom()) => String.t()}

  @doc """
  Saves images from base64 data URLs to the working directory.

  Creates a `.viban-images` subdirectory in the working directory and
  saves each image with a numbered prefix.

  Returns a list of file paths for successfully saved images.

  ## Examples

      images = [%{"data" => "data:image/png;base64,...", "name" => "screenshot.png"}]
      paths = ImageHandler.save_to_directory(images, "/path/to/worktree")
      # => ["/path/to/worktree/.viban-images/1-screenshot.png"]
  """
  @spec save_to_directory([image_map()], String.t() | nil) :: [String.t()]
  def save_to_directory([], _working_directory), do: []
  def save_to_directory(_images, nil), do: []
  def save_to_directory(_images, ""), do: []

  def save_to_directory(images, working_directory) when is_binary(working_directory) do
    images_dir = Path.join(working_directory, @images_dir_name)
    File.mkdir_p!(images_dir)

    images
    |> Enum.with_index()
    |> Enum.map(fn {image, index} -> save_single_image(image, images_dir, index) end)
    |> Enum.filter(&(&1 != nil))
  end

  @doc """
  Builds a display prompt that indicates how many images are attached.

  Used for showing the user what was sent to the executor.

  ## Examples

      build_display_prompt("Fix this", ["/path/to/img.png"])
      # => "Fix this\\n\\n[1 image attached]"

      build_display_prompt("", ["/path/to/img.png"])
      # => "[1 image attached]"
  """
  @spec build_display_prompt(String.t(), [String.t()]) :: String.t()
  def build_display_prompt(prompt, []), do: prompt

  def build_display_prompt(prompt, image_paths) do
    image_count = length(image_paths)
    suffix = if image_count == 1, do: "1 image attached", else: "#{image_count} images attached"

    if prompt == "" do
      "[#{suffix}]"
    else
      "#{prompt}\n\n[#{suffix}]"
    end
  end

  @doc """
  Builds the enhanced prompt with image file path references.

  This prompt instructs the executor to use its Read tool to view the images.

  ## Examples

      build_prompt_with_images("Analyze this", ["/path/to/img.png"])
      # => "Analyze this\\n\\nI've attached the following image(s)..."
  """
  @spec build_prompt_with_images(String.t(), [String.t()]) :: String.t()
  def build_prompt_with_images(prompt, []), do: prompt

  def build_prompt_with_images(prompt, image_paths) do
    image_refs =
      image_paths
      |> Enum.with_index(1)
      |> Enum.map(fn {path, index} -> "Image #{index}: #{path}" end)
      |> Enum.join("\n")

    image_section = """
    I've attached the following image(s) for you to analyze. Please use the Read tool to view them:

    #{image_refs}
    """

    if prompt == "" do
      image_section
    else
      "#{prompt}\n\n#{image_section}"
    end
  end

  # Private functions

  defp save_single_image(image, images_dir, index) do
    data_url = Map.get(image, "data") || Map.get(image, :data)
    name = Map.get(image, "name") || Map.get(image, :name) || "image-#{index}.png"

    case extract_base64_data(data_url) do
      {:ok, binary_data, extension} ->
        filename = "#{index + 1}-#{sanitize_filename(name, extension)}"
        file_path = Path.join(images_dir, filename)

        case File.write(file_path, binary_data) do
          :ok ->
            Logger.info("[ImageHandler] Saved image to #{file_path}")
            file_path

          {:error, reason} ->
            Logger.error("[ImageHandler] Failed to save image: #{inspect(reason)}")
            nil
        end

      {:error, reason} ->
        Logger.error("[ImageHandler] Failed to extract image data: #{inspect(reason)}")
        nil
    end
  end

  defp extract_base64_data(data_url) when is_binary(data_url) do
    # Parse data URL: data:image/png;base64,<data>
    case Regex.run(~r/^data:image\/(\w+);base64,(.+)$/, data_url) do
      [_, extension, base64_data] ->
        case Base.decode64(base64_data) do
          {:ok, binary} -> {:ok, binary, extension}
          :error -> {:error, :invalid_base64}
        end

      _ ->
        {:error, :invalid_data_url}
    end
  end

  defp extract_base64_data(_), do: {:error, :not_a_string}

  defp sanitize_filename(name, default_extension) do
    basename = Path.basename(name)

    # Ensure it has an extension
    filename =
      if Path.extname(basename) == "" do
        "#{basename}.#{default_extension}"
      else
        basename
      end

    # Remove unsafe characters
    String.replace(filename, ~r/[^a-zA-Z0-9._-]/, "_")
  end
end
