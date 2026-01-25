defmodule VibanWeb.HealthController do
  @moduledoc """
  Health check controller for monitoring and container orchestration.
  """

  use VibanWeb, :controller

  def check(conn, _params) do
    case Ecto.Adapters.SQL.query(Viban.RepoSqlite, "SELECT 1", []) do
      {:ok, _} ->
        json(conn, %{status: "ok", database: "connected"})

      {:error, _reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error", database: "disconnected"})
    end
  end

  def ping(conn, _params) do
    json(conn, %{pong: true})
  end
end
