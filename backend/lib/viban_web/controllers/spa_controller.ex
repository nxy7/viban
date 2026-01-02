defmodule VibanWeb.SPAController do
  use VibanWeb, :controller

  def index(conn, _params) do
    index_path =
      :viban
      |> :code.priv_dir()
      |> Path.join("static/index.html")

    if File.exists?(index_path) do
      conn
      |> put_resp_header("content-type", "text/html; charset=utf-8")
      |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
      |> send_file(200, index_path)
    else
      conn
      |> put_status(404)
      |> json(%{error: "SPA not built. Run: cd frontend && bun run build"})
    end
  end
end
