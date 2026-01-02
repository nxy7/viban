defmodule VibanWeb.TaskController do
  @moduledoc """
  Controller for task-related endpoints that cannot be handled via RPC.

  Most task operations are handled through Ash RPC, but binary file
  serving (images) requires a traditional REST endpoint.
  """

  use VibanWeb, :controller

  import VibanWeb.ControllerHelpers, only: [json_error: 3]

  alias Viban.Kanban.TaskImageManager

  require Logger

  @doc """
  Serves an image file for a task.

  Images are stored in the task's working directory and served with
  appropriate content types based on file extension.

  ## Path Parameters

  - `task_id` - The ID of the task
  - `image_id` - The image identifier

  ## Response

  Returns the image file with appropriate Content-Type header.
  """
  @spec get_image(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_image(conn, %{"task_id" => task_id, "image_id" => image_id}) do
    case TaskImageManager.get_image_path(task_id, image_id) do
      {:ok, filepath} ->
        content_type = MIME.from_path(filepath)

        conn
        |> put_resp_content_type(content_type)
        |> send_file(200, filepath)

      {:error, :not_found} ->
        json_error(conn, :not_found, "Image not found")

      {:error, reason} ->
        Logger.error("[TaskController] Failed to get image: #{inspect(reason)}")
        json_error(conn, :internal_server_error, "Failed to retrieve image")
    end
  end
end
