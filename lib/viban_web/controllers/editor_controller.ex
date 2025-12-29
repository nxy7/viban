defmodule VibanWeb.EditorController do
  @moduledoc """
  API endpoint for opening paths in code editors.

  Opens the specified path in the user's preferred code editor.
  If the path is a file, opens the containing directory.

  ## Supported Editors

  Editors are tried in order of preference:
  1. Cursor (AI-enhanced VS Code)
  2. VS Code (`code`)
  3. `$EDITOR` environment variable

  ## Endpoints

  - `POST /api/editor/open` - Open a path in the code editor
  """

  use VibanWeb, :controller

  import VibanWeb.ControllerHelpers, only: [json_ok: 2, json_error: 3]

  alias VibanWeb.PathOpener

  @doc """
  Opens a path in the user's code editor.

  ## Body Parameters

  - `path` (required) - Absolute path to open

  ## Response

  Returns success or an error if the path cannot be opened.
  """
  @spec open(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def open(conn, %{"path" => path}) do
    with {:ok, dir_path} <- PathOpener.resolve_to_directory(path),
         :ok <- PathOpener.open_in_editor(dir_path) do
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
