defmodule VibanWeb.Live.HomeLive do
  @moduledoc """
  Home page for Viban Kanban - shows board list and allows board creation.
  Matches the SolidJS frontend design with GitHub authentication.
  """

  use VibanWeb, :live_view

  alias Viban.Accounts.User
  alias Viban.KanbanLite.Board
  alias Viban.VCS

  @impl true
  def mount(_params, session, socket) do
    user = load_user_from_session(session)
    boards = Board.list_all!()

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:boards, boards)
     |> assign(:show_create_form, false)
     |> assign(:repos, [])
     |> assign(:repos_loading, false)
     |> assign(:repos_error, nil)
     |> assign(:selected_repo, nil)
     |> assign(:repo_search, "")
     |> assign(:form, to_form(%{"name" => "", "description" => ""}))
     |> assign(:create_error, nil)
     |> assign(:is_submitting, false)}
  end

  defp load_user_from_session(%{"user_id" => user_id}) when is_binary(user_id) do
    case User.get(user_id) do
      {:ok, user} -> user
      _ -> nil
    end
  end

  defp load_user_from_session(_), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-gray-950 text-white p-8">
      <div class="max-w-4xl mx-auto">
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-3xl font-bold text-brand-500">Viban Kanban</h1>
            <p class="text-gray-400 mt-1">Manage your projects with ease</p>
          </div>
          <div class="flex items-center gap-4">
            <.user_menu user={@user} />
            <.button phx-click="start_creating" class="bg-brand-600 hover:bg-brand-700">
              <.icon name="hero-plus" class="h-5 w-5" /> New Board
            </.button>
          </div>
        </div>

        <.create_board_form
          :if={@show_create_form}
          form={@form}
          repos={@repos}
          repos_loading={@repos_loading}
          repos_error={@repos_error}
          selected_repo={@selected_repo}
          repo_search={@repo_search}
          create_error={@create_error}
          is_submitting={@is_submitting}
        />

        <.boards_list boards={@boards} user={@user} />

        <footer class="mt-16 pt-8 border-t border-gray-800 text-center text-gray-500 text-sm">
          <p>Powered by Elixir + Ash Framework + Phoenix LiveView + SQLite</p>
        </footer>
      </div>
    </main>
    """
  end

  # ============================================================================
  # Components
  # ============================================================================

  attr :user, :map, default: nil

  defp user_menu(assigns) do
    ~H"""
    <div :if={@user} class="flex items-center gap-3">
      <img
        :if={@user.avatar_url}
        src={@user.avatar_url}
        alt={@user.provider_login}
        class="w-8 h-8 rounded-full"
      />
      <span class="text-gray-300">{@user.provider_login}</span>
      <button phx-click="logout" class="text-gray-400 hover:text-gray-200 text-sm">
        Logout
      </button>
    </div>
    <button
      :if={!@user}
      phx-click="login"
      class="px-4 py-2 bg-gray-800 hover:bg-gray-700 text-white rounded-lg transition-colors flex items-center gap-2"
    >
      <.github_icon class="w-5 h-5" /> Sign in with GitHub
    </button>
    """
  end

  defp github_icon(assigns) do
    ~H"""
    <svg class={@class} fill="currentColor" viewBox="0 0 24 24">
      <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
    </svg>
    """
  end

  attr :form, :any, required: true
  attr :repos, :list, required: true
  attr :repos_loading, :boolean, required: true
  attr :repos_error, :string, default: nil
  attr :selected_repo, :map, default: nil
  attr :repo_search, :string, required: true
  attr :create_error, :string, default: nil
  attr :is_submitting, :boolean, required: true

  defp create_board_form(assigns) do
    ~H"""
    <div class="bg-gray-900/50 border border-gray-800 rounded-xl p-6 mb-8">
      <h2 class="text-lg font-semibold text-white mb-4">Create New Board</h2>
      <.form for={@form} phx-submit="create_board" class="space-y-4">
        <div>
          <label for="boardName" class="block text-sm font-medium text-gray-300 mb-1">
            Board Name *
          </label>
          <input
            id="boardName"
            name="name"
            type="text"
            value={@form[:name].value}
            placeholder="Enter board name..."
            class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500"
            autofocus
          />
        </div>

        <div>
          <label for="boardDescription" class="block text-sm font-medium text-gray-300 mb-1">
            Description
          </label>
          <textarea
            id="boardDescription"
            name="description"
            value={@form[:description].value}
            placeholder="Enter board description..."
            rows="2"
            class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 resize-none"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-300 mb-1">
            Repository *
          </label>

          <div
            :if={@selected_repo}
            class="flex items-center justify-between p-3 bg-gray-800 border border-brand-500/50 rounded-lg"
          >
            <div class="flex items-center gap-2">
              <img
                src={@selected_repo["owner"]["avatar_url"]}
                alt={@selected_repo["owner"]["login"]}
                class="w-5 h-5 rounded-full"
              />
              <span class="font-medium text-white">{@selected_repo["full_name"]}</span>
              <span
                :if={@selected_repo["private"]}
                class="px-1.5 py-0.5 text-xs bg-amber-500/20 text-amber-400 rounded"
              >
                Private
              </span>
            </div>
            <button type="button" phx-click="clear_repo" class="text-gray-400 hover:text-gray-200">
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>

          <div :if={!@selected_repo} class="space-y-2">
            <input
              type="text"
              value={@repo_search}
              phx-keyup="search_repos"
              phx-debounce="150"
              placeholder="Search repositories..."
              class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500"
            />

            <div class="max-h-64 overflow-y-auto bg-gray-800 border border-gray-700 rounded-lg">
              <div :if={@repos_loading} class="p-4 text-center text-gray-400">
                <.spinner class="h-6 w-6 mx-auto mb-2" /> Loading repositories...
              </div>

              <div :if={@repos_error} class="p-4 text-center text-red-400">
                {@repos_error}
              </div>

              <div
                :if={!@repos_loading && !@repos_error && @repos == []}
                class="p-4 text-center text-gray-400"
              >
                No repositories found
              </div>

              <button
                :for={repo <- filter_repos(@repos, @repo_search)}
                type="button"
                phx-click="select_repo"
                phx-value-repo_id={repo["id"]}
                class="w-full p-3 text-left hover:bg-gray-700 border-b border-gray-700 last:border-b-0 transition-colors"
              >
                <div class="flex items-center gap-2">
                  <img
                    src={repo["owner"]["avatar_url"]}
                    alt={repo["owner"]["login"]}
                    class="w-5 h-5 rounded-full"
                  />
                  <span class="font-medium text-white">{repo["full_name"]}</span>
                  <span
                    :if={repo["private"]}
                    class="px-1.5 py-0.5 text-xs bg-amber-500/20 text-amber-400 rounded"
                  >
                    Private
                  </span>
                </div>
                <p :if={repo["description"]} class="text-sm text-gray-400 mt-1 line-clamp-1">
                  {repo["description"]}
                </p>
                <p class="text-xs text-gray-500 mt-1">
                  Default branch: {repo["default_branch"]}
                </p>
              </button>
            </div>
          </div>
        </div>

        <div
          :if={@create_error}
          class="p-3 bg-red-500/10 border border-red-500/30 rounded-lg text-red-400 text-sm"
        >
          {@create_error}
        </div>

        <div class="flex gap-3">
          <button
            type="button"
            phx-click="cancel_create"
            class="flex-1 py-2 px-4 bg-gray-800 hover:bg-gray-700 text-gray-300 rounded-lg transition-colors"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={@is_submitting}
            class="flex-1 py-2 px-4 bg-brand-600 hover:bg-brand-700 disabled:bg-brand-800 disabled:cursor-not-allowed text-white rounded-lg transition-colors flex items-center justify-center gap-2"
          >
            <.spinner :if={@is_submitting} class="h-4 w-4" />
            {if @is_submitting, do: "Creating...", else: "Create Board"}
          </button>
        </div>
      </.form>
    </div>
    """
  end

  attr :boards, :list, required: true
  attr :user, :map, default: nil

  defp boards_list(assigns) do
    ~H"""
    <div
      :if={@boards == []}
      class="bg-gray-900/50 border border-gray-800 border-dashed rounded-xl p-12 text-center"
    >
      <.icon name="hero-clipboard-document-list" class="w-12 h-12 text-gray-600 mx-auto mb-4" />
      <h3 class="text-lg font-medium text-gray-400 mb-2">No boards yet</h3>
      <p class="text-gray-500 mb-4">
        {if @user,
          do: "Create your first board to get started",
          else: "Sign in to create your first board"}
      </p>
      <button
        phx-click={if @user, do: "start_creating", else: "login"}
        class="px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white rounded-lg transition-colors"
      >
        {if @user, do: "Create a Board", else: "Sign in with GitHub"}
      </button>
    </div>

    <div :if={@boards != []} class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <.link
        :for={board <- @boards}
        navigate={~p"/board/#{board.id}"}
        class="block bg-gray-900/50 border border-gray-800 rounded-xl p-6 hover:border-brand-500/50 hover:bg-gray-900 transition-all group"
      >
        <h3 class="text-lg font-semibold text-white group-hover:text-brand-400 transition-colors">
          {board.name}
        </h3>
        <p :if={board.description} class="text-gray-400 text-sm mt-1 line-clamp-2">
          {board.description}
        </p>
        <p class="text-xs text-gray-500 mt-4">
          Updated {format_date(board.updated_at)}
        </p>
      </.link>
    </div>
    """
  end

  defp filter_repos(repos, ""), do: repos

  defp filter_repos(repos, search) do
    search_lower = String.downcase(search)

    Enum.filter(repos, fn repo ->
      String.contains?(String.downcase(repo["name"] || ""), search_lower) ||
        String.contains?(String.downcase(repo["full_name"] || ""), search_lower) ||
        String.contains?(String.downcase(repo["description"] || ""), search_lower)
    end)
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y")
  end

  # ============================================================================
  # Event Handlers
  # ============================================================================

  @impl true
  def handle_event("login", _params, socket) do
    {:noreply, redirect(socket, external: "/api/auth/device/start")}
  end

  def handle_event("logout", _params, socket) do
    {:noreply,
     socket
     |> assign(:user, nil)
     |> put_flash(:info, "Logged out successfully")}
  end

  def handle_event("start_creating", _params, socket) do
    if socket.assigns.user do
      send(self(), :load_repos)

      {:noreply,
       socket
       |> assign(:show_create_form, true)
       |> assign(:repos_loading, true)
       |> assign(:repos_error, nil)}
    else
      {:noreply, redirect(socket, external: "/api/auth/device/start")}
    end
  end

  def handle_event("cancel_create", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_create_form, false)
     |> assign(:selected_repo, nil)
     |> assign(:repo_search, "")
     |> assign(:create_error, nil)
     |> assign(:form, to_form(%{"name" => "", "description" => ""}))}
  end

  def handle_event("search_repos", %{"value" => value}, socket) do
    {:noreply, assign(socket, :repo_search, value)}
  end

  def handle_event("select_repo", %{"repo_id" => repo_id}, socket) do
    repo = Enum.find(socket.assigns.repos, fn r -> to_string(r["id"]) == repo_id end)
    {:noreply, assign(socket, :selected_repo, repo)}
  end

  def handle_event("clear_repo", _params, socket) do
    {:noreply, assign(socket, :selected_repo, nil)}
  end

  def handle_event("create_board", %{"name" => name, "description" => description}, socket) do
    if socket.assigns.selected_repo do
      repo = socket.assigns.selected_repo

      {:noreply, assign(socket, :is_submitting, true)}

      case Board.create(%{
             name: name,
             description: if(description == "", do: nil, else: description),
             user_id: socket.assigns.user.id,
             repository_id: repo["id"],
             repository_full_name: repo["full_name"],
             repository_name: repo["name"],
             repository_clone_url: repo["clone_url"],
             repository_html_url: repo["html_url"],
             repository_default_branch: repo["default_branch"]
           }) do
        {:ok, board} ->
          {:noreply,
           socket
           |> put_flash(:info, "Board created!")
           |> push_navigate(to: ~p"/board/#{board.id}")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> assign(:is_submitting, false)
           |> assign(:create_error, "Failed to create board")}
      end
    else
      {:noreply, assign(socket, :create_error, "Please select a repository")}
    end
  end

  @impl true
  def handle_info(:load_repos, socket) do
    user = socket.assigns.user

    case VCS.list_repos(user.provider, user.access_token, per_page: 100, sort: "updated") do
      {:ok, repos} ->
        {:noreply,
         socket
         |> assign(:repos, repos)
         |> assign(:repos_loading, false)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:repos_loading, false)
         |> assign(:repos_error, "Failed to load repositories: #{inspect(reason)}")}
    end
  end
end
