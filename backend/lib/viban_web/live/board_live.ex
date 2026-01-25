defmodule VibanWeb.BoardLive do
  use VibanWeb, :live_view

  alias Viban.Kanban.{Board, Column, ColumnHook, Hook, Task, TaskTemplate}
  alias Viban.Kanban.{HookExecution, ExecutorSession, Message}
  alias Viban.Kanban.SystemHooks.Registry
  alias Phoenix.PubSub

  require Logger

  @impl true
  def mount(%{"board_id" => board_id, "task_id" => task_id}, session, socket) do
    mount(%{"id" => board_id, "task_id" => task_id}, session, socket)
  end

  def mount(%{"id" => board_id} = params, session, socket) do
    user_id = session["user_id"] || get_connect_params(socket)["user_id"]
    task_id = params["task_id"]

    case load_board_with_data(board_id) do
      {:ok, board, columns} ->
        if connected?(socket) do
          PubSub.subscribe(Viban.PubSub, "kanban_lite:board:#{board_id}")
        end

        socket =
          socket
          |> assign(:page_title, board.name)
          |> assign(:board, serialize_board(board))
          |> assign(:columns, columns)
          |> assign(:user_id, user_id)
          |> assign(:selected_task_id, task_id)
          |> assign(:selected_task, load_selected_task(task_id))
          |> assign(:show_create_task_modal, false)
          |> assign(:create_task_column_id, nil)
          |> assign(:show_settings, false)
          |> assign(:settings_tab, "general")
          |> assign(:show_column_settings, false)
          |> assign(:column_settings_id, nil)
          |> assign(:column_settings_tab, "general")
          |> assign(:available_hooks, [])
          |> assign(:column_hooks, [])
          |> assign(:board_hooks, [])
          |> assign(:is_creating_hook, false)
          |> assign(:editing_hook_id, nil)
          |> assign(:hook_form, %{
            name: "",
            kind: "script",
            command: "",
            agent_prompt: "",
            agent_executor: "claude_code",
            agent_auto_approve: false
          })
          |> assign(:task_templates, [])
          |> assign(:is_creating_template, false)
          |> assign(:editing_template_id, nil)
          |> assign(:template_form, %{name: "", description_template: ""})
          |> assign(:show_create_pr_modal, false)
          |> assign(:pr_form, %{title: "", body: ""})
          |> assign(:show_keyboard_shortcuts, false)
          |> assign(:search_query, "")
          |> assign(:task_activity, [])
          |> assign(:task_sessions, [])
          |> assign(:task_panel_fullscreen, false)
          |> assign(:task_panel_hide_details, false)

        {:ok, socket}

      {:error, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Board not found")
          |> redirect(to: ~p"/")

        {:ok, socket}
    end
  end

  @impl true
  def handle_params(%{"task_id" => task_id}, _uri, socket) do
    old_task_id = socket.assigns[:selected_task_id]

    if connected?(socket) && old_task_id && old_task_id != task_id do
      PubSub.unsubscribe(Viban.PubSub, "kanban_lite:task:#{old_task_id}")
    end

    if connected?(socket) && task_id do
      PubSub.subscribe(Viban.PubSub, "kanban_lite:task:#{task_id}")
    end

    {activity, sessions} = load_task_activity(task_id)

    socket =
      socket
      |> assign(:selected_task_id, task_id)
      |> assign(:selected_task, load_selected_task(task_id))
      |> assign(:task_activity, activity)
      |> assign(:task_sessions, sessions)

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    old_task_id = socket.assigns[:selected_task_id]

    if connected?(socket) && old_task_id do
      PubSub.unsubscribe(Viban.PubSub, "kanban_lite:task:#{old_task_id}")
    end

    socket =
      socket
      |> assign(:selected_task_id, nil)
      |> assign(:selected_task, nil)
      |> assign(:task_activity, [])
      |> assign(:task_sessions, [])

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gray-950">
      <header class="flex-shrink-0 border-b border-gray-800 bg-gray-900/50 backdrop-blur-sm">
        <div class="px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-14">
            <div class="flex items-center gap-3">
              <.link navigate={~p"/"} class="text-gray-400 hover:text-white transition-colors">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                </svg>
              </.link>
              <h1 class="text-lg font-semibold text-white">{@board.name}</h1>
            </div>

            <div class="flex-1 flex justify-center px-4">
              <div class="relative w-full max-w-md">
                <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
                <input
                  type="text"
                  placeholder="Filter tasks... (/)"
                  value={@search_query}
                  phx-keyup="update_search"
                  phx-debounce="150"
                  data-keyboard-search
                  class="w-full pl-9 pr-8 py-1.5 bg-gray-800/50 border border-gray-700 rounded-lg text-white placeholder-gray-500 text-sm focus:outline-none focus:ring-1 focus:ring-brand-500 focus:border-brand-500"
                />
                <%= if @search_query != "" do %>
                  <button
                    phx-click="clear_search"
                    class="absolute right-2 top-1/2 -translate-y-1/2 p-1 text-gray-500 hover:text-white transition-colors"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                <% end %>
              </div>
            </div>

            <div class="flex items-center gap-2">
              <button
                phx-click="show_keyboard_shortcuts"
                class="p-2 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
                title="Keyboard shortcuts (?)"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </button>
              <button
                phx-click="open_settings"
                data-keyboard-settings
                class="p-2 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
                title="Settings (,)"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
              </button>
            </div>
          </div>
        </div>
      </header>

      <main class="flex-1 overflow-hidden">
        <.vue
          id="kanban-board"
          component="KanbanBoard"
          props={%{
            board: @board,
            columns: filter_columns(@columns, @search_query),
            selectedTaskId: @selected_task_id
          }}
          class="h-full"
        />
      </main>

      <%= if @selected_task do %>
        <.task_details_panel task={@selected_task} board_id={@board.id} activity={@task_activity} sessions={@task_sessions} fullscreen={@task_panel_fullscreen} hide_details={@task_panel_hide_details} />
      <% end %>

      <%= if @show_create_task_modal do %>
        <.create_task_modal column_id={@create_task_column_id} />
      <% end %>

      <%= if @show_create_pr_modal && @selected_task do %>
        <.create_pr_modal task={@selected_task} pr_form={@pr_form} />
      <% end %>

      <%= if @show_settings do %>
        <.settings_panel
          board={@board}
          active_tab={@settings_tab}
          columns={@columns}
          board_hooks={@board_hooks}
          is_creating_hook={@is_creating_hook}
          editing_hook_id={@editing_hook_id}
          hook_form={@hook_form}
          task_templates={@task_templates}
          is_creating_template={@is_creating_template}
          editing_template_id={@editing_template_id}
          template_form={@template_form}
        />
      <% end %>

      <%= if @show_column_settings do %>
        <.column_settings_panel
          column={find_column(@columns, @column_settings_id)}
          active_tab={@column_settings_tab}
          available_hooks={@available_hooks}
          column_hooks={@column_hooks}
          all_columns={@columns}
        />
      <% end %>

      <%= if @show_keyboard_shortcuts do %>
        <.keyboard_shortcuts_panel />
      <% end %>

      <button class="hidden" phx-click="keyboard_escape" data-keyboard-escape></button>
      <button class="hidden" phx-click="show_keyboard_shortcuts" data-keyboard-help></button>
      <button class="hidden" phx-click="keyboard_new_task" data-keyboard-new-task></button>
    </div>
    """
  end

  defp find_column(columns, column_id) do
    Enum.find(columns, fn c -> c.id == column_id end)
  end

  defp filter_columns(columns, ""), do: columns
  defp filter_columns(columns, nil), do: columns

  defp filter_columns(columns, query) do
    query = String.downcase(query)

    Enum.map(columns, fn column ->
      filtered_tasks =
        Enum.filter(column.tasks, fn task ->
          title_match = task.title && String.contains?(String.downcase(task.title), query)

          desc_match =
            task.description && String.contains?(String.downcase(task.description), query)

          title_match || desc_match
        end)

      Map.put(column, :tasks, filtered_tasks)
    end)
  end

  defp keyboard_shortcuts_panel(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div phx-click="close_keyboard_shortcuts" class="fixed inset-0 bg-black/50 backdrop-blur-sm"></div>
      <div class="relative bg-gray-900 border border-gray-700 rounded-xl shadow-2xl w-full max-w-md mx-4 animate-in zoom-in-95 duration-200">
        <div class="flex items-center justify-between px-6 py-4 border-b border-gray-800">
          <h2 class="text-lg font-semibold text-white">Keyboard Shortcuts</h2>
          <button
            phx-click="close_keyboard_shortcuts"
            class="p-1 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="p-6 space-y-4">
          <div class="space-y-3">
            <h3 class="text-sm font-medium text-gray-400 uppercase tracking-wider">General</h3>
            <.shortcut_row key="?" description="Show this help" />
            <.shortcut_row key="Esc" description="Close panel/modal" />
            <.shortcut_row key="/" description="Focus search" />
            <.shortcut_row key="," description="Open board settings" />
          </div>

          <div class="space-y-3 pt-2">
            <h3 class="text-sm font-medium text-gray-400 uppercase tracking-wider">Tasks</h3>
            <.shortcut_row key="n" description="Create new task" />
          </div>

          <div class="space-y-3 pt-2">
            <h3 class="text-sm font-medium text-gray-400 uppercase tracking-wider">Task Panel</h3>
            <.shortcut_row key="Ctrl+D" description="Duplicate task" />
            <.shortcut_row key="Ctrl+E" description="Open folder" />
            <.shortcut_row key="Ctrl+O" description="Open in editor" />
            <.shortcut_row key="Del" description="Delete task" />
          </div>
        </div>

        <div class="px-6 py-4 border-t border-gray-800 bg-gray-900/50 rounded-b-xl">
          <p class="text-xs text-gray-500 text-center">
            Press <kbd class="px-1.5 py-0.5 bg-gray-800 rounded text-gray-300 font-mono text-xs">Esc</kbd> to close
          </p>
        </div>
      </div>
    </div>
    """
  end

  attr :key, :string, required: true
  attr :description, :string, required: true

  defp shortcut_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <span class="text-gray-300 text-sm">{@description}</span>
      <kbd class="px-2 py-1 bg-gray-800 border border-gray-700 rounded text-gray-300 font-mono text-sm min-w-[2rem] text-center">
        {@key}
      </kbd>
    </div>
    """
  end

  attr :task, :map, required: true
  attr :board_id, :string, required: true
  attr :activity, :list, default: []
  attr :sessions, :list, default: []
  attr :fullscreen, :boolean, default: false
  attr :hide_details, :boolean, default: false

  defp task_details_panel(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex justify-end">
      <div phx-click="close_task_details" class={["fixed inset-0 bg-black/50 backdrop-blur-sm", @fullscreen && "hidden"]}></div>
      <div data-task-panel class={["relative bg-gray-900 border-l border-gray-800 shadow-xl h-full overflow-hidden flex flex-col animate-in slide-in-from-right duration-200", if(@fullscreen, do: "w-full", else: "w-[32rem]")]}>
        <%!-- Header --%>
        <div class="flex-shrink-0 border-b border-gray-800">
          <div class="flex items-center justify-between px-4 py-3">
            <div class="flex items-center gap-2 min-w-0">
              <%= if @task.agent_status do %>
                <.agent_status_badge status={@task.agent_status} />
              <% end %>
              <h2 class="text-lg font-semibold text-white truncate">{@task.title}</h2>
            </div>
            <div class="flex items-center gap-1 flex-shrink-0">
              <%= if @task.worktree_path do %>
                <button
                  phx-click="open_folder"
                  phx-value-task-id={@task.id}
                  class="p-1.5 text-gray-400 hover:text-white hover:bg-gray-800 rounded transition-colors"
                  title="Open folder"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
                  </svg>
                </button>
                <button
                  phx-click="open_in_editor"
                  phx-value-task-id={@task.id}
                  class="p-1.5 text-gray-400 hover:text-white hover:bg-gray-800 rounded transition-colors"
                  title="Open in editor"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
                  </svg>
                </button>
              <% end %>
              <%= if @task.pr_url do %>
                <a
                  href={@task.pr_url}
                  target="_blank"
                  class="p-1.5 text-gray-400 hover:text-white hover:bg-gray-800 rounded transition-colors"
                  title="View PR"
                >
                  <svg class="w-4 h-4" viewBox="0 0 16 16" fill="currentColor">
                    <path fill-rule="evenodd" d="M7.177 3.073L9.573.677A.25.25 0 0110 .854v4.792a.25.25 0 01-.427.177L7.177 3.427a.25.25 0 010-.354zM3.75 2.5a.75.75 0 100 1.5.75.75 0 000-1.5zm-2.25.75a2.25 2.25 0 113 2.122v5.256a2.251 2.251 0 11-1.5 0V5.372A2.25 2.25 0 011.5 3.25zM11 2.5h-1V4h1a1 1 0 011 1v5.628a2.251 2.251 0 101.5 0V5A2.5 2.5 0 0011 2.5zm1 10.25a.75.75 0 111.5 0 .75.75 0 01-1.5 0zM3.75 12a.75.75 0 100 1.5.75.75 0 000-1.5z"/>
                  </svg>
                </a>
              <% else %>
                <%= if @task.worktree_branch do %>
                  <button
                    phx-click="show_create_pr_modal"
                    phx-value-task-id={@task.id}
                    class="p-1.5 text-gray-400 hover:text-brand-400 hover:bg-gray-800 rounded transition-colors"
                    title="Create Pull Request"
                  >
                    <svg class="w-4 h-4" viewBox="0 0 16 16" fill="currentColor">
                      <path fill-rule="evenodd" d="M7.177 3.073L9.573.677A.25.25 0 0110 .854v4.792a.25.25 0 01-.427.177L7.177 3.427a.25.25 0 010-.354zM3.75 2.5a.75.75 0 100 1.5.75.75 0 000-1.5zm-2.25.75a2.25 2.25 0 113 2.122v5.256a2.251 2.251 0 11-1.5 0V5.372A2.25 2.25 0 011.5 3.25zM11 2.5h-1V4h1a1 1 0 011 1v5.628a2.251 2.251 0 101.5 0V5A2.5 2.5 0 0011 2.5zm1 10.25a.75.75 0 111.5 0 .75.75 0 01-1.5 0zM3.75 12a.75.75 0 100 1.5.75.75 0 000-1.5z"/>
                    </svg>
                  </button>
                <% end %>
              <% end %>
              <button
                phx-click="toggle_hide_details"
                class={["p-1.5 hover:bg-gray-800 rounded transition-colors", if(@hide_details, do: "text-brand-400", else: "text-gray-400 hover:text-white")]}
                title={if(@hide_details, do: "Show details", else: "Hide details")}
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <%= if @hide_details do %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                  <% else %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                  <% end %>
                </svg>
              </button>
              <button
                phx-click="toggle_fullscreen"
                class={["p-1.5 hover:bg-gray-800 rounded transition-colors", if(@fullscreen, do: "text-brand-400", else: "text-gray-400 hover:text-white")]}
                title={if(@fullscreen, do: "Exit fullscreen", else: "Fullscreen")}
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <%= if @fullscreen do %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 9V4.5M9 9H4.5M9 9L3.75 3.75M9 15v4.5M9 15H4.5M9 15l-5.25 5.25M15 9h4.5M15 9V4.5M15 9l5.25-5.25M15 15h4.5M15 15v4.5m0-4.5l5.25 5.25" />
                  <% else %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.75 3.75v4.5m0-4.5h4.5m-4.5 0L9 9M3.75 20.25v-4.5m0 4.5h4.5m-4.5 0L9 15M20.25 3.75h-4.5m4.5 0v4.5m0-4.5L15 9m5.25 11.25h-4.5m4.5 0v-4.5m0 4.5L15 15" />
                  <% end %>
                </svg>
              </button>
              <button
                phx-click="close_task_details"
                class="p-1.5 text-gray-400 hover:text-white hover:bg-gray-800 rounded transition-colors"
                title="Close"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          </div>

          <%= if @task.worktree_branch do %>
            <div class="px-4 pb-2 flex items-center gap-2">
              <span class="text-xs text-gray-500 font-mono truncate">{@task.worktree_branch}</span>
              <%= if @task.pr_url do %>
                <a href={@task.pr_url} target="_blank" class={"inline-flex items-center gap-1 px-2 py-0.5 text-xs rounded-full #{pr_status_class(@task.pr_status)}"}>
                  PR #{@task.pr_number}
                </a>
              <% end %>
            </div>
          <% end %>

          <%= if @task.agent_status_message do %>
            <div class="px-4 pb-2">
              <div class="flex items-center gap-2 text-sm text-gray-400">
                <span class="animate-pulse">●</span>
                <span class="truncate">{@task.agent_status_message}</span>
              </div>
            </div>
          <% end %>
        </div>

        <%!-- Activity Feed - Scrollable --%>
        <div class="flex-1 overflow-y-auto px-4 py-4">
          <div class="space-y-4">
            <%!-- Task created message --%>
            <%= unless @hide_details do %>
              <div class="flex items-start gap-3">
                <div class="w-8 h-8 rounded-full bg-gray-800 flex items-center justify-center flex-shrink-0">
                  <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                  </svg>
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-sm text-gray-300">Task created</p>
                  <%= if @task.description do %>
                    <p class="text-sm text-gray-500 mt-1 whitespace-pre-wrap">{@task.description}</p>
                  <% end %>
                  <p class="text-xs text-gray-600 mt-1">{format_activity_time(@task.inserted_at)}</p>
                </div>
              </div>
            <% end %>

            <%!-- Activity items (hook executions and messages) --%>
            <%= for item <- @activity do %>
              <.activity_item item={item} hide_details={@hide_details} />
            <% end %>
          </div>
        </div>

        <%!-- Input area at bottom --%>
        <div class="flex-shrink-0 border-t border-gray-800 p-4">
          <form phx-submit="send_message" class="flex flex-col gap-2">
            <input type="hidden" name="task_id" value={@task.id} />
            <div class="flex items-center gap-2 text-xs text-gray-500 px-1">
              <span>Claude Code</span>
            </div>
            <div class="flex gap-2">
              <textarea
                name="message"
                rows="1"
                placeholder="Enter a prompt... (⌘+Enter to send)"
                class="flex-1 px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-1 focus:ring-brand-500 resize-none"
                phx-hook="AutoResize"
                phx-keydown="maybe_send_message"
                phx-value-task-id={@task.id}
                id={"task-input-#{@task.id}"}
              ></textarea>
              <button
                type="submit"
                class="px-3 py-2 bg-brand-600 hover:bg-brand-700 text-white rounded-lg transition-colors"
                title="Send"
              >
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                </svg>
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :hide_details, :boolean, default: false

  defp activity_item(%{item: %{type: :hook_execution}, hide_details: true} = assigns) do
    ~H"""
    """
  end

  defp activity_item(%{item: %{type: :hook_execution}} = assigns) do
    ~H"""
    <div class="flex items-center gap-2 py-1 px-2 text-xs text-gray-500">
      <span class={"w-1.5 h-1.5 rounded-full flex-shrink-0 #{hook_status_dot(@item.status)}"}></span>
      <span class="truncate">{@item.hook_name}</span>
      <span class={"#{hook_status_text_color(@item.status)}"}>{hook_status_text(@item.status)}</span>
      <%= if @item.duration_ms do %>
        <span class="text-gray-600">{format_duration(@item.duration_ms)}</span>
      <% end %>
      <%= if @item.error_message do %>
        <span class="text-red-400 truncate" title={@item.error_message}>- {@item.error_message}</span>
      <% end %>
      <span class="text-gray-600 ml-auto flex-shrink-0">{format_activity_time(@item.timestamp)}</span>
    </div>
    """
  end

  defp activity_item(%{item: %{type: :message, role: role}} = assigns) do
    assigns = assign(assigns, :is_user, role == :user)

    ~H"""
    <div class={"flex #{if @is_user, do: "justify-end", else: "justify-start"}"}>
      <div class={"max-w-[85%] #{if @is_user, do: "bg-brand-600", else: "bg-gray-700"} rounded-2xl px-3 py-2 #{if @is_user, do: "rounded-br-md", else: "rounded-bl-md"}"}>
        <p class="text-sm text-gray-100 whitespace-pre-wrap break-words">{truncate_content(@item.content, 500)}</p>
        <%= unless @hide_details do %>
          <p class={"text-xs mt-1 #{if @is_user, do: "text-brand-300", else: "text-gray-500"}"}>{format_activity_time(@item.timestamp)}</p>
        <% end %>
      </div>
    </div>
    """
  end

  defp activity_item(assigns) do
    ~H"""
    <div class="flex gap-3">
      <div class="w-8 h-8 rounded-full bg-gray-800 flex items-center justify-center flex-shrink-0">
        <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
      </div>
      <div class="flex-1 pt-1">
        <p class="text-sm text-gray-400">Unknown activity</p>
      </div>
    </div>
    """
  end

  attr :status, :atom, required: true

  defp hook_status_icon(%{status: :completed} = assigns) do
    ~H"""
    <svg class="w-4 h-4 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
    </svg>
    """
  end

  defp hook_status_icon(%{status: :running} = assigns) do
    ~H"""
    <svg class="w-4 h-4 text-blue-400 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
    </svg>
    """
  end

  defp hook_status_icon(%{status: :failed} = assigns) do
    ~H"""
    <svg class="w-4 h-4 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
    </svg>
    """
  end

  defp hook_status_icon(%{status: :skipped} = assigns) do
    ~H"""
    <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 5l7 7-7 7M5 5l7 7-7 7" />
    </svg>
    """
  end

  defp hook_status_icon(assigns) do
    ~H"""
    <svg class="w-4 h-4 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    """
  end

  attr :role, :atom, required: true

  defp message_role_icon(%{role: :user} = assigns) do
    ~H"""
    <svg class="w-4 h-4 text-brand-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
    </svg>
    """
  end

  defp message_role_icon(%{role: :assistant} = assigns) do
    ~H"""
    <svg class="w-4 h-4 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
    </svg>
    """
  end

  defp message_role_icon(%{role: :tool} = assigns) do
    ~H"""
    <svg class="w-4 h-4 text-cyan-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
    </svg>
    """
  end

  defp message_role_icon(assigns) do
    ~H"""
    <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z" />
    </svg>
    """
  end

  defp hook_status_text(:completed), do: "completed"
  defp hook_status_text(:running), do: "running"
  defp hook_status_text(:failed), do: "failed"
  defp hook_status_text(:cancelled), do: "cancelled"
  defp hook_status_text(:skipped), do: "skipped"
  defp hook_status_text(:pending), do: "pending"
  defp hook_status_text(_), do: "unknown"

  defp hook_status_dot(:completed), do: "bg-green-400"
  defp hook_status_dot(:running), do: "bg-blue-400 animate-pulse"
  defp hook_status_dot(:failed), do: "bg-red-400"
  defp hook_status_dot(:cancelled), do: "bg-gray-400"
  defp hook_status_dot(:skipped), do: "bg-gray-400"
  defp hook_status_dot(_), do: "bg-amber-400"

  defp hook_status_text_color(:completed), do: "text-green-400"
  defp hook_status_text_color(:running), do: "text-blue-400"
  defp hook_status_text_color(:failed), do: "text-red-400"
  defp hook_status_text_color(:cancelled), do: "text-gray-400"
  defp hook_status_text_color(:skipped), do: "text-gray-400"
  defp hook_status_text_color(_), do: "text-amber-400"

  defp format_activity_time(nil), do: ""

  defp format_activity_time(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      diff when diff < 60 -> "just now"
      diff when diff < 3600 -> "#{div(diff, 60)}m ago"
      diff when diff < 86400 -> "#{div(diff, 3600)}h ago"
      _ -> Calendar.strftime(datetime, "%b %d, %H:%M")
    end
  end

  defp format_duration(nil), do: ""
  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  defp format_duration(ms) when ms < 60_000, do: "#{Float.round(ms / 1000, 1)}s"
  defp format_duration(ms), do: "#{Float.round(ms / 60_000, 1)}m"

  defp truncate_content(nil, _max), do: ""
  defp truncate_content(content, max) when byte_size(content) <= max, do: content
  defp truncate_content(content, max), do: String.slice(content, 0, max) <> "..."

  attr :column_id, :string, required: true

  defp create_task_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto">
      <div class="flex min-h-full items-center justify-center p-4">
        <div phx-click="hide_create_task_modal" class="fixed inset-0 bg-black/60 transition-opacity"></div>
        <div class="relative transform overflow-hidden rounded-xl bg-gray-900 border border-gray-800 shadow-xl transition-all w-full max-w-md p-6">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-semibold text-white">Create New Task</h3>
            <button
              phx-click="hide_create_task_modal"
              class="text-gray-400 hover:text-white transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <form phx-submit="create_task" class="space-y-4">
            <input type="hidden" name="column_id" value={@column_id} />

            <div>
              <label for="task_title" class="block text-sm font-medium text-gray-300 mb-1">Title *</label>
              <input
                type="text"
                id="task_title"
                name="title"
                required
                class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent"
                placeholder="Enter task title..."
              />
            </div>

            <div>
              <label for="task_description" class="block text-sm font-medium text-gray-300 mb-1">Description</label>
              <textarea
                id="task_description"
                name="description"
                rows="4"
                class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent resize-none"
                placeholder="Enter task description..."
              ></textarea>
            </div>

            <div class="flex gap-3 pt-2">
              <button
                type="button"
                phx-click="hide_create_task_modal"
                class="flex-1 px-4 py-2 text-gray-300 hover:text-white bg-gray-800 hover:bg-gray-700 rounded-lg transition-colors"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="flex-1 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors"
              >
                Create Task
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  attr :task, :map, required: true
  attr :pr_form, :map, required: true

  defp create_pr_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto">
      <div class="flex min-h-full items-center justify-center p-4">
        <div phx-click="hide_create_pr_modal" class="fixed inset-0 bg-black/60 transition-opacity"></div>
        <div class="relative transform overflow-hidden rounded-xl bg-gray-900 border border-gray-800 shadow-xl transition-all w-full max-w-lg p-6">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-semibold text-white">Create Pull Request</h3>
            <button
              phx-click="hide_create_pr_modal"
              class="text-gray-400 hover:text-white transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <div class="p-3 bg-gray-800 rounded-lg mb-4">
            <div class="flex items-center gap-2">
              <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              <span class="text-sm text-gray-400">Branch:</span>
              <span class="text-sm font-mono text-white">{@task.worktree_branch}</span>
            </div>
          </div>

          <form phx-submit="create_pr" class="space-y-4">
            <input type="hidden" name="task_id" value={@task.id} />

            <div>
              <label for="pr_title" class="block text-sm font-medium text-gray-300 mb-1">Title *</label>
              <input
                type="text"
                id="pr_title"
                name="title"
                value={@pr_form.title}
                phx-change="update_pr_form"
                phx-value-field="title"
                required
                class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent"
                placeholder="Enter PR title..."
              />
            </div>

            <div>
              <label for="pr_body" class="block text-sm font-medium text-gray-300 mb-1">Description</label>
              <textarea
                id="pr_body"
                name="body"
                rows="6"
                phx-change="update_pr_form"
                phx-value-field="body"
                class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent resize-none"
                placeholder="Enter PR description..."
              ><%= @pr_form.body %></textarea>
            </div>

            <div class="flex gap-3 pt-2">
              <button
                type="button"
                phx-click="hide_create_pr_modal"
                class="flex-1 px-4 py-2 text-gray-300 hover:text-white bg-gray-800 hover:bg-gray-700 rounded-lg transition-colors"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="flex-1 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors"
              >
                Create PR
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  attr :board, :map, required: true
  attr :active_tab, :string, required: true
  attr :columns, :list, required: true
  attr :board_hooks, :list, required: true
  attr :is_creating_hook, :boolean, required: true
  attr :editing_hook_id, :string, default: nil
  attr :hook_form, :map, required: true
  attr :task_templates, :list, required: true
  attr :is_creating_template, :boolean, required: true
  attr :editing_template_id, :string, default: nil
  attr :template_form, :map, required: true

  defp settings_panel(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex justify-end">
      <div phx-click="close_settings" class="fixed inset-0 bg-black/50 backdrop-blur-sm"></div>
      <div class="relative bg-gray-900 border-l border-gray-800 w-full max-w-2xl h-full shadow-2xl flex flex-col animate-in slide-in-from-right duration-200">
        <div class="flex-shrink-0 bg-gray-900 border-b border-gray-800 px-6 py-4 flex items-center justify-between">
          <h2 class="text-lg font-semibold text-white">{@board.name} Settings</h2>
          <button
            phx-click="close_settings"
            class="p-1 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="flex border-b border-gray-700 px-6">
          <button
            phx-click="set_settings_tab"
            phx-value-tab="general"
            class={"px-3 py-2 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "general", do: "border-brand-500 text-brand-400", else: "border-transparent text-gray-400 hover:text-white"}"}
          >
            General
          </button>
          <button
            phx-click="set_settings_tab"
            phx-value-tab="templates"
            class={"px-3 py-2 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "templates", do: "border-brand-500 text-brand-400", else: "border-transparent text-gray-400 hover:text-white"}"}
          >
            Templates
          </button>
          <button
            phx-click="set_settings_tab"
            phx-value-tab="hooks"
            class={"px-3 py-2 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "hooks", do: "border-brand-500 text-brand-400", else: "border-transparent text-gray-400 hover:text-white"}"}
          >
            Hooks
          </button>
          <button
            phx-click="set_settings_tab"
            phx-value-tab="columns"
            class={"px-3 py-2 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "columns", do: "border-brand-500 text-brand-400", else: "border-transparent text-gray-400 hover:text-white"}"}
          >
            Column Hooks
          </button>
        </div>

        <div class="flex-1 overflow-y-auto px-6 py-4">
          <%= if @active_tab == "general" do %>
            <.settings_general_tab board={@board} />
          <% else %>
            <%= if @active_tab == "templates" do %>
              <.settings_templates_tab
                task_templates={@task_templates}
                is_creating_template={@is_creating_template}
                editing_template_id={@editing_template_id}
                template_form={@template_form}
              />
            <% else %>
              <%= if @active_tab == "hooks" do %>
                <.settings_hooks_tab
                  board_hooks={@board_hooks}
                  is_creating_hook={@is_creating_hook}
                  editing_hook_id={@editing_hook_id}
                  hook_form={@hook_form}
                />
              <% else %>
                <.settings_columns_tab columns={@columns} />
              <% end %>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :board, :map, required: true

  defp settings_general_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-sm font-medium text-gray-400 mb-3">Board Information</h3>
        <form phx-submit="update_board" class="space-y-4">
          <div>
            <label for="board_name" class="block text-sm font-medium text-gray-300 mb-1">Name</label>
            <input
              type="text"
              id="board_name"
              name="name"
              value={@board.name}
              class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
          </div>

          <div>
            <label for="board_description" class="block text-sm font-medium text-gray-300 mb-1">Description</label>
            <textarea
              id="board_description"
              name="description"
              rows="3"
              class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-brand-500 resize-none"
            ><%= @board.description %></textarea>
          </div>

          <button
            type="submit"
            class="w-full px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors"
          >
            Save Changes
          </button>
        </form>
      </div>

      <div class="pt-6 border-t border-gray-800">
        <h3 class="text-sm font-medium text-gray-400 mb-3">Danger Zone</h3>
        <button
          phx-click="delete_board"
          data-confirm="Are you sure you want to delete this board? This action cannot be undone."
          class="w-full px-4 py-2 text-red-400 hover:text-red-300 hover:bg-red-950/50 border border-red-900/50 rounded-lg transition-colors"
        >
          Delete Board
        </button>
      </div>
    </div>
    """
  end

  attr :task_templates, :list, required: true
  attr :is_creating_template, :boolean, required: true
  attr :editing_template_id, :string, default: nil
  attr :template_form, :map, required: true

  defp settings_templates_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex justify-between items-center">
        <div>
          <h3 class="text-lg font-semibold text-white">Task Templates</h3>
          <p class="text-sm text-gray-400">Define templates for quick task creation with pre-filled descriptions.</p>
        </div>
        <%= if !@is_creating_template && !@editing_template_id do %>
          <button
            phx-click="start_create_template"
            class="px-3 py-1.5 bg-brand-600 hover:bg-brand-700 text-white text-sm font-medium rounded-lg transition-colors"
          >
            Add Template
          </button>
        <% end %>
      </div>

      <%= if @is_creating_template || @editing_template_id do %>
        <div class="p-4 bg-gray-800 border border-gray-700 rounded-lg space-y-4">
          <h4 class="text-sm font-medium text-gray-300">
            <%= if @is_creating_template do %>Create Template<% else %>Edit Template<% end %>
          </h4>

          <div>
            <label class="block text-sm text-gray-400 mb-1">Name</label>
            <input
              type="text"
              phx-change="update_template_form"
              phx-value-field="name"
              name="value"
              value={@template_form.name}
              class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500"
              placeholder="e.g., Feature, Bugfix, Refactor"
            />
          </div>

          <div>
            <label class="block text-sm text-gray-400 mb-1">Description Template</label>
            <textarea
              phx-change="update_template_form"
              phx-value-field="description_template"
              name="value"
              rows="4"
              class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 resize-none"
              placeholder="Template text that will be pre-filled when creating tasks..."
            ><%= @template_form.description_template %></textarea>
          </div>

          <div class="flex gap-2">
            <button
              phx-click="cancel_template_edit"
              class="flex-1 px-4 py-2 text-gray-300 hover:text-white bg-gray-700 hover:bg-gray-600 rounded-lg transition-colors"
            >
              Cancel
            </button>
            <button
              phx-click="save_template"
              class="flex-1 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors"
            >
              Save
            </button>
          </div>
        </div>
      <% end %>

      <div class="space-y-2">
        <%= if length(@task_templates) > 0 do %>
          <%= for template <- @task_templates do %>
            <div class="p-4 bg-gray-800/50 border border-gray-700 rounded-lg flex items-center justify-between">
              <div class="min-w-0">
                <div class="font-medium text-white">{template.name}</div>
                <%= if template.description_template do %>
                  <div class="text-sm text-gray-400 mt-1 truncate max-w-md">{truncate_text(template.description_template, 100)}</div>
                <% end %>
              </div>
              <div class="flex items-center gap-2 flex-shrink-0">
                <button
                  phx-click="start_edit_template"
                  phx-value-template-id={template.id}
                  class="p-2 text-gray-400 hover:text-white hover:bg-gray-700 rounded-lg transition-colors"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                  </svg>
                </button>
                <button
                  phx-click="delete_template"
                  phx-value-template-id={template.id}
                  data-confirm="Are you sure you want to delete this template?"
                  class="p-2 text-gray-400 hover:text-red-400 hover:bg-gray-700 rounded-lg transition-colors"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                </button>
              </div>
            </div>
          <% end %>
        <% else %>
          <div class="text-gray-500 text-sm text-center py-8">
            No templates yet. Create one to speed up task creation.
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :board_hooks, :list, required: true
  attr :is_creating_hook, :boolean, required: true
  attr :editing_hook_id, :string, default: nil
  attr :hook_form, :map, required: true

  defp settings_hooks_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex justify-between items-center">
        <div>
          <h3 class="text-lg font-semibold text-white">Hooks</h3>
          <p class="text-sm text-gray-400">Scripts or AI agents triggered when tasks move between columns.</p>
        </div>
        <%= if !@is_creating_hook && !@editing_hook_id do %>
          <button
            phx-click="start_create_hook"
            class="px-3 py-1.5 bg-brand-600 hover:bg-brand-700 text-white text-sm font-medium rounded-lg transition-colors"
          >
            Add Hook
          </button>
        <% end %>
      </div>

      <%= if @is_creating_hook || @editing_hook_id do %>
        <div class="p-4 bg-gray-800 border border-gray-700 rounded-lg space-y-4">
          <h4 class="text-sm font-medium text-gray-300">
            <%= if @is_creating_hook do %>Create Hook<% else %>Edit Hook<% end %>
          </h4>

          <div>
            <label class="block text-sm text-gray-400 mb-1">Name</label>
            <input
              type="text"
              phx-change="update_hook_form"
              phx-value-field="name"
              name="value"
              value={@hook_form.name}
              class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500"
              placeholder="e.g., Run Tests, Deploy to Staging"
            />
          </div>

          <div>
            <label class="block text-sm text-gray-400 mb-2">Hook Type</label>
            <div class="flex gap-4">
              <label class="flex items-center gap-2 cursor-pointer">
                <input
                  type="radio"
                  name="hook_kind"
                  value="script"
                  checked={@hook_form.kind == "script"}
                  phx-click="update_hook_form"
                  phx-value-field="kind"
                  phx-value-value="script"
                  class="text-brand-500 focus:ring-brand-500"
                />
                <span class="text-sm text-gray-300">Script</span>
              </label>
              <label class="flex items-center gap-2 cursor-pointer">
                <input
                  type="radio"
                  name="hook_kind"
                  value="agent"
                  checked={@hook_form.kind == "agent"}
                  phx-click="update_hook_form"
                  phx-value-field="kind"
                  phx-value-value="agent"
                  class="text-brand-500 focus:ring-brand-500"
                />
                <span class="text-sm text-gray-300">AI Agent</span>
              </label>
            </div>
          </div>

          <%= if @hook_form.kind == "script" do %>
            <div>
              <label class="block text-sm text-gray-400 mb-1">Command</label>
              <input
                type="text"
                phx-change="update_hook_form"
                phx-value-field="command"
                name="value"
                value={@hook_form.command}
                class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white font-mono text-sm placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500"
                placeholder="e.g., ./scripts/run-tests.sh"
              />
            </div>
          <% else %>
            <div>
              <label class="block text-sm text-gray-400 mb-1">Agent Executor</label>
              <select
                phx-change="update_hook_form"
                phx-value-field="agent_executor"
                name="value"
                class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-brand-500"
              >
                <option value="claude_code" selected={@hook_form.agent_executor == "claude_code"}>Claude Code</option>
                <option value="gemini_cli" selected={@hook_form.agent_executor == "gemini_cli"}>Gemini CLI</option>
                <option value="codex" selected={@hook_form.agent_executor == "codex"}>Codex</option>
                <option value="opencode" selected={@hook_form.agent_executor == "opencode"}>OpenCode</option>
                <option value="cursor_agent" selected={@hook_form.agent_executor == "cursor_agent"}>Cursor Agent</option>
              </select>
            </div>

            <div>
              <label class="block text-sm text-gray-400 mb-1">Prompt</label>
              <textarea
                phx-change="update_hook_form"
                phx-value-field="agent_prompt"
                name="value"
                rows="4"
                class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 resize-none"
                placeholder="Instructions for the AI agent..."
              ><%= @hook_form.agent_prompt %></textarea>
            </div>

            <div>
              <label class="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={@hook_form.agent_auto_approve}
                  phx-click="toggle_hook_auto_approve"
                  class="text-brand-500 focus:ring-brand-500 rounded"
                />
                <span class="text-sm text-gray-300">Auto-approve agent actions</span>
              </label>
            </div>
          <% end %>

          <div class="flex gap-2">
            <button
              phx-click="cancel_hook_edit"
              class="flex-1 px-4 py-2 text-gray-300 hover:text-white bg-gray-700 hover:bg-gray-600 rounded-lg transition-colors"
            >
              Cancel
            </button>
            <button
              phx-click="save_hook"
              class="flex-1 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors"
            >
              Save
            </button>
          </div>
        </div>
      <% end %>

      <div class="space-y-2">
        <%= if length(@board_hooks) > 0 do %>
          <%= for hook <- @board_hooks do %>
            <div class="p-4 bg-gray-800/50 border border-gray-700 rounded-lg flex items-center justify-between">
              <div class="flex items-center gap-3">
                <%= if hook.is_system do %>
                  <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                <% else %>
                  <%= if hook.hook_kind == "agent" do %>
                    <svg class="w-4 h-4 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                    </svg>
                  <% else %>
                    <svg class="w-4 h-4 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                  <% end %>
                <% end %>
                <div>
                  <div class="font-medium text-white flex items-center gap-2">
                    {hook.name}
                    <%= if hook.is_system do %>
                      <span class="text-xs px-1.5 py-0.5 bg-gray-700 text-gray-400 rounded">System</span>
                    <% end %>
                  </div>
                  <%= if hook.hook_kind == "agent" && hook.agent_prompt do %>
                    <div class="text-xs text-gray-500 mt-0.5 truncate max-w-md">{truncate_text(hook.agent_prompt, 100)}</div>
                  <% end %>
                  <%= if hook.hook_kind == "script" && hook.command do %>
                    <div class="text-xs text-gray-500 font-mono mt-0.5">{hook.command}</div>
                  <% end %>
                </div>
              </div>
              <%= if !hook.is_system do %>
                <div class="flex items-center gap-2">
                  <button
                    phx-click="start_edit_hook"
                    phx-value-hook-id={hook.id}
                    class="p-2 text-gray-400 hover:text-white hover:bg-gray-700 rounded-lg transition-colors"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                    </svg>
                  </button>
                  <button
                    phx-click="delete_hook"
                    phx-value-hook-id={hook.id}
                    data-confirm="Are you sure you want to delete this hook?"
                    class="p-2 text-gray-400 hover:text-red-400 hover:bg-gray-700 rounded-lg transition-colors"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>
        <% else %>
          <div class="text-gray-500 text-sm text-center py-8">
            No hooks configured. Add a hook to automate workflows.
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :columns, :list, required: true

  defp settings_columns_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <p class="text-sm text-gray-400">
        Configure which hooks run when tasks enter each column.
      </p>

      <%= for column <- @columns do %>
        <div class="p-4 bg-gray-800/50 border border-gray-700 rounded-lg">
          <div class="flex items-center gap-2 mb-3">
            <div class="w-3 h-3 rounded-full" style={"background-color: #{column.color}"}></div>
            <h4 class="font-medium text-white">{column.name}</h4>
          </div>
          <p class="text-xs text-gray-500">Hook configuration coming soon...</p>
        </div>
      <% end %>

      <%= if @columns == [] do %>
        <div class="text-gray-500 text-sm text-center py-4">
          No columns found for this board.
        </div>
      <% end %>
    </div>
    """
  end

  attr :column, :map, required: true
  attr :active_tab, :string, required: true
  attr :available_hooks, :list, required: true
  attr :column_hooks, :list, required: true
  attr :all_columns, :list, required: true

  defp column_settings_panel(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex justify-end">
      <div phx-click="close_column_settings" class="fixed inset-0 bg-black/50 backdrop-blur-sm"></div>
      <div class="relative w-[28rem] bg-gray-900 border-l border-gray-800 shadow-xl h-full overflow-hidden flex flex-col animate-in slide-in-from-right duration-200">
        <div class="flex items-center justify-between p-4 border-b border-gray-800">
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 rounded-full" style={"background-color: #{@column.color}"}></div>
          <h2 class="text-lg font-semibold text-white">{@column.name}</h2>
        </div>
        <button
          phx-click="close_column_settings"
          class="p-1 text-gray-400 hover:text-white transition-colors"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <div class="flex border-b border-gray-700 px-4">
        <button
          phx-click="set_column_settings_tab"
          phx-value-tab="general"
          class={"px-3 py-2 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "general", do: "border-brand-500 text-brand-400", else: "border-transparent text-gray-400 hover:text-white"}"}
        >
          General
        </button>
        <button
          phx-click="set_column_settings_tab"
          phx-value-tab="hooks"
          class={"px-3 py-2 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "hooks", do: "border-brand-500 text-brand-400", else: "border-transparent text-gray-400 hover:text-white"}"}
        >
          Hooks
        </button>
      </div>

      <div class="flex-1 overflow-y-auto p-4">
        <%= if @active_tab == "general" do %>
          <form phx-submit="update_column" class="space-y-4">
            <input type="hidden" name="column_id" value={@column.id} />

            <div>
              <label for="column_name" class="block text-sm font-medium text-gray-300 mb-1">Name</label>
              <input
                type="text"
                id="column_name"
                name="name"
                value={@column.name}
                class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>

            <div>
              <label for="column_color" class="block text-sm font-medium text-gray-300 mb-1">Color</label>
              <div class="flex items-center gap-2">
                <input
                  type="color"
                  id="column_color"
                  name="color"
                  value={@column.color}
                  class="w-10 h-10 rounded border border-gray-700 cursor-pointer"
                />
                <span class="text-sm text-gray-400 font-mono">{@column.color}</span>
              </div>
            </div>

            <button
              type="submit"
              class="w-full px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors"
            >
              Save Changes
            </button>
          </form>
        <% else %>
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <div>
                <h4 class="text-sm font-medium text-gray-200">On Entry Hooks</h4>
                <p class="text-xs text-gray-500">Run when task enters this column</p>
              </div>
              <%= if length(unassigned_hooks(@column_hooks, @available_hooks)) > 0 do %>
                <div class="relative" id="hook-picker-container">
                  <button
                    phx-click="toggle_hook_picker"
                    class="text-sm text-brand-400 hover:text-brand-300"
                  >
                    + Add
                  </button>
                </div>
              <% end %>
            </div>

            <div class="space-y-2">
              <%= if length(@column_hooks) > 0 do %>
                <%= for column_hook <- @column_hooks do %>
                  <div class="p-3 bg-gray-800/50 border border-gray-700 rounded-lg">
                    <div class="flex items-center justify-between">
                      <div class="flex items-center gap-2 min-w-0">
                        <svg class="w-4 h-4 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                        </svg>
                        <span class="text-sm text-white truncate">{get_hook_name(column_hook.hook_id, @available_hooks)}</span>
                      </div>
                      <div class="flex items-center gap-1 flex-shrink-0">
                        <button
                          phx-click="toggle_hook_execute_once"
                          phx-value-column-hook-id={column_hook.id}
                          class={"px-1.5 py-0.5 text-xs rounded border #{if column_hook.execute_once, do: "bg-yellow-500/20 text-yellow-400 border-yellow-500/30", else: "bg-gray-700/50 text-gray-500 border-gray-600/30"}"}
                          title={if column_hook.execute_once, do: "Runs only once per task", else: "Runs every time"}
                        >
                          <%= if column_hook.execute_once do %>1x<% else %>∞<% end %>
                        </button>
                        <button
                          phx-click="toggle_hook_transparent"
                          phx-value-column-hook-id={column_hook.id}
                          class={"px-1.5 py-0.5 text-xs rounded border #{if column_hook.transparent, do: "bg-blue-500/20 text-blue-400 border-blue-500/30", else: "bg-gray-700/50 text-gray-500 border-gray-600/30"}"}
                          title={if column_hook.transparent, do: "Transparent: runs even on error", else: "Normal: skipped on error"}
                        >
                          <%= if column_hook.transparent do %>T<% else %>N<% end %>
                        </button>
                        <%= if column_hook.removable do %>
                          <button
                            phx-click="remove_column_hook"
                            phx-value-column-hook-id={column_hook.id}
                            class="p-1 text-gray-400 hover:text-red-400 transition-colors"
                          >
                            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                            </svg>
                          </button>
                        <% end %>
                      </div>
                    </div>

                    <div class="flex items-center gap-2 mt-2">
                      <%= if is_system_hook?(column_hook.hook_id, @available_hooks) do %>
                        <span class="px-1.5 py-0.5 text-xs bg-purple-500/20 text-purple-400 rounded">System</span>
                      <% end %>
                      <%= if !column_hook.removable do %>
                        <span class="px-1.5 py-0.5 text-xs bg-gray-700/50 text-gray-400 rounded">Required</span>
                      <% end %>
                    </div>

                    <%= if column_hook.hook_id == "system:play-sound" do %>
                      <div class="mt-3 pt-3 border-t border-gray-700/50">
                        <label class="block text-xs text-gray-400 mb-1">Sound</label>
                        <form phx-change="update_hook_sound" class="flex gap-2">
                          <input type="hidden" name="column-hook-id" value={column_hook.id} />
                          <select
                            name="sound"
                            class="flex-1 px-2 py-1.5 text-sm bg-gray-800 border border-gray-700 rounded text-white focus:outline-none focus:ring-1 focus:ring-brand-500"
                          >
                            <%= for {value, name} <- available_sounds() do %>
                              <option value={value} selected={get_hook_setting(column_hook, "sound", "ding") == value}>{name}</option>
                            <% end %>
                          </select>
                          <button
                            type="button"
                            phx-click="preview_sound"
                            phx-value-sound={get_hook_setting(column_hook, "sound", "ding")}
                            class="px-2 py-1.5 text-sm bg-gray-700 hover:bg-gray-600 border border-gray-600 rounded text-white transition-colors"
                            title="Preview sound"
                          >
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path>
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                            </svg>
                          </button>
                        </form>
                      </div>
                    <% end %>

                    <%= if column_hook.hook_id == "system:move-task" do %>
                      <div class="mt-3 pt-3 border-t border-gray-700/50">
                        <label class="block text-xs text-gray-400 mb-1">Target Column</label>
                        <form phx-change="update_hook_target_column">
                          <input type="hidden" name="column-hook-id" value={column_hook.id} />
                          <select
                            name="target_column"
                            class="w-full px-2 py-1.5 text-sm bg-gray-800 border border-gray-700 rounded text-white focus:outline-none focus:ring-1 focus:ring-brand-500"
                          >
                            <option value="next" selected={get_hook_setting(column_hook, "target_column", "next") == "next"}>Next Column</option>
                            <%= for col <- @all_columns do %>
                              <%= if col.id != @column.id do %>
                                <option value={col.name} selected={get_hook_setting(column_hook, "target_column", "next") == col.name}>{col.name}</option>
                              <% end %>
                            <% end %>
                          </select>
                        </form>
                        <p class="text-xs text-gray-500 mt-1">Where to move the task when this hook runs</p>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              <% else %>
                <p class="text-xs text-gray-500 italic py-2">No hooks assigned to this column</p>
              <% end %>
            </div>

            <%= if length(unassigned_hooks(@column_hooks, @available_hooks)) > 0 do %>
              <div class="mt-4 pt-4 border-t border-gray-700">
                <h4 class="text-sm font-medium text-gray-300 mb-2">Available Hooks</h4>
                <div class="space-y-1">
                  <%= for hook <- unassigned_hooks(@column_hooks, @available_hooks) do %>
                    <button
                      phx-click="add_column_hook"
                      phx-value-hook-id={hook.id}
                      class="w-full px-3 py-2 text-left text-sm text-gray-300 hover:bg-gray-800 rounded flex items-center justify-between"
                    >
                      <span class="truncate">{hook.name}</span>
                      <%= if hook.is_system do %>
                        <span class="px-1.5 py-0.5 text-xs bg-purple-500/20 text-purple-400 rounded">System</span>
                      <% end %>
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
      </div>
    </div>
    """
  end

  # Event handlers

  @impl true
  def handle_event("move_task", params, socket) do
    task_id = params["taskId"]
    column_id = params["columnId"]
    prev_task_id = params["prevTaskId"]
    next_task_id = params["nextTaskId"]

    Logger.info("[BoardLive] move_task: task=#{task_id} to column=#{column_id}")

    case Task.get(task_id) do
      {:ok, task} ->
        move_params = %{
          column_id: column_id,
          before_task_id: normalize_id(prev_task_id),
          after_task_id: normalize_id(next_task_id)
        }

        case Task.move(task, move_params) do
          {:ok, _updated_task} ->
            {:noreply, socket}

          {:error, error} ->
            Logger.error("[BoardLive] Failed to move task: #{inspect(error)}")
            {:noreply, put_flash(socket, :error, "Failed to move task")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Task not found")}
    end
  end

  @impl true
  def handle_event("select_task", %{"taskId" => task_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/boards/#{socket.assigns.board.id}/tasks/#{task_id}")}
  end

  @impl true
  def handle_event("close_task_details", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/boards/#{socket.assigns.board.id}")}
  end

  @impl true
  def handle_event(
        "maybe_send_message",
        %{"key" => "Enter", "metaKey" => true, "value" => message} = params,
        socket
      ) do
    task_id = params["task-id"]
    handle_event("send_message", %{"task_id" => task_id, "message" => message}, socket)
  end

  def handle_event("maybe_send_message", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"task_id" => task_id, "message" => message}, socket) do
    message = String.trim(message)

    if message != "" do
      Logger.info(
        "[BoardLive] send_message: task=#{task_id} message=#{String.slice(message, 0, 50)}..."
      )

      case Task.get(task_id) do
        {:ok, task} ->
          save_user_message(task_id, message)

          case queue_and_move_task(task, message) do
            {:ok, updated_task} ->
              activity_item = %{
                type: :message,
                content: message,
                role: :user,
                timestamp: DateTime.utc_now()
              }

              activity = socket.assigns.activity ++ [activity_item]

              socket =
                socket
                |> assign(:activity, activity)
                |> assign(:task, updated_task)

              {:noreply, socket}

            {:error, reason} ->
              Logger.error("[BoardLive] Failed to queue message: #{inspect(reason)}")
              {:noreply, put_flash(socket, :error, "Failed to send message")}
          end

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Task not found")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_fullscreen", _params, socket) do
    {:noreply, assign(socket, :task_panel_fullscreen, !socket.assigns.task_panel_fullscreen)}
  end

  @impl true
  def handle_event("toggle_hide_details", _params, socket) do
    {:noreply, assign(socket, :task_panel_hide_details, !socket.assigns.task_panel_hide_details)}
  end

  @impl true
  def handle_event("show_create_task_modal", %{"columnId" => column_id}, socket) do
    socket =
      socket
      |> assign(:show_create_task_modal, true)
      |> assign(:create_task_column_id, column_id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_create_task_modal", _params, socket) do
    {:noreply, assign(socket, show_create_task_modal: false, create_task_column_id: nil)}
  end

  @impl true
  def handle_event(
        "create_task",
        %{"title" => title, "description" => description, "column_id" => column_id},
        socket
      ) do
    case Task.create(%{title: title, description: description, column_id: column_id}) do
      {:ok, _task} ->
        socket =
          socket
          |> assign(:show_create_task_modal, false)
          |> assign(:create_task_column_id, nil)

        {:noreply, socket}

      {:error, error} ->
        Logger.error("[BoardLive] Failed to create task: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to create task")}
    end
  end

  @impl true
  def handle_event("update_task_title", %{"task-id" => task_id, "value" => title}, socket) do
    case Task.get(task_id) do
      {:ok, task} ->
        case Task.update(task, %{title: title}) do
          {:ok, _updated_task} -> {:noreply, socket}
          {:error, _error} -> {:noreply, put_flash(socket, :error, "Failed to update task")}
        end

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "update_task_description",
        %{"task-id" => task_id, "value" => description},
        socket
      ) do
    case Task.get(task_id) do
      {:ok, task} ->
        case Task.update(task, %{description: description}) do
          {:ok, _updated_task} -> {:noreply, socket}
          {:error, _error} -> {:noreply, put_flash(socket, :error, "Failed to update task")}
        end

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_task", %{"task-id" => task_id}, socket) do
    case Task.get(task_id) do
      {:ok, task} ->
        case Task.destroy(task) do
          :ok ->
            socket =
              socket
              |> assign(:selected_task_id, nil)
              |> assign(:selected_task, nil)
              |> push_patch(to: ~p"/boards/#{socket.assigns.board.id}")

            {:noreply, socket}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Failed to delete task")}
        end

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_settings", _params, socket) do
    board_id = socket.assigns.board.id
    board_hooks = load_board_hooks(board_id)
    task_templates = load_task_templates(board_id)

    socket =
      socket
      |> assign(:show_settings, true)
      |> assign(:board_hooks, board_hooks)
      |> assign(:task_templates, task_templates)

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_settings_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :settings_tab, tab)}
  end

  @impl true
  def handle_event("open_column_settings", %{"columnId" => column_id}, socket) do
    available_hooks = load_available_hooks(socket.assigns.board.id)
    column_hooks = load_column_hooks(column_id)

    socket =
      socket
      |> assign(:show_column_settings, true)
      |> assign(:column_settings_id, column_id)
      |> assign(:available_hooks, available_hooks)
      |> assign(:column_hooks, column_hooks)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_column_settings", _params, socket) do
    {:noreply,
     assign(socket,
       show_column_settings: false,
       column_settings_id: nil,
       column_settings_tab: "general"
     )}
  end

  @impl true
  def handle_event("set_column_settings_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :column_settings_tab, tab)}
  end

  @impl true
  def handle_event(
        "update_column",
        %{"column_id" => column_id, "name" => name, "color" => color},
        socket
      ) do
    case Column.get(column_id) do
      {:ok, column} ->
        case Column.update(column, %{name: name, color: color}) do
          {:ok, _updated_column} ->
            columns = reload_columns(socket.assigns.board.id)

            socket =
              socket
              |> assign(:columns, columns)
              |> assign(:show_column_settings, false)
              |> assign(:column_settings_id, nil)

            {:noreply, socket}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Failed to update column")}
        end

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_settings", _params, socket) do
    {:noreply, assign(socket, :show_settings, false)}
  end

  @impl true
  def handle_event("show_keyboard_shortcuts", _params, socket) do
    {:noreply, assign(socket, :show_keyboard_shortcuts, true)}
  end

  @impl true
  def handle_event("close_keyboard_shortcuts", _params, socket) do
    {:noreply, assign(socket, :show_keyboard_shortcuts, false)}
  end

  @impl true
  def handle_event("keyboard_escape", _params, socket) do
    socket =
      cond do
        socket.assigns.show_keyboard_shortcuts ->
          assign(socket, :show_keyboard_shortcuts, false)

        socket.assigns.show_create_pr_modal ->
          socket
          |> assign(:show_create_pr_modal, false)
          |> assign(:pr_form, %{title: "", body: ""})

        socket.assigns.show_create_task_modal ->
          socket
          |> assign(:show_create_task_modal, false)
          |> assign(:create_task_column_id, nil)

        socket.assigns.show_column_settings ->
          socket
          |> assign(:show_column_settings, false)
          |> assign(:column_settings_id, nil)
          |> assign(:column_hooks, [])
          |> assign(:available_hooks, [])

        socket.assigns.show_settings ->
          assign(socket, :show_settings, false)

        socket.assigns.selected_task ->
          socket
          |> assign(:selected_task, nil)
          |> assign(:selected_task_id, nil)

        true ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("keyboard_new_task", _params, socket) do
    first_column = List.first(socket.assigns.columns)

    if first_column do
      socket =
        socket
        |> assign(:show_create_task_modal, true)
        |> assign(:create_task_column_id, first_column.id)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_search", %{"value" => query}, socket) do
    {:noreply, assign(socket, :search_query, query)}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply, assign(socket, :search_query, "")}
  end

  @impl true
  def handle_event("update_board", %{"name" => name, "description" => description}, socket) do
    board_id = socket.assigns.board.id

    case Board.get(board_id) do
      {:ok, board} ->
        case Board.update(board, %{name: name, description: description}) do
          {:ok, updated_board} ->
            socket =
              socket
              |> assign(:board, serialize_board(updated_board))
              |> assign(:page_title, updated_board.name)
              |> assign(:show_settings, false)

            {:noreply, socket}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Failed to update board")}
        end

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_board", _params, socket) do
    board_id = socket.assigns.board.id

    case Board.get(board_id) do
      {:ok, board} ->
        case Board.destroy(board) do
          :ok ->
            socket =
              socket
              |> put_flash(:info, "Board deleted")
              |> redirect(to: ~p"/")

            {:noreply, socket}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Failed to delete board")}
        end

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("duplicate_task", %{"task-id" => task_id}, socket) do
    case Task.get(task_id) do
      {:ok, task} ->
        duplicate_params = %{
          title: "#{task.title} (copy)",
          description: task.description,
          column_id: task.column_id
        }

        case Task.create(duplicate_params) do
          {:ok, new_task} ->
            {:noreply,
             push_patch(socket, to: ~p"/boards/#{socket.assigns.board.id}/tasks/#{new_task.id}")}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Failed to duplicate task")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Task not found")}
    end
  end

  @impl true
  def handle_event("create_worktree", %{"task-id" => task_id}, socket) do
    case Task.create_worktree(task_id) do
      {:ok, updated_task} ->
        socket =
          socket
          |> assign(:selected_task, serialize_task(updated_task))
          |> put_flash(:info, "Worktree created successfully")

        {:noreply, socket}

      {:error, error} ->
        Logger.error("[BoardLive] Failed to create worktree: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to create worktree")}
    end
  end

  @impl true
  def handle_event("open_in_editor", %{"task-id" => task_id}, socket) do
    case Task.get(task_id) do
      {:ok, task} when not is_nil(task.worktree_path) ->
        System.cmd("code", [task.worktree_path], stderr_to_stdout: true)
        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "No worktree path available")}
    end
  end

  @impl true
  def handle_event("open_folder", %{"task-id" => task_id}, socket) do
    case Task.get(task_id) do
      {:ok, task} when not is_nil(task.worktree_path) ->
        System.cmd("open", [task.worktree_path], stderr_to_stdout: true)
        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "No worktree path available")}
    end
  end

  @impl true
  def handle_event("add_column_hook", %{"hook-id" => hook_id}, socket) do
    column_id = socket.assigns.column_settings_id
    position = length(socket.assigns.column_hooks)

    case ColumnHook.create(%{column_id: column_id, hook_id: hook_id, position: position}) do
      {:ok, _column_hook} ->
        column_hooks = load_column_hooks(column_id)
        {:noreply, assign(socket, :column_hooks, column_hooks)}

      {:error, error} ->
        Logger.error("[BoardLive] Failed to add column hook: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to add hook")}
    end
  end

  @impl true
  def handle_event("remove_column_hook", %{"column-hook-id" => column_hook_id}, socket) do
    case ColumnHook.get(column_hook_id) do
      {:ok, column_hook} ->
        case ColumnHook.destroy(column_hook) do
          :ok ->
            column_hooks = load_column_hooks(socket.assigns.column_settings_id)
            {:noreply, assign(socket, :column_hooks, column_hooks)}

          {:error, error} ->
            Logger.error("[BoardLive] Failed to remove column hook: #{inspect(error)}")
            {:noreply, put_flash(socket, :error, "Failed to remove hook")}
        end

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_hook_execute_once", %{"column-hook-id" => column_hook_id}, socket) do
    case ColumnHook.get(column_hook_id) do
      {:ok, column_hook} ->
        case ColumnHook.update(column_hook, %{execute_once: !column_hook.execute_once}) do
          {:ok, _updated} ->
            column_hooks = load_column_hooks(socket.assigns.column_settings_id)
            {:noreply, assign(socket, :column_hooks, column_hooks)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to update hook")}
        end

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_hook_transparent", %{"column-hook-id" => column_hook_id}, socket) do
    case ColumnHook.get(column_hook_id) do
      {:ok, column_hook} ->
        case ColumnHook.update(column_hook, %{transparent: !column_hook.transparent}) do
          {:ok, _updated} ->
            column_hooks = load_column_hooks(socket.assigns.column_settings_id)
            {:noreply, assign(socket, :column_hooks, column_hooks)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to update hook")}
        end

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "update_hook_sound",
        %{"column-hook-id" => column_hook_id, "sound" => sound},
        socket
      ) do
    Logger.info("[BoardLive] update_hook_sound: hook=#{column_hook_id} sound=#{sound}")

    case ColumnHook.get(column_hook_id) do
      {:ok, column_hook} ->
        new_settings = Map.put(column_hook.hook_settings || %{}, "sound", sound)
        Logger.info("[BoardLive] Updating hook_settings to: #{inspect(new_settings)}")

        case ColumnHook.update(column_hook, %{hook_settings: new_settings}) do
          {:ok, updated} ->
            Logger.info(
              "[BoardLive] Updated successfully, new settings: #{inspect(updated.hook_settings)}"
            )

            column_hooks = load_column_hooks(socket.assigns.column_settings_id)
            {:noreply, assign(socket, :column_hooks, column_hooks)}

          {:error, error} ->
            Logger.error("[BoardLive] Failed to update hook: #{inspect(error)}")
            {:noreply, put_flash(socket, :error, "Failed to update hook settings")}
        end

      {:error, error} ->
        Logger.error("[BoardLive] Failed to get column hook: #{inspect(error)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "update_hook_target_column",
        %{"column-hook-id" => column_hook_id, "target_column" => target_column},
        socket
      ) do
    case ColumnHook.get(column_hook_id) do
      {:ok, column_hook} ->
        new_settings = Map.put(column_hook.hook_settings || %{}, "target_column", target_column)

        case ColumnHook.update(column_hook, %{hook_settings: new_settings}) do
          {:ok, _updated} ->
            column_hooks = load_column_hooks(socket.assigns.column_settings_id)
            {:noreply, assign(socket, :column_hooks, column_hooks)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to update hook settings")}
        end

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("preview_sound", %{"sound" => sound}, socket) do
    {:noreply, push_event(socket, "hook_executed", %{effects: %{play_sound: %{sound: sound}}})}
  end

  @impl true
  def handle_event("start_create_hook", _params, socket) do
    socket =
      socket
      |> assign(:is_creating_hook, true)
      |> assign(:editing_hook_id, nil)
      |> assign(:hook_form, %{
        name: "",
        kind: "script",
        command: "",
        agent_prompt: "",
        agent_executor: "claude_code",
        agent_auto_approve: false
      })

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_edit_hook", %{"hook-id" => hook_id}, socket) do
    hook = Enum.find(socket.assigns.board_hooks, &(&1.id == hook_id))

    if hook do
      socket =
        socket
        |> assign(:is_creating_hook, false)
        |> assign(:editing_hook_id, hook_id)
        |> assign(:hook_form, %{
          name: hook.name,
          kind: hook.hook_kind,
          command: hook.command || "",
          agent_prompt: hook.agent_prompt || "",
          agent_executor: hook.agent_executor || "claude_code",
          agent_auto_approve: hook.agent_auto_approve || false
        })

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_hook_edit", _params, socket) do
    socket =
      socket
      |> assign(:is_creating_hook, false)
      |> assign(:editing_hook_id, nil)
      |> assign(:hook_form, %{
        name: "",
        kind: "script",
        command: "",
        agent_prompt: "",
        agent_executor: "claude_code",
        agent_auto_approve: false
      })

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_hook_form", %{"field" => field, "value" => value}, socket) do
    hook_form = Map.put(socket.assigns.hook_form, String.to_existing_atom(field), value)
    {:noreply, assign(socket, :hook_form, hook_form)}
  end

  @impl true
  def handle_event("toggle_hook_auto_approve", _params, socket) do
    hook_form =
      Map.put(
        socket.assigns.hook_form,
        :agent_auto_approve,
        !socket.assigns.hook_form.agent_auto_approve
      )

    {:noreply, assign(socket, :hook_form, hook_form)}
  end

  @impl true
  def handle_event("save_hook", _params, socket) do
    form = socket.assigns.hook_form
    board_id = socket.assigns.board.id

    result =
      if socket.assigns.is_creating_hook do
        if form.kind == "script" do
          Hook.create_script_hook(%{name: form.name, command: form.command, board_id: board_id})
        else
          Hook.create_agent_hook(%{
            name: form.name,
            agent_prompt: form.agent_prompt,
            agent_executor: String.to_existing_atom(form.agent_executor),
            agent_auto_approve: form.agent_auto_approve,
            board_id: board_id
          })
        end
      else
        case Hook.get(socket.assigns.editing_hook_id) do
          {:ok, hook} ->
            if form.kind == "script" do
              Hook.update(hook, %{name: form.name, command: form.command})
            else
              Hook.update(hook, %{
                name: form.name,
                agent_prompt: form.agent_prompt,
                agent_executor: String.to_existing_atom(form.agent_executor),
                agent_auto_approve: form.agent_auto_approve
              })
            end

          {:error, _} ->
            {:error, :not_found}
        end
      end

    case result do
      {:ok, _hook} ->
        board_hooks = load_board_hooks(board_id)

        socket =
          socket
          |> assign(:board_hooks, board_hooks)
          |> assign(:is_creating_hook, false)
          |> assign(:editing_hook_id, nil)
          |> assign(:hook_form, %{
            name: "",
            kind: "script",
            command: "",
            agent_prompt: "",
            agent_executor: "claude_code",
            agent_auto_approve: false
          })

        {:noreply, socket}

      {:error, error} ->
        Logger.error("[BoardLive] Failed to save hook: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to save hook")}
    end
  end

  @impl true
  def handle_event("delete_hook", %{"hook-id" => hook_id}, socket) do
    case Hook.get(hook_id) do
      {:ok, hook} ->
        case Hook.destroy(hook) do
          :ok ->
            board_hooks = load_board_hooks(socket.assigns.board.id)
            {:noreply, assign(socket, :board_hooks, board_hooks)}

          {:error, error} ->
            Logger.error("[BoardLive] Failed to delete hook: #{inspect(error)}")
            {:noreply, put_flash(socket, :error, "Failed to delete hook")}
        end

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("start_create_template", _params, socket) do
    socket =
      socket
      |> assign(:is_creating_template, true)
      |> assign(:editing_template_id, nil)
      |> assign(:template_form, %{name: "", description_template: ""})

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_edit_template", %{"template-id" => template_id}, socket) do
    template = Enum.find(socket.assigns.task_templates, &(&1.id == template_id))

    if template do
      socket =
        socket
        |> assign(:is_creating_template, false)
        |> assign(:editing_template_id, template_id)
        |> assign(:template_form, %{
          name: template.name,
          description_template: template.description_template || ""
        })

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_template_edit", _params, socket) do
    socket =
      socket
      |> assign(:is_creating_template, false)
      |> assign(:editing_template_id, nil)
      |> assign(:template_form, %{name: "", description_template: ""})

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_template_form", %{"field" => field, "value" => value}, socket) do
    template_form = Map.put(socket.assigns.template_form, String.to_existing_atom(field), value)
    {:noreply, assign(socket, :template_form, template_form)}
  end

  @impl true
  def handle_event("save_template", _params, socket) do
    form = socket.assigns.template_form
    board_id = socket.assigns.board.id

    result =
      if socket.assigns.is_creating_template do
        TaskTemplate.create(%{
          name: form.name,
          description_template: form.description_template,
          board_id: board_id
        })
      else
        case TaskTemplate.get(socket.assigns.editing_template_id) do
          {:ok, template} ->
            TaskTemplate.update(template, %{
              name: form.name,
              description_template: form.description_template
            })

          {:error, _} ->
            {:error, :not_found}
        end
      end

    case result do
      {:ok, _template} ->
        task_templates = load_task_templates(board_id)

        socket =
          socket
          |> assign(:task_templates, task_templates)
          |> assign(:is_creating_template, false)
          |> assign(:editing_template_id, nil)
          |> assign(:template_form, %{name: "", description_template: ""})

        {:noreply, socket}

      {:error, error} ->
        Logger.error("[BoardLive] Failed to save template: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to save template")}
    end
  end

  @impl true
  def handle_event("delete_template", %{"template-id" => template_id}, socket) do
    case TaskTemplate.get(template_id) do
      {:ok, template} ->
        case TaskTemplate.destroy(template) do
          :ok ->
            task_templates = load_task_templates(socket.assigns.board.id)
            {:noreply, assign(socket, :task_templates, task_templates)}

          {:error, error} ->
            Logger.error("[BoardLive] Failed to delete template: #{inspect(error)}")
            {:noreply, put_flash(socket, :error, "Failed to delete template")}
        end

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_create_pr_modal", %{"task-id" => _task_id}, socket) do
    task = socket.assigns.selected_task
    pr_title = (task && task.title) || ""

    socket =
      socket
      |> assign(:show_create_pr_modal, true)
      |> assign(:pr_form, %{title: pr_title, body: ""})

    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_create_pr_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_create_pr_modal, false)
      |> assign(:pr_form, %{title: "", body: ""})

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_pr_form", %{"field" => field, "value" => value}, socket) do
    pr_form = Map.put(socket.assigns.pr_form, String.to_existing_atom(field), value)
    {:noreply, assign(socket, :pr_form, pr_form)}
  end

  @impl true
  def handle_event("create_pr", %{"task_id" => task_id, "title" => title, "body" => body}, socket) do
    case Task.create_pr(task_id, title, body, nil) do
      {:ok, _result} ->
        case Task.get(task_id) do
          {:ok, updated_task} ->
            socket =
              socket
              |> assign(:show_create_pr_modal, false)
              |> assign(:pr_form, %{title: "", body: ""})
              |> assign(:selected_task, serialize_task(updated_task))
              |> put_flash(:info, "Pull request created successfully!")

            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to reload task after PR creation")}
        end

      {:error, error} ->
        Logger.error("[BoardLive] Failed to create PR: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to create pull request")}
    end
  end

  # Handle PubSub messages for real-time updates

  @impl true
  def handle_info({:task_changed, %{task: task, action: action}}, socket) do
    Logger.debug("[BoardLive] task_changed: action=#{action} task=#{task.id}")

    columns = reload_columns(socket.assigns.board.id)

    socket =
      socket
      |> assign(:columns, columns)
      |> maybe_update_selected_task(task, action)
      |> push_event("hook_executed", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:hook_executed, payload}, socket) do
    socket =
      if socket.assigns.selected_task_id == payload.task_id do
        activity_item = %{
          type: :hook_execution,
          id: payload[:execution_id] || Ecto.UUID.generate(),
          hook_id: payload.hook_id,
          hook_name: payload.hook_name,
          status: payload[:status] || :completed,
          skip_reason: nil,
          error_message: nil,
          hook_settings: payload[:effects] || %{},
          queued_at: DateTime.utc_now(),
          started_at: DateTime.utc_now(),
          completed_at: DateTime.utc_now(),
          timestamp: DateTime.utc_now()
        }

        update(socket, :task_activity, fn activity -> activity ++ [activity_item] end)
      else
        socket
      end

    {:noreply, push_event(socket, "hook_executed", payload)}
  end

  @impl true
  def handle_info({:executor_message, %{task_id: task_id} = payload}, socket) do
    if socket.assigns.selected_task_id == task_id do
      activity_item = %{
        type: :message,
        id: payload[:id] || Ecto.UUID.generate(),
        role: payload.role,
        content: payload.content,
        session_id: payload[:session_id],
        metadata: payload[:metadata] || %{},
        inserted_at: DateTime.utc_now(),
        timestamp: DateTime.utc_now()
      }

      socket = update(socket, :task_activity, fn activity -> activity ++ [activity_item] end)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:executor_session_update, %{task_id: task_id} = payload}, socket) do
    if socket.assigns.selected_task_id == task_id do
      sessions =
        Enum.map(socket.assigns.task_sessions, fn sess ->
          if sess.id == payload.id do
            Map.merge(sess, %{
              status: payload[:status] || sess.status,
              exit_code: payload[:exit_code],
              error_message: payload[:error_message],
              completed_at: payload[:completed_at]
            })
          else
            sess
          end
        end)

      {:noreply, assign(socket, :task_sessions, sessions)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  # Private helpers

  defp save_user_message(task_id, user_prompt) do
    case Message.create(%{
           task_id: task_id,
           role: :user,
           content: user_prompt,
           status: :pending,
           metadata: %{executor_type: :claude_code}
         }) do
      {:ok, _message} ->
        Logger.info("[BoardLive] Saved user message for task #{task_id}")

      {:error, error} ->
        Logger.warning("[BoardLive] Failed to save message: #{inspect(error)}")
    end
  end

  defp queue_and_move_task(task, user_prompt) do
    case Task.queue_message(task, user_prompt, :claude_code, []) do
      {:ok, updated_task} ->
        Logger.info(
          "[BoardLive] Queued message for task #{task.id}, queue size: #{length(updated_task.message_queue)}"
        )

        {:ok, maybe_move_to_in_progress(updated_task)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp maybe_move_to_in_progress(task) do
    alias Viban.Kanban.Actors.ColumnLookup
    alias Viban.Kanban.Column

    with {:ok, column} <- Column.get(task.column_id),
         false <- ColumnLookup.in_progress_column?(task.column_id),
         in_progress_column_id when not is_nil(in_progress_column_id) <-
           ColumnLookup.find_in_progress_column(column.board_id),
         {:ok, updated_task} <-
           Task.move(task, %{column_id: in_progress_column_id, position: 0.0}) do
      Logger.info("[BoardLive] Moved task #{task.id} to 'In Progress' column")
      updated_task
    else
      true ->
        task

      nil ->
        Logger.warning("[BoardLive] No 'In Progress' column found")
        task

      {:error, error} ->
        Logger.error("[BoardLive] Failed to move task: #{inspect(error)}")
        task
    end
  end

  defp load_board_with_data(board_id) do
    case Board.get(board_id) do
      {:ok, board} ->
        columns = load_columns_with_tasks(board_id)
        {:ok, board, columns}

      {:error, _} ->
        {:error, :not_found}
    end
  end

  defp load_columns_with_tasks(board_id) do
    board_id
    |> Column.for_board!()
    |> Enum.map(fn column ->
      tasks =
        column.id
        |> Task.for_column!()
        |> Enum.map(&serialize_task/1)

      Map.put(serialize_column(column), :tasks, tasks)
    end)
  end

  defp reload_columns(board_id) do
    load_columns_with_tasks(board_id)
  end

  defp load_selected_task(nil), do: nil

  defp load_selected_task(task_id) do
    case Task.get(task_id) do
      {:ok, task} -> serialize_task(task)
      {:error, _} -> nil
    end
  end

  defp load_task_activity(nil), do: {[], []}

  defp load_task_activity(task_id) do
    hook_executions =
      case HookExecution.history_for_task(task_id) do
        {:ok, execs} -> Enum.map(execs, &serialize_hook_execution/1)
        _ -> []
      end

    messages =
      case Message.for_task(task_id) do
        {:ok, msgs} -> Enum.map(msgs, &serialize_message/1)
        _ -> []
      end

    sessions =
      case ExecutorSession.for_task(task_id) do
        {:ok, sess} -> Enum.map(sess, &serialize_executor_session/1)
        _ -> []
      end

    activity =
      (hook_executions ++ messages)
      |> Enum.reject(&is_nil(&1.timestamp))
      |> Enum.reject(&empty_message?/1)
      |> Enum.sort_by(& &1.timestamp, {:asc, DateTime})

    {activity, sessions}
  end

  defp empty_message?(%{type: :message, content: nil}), do: true
  defp empty_message?(%{type: :message, content: ""}), do: true

  defp empty_message?(%{type: :message, content: content}) when is_binary(content),
    do: String.trim(content) == ""

  defp empty_message?(_), do: false

  defp serialize_hook_execution(exec) do
    duration_ms = calculate_duration_ms(exec.started_at, exec.completed_at)

    %{
      type: :hook_execution,
      id: exec.id,
      hook_id: exec.hook_id,
      hook_name: exec.hook_name,
      status: exec.status,
      skip_reason: exec.skip_reason,
      error_message: exec.error_message,
      hook_settings: exec.hook_settings,
      queued_at: exec.queued_at,
      started_at: exec.started_at,
      completed_at: exec.completed_at,
      duration_ms: duration_ms,
      timestamp: exec.queued_at
    }
  end

  defp calculate_duration_ms(nil, _), do: nil
  defp calculate_duration_ms(_, nil), do: nil

  defp calculate_duration_ms(started_at, completed_at) do
    DateTime.diff(completed_at, started_at, :millisecond)
  end

  defp serialize_message(msg) do
    %{
      type: :message,
      id: msg.id,
      role: msg.role,
      content: msg.content,
      status: msg.status,
      metadata: msg.metadata,
      inserted_at: msg.inserted_at,
      timestamp: msg.inserted_at
    }
  end

  defp serialize_executor_session(sess) do
    %{
      id: sess.id,
      executor_type: sess.executor_type,
      prompt: sess.prompt,
      status: sess.status,
      exit_code: sess.exit_code,
      error_message: sess.error_message,
      started_at: sess.started_at,
      completed_at: sess.completed_at
    }
  end

  defp maybe_update_selected_task(socket, task, action) do
    case {socket.assigns.selected_task_id, action} do
      {nil, _} ->
        socket

      {selected_id, :destroy} when selected_id == task.id ->
        socket
        |> assign(:selected_task_id, nil)
        |> assign(:selected_task, nil)

      {selected_id, _action} when selected_id == task.id ->
        assign(socket, :selected_task, serialize_task(task))

      _ ->
        socket
    end
  end

  defp normalize_id(nil), do: nil
  defp normalize_id(""), do: nil
  defp normalize_id("null"), do: nil
  defp normalize_id(id) when is_binary(id), do: id

  defp serialize_board(board) do
    %{
      id: board.id,
      name: board.name,
      description: board.description
    }
  end

  defp serialize_column(column) do
    %{
      id: column.id,
      name: column.name,
      position: column.position,
      color: column.color
    }
  end

  defp serialize_task(task) do
    %{
      id: task.id,
      title: task.title,
      description: task.description,
      position: task.position,
      column_id: task.column_id,
      parent_task_id: task.parent_task_id,
      is_parent: task.is_parent,
      worktree_path: task.worktree_path,
      worktree_branch: task.worktree_branch,
      agent_status: task.agent_status && to_string(task.agent_status),
      agent_status_message: task.agent_status_message,
      pr_url: task.pr_url,
      pr_number: task.pr_number,
      pr_status: task.pr_status && to_string(task.pr_status),
      inserted_at: task.inserted_at
    }
  end

  defp load_task_templates(board_id) do
    board_id
    |> TaskTemplate.for_board!()
    |> Enum.map(fn template ->
      %{
        id: template.id,
        name: template.name,
        description_template: template.description_template,
        position: template.position
      }
    end)
  end

  defp load_board_hooks(board_id) do
    system_hooks = Registry.all()

    custom_hooks =
      board_id
      |> Hook.for_board!()
      |> Enum.map(fn hook ->
        %{
          id: hook.id,
          name: hook.name,
          is_system: false,
          hook_kind: to_string(hook.hook_kind),
          command: hook.command,
          agent_prompt: hook.agent_prompt,
          agent_executor: hook.agent_executor && to_string(hook.agent_executor),
          agent_auto_approve: hook.agent_auto_approve
        }
      end)

    system_hooks ++ custom_hooks
  end

  defp load_available_hooks(board_id) do
    system_hooks = Registry.all()

    custom_hooks =
      board_id
      |> Hook.for_board!()
      |> Enum.map(fn hook ->
        %{
          id: hook.id,
          name: hook.name,
          description: nil,
          is_system: false,
          hook_kind: hook.hook_kind
        }
      end)

    system_hooks ++ custom_hooks
  end

  defp load_column_hooks(column_id) do
    column_id
    |> ColumnHook.for_column!()
    |> Enum.map(fn ch ->
      %{
        id: ch.id,
        hook_id: ch.hook_id,
        position: ch.position,
        execute_once: ch.execute_once,
        transparent: ch.transparent,
        removable: ch.removable,
        hook_settings: ch.hook_settings || %{}
      }
    end)
  end

  defp get_hook_name(hook_id, available_hooks) do
    case Enum.find(available_hooks, &(&1.id == hook_id)) do
      nil -> "Unknown Hook"
      hook -> hook.name
    end
  end

  defp is_system_hook?(hook_id, available_hooks) do
    case Enum.find(available_hooks, &(&1.id == hook_id)) do
      nil -> false
      hook -> hook.is_system == true
    end
  end

  defp unassigned_hooks(column_hooks, available_hooks) do
    assigned_ids = Enum.map(column_hooks, & &1.hook_id)
    Enum.filter(available_hooks, fn hook -> hook.id not in assigned_ids end)
  end

  defp get_hook_setting(column_hook, key, default) do
    settings = column_hook.hook_settings || %{}
    settings[key] || settings[to_string(key)] || default
  end

  defp available_sounds do
    [
      {"ding", "Ding"},
      {"bell", "Bell"},
      {"chime", "Chime"},
      {"success", "Success"},
      {"notification", "Notification"},
      {"woof", "Woof"},
      {"bark1", "Bark 1"},
      {"bark2", "Bark 2"},
      {"bark3", "Bark 3"},
      {"bark4", "Bark 4"},
      {"bark5", "Bark 5"},
      {"bark6", "Bark 6"}
    ]
  end

  defp truncate_text(nil, _max), do: ""
  defp truncate_text(str, max) when byte_size(str) <= max, do: str
  defp truncate_text(str, max), do: String.slice(str, 0, max) <> "..."

  defp pr_status_class("open"), do: "bg-green-900/50 text-green-400"
  defp pr_status_class("merged"), do: "bg-purple-900/50 text-purple-400"
  defp pr_status_class("closed"), do: "bg-red-900/50 text-red-400"
  defp pr_status_class("draft"), do: "bg-gray-800 text-gray-400"
  defp pr_status_class(_), do: "bg-gray-800 text-gray-400"

  attr :status, :string, required: true

  defp agent_status_badge(assigns) do
    ~H"""
    <span class={"inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium #{agent_status_class(@status)}"}>
      <%= agent_status_icon(@status) %>
      <span class="ml-1">{agent_status_label(@status)}</span>
    </span>
    """
  end

  defp agent_status_class("idle"), do: "bg-gray-800 text-gray-400"
  defp agent_status_class("running"), do: "bg-blue-900/50 text-blue-400"
  defp agent_status_class("waiting"), do: "bg-yellow-900/50 text-yellow-400"
  defp agent_status_class("success"), do: "bg-green-900/50 text-green-400"
  defp agent_status_class("error"), do: "bg-red-900/50 text-red-400"
  defp agent_status_class(_), do: "bg-gray-800 text-gray-400"

  defp agent_status_label("idle"), do: "Idle"
  defp agent_status_label("running"), do: "Running"
  defp agent_status_label("waiting"), do: "Waiting"
  defp agent_status_label("success"), do: "Success"
  defp agent_status_label("error"), do: "Error"
  defp agent_status_label(status), do: status || "Unknown"

  defp agent_status_icon("running") do
    Phoenix.HTML.raw("""
    <svg class="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>
    """)
  end

  defp agent_status_icon("success") do
    Phoenix.HTML.raw("""
    <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
    </svg>
    """)
  end

  defp agent_status_icon("error") do
    Phoenix.HTML.raw("""
    <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
      <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/>
    </svg>
    """)
  end

  defp agent_status_icon(_) do
    Phoenix.HTML.raw("""
    <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
      <circle cx="10" cy="10" r="3"/>
    </svg>
    """)
  end
end
