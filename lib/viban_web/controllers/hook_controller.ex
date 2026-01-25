defmodule VibanWeb.HookController do
  @moduledoc """
  API endpoints for hook management.

  Provides access to both system hooks (built-in automation) and custom hooks
  (user-defined). Hooks are used to trigger automated actions on tasks, such as
  running AI agents or updating task status.

  ## Hook Types

  - **System Hooks**: Built-in hooks that come with the application (e.g., "Run Agent")
  - **Custom Hooks**: User-defined hooks stored in the database

  ## Endpoints

  - `GET /api/boards/:board_id/hooks` - List all hooks for a board
  - `GET /api/hooks/system` - List only system hooks
  """

  use VibanWeb, :controller

  import VibanWeb.ControllerHelpers, only: [json_ok: 2]

  alias Viban.Kanban.Hook.HookService

  @doc """
  Lists all available hooks (system + custom) for a board.

  Returns system hooks first, followed by custom hooks sorted by name.
  This provides a unified view of all automation options available
  for the board's columns.

  ## Path Parameters

  - `board_id` - The ID of the board

  ## Response

  Returns a list of hooks, each containing:
  - `id` - Hook identifier
  - `name` - Display name
  - `type` - "system" or "custom"
  - Additional hook-specific configuration
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, %{"board_id" => board_id}) do
    hooks = HookService.list_all_hooks(board_id)
    json_ok(conn, %{hooks: hooks})
  end

  @doc """
  Lists only system hooks.

  Returns the built-in hooks that are available on all boards.
  No board context is needed for this endpoint.

  ## Response

  Returns a list of system hooks.
  """
  @spec system_hooks(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def system_hooks(conn, _params) do
    hooks = Viban.Kanban.SystemHooks.Registry.all()
    json_ok(conn, %{hooks: hooks})
  end
end
