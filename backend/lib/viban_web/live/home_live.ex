defmodule VibanWeb.HomeLive do
  use VibanWeb, :live_view

  alias Viban.Accounts.User
  alias Viban.Auth.DeviceFlow
  alias Viban.Kanban.Board

  require Logger

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"] || get_connect_params(socket)["user_id"]

    {user, boards} = load_user_and_boards(user_id)

    socket =
      socket
      |> assign(:page_title, "Home")
      |> assign(:user, user)
      |> assign(:boards, boards)
      |> assign(:loading, false)
      |> assign(:show_create_modal, false)
      |> assign(:show_auth_modal, false)
      |> assign(:auth_status, :idle)
      |> assign(:auth_user_code, nil)
      |> assign(:auth_verification_uri, nil)
      |> assign(:auth_error, nil)
      |> assign(:auth_device_code, nil)
      |> assign(:auth_poll_interval, 5)
      |> assign(:user_menu_open, false)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
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
              <%= if @user == nil do %>
                <button
                  phx-click="start_auth"
                  class="inline-flex items-center gap-2 px-4 py-2 bg-gray-800 hover:bg-gray-700 text-white border border-gray-700 font-medium rounded-lg transition-colors"
                >
                  <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
                  </svg>
                  Sign in with GitHub
                </button>
              <% else %>
                <.user_menu user={@user} menu_open={@user_menu_open} />
              <% end %>
            </div>
          </div>
        </div>
      </header>

      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="flex items-center justify-between mb-8">
          <h2 class="text-2xl font-bold text-white">Your Boards</h2>
          <%= if @user != nil do %>
            <button
              phx-click="show_create_modal"
              class="inline-flex items-center gap-2 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors"
            >
              + New Board
            </button>
          <% end %>
        </div>

        <%= if @loading do %>
          <div class="flex items-center justify-center py-12">
            <.spinner class="h-8 w-8" />
          </div>
        <% else %>
          <%= if @user == nil do %>
            <div class="text-center py-12">
              <h3 class="text-lg font-medium text-white mb-2">Welcome to Viban</h3>
              <p class="text-gray-400 mb-6">Sign in with GitHub to create and manage your boards</p>
            </div>
          <% else %>
            <%= if @boards == [] do %>
              <div class="text-center py-12">
                <h3 class="text-lg font-medium text-white mb-2">No boards yet</h3>
                <p class="text-gray-400 mb-6">Create your first board to get started</p>
              </div>
            <% else %>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <%= for board <- @boards do %>
                  <.board_card board={board} />
                <% end %>
              </div>
            <% end %>
          <% end %>
        <% end %>
      </main>

      <%= if @show_auth_modal do %>
        <.auth_modal
          status={@auth_status}
          user_code={@auth_user_code}
          verification_uri={@auth_verification_uri}
          error={@auth_error}
        />
      <% end %>

      <%= if @show_create_modal do %>
        <.create_board_modal />
      <% end %>
    </div>
    """
  end

  attr :user, :map, required: true
  attr :menu_open, :boolean, required: true

  defp user_menu(assigns) do
    ~H"""
    <div class="relative">
      <button
        phx-click="toggle_user_menu"
        class="flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-gray-800 transition-colors"
      >
        <img
          src={@user.avatar_url}
          alt={@user.name}
          class="w-8 h-8 rounded-full"
        />
        <span class="text-white text-sm">{@user.name || @user.provider_login}</span>
        <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      <%= if @menu_open do %>
        <div
          phx-click-away="close_user_menu"
          class="absolute right-0 mt-2 w-48 bg-gray-900 border border-gray-800 rounded-lg shadow-xl z-50"
        >
          <div class="py-1">
            <button
              phx-click="logout"
              class="w-full text-left px-4 py-2 text-sm text-gray-300 hover:bg-gray-800 hover:text-white"
            >
              Sign out
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  attr :board, :map, required: true

  defp board_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/boards/#{@board.id}"}
      class="block p-6 bg-gray-900 border border-gray-800 rounded-xl hover:border-gray-700 transition-colors"
    >
      <h3 class="text-lg font-semibold text-white mb-2">{@board.name}</h3>
      <p class="text-gray-400 text-sm line-clamp-2">{@board.description || "No description"}</p>
    </.link>
    """
  end

  attr :status, :atom, required: true
  attr :user_code, :string, default: nil
  attr :verification_uri, :string, default: nil
  attr :error, :string, default: nil

  defp auth_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto">
      <div class="flex min-h-full items-center justify-center p-4">
        <div phx-click="close_auth_modal" class="fixed inset-0 bg-black/60 transition-opacity"></div>
        <div class="relative transform overflow-hidden rounded-xl bg-gray-900 border border-gray-800 shadow-xl transition-all w-full max-w-md p-6">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-semibold text-white">Sign in with GitHub</h3>
            <button
              phx-click="close_auth_modal"
              class="text-gray-400 hover:text-white transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <%= case @status do %>
            <% status when status in [:idle, :loading] -> %>
              <div class="flex flex-col items-center py-8">
                <.spinner class="h-8 w-8" />
                <p class="text-gray-400 mt-4">Initializing GitHub login...</p>
              </div>

            <% :pending -> %>
              <div class="text-center">
                <p class="text-gray-400 mb-6">
                  Visit <a href={@verification_uri} target="_blank" class="text-brand-500 hover:text-brand-400">{@verification_uri}</a> and enter this code:
                </p>
                <div class="relative mb-6">
                  <button
                    phx-click="copy_code"
                    phx-value-code={@user_code}
                    class="w-full bg-gray-800 border-2 border-gray-700 hover:border-brand-500 rounded-lg p-4 transition-colors"
                  >
                    <span class="text-3xl font-mono font-bold text-white tracking-widest">{@user_code}</span>
                  </button>
                  <p class="text-xs text-gray-500 mt-2">Click to copy</p>
                </div>
                <div class="flex items-center justify-center gap-2 text-gray-400">
                  <.spinner class="h-4 w-4" />
                  <span>Waiting for authorization...</span>
                </div>
              </div>

            <% :error -> %>
              <div class="text-center py-8">
                <h3 class="text-lg font-medium text-white mb-2">Authentication Failed</h3>
                <p class="text-gray-400 mb-4">{@error}</p>
                <button
                  phx-click="retry_auth"
                  class="px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors"
                >
                  Try Again
                </button>
              </div>

            <% :success -> %>
              <div class="text-center py-8">
                <h3 class="text-lg font-medium text-white mb-2">Successfully signed in!</h3>
                <p class="text-gray-400">Redirecting...</p>
              </div>

            <% _ -> %>
              <div class="text-center py-8">
                <p class="text-gray-400">Unknown state</p>
              </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp create_board_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto">
      <div class="flex min-h-full items-center justify-center p-4">
        <div phx-click="hide_create_modal" class="fixed inset-0 bg-black/60 transition-opacity"></div>
        <div class="relative transform overflow-hidden rounded-xl bg-gray-900 border border-gray-800 shadow-xl transition-all w-full max-w-md p-6">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-semibold text-white">Create New Board</h3>
            <button
              phx-click="hide_create_modal"
              class="text-gray-400 hover:text-white transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <form phx-submit="create_board" class="space-y-4">
            <div>
              <label for="board_name" class="block text-sm font-medium text-gray-300 mb-1">Name *</label>
              <input
                type="text"
                id="board_name"
                name="name"
                required
                class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent"
                placeholder="Enter board name..."
              />
            </div>

            <div>
              <label for="board_description" class="block text-sm font-medium text-gray-300 mb-1">Description</label>
              <textarea
                id="board_description"
                name="description"
                rows="3"
                class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent resize-none"
                placeholder="Enter board description..."
              ></textarea>
            </div>

            <div class="flex gap-3 pt-2">
              <button
                type="button"
                phx-click="hide_create_modal"
                class="flex-1 px-4 py-2 text-gray-300 hover:text-white bg-gray-800 hover:bg-gray-700 rounded-lg transition-colors"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="flex-1 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors"
              >
                Create Board
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # Event handlers

  @impl true
  def handle_event("start_auth", _params, socket) do
    socket =
      socket
      |> assign(:show_auth_modal, true)
      |> assign(:auth_status, :loading)

    send(self(), :request_device_code)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_auth_modal", _params, socket) do
    {:noreply, assign(socket, show_auth_modal: false, auth_status: :idle)}
  end

  @impl true
  def handle_event("retry_auth", _params, socket) do
    socket =
      socket
      |> assign(:auth_status, :loading)
      |> assign(:auth_error, nil)

    send(self(), :request_device_code)

    {:noreply, socket}
  end

  @impl true
  def handle_event("copy_code", %{"code" => code}, socket) do
    {:noreply, push_event(socket, "copy_to_clipboard", %{text: code})}
  end

  @impl true
  def handle_event("toggle_user_menu", _params, socket) do
    {:noreply, assign(socket, :user_menu_open, !socket.assigns.user_menu_open)}
  end

  @impl true
  def handle_event("close_user_menu", _params, socket) do
    {:noreply, assign(socket, :user_menu_open, false)}
  end

  @impl true
  def handle_event("logout", _params, socket) do
    {:noreply, redirect(socket, to: ~p"/logout")}
  end

  @impl true
  def handle_event("show_create_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_modal, true)}
  end

  @impl true
  def handle_event("hide_create_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_modal, false)}
  end

  @impl true
  def handle_event("create_board", %{"name" => name, "description" => description}, socket) do
    user = socket.assigns.user

    case Board.create(%{name: name, description: description, user_id: user.id}) do
      {:ok, board} ->
        boards = [serialize_board(board) | socket.assigns.boards]

        socket =
          socket
          |> assign(:boards, boards)
          |> assign(:show_create_modal, false)
          |> put_flash(:info, "Board created successfully!")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create board")}
    end
  end

  # Handle info messages for async operations

  @impl true
  def handle_info(:request_device_code, socket) do
    case DeviceFlow.request_device_code() do
      {:ok, data} ->
        socket =
          socket
          |> assign(:auth_status, :pending)
          |> assign(:auth_user_code, data.user_code)
          |> assign(:auth_verification_uri, data.verification_uri)
          |> assign(:auth_device_code, data.device_code)
          |> assign(:auth_poll_interval, data.interval)

        schedule_poll(data.interval)

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:auth_status, :error)
          |> assign(:auth_error, reason)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:poll_for_token, socket) do
    device_code = socket.assigns.auth_device_code
    interval = socket.assigns.auth_poll_interval

    case DeviceFlow.poll_for_token(device_code) do
      {:ok, access_token} ->
        handle_successful_auth(socket, access_token)

      :pending ->
        schedule_poll(interval)
        {:noreply, socket}

      :slow_down ->
        new_interval = interval + 5
        schedule_poll(new_interval)
        {:noreply, assign(socket, :auth_poll_interval, new_interval)}

      {:error, reason} ->
        socket =
          socket
          |> assign(:auth_status, :error)
          |> assign(:auth_error, reason)

        {:noreply, socket}
    end
  end

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll_for_token, interval * 1000)
  end

  defp handle_successful_auth(socket, access_token) do
    case DeviceFlow.get_user_info(access_token) do
      {:ok, user_info} ->
        user_params = Map.put(user_info, :access_token, access_token)

        case find_or_create_user(user_params) do
          {:ok, user} ->
            token = Phoenix.Token.sign(VibanWeb.Endpoint, "device_flow_user", user.id)
            callback_url = ~p"/auth/callback?token=#{token}"

            socket =
              socket
              |> assign(:auth_status, :success)
              |> redirect(to: callback_url)

            {:noreply, socket}

          {:error, _reason} ->
            socket =
              socket
              |> assign(:auth_status, :error)
              |> assign(:auth_error, "Failed to create user account")

            {:noreply, socket}
        end

      {:error, reason} ->
        socket =
          socket
          |> assign(:auth_status, :error)
          |> assign(:auth_error, reason)

        {:noreply, socket}
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
          |> Board.for_user!()
          |> Enum.map(&serialize_board/1)

        {serialize_user(user), boards}
    end
  end

  defp load_user_by_id(user_id) do
    User.get!(user_id)
  rescue
    _ -> nil
  end

  defp serialize_user(user) do
    %{
      id: user.id,
      name: user.name || "",
      email: user.email || "",
      avatar_url: user.avatar_url || "",
      provider: user.provider,
      provider_login: user.provider_login
    }
  end

  defp serialize_board(board) do
    %{
      id: board.id,
      name: board.name || "",
      description: board.description || ""
    }
  end
end
