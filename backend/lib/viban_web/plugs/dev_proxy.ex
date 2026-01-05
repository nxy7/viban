defmodule VibanWeb.Plugs.DevProxy do
  @moduledoc """
  Reverse proxy plug for development.
  Forwards requests to the Vite dev server.
  Only available in dev environment.
  """

  use Plug.Builder

  if Mix.env() == :dev do
    plug ReverseProxyPlug,
      upstream: "http://127.0.0.1:3000",
      client: ReverseProxyPlug.HTTPClient.Adapters.Req,
      error_callback: &__MODULE__.log_error/1

    def log_error(error) do
      require Logger
      Logger.warning("DevProxy error: #{inspect(error)}")
    end
  else
    def call(conn, _opts), do: conn
  end
end
