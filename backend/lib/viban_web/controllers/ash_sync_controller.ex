defmodule VibanWeb.AshSyncController do
  use Phoenix.Controller, formats: [:html, :json]

  def sync(conn, params) do
    AshSync.sync_render(:viban, conn, params)
  end
end
