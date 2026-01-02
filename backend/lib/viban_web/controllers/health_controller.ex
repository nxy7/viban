defmodule VibanWeb.HealthController do
  @moduledoc """
  Health check controller for monitoring and container orchestration.
  """

  use VibanWeb, :controller

  def check(conn, _params) do
    case Ecto.Adapters.SQL.query(Viban.Repo, "SELECT 1", []) do
      {:ok, _} ->
        json(conn, %{status: "ok", database: "connected"})

      {:error, _reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error", database: "disconnected"})
    end
  end
end
