defmodule VibanWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug that requires a user to be authenticated.

  This plug should be used after `LoadUserFromSession` in the pipeline.
  It halts the request with a 401 Unauthorized response if no user is authenticated.

  ## Usage

  In your router, add to a pipeline:

      pipeline :authenticated_api do
        plug :accepts, ["json"]
        plug :fetch_session
        plug VibanWeb.Plugs.LoadUserFromSession
        plug VibanWeb.Plugs.RequireAuth
      end

  Or in a specific controller:

      plug VibanWeb.Plugs.RequireAuth when action in [:create, :update, :delete]

  ## Options

  - `:error_message` - Custom error message (default: "Not authenticated. Please sign in.")
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @default_message "Not authenticated. Please sign in."

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, opts) do
    case conn.assigns[:current_user] do
      nil ->
        message = Keyword.get(opts, :error_message, @default_message)

        conn
        |> put_status(:unauthorized)
        |> json(%{ok: false, error: message})
        |> halt()

      _user ->
        conn
    end
  end
end
