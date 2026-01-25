defmodule VibanWeb.FolderController do
  @moduledoc """
  API endpoint for opening folders in the system file manager.

  Opens the specified path in the operating system's native file manager.
  If the path is a file, opens the containing directory.

  ## Supported Platforms

  - macOS: Opens in Finder
  - Linux: Opens with `xdg-open`
  - Windows: Opens in Explorer

  ## Endpoints

  - `POST /api/folder/open` - Open a path in the file manager
  """

  use VibanWeb, :controller

  import VibanWeb.ControllerHelpers, only: [json_ok: 2, json_error: 3]

  alias VibanWeb.PathOpener

  @doc """
  Opens a folder in the system's file manager.

  ## Body Parameters

  - `path` (required) - Absolute path to open

  ## Response

  Returns success or an error if the path cannot be opened.
  """
  @spec open(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def open(conn, %{"path" => path}) do
    with {:ok, dir_path} <- PathOpener.resolve_to_directory(path),
         :ok <- PathOpener.open_in_file_manager(dir_path) do
      json_ok(conn, %{})
    else
      {:error, :not_found, path} ->
        json_error(conn, :not_found, "Path does not exist: #{path}")

      {:error, :access_denied, reason} ->
        json_error(conn, :unprocessable_entity, "Cannot access path: #{reason}")

      {:error, reason} ->
        json_error(conn, :unprocessable_entity, reason)
    end
  end

  def open(conn, _params) do
    json_error(conn, :bad_request, "Missing required parameter: path")
  end
end
