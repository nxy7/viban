defmodule VibanWeb.SyncController do
  @moduledoc """
  Sync endpoints for test messages.

  Provides Electric sync integration for test message data.
  Used primarily for development and testing of the sync functionality.

  ## Endpoints

  - `GET /api/shapes/test_messages` - Sync test message data
  """

  use VibanWeb, :controller

  import Phoenix.Sync.Controller

  alias Viban.Messages.TestMessage

  @doc "Syncs test message data to clients."
  @spec test_messages(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def test_messages(conn, params) do
    sync_render(conn, params, TestMessage)
  end
end
