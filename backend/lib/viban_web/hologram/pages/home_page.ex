defmodule VibanWeb.Hologram.Pages.HomePage do
  use Hologram.Page

  alias Viban.Accounts.User
  alias Viban.Auth.DeviceFlow
  alias VibanWeb.Hologram.Components.BoardCard
  alias VibanWeb.Hologram.Components.CreateBoardModal
  alias VibanWeb.Hologram.Components.DeviceFlowModal
  alias VibanWeb.Hologram.Components.GitHubLoginButton
  alias VibanWeb.Hologram.Components.UserMenu
  alias VibanWeb.Hologram.Layouts.MainLayout
  alias VibanWeb.Hologram.UI.LoadingSpinner

  route "/"

  layout MainLayout

  require Logger

  @impl Hologram.Page
  def init(_params, component, server) do
    # Try to get user_id from Phoenix session first, then fall back to cookie
    user_id = get_session(server, :user_id) || get_cookie(server, "viban_user_id")
    Logger.info("[HomePage] init - user_id from session: #{inspect(user_id)}")

    {user, boards} = load_user_and_boards(user_id)
    Logger.info("[HomePage] init - loaded user: #{inspect(user && user.id)}, boards: #{length(boards)}")

    component =
      component
      |> put_state(:boards, boards)
      |> put_state(:user, user)
      |> put_state(:loading, false)
      |> put_state(:show_create_modal, false)
      |> put_state(:show_device_flow_modal, false)
      |> put_state(:device_flow_status, :idle)
      |> put_state(:device_flow_user_code, nil)
      |> put_state(:device_flow_verification_uri, nil)
      |> put_state(:device_flow_error, nil)
      |> put_state(:device_flow_device_code, nil)
      |> put_state(:device_flow_interval, 5)
      |> put_state(:user_menu_open, false)

    {component, server}
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <div class="min-h-screen bg-gray-950">
      <header class="border-b border-gray-800 bg-gray-900/50 backdrop-blur-sm sticky top-0 z-50">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <div class="flex items-center gap-3">
              <div class="w-8 h-8 bg-brand-600 rounded-lg flex items-center justify-center">
                <span class="text-white font-bold text-sm">V</span>
              </div>
              <h1 class="text-xl font-semibold text-white">Viban</h1>
            </div>

            <div class="flex items-center gap-4">
              {%if @user == nil}
                <GitHubLoginButton />
              {%else}
                {%if is_map(@user) && Map.has_key?(@user, :email)}
                  <UserMenu
                  user={@user}
                  menu_open={@user_menu_open}
                  on_toggle="toggle_user_menu"
                  on_close="close_user_menu"
                  on_logout="logout_user"
                />
                {%else}
                  <button class="text-gray-400">Invalid user data</button>
                {/if}
              {/if}
            </div>
          </div>
        </div>
      </header>

      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="flex items-center justify-between mb-8">
          <h2 class="text-2xl font-bold text-white">Your Boards</h2>
          {%if @user != nil}
            <button
              class="inline-flex items-center gap-2 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors"
              $click="show_create_board_modal"
            >
              + New Board
            </button>
          {/if}
        </div>

        {%if @loading}
          <div class="flex items-center justify-center py-12">
            <LoadingSpinner size="lg" />
          </div>
        {%else}
          {%if @user == nil}
            <div class="text-center py-12">
              <h3 class="text-lg font-medium text-white mb-2">Welcome to Viban</h3>
              <p class="text-gray-400 mb-6">Sign in with GitHub to create and manage your boards</p>
            </div>
          {%else}
            {%if @boards == []}
              <div class="text-center py-12">
                <h3 class="text-lg font-medium text-white mb-2">No boards yet</h3>
                <p class="text-gray-400 mb-6">Create your first board to get started</p>
              </div>
            {%else}
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {%for board <- @boards}
                  <BoardCard board={board} />
                {/for}
              </div>
            {/if}
          {/if}
        {/if}
      </main>

      <DeviceFlowModal
        is_open={@show_device_flow_modal}
        status={@device_flow_status}
        user_code={@device_flow_user_code}
        verification_uri={@device_flow_verification_uri}
        error={@device_flow_error}
      />

      {%if @device_flow_status == :pending && @device_flow_device_code != nil}
        <div
          id="device-flow-poller"
          data-device-code={@device_flow_device_code}
          data-interval={@device_flow_interval}
          style="display: none;"
        >
          <button id="poll-trigger" $click={action: :trigger_poll, params: %{device_code: @device_flow_device_code}}></button>
        </div>
      {/if}

      {%if @show_create_modal}
        <CreateBoardModal cid="create_board_modal" />
      {/if}
    </div>
    """
  end

  def action(:show_create_board_modal, _params, component) do
    put_state(component, :show_create_modal, true)
  end

  def action(:hide_create_board_modal, _params, component) do
    put_state(component, :show_create_modal, false)
  end

  def action(:show_device_flow_modal, _params, component) do
    component
    |> put_state(:show_device_flow_modal, true)
    |> put_state(:device_flow_status, :loading)
    |> put_command(:request_device_code, %{})
  end

  def action(:hide_device_flow_modal, _params, component) do
    component
    |> put_state(:show_device_flow_modal, false)
    |> put_state(:device_flow_status, :idle)
    |> put_state(:device_flow_user_code, nil)
    |> put_state(:device_flow_verification_uri, nil)
    |> put_state(:device_flow_error, nil)
  end

  def action(:close_device_flow_modal, _params, component) do
    component
    |> put_state(:show_device_flow_modal, false)
    |> put_state(:device_flow_status, :idle)
    |> put_state(:device_flow_user_code, nil)
    |> put_state(:device_flow_verification_uri, nil)
    |> put_state(:device_flow_error, nil)
  end

  def action(:set_device_flow_status, %{status: status}, component) do
    put_state(component, :device_flow_status, status)
  end

  def action(:set_device_code, %{user_code: code, verification_uri: uri, device_code: device_code, interval: interval}, component) do
    component
    |> put_state(:device_flow_status, :pending)
    |> put_state(:device_flow_user_code, code)
    |> put_state(:device_flow_verification_uri, uri)
    |> put_state(:device_flow_device_code, device_code)
    |> put_state(:device_flow_interval, interval)
  end

  def action(:trigger_poll, %{device_code: device_code}, component) do
    put_command(component, :poll_for_token, %{device_code: device_code})
  end

  def action(:poll_pending, _params, component) do
    component
  end

  def action(:poll_slow_down, _params, component) do
    interval = component.state[:device_flow_interval] || 5
    put_state(component, :device_flow_interval, interval + 5)
  end

  def action(:set_device_flow_error, %{error: error}, component) do
    component
    |> put_state(:device_flow_status, :error)
    |> put_state(:device_flow_error, error)
  end

  def action(:start_auth, _params, component) do
    component
    |> put_state(:device_flow_status, :loading)
    |> put_command(:request_device_code, %{})
  end

  def action(:retry_auth, _params, component) do
    component
    |> put_state(:device_flow_status, :loading)
    |> put_state(:device_flow_error, nil)
    |> put_command(:request_device_code, %{})
  end


  def action(:auth_success, %{user: user}, component) do
    require Logger
    Logger.info("[HomePage] auth_success - user: #{inspect(user)}")
    Logger.info("[HomePage] auth_success - user keys: #{inspect(Map.keys(user))}")

    component
    |> put_state(:device_flow_status, :success)
    |> put_state(:device_flow_error, nil)
    |> put_state(:user, user)
    |> put_state(:show_device_flow_modal, false)
    |> put_state(:loading, false)
  end

  def action(:set_user, %{user: user}, component) do
    component
    |> put_state(:user, user)
    |> put_state(:loading, false)
    |> put_state(:show_device_flow_modal, false)
  end

  def action(:set_boards, %{boards: boards}, component) do
    put_state(component, :boards, boards)
  end

  def action(:reload_boards, _params, component) do
    component
    |> put_state(:show_create_modal, false)
    |> put_command(:load_boards, %{})
  end

  def action(:logout_complete, _params, component) do
    component
    |> put_state(:user, nil)
    |> put_state(:boards, [])
    |> put_state(:user_menu_open, false)
  end

  def action(:toggle_user_menu, _params, component) do
    put_state(component, :user_menu_open, !component.state.user_menu_open)
  end

  def action(:close_user_menu, _params, component) do
    put_state(component, :user_menu_open, false)
  end

  def action(:logout_user, _params, component) do
    component
    |> put_state(:user_menu_open, false)
    |> put_command(:logout, %{})
  end

  def command(:load_boards, _params, server) do
    user_id = get_session(server, :user_id) || get_cookie(server, "viban_user_id")

    boards = case user_id do
      nil -> []
      id ->
        id
        |> Viban.Kanban.Board.for_user!()
        |> Enum.map(&serialize_board/1)
    end

    put_action(server, :set_boards, %{boards: boards})
  end

  def command(:logout, _params, server) do
    server
    |> put_session(:user_id, nil)
    |> delete_cookie("viban_user_id")
    |> put_action(:logout_complete, %{})
  end

  def command(:request_device_code, _params, server) do
    case DeviceFlow.request_device_code() do
      {:ok, data} ->
        server
        |> put_session(:device_code, data.device_code)
        |> put_session(:device_code_expires_at, System.system_time(:second) + data.expires_in)
        |> put_session(:device_poll_interval, data.interval)
        |> put_action(:set_device_code, %{
          user_code: data.user_code,
          verification_uri: data.verification_uri,
          device_code: data.device_code,
          interval: data.interval
        })

      {:error, reason} ->
        put_action(server, :set_device_flow_error, %{error: reason})
    end
  end

  def command(:poll_for_token, %{device_code: device_code}, server) do
    case DeviceFlow.poll_for_token(device_code) do
      {:ok, access_token} ->
        handle_successful_auth(server, access_token)

      :pending ->
        put_action(server, :poll_pending, %{})

      :slow_down ->
        put_action(server, :poll_slow_down, %{})

      {:error, reason} ->
        put_action(server, :set_device_flow_error, %{error: reason})
    end
  end

  defp handle_successful_auth(server, access_token) do
    case DeviceFlow.get_user_info(access_token) do
      {:ok, user_info} ->
        user_params = Map.put(user_info, :access_token, access_token)

        case find_or_create_user(user_params) do
          {:ok, user} ->
            server
            |> delete_session(:device_code)
            |> delete_session(:device_code_expires_at)
            |> delete_session(:device_poll_interval)
            |> put_session(:user_id, user.id)
            |> put_cookie("viban_user_id", user.id, max_age: 60 * 60 * 24 * 30)  # 30 days
            |> put_action(:auth_success, %{user: serialize_user(user)})

          {:error, _reason} ->
            put_action(server, :set_device_flow_error, %{error: "Failed to create user account"})
        end

      {:error, reason} ->
        put_action(server, :set_device_flow_error, %{error: reason})
    end
  end

  defp find_or_create_user(%{provider: provider, provider_uid: provider_uid} = params) do
    case User.by_provider_uid(provider, provider_uid) do
      {:ok, nil} ->
        User.create(params)

      {:ok, user} ->
        update_params = Map.drop(params, [:provider, :provider_uid])
        User.update(user, update_params)

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        if Enum.any?(errors, &match?(%Ash.Error.Query.NotFound{}, &1)) do
          User.create(params)
        else
          {:error, errors}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp load_user_and_boards(nil), do: {nil, []}

  defp load_user_and_boards(user_id) do
    case load_user_by_id(user_id) do
      nil ->
        {nil, []}

      user ->
        boards =
          user_id
          |> Viban.Kanban.Board.for_user!()
          |> Enum.map(&serialize_board/1)

        {serialize_user(user), boards}
    end
  end

  defp load_user_by_id(user_id) do
    Viban.Accounts.User.get!(user_id)
  rescue
    _ -> nil
  end

  defp serialize_user(user) do
    %{
      id: to_string(user.id),
      name: user.name || "",
      email: user.email || "",
      avatar_url: user.avatar_url || "",
      provider: user.provider,
      provider_login: user.provider_login
    }
  end

  defp serialize_board(board) do
    %{
      id: to_string(board.id),
      name: board.name || "",
      description: board.description || ""
    }
  end
end
