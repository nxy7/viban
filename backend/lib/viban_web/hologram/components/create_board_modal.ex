defmodule VibanWeb.Hologram.Components.CreateBoardModal do
  use Hologram.Component

  alias Viban.Kanban.Board
  alias Viban.VCS

  def init(_props, component) do
    component
    |> put_state(:board_name, "")
    |> put_state(:board_description, "")
    |> put_state(:repos, [])
    |> put_state(:repos_loading, true)
    |> put_state(:selected_repo, nil)
    |> put_state(:search_query, "")
    |> put_state(:submitting, false)
    |> put_state(:error, nil)
    |> put_state(:name_manually_edited, false)
    |> put_action(:load_repos_init)
  end

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <div class="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center z-50">
      <div class="bg-gray-900 border border-gray-800 rounded-xl shadow-2xl w-full max-w-lg mx-4 max-h-[90vh] flex flex-col">
        <div class="flex items-center justify-between p-4 border-b border-gray-800">
          <h2 class="text-lg font-semibold text-white">Create New Board</h2>
          <button
            class="p-1 text-gray-400 hover:text-white rounded transition-colors"
            $click={action: :hide_create_board_modal, target: "page"}
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>

        <div class="p-4 overflow-y-auto flex-1">
          {%if @error}
            <div class="mb-4 p-3 bg-red-500/20 border border-red-500/50 rounded-lg text-red-400 text-sm">
              {@error}
            </div>
          {/if}

          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-300 mb-2">Repository (count: {length(@repos)})</label>
              {%if @repos_loading}
                <div class="flex items-center gap-2 text-gray-400 py-2">
                  <div class="animate-spin rounded-full h-4 w-4 border border-gray-600 border-t-brand-500"></div>
                  <span class="text-sm">Loading repositories...</span>
                </div>
              {%else}
                <div class="relative">
                  <input
                    type="text"
                    placeholder="Search repositories..."
                    class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-brand-500 transition-colors"
                    value={@search_query}
                    $input="update_search"
                  />
                  <svg class="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                  </svg>
                </div>

                <div class="mt-2 max-h-48 overflow-y-auto border border-gray-700 rounded-lg">
                  {%if filtered_repos(@repos, @search_query) == []}
                    <div class="p-3 text-gray-400 text-sm text-center">
                      No repositories found
                    </div>
                  {%else}
                    {%for {repo, index} <- Enum.with_index(filtered_repos(@repos, @search_query))}
                      <button
                        class={"w-full text-left px-3 py-2 hover:bg-gray-800 transition-colors border-b border-gray-700 last:border-0 #{if is_selected(@selected_repo, repo), do: "bg-brand-600/20 border-brand-500/50", else: ""}"}
                        $click={:select_repo, index: index}

                      >
                        <div class="flex items-center gap-2">
                          <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"></path>
                          </svg>
                          <span class="text-white text-sm">{repo.full_name}</span>
                        </div>
                        {%if repo.description}
                          <p class="text-gray-400 text-xs mt-1 line-clamp-1">{repo.description}</p>
                        {/if}
                      </button>
                    {/for}
                  {/if}
                </div>
              {/if}

              {%if @selected_repo}
                <div class="mt-2 flex items-center gap-2 text-sm text-brand-400">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                  </svg>
                  <span>Selected: {@selected_repo.full_name}</span>
                </div>
              {/if}
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-300 mb-2">Board Name</label>
              <input
                type="text"
                placeholder="Enter board name..."
                class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-brand-500 transition-colors"
                value={@board_name}
                $input="update_board_name"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-300 mb-2">Description (optional)</label>
              <textarea
                placeholder="Enter board description..."
                class="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-brand-500 transition-colors resize-none"
                rows="3"
                $input="update_description"
              >{@board_description}</textarea>
            </div>
          </div>
        </div>

        <div class="flex items-center justify-end gap-3 p-4 border-t border-gray-800">
          <button
            class="px-4 py-2 text-gray-300 hover:text-white transition-colors"
            $click={action: :hide_create_board_modal, target: "page"}
          >
            Cancel
          </button>
          <button
            class={"px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed #{if @submitting, do: "opacity-50 cursor-not-allowed", else: ""}"}
            $click="create_board"
            disabled={is_disabled(@board_name, @selected_repo, @submitting)}
          >
            {%if @submitting}
              <span class="flex items-center gap-2">
                <div class="animate-spin rounded-full h-4 w-4 border border-white/50 border-t-white"></div>
                Creating...
              </span>
            {%else}
              Create Board
            {/if}
          </button>
        </div>
      </div>
    </div>
    """
  end

  def action(:load_repos_init, _params, component) do
    put_command(component, :load_repos, %{})
  end

  def action(:stop_propagation, _params, component) do
    component
  end

  def action(:update_search, %{event: %{value: value}}, component) do
    put_state(component, :search_query, value)
  end

  def action(:update_board_name, %{event: %{value: value}}, component) do
    component
    |> put_state(:board_name, value)
    |> put_state(:name_manually_edited, true)
  end

  def action(:update_description, %{event: %{value: value}}, component) do
    put_state(component, :board_description, value)
  end

  def action(:select_repo, %{index: index}, component) do
    filtered = filtered_repos(component.state.repos, component.state.search_query)
    repo = Enum.at(filtered, index)

    component = put_state(component, :selected_repo, repo)

    if !component.state.name_manually_edited || component.state.board_name == "" do
      generated_name = generate_board_name(repo.name)
      put_state(component, :board_name, generated_name)
    else
      component
    end
  end

  def action(:set_repos, %{repos: repos}, component) do
    component
    |> put_state(:repos, repos)
    |> put_state(:repos_loading, false)
  end

  def action(:set_error, %{error: error}, component) do
    component
    |> put_state(:error, error)
    |> put_state(:submitting, false)
  end

  def action(:board_created, _params, component) do
    component
    |> put_state(:submitting, false)
    |> put_action(name: :reload_boards, params: %{}, target: :page)
  end

  def action(:create_board, _params, component) do
    component
    |> put_state(:submitting, true)
    |> put_state(:error, nil)
    |> put_command(:create_board, %{
      name: component.state.board_name,
      description: component.state.board_description,
      repo: component.state.selected_repo
    })
  end

  def command(:load_repos, _params, server) do
    user_id = server.session[:user_id] || get_cookie(server, "viban_user_id")

    case Viban.Accounts.User.get(user_id) do
      {:ok, user} ->
        case VCS.list_repos(user.provider, user.access_token, per_page: 100, sort: "updated") do
          {:ok, repos} ->
            IO.puts("========== RAW REPOS FROM GITHUB API ==========")
            IO.inspect(Enum.take(repos, 1), label: "First repo", pretty: true, limit: :infinity)
            IO.puts("===============================================")

            formatted_repos =
              Enum.map(repos, fn repo ->
                %{
                  id: to_string(repo.id),
                  full_name: repo.full_name || "",
                  name: repo.name || "",
                  description: repo.description || "",
                  clone_url: repo.clone_url || "",
                  html_url: repo.html_url || "",
                  default_branch: repo.default_branch || "main"
                }
              end)

            IO.puts("========== FORMATTED REPOS ==========")
            IO.inspect(Enum.take(formatted_repos, 1), label: "First formatted repo", pretty: true)
            IO.puts("=====================================")

            put_action(server, :set_repos, %{repos: formatted_repos})

          {:error, _reason} ->
            server
            |> put_action(:set_repos, %{repos: []})
            |> put_action(:set_error, %{error: "Failed to load repositories"})
        end

      {:error, _reason} ->
        put_action(server, :set_error, %{error: "User not found"})
    end
  end

  def command(:create_board, %{name: name, description: description, repo: repo}, server) do
    user_id = server.session[:user_id] || get_cookie(server, "viban_user_id")

    case Board.create_with_repository(name, description, user_id, repo) do
      {:ok, _board} ->
        put_action(server, :board_created, %{})

      {:error, reason} ->
        error_message = format_error(reason)
        put_action(server, :set_error, %{error: error_message})
    end
  end

  def filtered_repos(repos, ""), do: repos

  def filtered_repos(repos, query) do
    query = String.downcase(query)

    Enum.filter(repos, fn repo ->
      String.contains?(String.downcase(repo.full_name), query)
    end)
  end

  def is_selected(nil, _repo), do: false
  def is_selected(selected, repo), do: selected.id == repo.id

  def is_disabled(name, repo, submitting) do
    submitting || String.trim(name) == "" || is_nil(repo)
  end

  defp format_error(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map(fn
      %{field: field, message: message} -> "#{field}: #{message}"
      %{message: message} -> message
      error -> inspect(error)
    end)
    |> Enum.join(", ")
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)

  defp generate_board_name(repo_name) when is_binary(repo_name) do
    repo_name
    |> String.replace("-", " ")
    |> String.replace("_", " ")
  end

  defp generate_board_name(_), do: ""
end
