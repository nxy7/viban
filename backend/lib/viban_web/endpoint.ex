defmodule VibanWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :viban

  import Plug.Conn

  @session_options [
    store: :cookie,
    key: "_viban_key",
    signing_salt: "viban_signing_salt",
    same_site: "Lax",
    http_only: true
  ]

  # Allowed origins for CORS
  @allowed_origins [
    "http://localhost:7777",
    "http://127.0.0.1:7777"
  ]

  # User socket for task chat and LLM streaming
  socket "/socket", VibanWeb.UserSocket,
    websocket: true,
    longpoll: false

  # Hologram static assets (must be before regular static plug)
  plug Plug.Static,
    at: "/hologram",
    from: {:viban, "priv/static/hologram"},
    gzip: true

  plug Plug.Static,
    at: "/",
    from: :viban,
    gzip: true,
    brotli: true,
    only: VibanWeb.static_paths(),
    headers: [{"cache-control", "public, max-age=31536000, immutable"}]

  if Code.ensure_loaded?(Tidewave) do
    plug Tidewave
  end

  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug :cors

  # Hologram router (before Phoenix router for Hologram pages)
  plug Hologram.Router, otp_app: :viban

  plug VibanWeb.Router

  # Custom CORS plug that properly handles credentials
  defp cors(conn, _opts) do
    origin = conn |> get_req_header("origin") |> List.first()

    conn =
      if origin in @allowed_origins do
        conn
        |> put_resp_header("access-control-allow-origin", origin)
        |> put_resp_header("access-control-allow-credentials", "true")
        |> put_resp_header(
          "access-control-allow-methods",
          "GET, POST, PUT, PATCH, DELETE, OPTIONS"
        )
        |> put_resp_header(
          "access-control-allow-headers",
          "content-type, authorization, x-csrf-token, x-request-id"
        )
      else
        conn
      end

    # Handle preflight OPTIONS requests
    if conn.method == "OPTIONS" do
      conn
      |> send_resp(200, "")
      |> halt()
    else
      conn
    end
  end
end
