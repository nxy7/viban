defmodule VibanWeb.Plugs.LoadUserFromSession do
  @moduledoc """
  Plug that loads the current user from session and sets it as the Ash actor.

  This plug reads the `:user_id` from the session, loads the corresponding user
  from the database, and:
  1. Assigns the user to `conn.assigns.current_user`
  2. Sets the user as the Ash actor for policy authorization

  If no user is in session or the user cannot be found, `current_user` is set to nil
  and any stale session data is cleared.

  ## Usage

  Add to your router pipeline:

      pipeline :api do
        plug :accepts, ["json"]
        plug :fetch_session
        plug VibanWeb.Plugs.LoadUserFromSession
      end

  Then in your controllers, access the user via:

      conn.assigns.current_user

  ## Ash Integration

  The user is also set as the Ash actor via `Ash.PlugHelpers.set_actor/2`,
  which means Ash policies will automatically use this user for authorization.
  """

  @behaviour Plug

  import Plug.Conn

  alias Viban.Accounts.User

  @impl Plug
  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @impl Plug
  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    case get_session(conn, :user_id) do
      nil ->
        assign(conn, :current_user, nil)

      user_id ->
        load_user(conn, user_id)
    end
  end

  @spec load_user(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  defp load_user(conn, user_id) do
    case User.get(user_id) do
      {:ok, user} ->
        conn
        |> assign(:current_user, user)
        |> Ash.PlugHelpers.set_actor(user)

      {:error, _} ->
        # User not found, clear invalid session
        conn
        |> configure_session(drop: true)
        |> assign(:current_user, nil)
    end
  end
end
