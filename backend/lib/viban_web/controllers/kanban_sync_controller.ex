defmodule VibanWeb.KanbanSyncController do
  @moduledoc """
  Sync endpoints for Kanban resources.

  These endpoints integrate with Phoenix.Sync/Electric to provide real-time
  synchronization of Kanban data to the frontend. Each endpoint maps to an
  Ash resource and provides the data in a format compatible with Electric sync.

  ## Endpoints

  All endpoints are under `/api/shapes`:

  - `GET /boards` - Sync board data
  - `GET /columns` - Sync column data
  - `GET /tasks` - Sync task data
  - `GET /hooks` - Sync hook definitions
  - `GET /column_hooks` - Sync column-hook associations
  - `GET /repositories` - Sync repository data
  - `GET /messages` - Sync message data

  ## How It Works

  These endpoints use `Phoenix.Sync.Controller.sync_render/3` which:
  1. Accepts sync parameters from the client
  2. Queries the Ash resource
  3. Returns data in Electric sync format

  The client subscribes to these shapes and receives real-time updates
  when data changes in the database.
  """

  use VibanWeb, :controller

  import Phoenix.Sync.Controller

  alias Viban.Kanban.{Board, Column, Task, Hook, ColumnHook, Repository, Message}

  @doc "Syncs board data to clients."
  @spec boards(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def boards(conn, params) do
    sync_render(conn, params, Board)
  end

  @doc "Syncs column data to clients."
  @spec columns(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def columns(conn, params) do
    sync_render(conn, params, Column)
  end

  @doc "Syncs task data to clients."
  @spec tasks(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def tasks(conn, params) do
    sync_render(conn, params, Task)
  end

  @doc "Syncs hook definitions to clients."
  @spec hooks(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def hooks(conn, params) do
    sync_render(conn, params, Hook)
  end

  @doc "Syncs column-hook associations to clients."
  @spec column_hooks(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def column_hooks(conn, params) do
    sync_render(conn, params, ColumnHook)
  end

  @doc "Syncs repository data to clients."
  @spec repositories(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def repositories(conn, params) do
    sync_render(conn, params, Repository)
  end

  @doc "Syncs message data to clients."
  @spec messages(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def messages(conn, params) do
    sync_render(conn, params, Message)
  end
end
