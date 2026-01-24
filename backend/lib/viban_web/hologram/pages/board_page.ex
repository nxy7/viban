defmodule VibanWeb.Hologram.Pages.BoardPage do
  @moduledoc false
  use Hologram.Page

  alias Viban.Kanban.ColumnHook
  alias Viban.Kanban.Hook
  alias Viban.Kanban.PeriodicalTask
  alias Viban.Kanban.Repository
  alias Viban.Kanban.TaskTemplate
  alias VibanWeb.Hologram.Components.BoardSettingsPanel
  alias VibanWeb.Hologram.Components.Column
  alias VibanWeb.Hologram.Components.ColumnSettingsPopup
  alias VibanWeb.Hologram.Components.CreatePRModal
  alias VibanWeb.Hologram.Components.SubtaskList
  alias VibanWeb.Hologram.Layouts.MainLayout

  route("/board/:board_id")

  param(:board_id, :string)

  layout(MainLayout)

  @impl Hologram.Page
  def init(params, component, server) do
    board_id = params.board_id

    component =
      component
      |> put_state(:board_id, board_id)
      |> put_state(:user, nil)
      |> put_state(:selected_task_id, nil)
      |> put_state(:show_create_task_modal, false)
      |> put_state(:create_task_column_id, nil)
      |> put_state(:create_task_column_name, "")
      |> put_state(:new_task_title, "")
      |> put_state(:new_task_description, "")
      |> put_state(:create_task_error, nil)
      |> put_state(:is_creating_task, false)
      |> put_state(:search_query, "")
      |> put_state(:tasks_version, 0)
      |> put_state(:show_task_details, false)
      |> put_state(:selected_task, nil)
      |> put_state(:selected_task_column_name, nil)
      |> put_state(:is_editing_title, false)
      |> put_state(:is_editing_description, false)
      |> put_state(:edit_title, "")
      |> put_state(:edit_description, "")
      |> put_state(:is_saving_task, false)
      |> put_state(:is_deleting_task, false)
      |> put_state(:show_delete_confirm, false)
      |> put_state(:task_details_error, nil)
      |> put_state(:subtasks, [])
      |> put_state(:is_generating_subtasks, false)
      |> put_state(:show_create_pr_modal, false)
      |> put_state(:pr_branches, [])
      |> put_state(:is_loading_branches, false)
      |> put_state(:is_creating_pr, false)
      |> put_state(:create_pr_error, nil)
      |> put_state(:pr_title, "")
      |> put_state(:pr_body, "")
      |> put_state(:pr_base_branch, nil)
      |> put_state(:show_settings, false)
      |> put_state(:settings_tab, "general")
      |> put_state(:repository, nil)
      |> put_state(:is_loading_repository, false)
      |> put_state(:is_editing_repository, false)
      |> put_state(:repository_name, "")
      |> put_state(:repository_path, "")
      |> put_state(:repository_default_branch, "main")
      |> put_state(:repository_error, nil)
      |> put_state(:is_saving_repository, false)
      |> put_state(:hooks, [])
      |> put_state(:is_loading_hooks, false)
      |> put_state(:is_creating_hook, false)
      |> put_state(:editing_hook, nil)
      |> put_state(:hook_name, "")
      |> put_state(:hook_kind, "script")
      |> put_state(:hook_command, "")
      |> put_state(:hook_agent_prompt, "")
      |> put_state(:hook_agent_executor, "claude_code")
      |> put_state(:hook_agent_auto_approve, false)
      |> put_state(:hook_error, nil)
      |> put_state(:is_saving_hook, false)
      |> put_state(:task_templates, [])
      |> put_state(:is_loading_templates, false)
      |> put_state(:is_creating_template, false)
      |> put_state(:editing_template, nil)
      |> put_state(:template_name, "")
      |> put_state(:template_description, "")
      |> put_state(:template_error, nil)
      |> put_state(:is_saving_template, false)
      |> put_state(:periodical_tasks, [])
      |> put_state(:is_loading_periodical_tasks, false)
      |> put_state(:is_creating_periodical_task, false)
      |> put_state(:editing_periodical_task, nil)
      |> put_state(:periodical_task_title, "")
      |> put_state(:periodical_task_description, "")
      |> put_state(:periodical_task_schedule, "0 9 * * *")
      |> put_state(:periodical_task_executor, "claude_code")
      |> put_state(:periodical_task_error, nil)
      |> put_state(:cron_validation_error, nil)
      |> put_state(:is_saving_periodical_task, false)
      |> put_state(:system_tools, [])
      |> put_state(:is_loading_tools, false)
      # Column settings popup state
      |> put_state(:show_column_settings, false)
      |> put_state(:column_settings_tab, "general")
      |> put_state(:selected_column, nil)
      |> put_state(:column_settings_name, "")
      |> put_state(:column_settings_color, "#6366f1")
      |> put_state(:column_settings_description, "")
      |> put_state(:column_settings_is_saving, false)
      |> put_state(:column_settings_error, nil)
      |> put_state(:column_settings_show_delete_confirm, false)
      |> put_state(:column_settings_is_deleting, false)
      |> put_state(:column_hooks_enabled, true)
      |> put_state(:column_hooks, [])
      |> put_state(:column_available_hooks, [])
      |> put_state(:is_loading_column_hooks, false)
      |> put_state(:show_column_hook_picker, false)
      |> put_state(:is_adding_column_hook, false)
      |> put_state(:column_concurrency_enabled, false)
      |> put_state(:column_concurrency_limit, 3)
      |> put_state(:column_concurrency_is_saving, false)
      # Keyboard shortcuts modal state
      |> put_state(:show_keyboard_shortcuts, false)
      # Parent/child task highlighting state
      |> put_state(:hovered_task_id, nil)
      # Chat state
      |> put_state(:chat_message, "")

    component =
      case load_board_data(board_id) do
        {:ok, board, columns, tasks_by_column} ->
          component
          |> put_state(:board, serialize_board(board))
          |> put_state(:columns, Enum.map(columns, &serialize_column/1))
          |> put_state(:tasks_by_column, serialize_tasks_by_column(tasks_by_column))
          |> put_state(:loading, false)
          |> put_state(:error, nil)

        {:error, reason} ->
          component
          |> put_state(:board, nil)
          |> put_state(:columns, [])
          |> put_state(:tasks_by_column, %{})
          |> put_state(:loading, false)
          |> put_state(:error, reason)
      end

    {component, server}
  end

  @impl Hologram.Page
  def template do
    ~HOLO"""
    <div class="h-screen bg-gray-950 flex flex-col overflow-hidden">
      <header class="border-b border-gray-800 bg-gray-900/50 backdrop-blur-sm sticky top-0 z-50">
        <div class="px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <div class="flex items-center gap-4">
              <a href="/" class="text-gray-400 hover:text-white transition-colors">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
                </svg>
              </a>
              {%if @board}
                <h1 class="text-xl font-semibold text-white">{@board.name}</h1>
              {%else}
                <div class="h-6 w-32 bg-gray-800 rounded animate-pulse"></div>
              {/if}
            </div>

            <div class="flex items-center gap-4">
              <div class="relative">
                <input
                  type="text"
                  placeholder="Search tasks... (/)"
                  class="w-64 px-4 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent text-sm"
                  value={@search_query}
                  $change="update_search"
                  data-keyboard-search="true"
                />
              </div>
              <button
                class="p-2 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
                $click="show_keyboard_shortcuts"
                title="Keyboard shortcuts (Shift+?)"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </button>
              <button
                class="hidden"
                $click="show_keyboard_shortcuts"
                data-keyboard-help="true"
              ></button>
              <button
                class="p-2 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
                $click="show_settings"
                data-keyboard-settings="true"
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
        {%if @loading}
          <div class="flex items-center justify-center h-full">
            <div class="animate-spin rounded-full h-12 w-12 border-2 border-gray-600 border-t-brand-500"></div>
          </div>
        {%else}
          {%if @error}
            <div class="flex items-center justify-center h-full">
              <div class="text-center">
                <h2 class="text-xl font-semibold text-red-400 mb-2">Error</h2>
                <p class="text-gray-400">{@error}</p>
                <a href="/" class="mt-4 inline-block text-brand-400 hover:text-brand-300">
                  Go back home
                </a>
              </div>
            </div>
          {%else}
            <div class="h-full overflow-x-auto p-4">
              <div class="flex gap-4 h-full min-w-max" data-kanban-board>
                {%for {column, index} <- Enum.with_index(@columns)}
                  <Column
                    key={"#{column.id}-#{@tasks_version}"}
                    column={column}
                    tasks={Map.get(@tasks_by_column, column.id, [])}
                    search_query={@search_query}
                    hovered_task_id={@hovered_task_id}
                    all_tasks={all_tasks(@tasks_by_column)}
                    is_first_column={index == 0}
                    tasks_version={@tasks_version}
                  />
                {/for}
              </div>
            </div>
          {/if}
        {/if}
      </main>

      {%if @show_create_task_modal}
        <div class="fixed inset-0 z-50 overflow-y-auto">
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="fixed inset-0 bg-black/60 transition-opacity" $click="close_create_task_modal"></div>
            <div class="relative transform overflow-hidden rounded-xl bg-gray-900 border border-gray-800 shadow-xl transition-all w-full max-w-lg">
              <div class="flex items-center justify-between p-4 border-b border-gray-800">
                <h3 class="text-lg font-semibold text-white">Add task to {@create_task_column_name}</h3>
                <button
                  type="button"
                  class="text-gray-400 hover:text-white transition-colors"
                  $click="close_create_task_modal"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
              <div class="p-4">
                <form $submit="submit_create_task" class="space-y-4">
                  {%if @create_task_error}
                    <div class="p-3 bg-red-900/50 border border-red-800 rounded-lg text-red-200 text-sm">
                      {@create_task_error}
                    </div>
                  {/if}

                  <div>
                    <label for="title" class="block text-sm font-medium text-gray-300 mb-1">
                      Title *
                    </label>
                    <input
                      id="title"
                      type="text"
                      class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent"
                      placeholder="Enter task title"
                      value={@new_task_title}
                      $change="update_new_task_title"
                      autofocus
                    />
                  </div>

                  <div>
                    <label for="description" class="block text-sm font-medium text-gray-300 mb-1">
                      Description
                    </label>
                    <textarea
                      id="description"
                      rows="4"
                      class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent resize-none"
                      placeholder="Enter task description"
                      $change="update_new_task_description"
                    >{@new_task_description}</textarea>
                  </div>

                  <div class="flex justify-end gap-3 pt-2">
                    <button
                      type="button"
                      class="px-4 py-2 text-gray-300 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
                      $click="close_create_task_modal"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      class="px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                      disabled={@is_creating_task || @new_task_title == ""}
                    >
                      {%if @is_creating_task}
                        Creating...
                      {%else}
                        Create Task
                      {/if}
                    </button>
                  </div>
                </form>
              </div>
            </div>
          </div>
        </div>
      {/if}

      {%if @show_task_details && @selected_task}
        <div class="fixed inset-0 z-50 flex">
          <div class="fixed inset-0 bg-black/40 transition-opacity" $click="close_task_details"></div>
          <div class="ml-auto relative w-full max-w-xl bg-gray-900 border-l border-gray-800 flex flex-col h-full overflow-hidden">
            <div class="flex-shrink-0 px-6 py-4 border-b border-gray-800">
              <div class="flex items-start justify-between gap-4">
                <div class="flex-1 min-w-0">
                  {%if @is_editing_title}
                    <div class="flex gap-2">
                      <input
                        type="text"
                        class="flex-1 px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-brand-500 text-lg font-semibold"
                        value={@edit_title}
                        $change="update_edit_title"
                        autofocus
                      />
                      <button
                        type="button"
                        class="px-3 py-2 bg-brand-600 hover:bg-brand-700 text-white rounded-lg text-sm transition-colors disabled:opacity-50"
                        $click="save_task_title"
                        disabled={@is_saving_task}
                      >
                        Save
                      </button>
                      <button
                        type="button"
                        class="px-3 py-2 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg text-sm transition-colors"
                        $click="cancel_edit_title"
                      >
                        Cancel
                      </button>
                    </div>
                  {%else}
                    <h2
                      class="text-lg font-semibold text-white cursor-pointer hover:text-brand-400 transition-colors break-words"
                      $click="start_edit_title"
                      title="Click to edit"
                    >
                      {@selected_task.title}
                    </h2>
                  {/if}
                  {%if @selected_task.worktree_branch}
                    <p class="text-xs text-gray-500 font-mono mt-1">{@selected_task.worktree_branch}</p>
                  {/if}
                  {%if @selected_task_column_name}
                    <p class="text-xs text-gray-400 mt-1">{@selected_task_column_name}</p>
                  {/if}
                </div>
                <div class="flex items-center gap-2 flex-shrink-0">
                  {%if @selected_task.agent_status && @selected_task.agent_status != :idle}
                    <span class={agent_status_badge_class(@selected_task.agent_status)}>
                      {%if @selected_task.agent_status == :thinking || @selected_task.agent_status == :executing}
                        <svg class="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24">
                          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                        </svg>
                      {/if}
                      {agent_status_label(@selected_task.agent_status)}
                    </span>
                  {/if}
                  {%if @selected_task.pr_url}
                    <a
                      href={@selected_task.pr_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      class={pr_badge_class(@selected_task.pr_status)}
                    >
                      PR #{@selected_task.pr_number}
                    </a>
                  {/if}
                  {%if @selected_task.worktree_branch && !@selected_task.pr_url}
                    <button
                      type="button"
                      class="p-2 text-gray-400 hover:text-green-400 hover:bg-gray-800 rounded-lg transition-colors"
                      $click="open_create_pr_modal"
                      title="Create Pull Request"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                    </button>
                  {/if}
                  <button
                    type="button"
                    class="p-2 text-gray-400 hover:text-red-400 hover:bg-gray-800 rounded-lg transition-colors"
                    $click="show_delete_confirm"
                    title="Delete task"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                  </button>
                  <button
                    type="button"
                    class="p-2 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
                    $click="close_task_details"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
              </div>

              {%if @task_details_error}
                <div class="mt-3 p-3 bg-red-900/50 border border-red-800 rounded-lg text-red-200 text-sm">
                  {@task_details_error}
                </div>
              {/if}

              {%if @show_delete_confirm}
                <div class="mt-3 p-3 bg-red-500/10 border border-red-500/30 rounded-lg space-y-2">
                  <p class="text-red-400 text-sm">Delete this task? This cannot be undone.</p>
                  <div class="flex gap-2">
                    <button
                      type="button"
                      class="flex-1 px-3 py-2 text-gray-300 hover:text-white hover:bg-gray-800 rounded-lg text-sm transition-colors"
                      $click="cancel_delete"
                    >
                      Cancel
                    </button>
                    <button
                      type="button"
                      class="flex-1 px-3 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg text-sm transition-colors disabled:opacity-50"
                      $click="confirm_delete"
                      disabled={@is_deleting_task}
                    >
                      {%if @is_deleting_task}
                        Deleting...
                      {%else}
                        Delete
                      {/if}
                    </button>
                  </div>
                </div>
              {/if}
            </div>

            <div class="flex-shrink-0 px-6 py-4 border-b border-gray-800 bg-gray-900/30">
              <div class="flex items-center justify-between mb-2">
                <h3 class="text-sm font-medium text-gray-400">Description</h3>
                {%if !@is_editing_description}
                  <button
                    type="button"
                    class="text-sm text-gray-400 hover:text-white transition-colors"
                    $click="start_edit_description"
                  >
                    Edit
                  </button>
                {/if}
              </div>
              {%if @is_editing_description}
                <div class="space-y-2">
                  <textarea
                    rows="6"
                    class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent resize-none"
                    placeholder="Add a description..."
                    $change="update_edit_description"
                  >{@edit_description}</textarea>
                  <div class="flex gap-2 justify-end">
                    <button
                      type="button"
                      class="px-3 py-2 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg text-sm transition-colors"
                      $click="cancel_edit_description"
                    >
                      Cancel
                    </button>
                    <button
                      type="button"
                      class="px-3 py-2 bg-brand-600 hover:bg-brand-700 text-white rounded-lg text-sm transition-colors disabled:opacity-50"
                      $click="save_task_description"
                      disabled={@is_saving_task}
                    >
                      Save
                    </button>
                  </div>
                </div>
              {%else}
                {%if @selected_task.description}
                  <div
                    class="text-sm text-gray-300 cursor-pointer hover:bg-gray-800/50 rounded-lg p-2 -m-2 transition-colors whitespace-pre-wrap"
                    $click="start_edit_description"
                    title="Click to edit"
                  >
                    {@selected_task.description}
                  </div>
                {%else}
                  <p
                    class="text-sm text-gray-500 italic cursor-pointer hover:text-gray-400 transition-colors"
                    $click="start_edit_description"
                  >
                    Click to add a description...
                  </p>
                {/if}
              {/if}
            </div>

            <div class="flex-shrink-0 px-6 py-4 border-b border-gray-800">
              <SubtaskList
                task={@selected_task}
                subtasks={@subtasks}
                is_generating={@is_generating_subtasks}
              />
            </div>

            <div class="flex-1 overflow-y-auto px-6 py-4">
              <h3 class="text-sm font-medium text-gray-400 mb-3">Activity</h3>
              <div class="space-y-3">
                {%if @selected_task.error_message}
                  <div class="flex items-start gap-3 p-3 bg-red-900/20 border border-red-800/50 rounded-lg">
                    <div class="w-8 h-8 rounded-full bg-red-500/20 flex items-center justify-center flex-shrink-0">
                      <svg class="w-4 h-4 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium text-red-400">Error</p>
                      <p class="text-sm text-red-300/70 mt-1">{@selected_task.error_message}</p>
                    </div>
                  </div>
                {/if}

                {%if @selected_task.in_progress}
                  <div class="flex items-start gap-3 p-3 bg-green-900/20 border border-green-800/50 rounded-lg">
                    <div class="w-8 h-8 rounded-full bg-green-500/20 flex items-center justify-center flex-shrink-0">
                      <div class="w-3 h-3 bg-green-500 rounded-full animate-pulse"></div>
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium text-green-400">In Progress</p>
                      <p class="text-sm text-gray-400 mt-1">Agent is working on this task</p>
                    </div>
                  </div>
                {/if}

                {%if @selected_task.queued_at}
                  <div class="flex items-start gap-3 p-3 bg-yellow-900/20 border border-yellow-800/50 rounded-lg">
                    <div class="w-8 h-8 rounded-full bg-yellow-500/20 flex items-center justify-center flex-shrink-0">
                      <svg class="w-4 h-4 text-yellow-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium text-yellow-400">Queued</p>
                      <p class="text-sm text-gray-400 mt-1">Waiting to be processed</p>
                    </div>
                  </div>
                {/if}

                <div class="flex items-start gap-3 p-3">
                  <div class="w-8 h-8 rounded-full bg-brand-500/20 flex items-center justify-center flex-shrink-0">
                    <svg class="w-4 h-4 text-brand-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                    </svg>
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium text-gray-300">Task created</p>
                    <p class="text-sm text-gray-500 mt-1">Ready for work</p>
                  </div>
                </div>
              </div>
            </div>

            <div class="flex-shrink-0 px-6 py-4 border-t border-gray-800 bg-gray-900" data-task-id={@selected_task && @selected_task.id}>
              <form data-task-chat-form data-task-id={@selected_task && @selected_task.id} class="flex items-center gap-3">
                <input
                  type="text"
                  name="chat_message"
                  value={@chat_message}
                  class="flex-1 px-4 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent"
                  placeholder="Send a message to the agent..."
                  $change="update_chat_message"
                />
                <button
                  type="submit"
                  class={send_button_class(@chat_message, @selected_task)}
                  disabled={@chat_message == "" || (@selected_task && @selected_task.agent_status == :thinking)}
                >
                  {%if @selected_task && @selected_task.agent_status == :thinking}
                    <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                  {/if}
                  Send
                </button>
              </form>
              {%if @selected_task && @selected_task.agent_status == :thinking}
                <div class="flex items-center justify-between mt-2">
                  <p class="text-xs text-blue-400">Agent is thinking...</p>
                  <button
                    type="button"
                    class="text-xs text-red-400 hover:text-red-300 transition-colors"
                    $click={action: :stop_executor}
                  >
                    Cancel
                  </button>
                </div>
              {/if}
            </div>
          </div>
        </div>
      {/if}

      <CreatePRModal
        is_open={@show_create_pr_modal}
        task={@selected_task}
        branches={@pr_branches}
        is_loading_branches={@is_loading_branches}
        is_submitting={@is_creating_pr}
        error={@create_pr_error}
        title={@pr_title}
        body={@pr_body}
        base_branch={@pr_base_branch}
      />

      <BoardSettingsPanel
        is_open={@show_settings}
        board={@board}
        columns={@columns}
        active_tab={@settings_tab}
        repository={@repository}
        is_loading_repository={@is_loading_repository}
        is_editing_repository={@is_editing_repository}
        repository_name={@repository_name}
        repository_path={@repository_path}
        repository_default_branch={@repository_default_branch}
        repository_error={@repository_error}
        is_saving_repository={@is_saving_repository}
        hooks={@hooks}
        is_loading_hooks={@is_loading_hooks}
        is_creating_hook={@is_creating_hook}
        editing_hook={@editing_hook}
        hook_name={@hook_name}
        hook_kind={@hook_kind}
        hook_command={@hook_command}
        hook_agent_prompt={@hook_agent_prompt}
        hook_agent_executor={@hook_agent_executor}
        hook_agent_auto_approve={@hook_agent_auto_approve}
        hook_error={@hook_error}
        is_saving_hook={@is_saving_hook}
        task_templates={@task_templates}
        is_loading_templates={@is_loading_templates}
        is_creating_template={@is_creating_template}
        editing_template={@editing_template}
        template_name={@template_name}
        template_description={@template_description}
        template_error={@template_error}
        is_saving_template={@is_saving_template}
        periodical_tasks={@periodical_tasks}
        is_loading_periodical_tasks={@is_loading_periodical_tasks}
        is_creating_periodical_task={@is_creating_periodical_task}
        editing_periodical_task={@editing_periodical_task}
        periodical_task_title={@periodical_task_title}
        periodical_task_description={@periodical_task_description}
        periodical_task_schedule={@periodical_task_schedule}
        periodical_task_executor={@periodical_task_executor}
        periodical_task_error={@periodical_task_error}
        cron_validation_error={@cron_validation_error}
        is_saving_periodical_task={@is_saving_periodical_task}
        system_tools={@system_tools}
        is_loading_tools={@is_loading_tools}
      />

      <ColumnSettingsPopup
        is_open={@show_column_settings}
        column={@selected_column}
        board_id={@board_id}
        active_tab={@column_settings_tab}
        column_name={@column_settings_name}
        column_color={@column_settings_color}
        column_description={@column_settings_description}
        is_saving={@column_settings_is_saving}
        save_error={@column_settings_error}
        show_delete_confirm={@column_settings_show_delete_confirm}
        is_deleting={@column_settings_is_deleting}
        hooks_enabled={@column_hooks_enabled}
        column_hooks={@column_hooks}
        available_hooks={@column_available_hooks}
        all_columns={@columns}
        is_loading_hooks={@is_loading_column_hooks}
        show_hook_picker={@show_column_hook_picker}
        is_adding_hook={@is_adding_column_hook}
        concurrency_enabled={@column_concurrency_enabled}
        concurrency_limit={@column_concurrency_limit}
        is_saving_concurrency={@column_concurrency_is_saving}
      />

      <!-- Hidden buttons for keyboard shortcuts -->
      <button class="hidden" $click="keyboard_escape" data-keyboard-escape="true"></button>
      <button class="hidden" $click="keyboard_new_task" data-keyboard-new-task="true"></button>

      <!-- Keyboard Shortcuts Modal -->
      {%if @show_keyboard_shortcuts}
        <div class="fixed inset-0 bg-black/50 backdrop-blur-sm z-[100] flex items-center justify-center">
          <div class="bg-gray-900 border border-gray-700 rounded-xl shadow-2xl w-full max-w-md mx-4 overflow-hidden">
            <div class="flex items-center justify-between p-4 border-b border-gray-800">
              <h3 class="text-lg font-semibold text-white">Keyboard Shortcuts</h3>
              <button
                class="p-1 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
                $click="close_keyboard_shortcuts"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <div class="p-4 space-y-3">
              <div class="flex items-center justify-between py-2">
                <span class="text-gray-300">Create new task</span>
                <kbd class="px-2 py-1 bg-gray-800 border border-gray-700 rounded text-sm text-gray-300 font-mono">n</kbd>
              </div>
              <div class="flex items-center justify-between py-2">
                <span class="text-gray-300">Focus search</span>
                <kbd class="px-2 py-1 bg-gray-800 border border-gray-700 rounded text-sm text-gray-300 font-mono">/</kbd>
              </div>
              <div class="flex items-center justify-between py-2">
                <span class="text-gray-300">Open settings</span>
                <kbd class="px-2 py-1 bg-gray-800 border border-gray-700 rounded text-sm text-gray-300 font-mono">,</kbd>
              </div>
              <div class="flex items-center justify-between py-2">
                <span class="text-gray-300">Close modal/panel</span>
                <kbd class="px-2 py-1 bg-gray-800 border border-gray-700 rounded text-sm text-gray-300 font-mono">Esc</kbd>
              </div>
              <div class="flex items-center justify-between py-2">
                <span class="text-gray-300">Show this help</span>
                <div class="flex gap-1">
                  <kbd class="px-2 py-1 bg-gray-800 border border-gray-700 rounded text-sm text-gray-300 font-mono">Shift</kbd>
                  <kbd class="px-2 py-1 bg-gray-800 border border-gray-700 rounded text-sm text-gray-300 font-mono">?</kbd>
                </div>
              </div>
            </div>
            <div class="px-4 pb-4">
              <p class="text-xs text-gray-500">Shortcuts are disabled when typing in an input field.</p>
            </div>
          </div>
        </div>
      {/if}

      <input type="hidden" id="task-click-trigger" $change="js_open_task_details" />
      <input type="hidden" id="task-hover-trigger" $change="js_hover_task" />
      <button class="hidden" id="task-unhover-trigger" $click="unhover_task"></button>
      <input type="hidden" id="column-settings-trigger" $change="js_open_column_settings" />
      <input type="hidden" id="create-task-trigger" data-column-name="" $change="js_open_create_task_modal" />
      <button class="hidden" id="task-changed-trigger" data-channel-task-changed data-channel-payload="" $click="js_task_changed"></button>
    </div>
    """
  end

  def action(:update_search, %{"value" => query}, component) do
    put_state(component, :search_query, query)
  end

  def action(:show_settings, _params, component) do
    component
    |> put_state(:show_settings, true)
    |> put_state(:settings_tab, "general")
    |> put_state(:is_loading_repository, true)
    |> put_state(:is_loading_hooks, true)
    |> put_state(:is_loading_templates, true)
    |> put_state(:is_loading_periodical_tasks, true)
    |> put_state(:is_loading_tools, true)
    |> put_command(:load_settings_data, %{board_id: component.state.board_id})
  end

  def action(:close_settings, _params, component) do
    component
    |> put_state(:show_settings, false)
    |> put_state(:is_editing_repository, false)
    |> put_state(:is_creating_hook, false)
    |> put_state(:editing_hook, nil)
    |> put_state(:is_creating_template, false)
    |> put_state(:editing_template, nil)
    |> put_state(:is_creating_periodical_task, false)
    |> put_state(:editing_periodical_task, nil)
  end

  def action(:show_keyboard_shortcuts, _params, component) do
    put_state(component, :show_keyboard_shortcuts, true)
  end

  def action(:close_keyboard_shortcuts, _params, component) do
    put_state(component, :show_keyboard_shortcuts, false)
  end

  def action(:keyboard_escape, _params, component) do
    cond do
      component.state.show_keyboard_shortcuts ->
        put_state(component, :show_keyboard_shortcuts, false)

      component.state.show_column_settings ->
        component
        |> put_state(:show_column_settings, false)
        |> put_state(:selected_column, nil)
        |> put_state(:column_hooks, [])
        |> put_state(:column_available_hooks, [])
        |> put_state(:show_column_hook_picker, false)

      component.state.show_create_pr_modal ->
        component
        |> put_state(:show_create_pr_modal, false)
        |> put_state(:pr_title, "")
        |> put_state(:pr_body, "")
        |> put_state(:pr_branches, [])
        |> put_state(:pr_base_branch, nil)
        |> put_state(:create_pr_error, nil)

      component.state.show_create_task_modal ->
        component
        |> put_state(:show_create_task_modal, false)
        |> put_state(:create_task_column_id, nil)
        |> put_state(:create_task_column_name, "")
        |> put_state(:new_task_title, "")
        |> put_state(:new_task_description, "")
        |> put_state(:create_task_error, nil)

      component.state.show_task_details ->
        component
        |> put_state(:show_task_details, false)
        |> put_state(:selected_task, nil)
        |> put_state(:selected_task_id, nil)
        |> put_state(:is_editing_title, false)
        |> put_state(:is_editing_description, false)
        |> put_state(:show_delete_confirm, false)

      component.state.show_settings ->
        component
        |> put_state(:show_settings, false)
        |> put_state(:is_editing_repository, false)
        |> put_state(:is_creating_hook, false)
        |> put_state(:editing_hook, nil)
        |> put_state(:is_creating_template, false)
        |> put_state(:editing_template, nil)
        |> put_state(:is_creating_periodical_task, false)
        |> put_state(:editing_periodical_task, nil)

      true ->
        component
    end
  end

  def action(:keyboard_new_task, _params, component) do
    first_column = List.first(component.state.columns)

    if first_column do
      component
      |> put_state(:show_create_task_modal, true)
      |> put_state(:create_task_column_id, first_column[:id] || first_column.id)
      |> put_state(:create_task_column_name, first_column[:name] || first_column.name)
      |> put_state(:new_task_title, "")
      |> put_state(:new_task_description, "")
      |> put_state(:create_task_error, nil)
    else
      component
    end
  end

  def action(:hover_task, %{task_id: task_id}, component) do
    all_tasks = all_tasks(component.state.tasks_by_column)
    task_id_str = to_string(task_id)
    task = Enum.find(all_tasks, fn t -> to_string(t[:id] || t.id) == task_id_str end)

    if task && (task[:is_parent] || task[:parent_task_id]) do
      put_state(component, :hovered_task_id, task_id)
    else
      component
    end
  end

  def action(:unhover_task, _params, component) do
    put_state(component, :hovered_task_id, nil)
  end

  def action(:js_open_task_details, params, component) do
    task_id = get_in(params, [:event, :target, :value]) || get_in(params, [:event, :value]) || ""
    action(:open_task_details, %{task_id: task_id}, component)
  end

  def action(:js_hover_task, params, component) do
    task_id = get_in(params, [:event, :target, :value]) || get_in(params, [:event, :value]) || ""
    action(:hover_task, %{task_id: task_id}, component)
  end

  def action(:js_open_column_settings, params, component) do
    column_id = get_in(params, [:event, :target, :value]) || get_in(params, [:event, :value]) || ""
    action(:open_column_settings, %{column_id: column_id}, component)
  end

  def action(:js_open_create_task_modal, params, component) do
    column_id = get_in(params, [:event, :target, :value]) || get_in(params, [:event, :value]) || ""
    column_name = get_in(params, [:event, :target, :dataset, :columnName]) || ""
    action(:open_create_task_modal, %{column_id: column_id, column_name: column_name}, component)
  end

  def action(:js_task_changed, params, component) do
    payload_json = get_in(params, [:event, :target, :dataset, :channelPayload]) || "{}"

    case Jason.decode(payload_json) do
      {:ok, %{"task" => task_data, "action" => action_name}} ->
        handle_task_changed(component, task_data, action_name)

      _ ->
        component
    end
  end

  def action(:update_chat_message, %{event: %{value: value}}, component) do
    put_state(component, :chat_message, value)
  end

  def action(:stop_executor, _params, component) do
    task = component.state.selected_task

    if task do
      Viban.Executors.Runner.stop_by_task(task.id, :user_cancelled)
    end

    component
  end

  def action(:change_settings_tab, %{tab: tab}, component) do
    put_state(component, :settings_tab, tab)
  end

  def action(:settings_data_loaded, params, component) do
    component
    |> put_state(:repository, params.repository)
    |> put_state(:hooks, params.hooks)
    |> put_state(:task_templates, params.task_templates)
    |> put_state(:periodical_tasks, params.periodical_tasks)
    |> put_state(:system_tools, params.system_tools)
    |> put_state(:is_loading_repository, false)
    |> put_state(:is_loading_hooks, false)
    |> put_state(:is_loading_templates, false)
    |> put_state(:is_loading_periodical_tasks, false)
    |> put_state(:is_loading_tools, false)
  end

  def action(:start_edit_repository, _params, component) do
    repo = component.state.repository

    component
    |> put_state(:is_editing_repository, true)
    |> put_state(:repository_name, if(repo, do: repo.name || "", else: ""))
    |> put_state(:repository_path, if(repo, do: repo.local_path || "", else: ""))
    |> put_state(:repository_default_branch, if(repo, do: repo.default_branch || "main", else: "main"))
    |> put_state(:repository_error, nil)
  end

  def action(:cancel_edit_repository, _params, component) do
    component
    |> put_state(:is_editing_repository, false)
    |> put_state(:repository_error, nil)
  end

  def action(:update_repository_name, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""
    put_state(component, :repository_name, value)
  end

  def action(:update_repository_path, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""
    put_state(component, :repository_path, value)
  end

  def action(:update_repository_default_branch, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""
    put_state(component, :repository_default_branch, value)
  end

  def action(:save_repository, _params, component) do
    name = component.state.repository_name
    path = component.state.repository_path

    if name == "" || path == "" do
      put_state(component, :repository_error, "Name and path are required")
    else
      component
      |> put_state(:is_saving_repository, true)
      |> put_state(:repository_error, nil)
      |> put_command(:save_repository, %{
        board_id: component.state.board_id,
        repository_id: if(component.state.repository, do: component.state.repository.id),
        name: name,
        path: path,
        default_branch: component.state.repository_default_branch
      })
    end
  end

  def action(:repository_saved, %{repository: repository}, component) do
    component
    |> put_state(:repository, repository)
    |> put_state(:is_saving_repository, false)
    |> put_state(:is_editing_repository, false)
  end

  def action(:repository_save_failed, %{error: error}, component) do
    component
    |> put_state(:is_saving_repository, false)
    |> put_state(:repository_error, error)
  end

  def action(:start_create_template, _params, component) do
    component
    |> put_state(:is_creating_template, true)
    |> put_state(:editing_template, nil)
    |> put_state(:template_name, "")
    |> put_state(:template_description, "")
    |> put_state(:template_error, nil)
  end

  def action(:start_edit_template, %{template_id: template_id}, component) do
    template = Enum.find(component.state.task_templates, fn t -> t.id == template_id end)

    if template do
      component
      |> put_state(:is_creating_template, false)
      |> put_state(:editing_template, template)
      |> put_state(:template_name, template.name || "")
      |> put_state(:template_description, template.description_template || "")
      |> put_state(:template_error, nil)
    else
      component
    end
  end

  def action(:cancel_template_edit, _params, component) do
    component
    |> put_state(:is_creating_template, false)
    |> put_state(:editing_template, nil)
    |> put_state(:template_name, "")
    |> put_state(:template_description, "")
    |> put_state(:template_error, nil)
  end

  def action(:update_template_name, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""
    put_state(component, :template_name, value)
  end

  def action(:update_template_description, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""
    put_state(component, :template_description, value)
  end

  def action(:save_template, _params, component) do
    name = component.state.template_name

    if name == "" do
      put_state(component, :template_error, "Name is required")
    else
      component
      |> put_state(:is_saving_template, true)
      |> put_state(:template_error, nil)
      |> put_command(:save_template, %{
        board_id: component.state.board_id,
        template_id: if(component.state.editing_template, do: component.state.editing_template.id),
        name: name,
        description_template: component.state.template_description
      })
    end
  end

  def action(:template_saved, %{templates: templates}, component) do
    component
    |> put_state(:task_templates, templates)
    |> put_state(:is_saving_template, false)
    |> put_state(:is_creating_template, false)
    |> put_state(:editing_template, nil)
  end

  def action(:template_save_failed, %{error: error}, component) do
    component
    |> put_state(:is_saving_template, false)
    |> put_state(:template_error, error)
  end

  def action(:delete_template, %{template_id: template_id}, component) do
    put_command(component, :delete_template, %{template_id: template_id})
  end

  def action(:template_deleted, %{templates: templates}, component) do
    put_state(component, :task_templates, templates)
  end

  def action(:start_create_hook, _params, component) do
    component
    |> put_state(:is_creating_hook, true)
    |> put_state(:editing_hook, nil)
    |> put_state(:hook_name, "")
    |> put_state(:hook_kind, "script")
    |> put_state(:hook_command, "")
    |> put_state(:hook_agent_prompt, "")
    |> put_state(:hook_agent_executor, "claude_code")
    |> put_state(:hook_agent_auto_approve, false)
    |> put_state(:hook_error, nil)
  end

  def action(:start_edit_hook, %{hook_id: hook_id}, component) do
    hook = Enum.find(component.state.hooks, fn h -> h.id == hook_id end)

    if hook && !hook.is_system do
      component
      |> put_state(:is_creating_hook, false)
      |> put_state(:editing_hook, hook)
      |> put_state(:hook_name, hook.name || "")
      |> put_state(:hook_kind, hook.hook_kind || "script")
      |> put_state(:hook_command, hook.command || "")
      |> put_state(:hook_agent_prompt, hook.agent_prompt || "")
      |> put_state(:hook_agent_executor, hook.agent_executor || "claude_code")
      |> put_state(:hook_agent_auto_approve, hook.agent_auto_approve || false)
      |> put_state(:hook_error, nil)
    else
      component
    end
  end

  def action(:cancel_hook_edit, _params, component) do
    component
    |> put_state(:is_creating_hook, false)
    |> put_state(:editing_hook, nil)
    |> put_state(:hook_name, "")
    |> put_state(:hook_kind, "script")
    |> put_state(:hook_command, "")
    |> put_state(:hook_agent_prompt, "")
    |> put_state(:hook_error, nil)
  end

  def action(:update_hook_name, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""
    put_state(component, :hook_name, value)
  end

  def action(:update_hook_kind, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || "script"
    put_state(component, :hook_kind, value)
  end

  def action(:update_hook_command, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""
    put_state(component, :hook_command, value)
  end

  def action(:update_hook_agent_prompt, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""
    put_state(component, :hook_agent_prompt, value)
  end

  def action(:update_hook_agent_executor, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || "claude_code"
    put_state(component, :hook_agent_executor, value)
  end

  def action(:toggle_hook_auto_approve, _params, component) do
    put_state(component, :hook_agent_auto_approve, !component.state.hook_agent_auto_approve)
  end

  def action(:save_hook, _params, component) do
    name = component.state.hook_name
    kind = component.state.hook_kind

    cond do
      name == "" ->
        put_state(component, :hook_error, "Name is required")

      kind == "script" && component.state.hook_command == "" ->
        put_state(component, :hook_error, "Command is required for script hooks")

      kind == "agent" && component.state.hook_agent_prompt == "" ->
        put_state(component, :hook_error, "Prompt is required for agent hooks")

      true ->
        component
        |> put_state(:is_saving_hook, true)
        |> put_state(:hook_error, nil)
        |> put_command(:save_hook, %{
          board_id: component.state.board_id,
          hook_id: if(component.state.editing_hook, do: component.state.editing_hook.id),
          name: name,
          hook_kind: kind,
          command: component.state.hook_command,
          agent_prompt: component.state.hook_agent_prompt,
          agent_executor: component.state.hook_agent_executor,
          agent_auto_approve: component.state.hook_agent_auto_approve
        })
    end
  end

  def action(:hook_saved, %{hooks: hooks}, component) do
    component
    |> put_state(:hooks, hooks)
    |> put_state(:is_saving_hook, false)
    |> put_state(:is_creating_hook, false)
    |> put_state(:editing_hook, nil)
  end

  def action(:hook_save_failed, %{error: error}, component) do
    component
    |> put_state(:is_saving_hook, false)
    |> put_state(:hook_error, error)
  end

  def action(:delete_hook, %{hook_id: hook_id}, component) do
    put_command(component, :delete_hook, %{hook_id: hook_id})
  end

  def action(:hook_deleted, %{hooks: hooks}, component) do
    put_state(component, :hooks, hooks)
  end

  def action(:start_create_periodical_task, _params, component) do
    component
    |> put_state(:is_creating_periodical_task, true)
    |> put_state(:editing_periodical_task, nil)
    |> put_state(:periodical_task_title, "")
    |> put_state(:periodical_task_description, "")
    |> put_state(:periodical_task_schedule, "0 9 * * *")
    |> put_state(:periodical_task_executor, "claude_code")
    |> put_state(:periodical_task_error, nil)
    |> put_state(:cron_validation_error, nil)
  end

  def action(:start_edit_periodical_task, %{task_id: task_id}, component) do
    task = Enum.find(component.state.periodical_tasks, fn t -> t.id == task_id end)

    if task do
      component
      |> put_state(:is_creating_periodical_task, false)
      |> put_state(:editing_periodical_task, task)
      |> put_state(:periodical_task_title, task.title || "")
      |> put_state(:periodical_task_description, task.description || "")
      |> put_state(:periodical_task_schedule, task.schedule || "0 9 * * *")
      |> put_state(:periodical_task_executor, task.executor || "claude_code")
      |> put_state(:periodical_task_error, nil)
      |> put_state(:cron_validation_error, nil)
    else
      component
    end
  end

  def action(:cancel_periodical_task_edit, _params, component) do
    component
    |> put_state(:is_creating_periodical_task, false)
    |> put_state(:editing_periodical_task, nil)
    |> put_state(:periodical_task_title, "")
    |> put_state(:periodical_task_description, "")
    |> put_state(:periodical_task_schedule, "0 9 * * *")
    |> put_state(:periodical_task_executor, "claude_code")
    |> put_state(:periodical_task_error, nil)
    |> put_state(:cron_validation_error, nil)
  end

  def action(:update_periodical_task_title, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""
    put_state(component, :periodical_task_title, value)
  end

  def action(:update_periodical_task_description, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""
    put_state(component, :periodical_task_description, value)
  end

  def action(:update_periodical_task_schedule, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""

    component
    |> put_state(:periodical_task_schedule, value)
    |> put_command(:validate_cron, %{schedule: value})
  end

  def action(:update_periodical_task_executor, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || "claude_code"
    put_state(component, :periodical_task_executor, value)
  end

  def action(:save_periodical_task, _params, component) do
    title = component.state.periodical_task_title

    if title == "" do
      put_state(component, :periodical_task_error, "Title is required")
    else
      component
      |> put_state(:is_saving_periodical_task, true)
      |> put_state(:periodical_task_error, nil)
      |> put_command(:save_periodical_task, %{
        board_id: component.state.board_id,
        task_id: if(component.state.editing_periodical_task, do: component.state.editing_periodical_task.id),
        title: title,
        description: component.state.periodical_task_description,
        schedule: component.state.periodical_task_schedule,
        executor: component.state.periodical_task_executor
      })
    end
  end

  def action(:periodical_task_saved, %{periodical_tasks: tasks}, component) do
    component
    |> put_state(:periodical_tasks, tasks)
    |> put_state(:is_saving_periodical_task, false)
    |> put_state(:is_creating_periodical_task, false)
    |> put_state(:editing_periodical_task, nil)
  end

  def action(:periodical_task_save_failed, %{error: error}, component) do
    component
    |> put_state(:is_saving_periodical_task, false)
    |> put_state(:periodical_task_error, error)
  end

  def action(:toggle_periodical_task, %{task_id: task_id, enabled: enabled}, component) do
    put_command(component, :toggle_periodical_task, %{task_id: task_id, enabled: enabled})
  end

  def action(:periodical_task_toggled, %{periodical_tasks: tasks}, component) do
    put_state(component, :periodical_tasks, tasks)
  end

  def action(:delete_periodical_task, %{task_id: task_id}, component) do
    put_command(component, :delete_periodical_task, %{task_id: task_id})
  end

  def action(:periodical_task_deleted, %{periodical_tasks: tasks}, component) do
    put_state(component, :periodical_tasks, tasks)
  end

  def action(:cron_validated, %{error: error}, component) do
    put_state(component, :cron_validation_error, error)
  end

  def action(:open_create_task_modal, %{column_id: column_id, column_name: column_name}, component) do
    component
    |> put_state(:show_create_task_modal, true)
    |> put_state(:create_task_column_id, column_id)
    |> put_state(:create_task_column_name, column_name)
  end

  def action(:close_create_task_modal, _params, component) do
    component
    |> put_state(:show_create_task_modal, false)
    |> put_state(:create_task_column_id, nil)
    |> put_state(:create_task_column_name, "")
    |> put_state(:new_task_title, "")
    |> put_state(:new_task_description, "")
    |> put_state(:create_task_error, nil)
  end

  def action(:update_new_task_title, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""
    put_state(component, :new_task_title, value)
  end

  def action(:update_new_task_description, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""
    put_state(component, :new_task_description, value)
  end

  def action(:submit_create_task, _params, component) do
    title = component.state.new_task_title

    if title == "" do
      put_state(component, :create_task_error, "Title is required")
    else
      component
      |> put_state(:is_creating_task, true)
      |> put_state(:create_task_error, nil)
      |> put_command(:create_task, %{
        title: title,
        description: component.state.new_task_description,
        column_id: component.state.create_task_column_id
      })
    end
  end

  def action(:task_created, %{task: task}, component) do
    column_id = component.state.create_task_column_id
    existing_key = find_matching_column_key(component.state.tasks_by_column, column_id)
    key_to_use = existing_key || column_id
    tasks = Map.get(component.state.tasks_by_column, key_to_use, [])
    updated_tasks = tasks ++ [task]
    tasks_by_column = Map.put(component.state.tasks_by_column, key_to_use, updated_tasks)

    component
    |> put_state(:is_creating_task, false)
    |> put_state(:show_create_task_modal, false)
    |> put_state(:create_task_column_id, nil)
    |> put_state(:create_task_column_name, "")
    |> put_state(:new_task_title, "")
    |> put_state(:new_task_description, "")
    |> put_state(:create_task_error, nil)
    |> put_state(:tasks_by_column, tasks_by_column)
  end

  def action(:task_creation_failed, %{error: error}, component) do
    component
    |> put_state(:is_creating_task, false)
    |> put_state(:create_task_error, error)
  end

  def action(:set_board_data, %{board: board, columns: columns, tasks_by_column: tasks_by_column}, component) do
    component
    |> put_state(:board, board)
    |> put_state(:columns, columns)
    |> put_state(:tasks_by_column, tasks_by_column)
    |> put_state(:loading, false)
  end

  def action(:set_error, %{error: error}, component) do
    component
    |> put_state(:error, error)
    |> put_state(:loading, false)
  end

  def action(:select_task, %{task_id: task_id}, component) do
    put_state(component, :selected_task_id, task_id)
  end

  def action(:open_task_details, %{task_id: task_id}, component) do
    task = find_task(component.state.tasks_by_column, task_id)
    column_name = find_column_name_for_task(component.state.columns, component.state.tasks_by_column, task_id)

    if task do
      component
      |> put_state(:show_task_details, true)
      |> put_state(:selected_task, task)
      |> put_state(:selected_task_id, task_id)
      |> put_state(:selected_task_column_name, column_name)
      |> put_state(:edit_title, task.title)
      |> put_state(:edit_description, task.description || "")
      |> put_state(:is_editing_title, false)
      |> put_state(:is_editing_description, false)
      |> put_state(:show_delete_confirm, false)
      |> put_state(:task_details_error, nil)
      |> put_state(:subtasks, [])
      |> put_state(:is_generating_subtasks, false)
      |> put_command(:load_subtasks, %{task_id: task_id})
    else
      component
    end
  end

  def action(:close_task_details, _params, component) do
    component
    |> put_state(:show_task_details, false)
    |> put_state(:selected_task, nil)
    |> put_state(:selected_task_id, nil)
    |> put_state(:selected_task_column_name, nil)
    |> put_state(:is_editing_title, false)
    |> put_state(:is_editing_description, false)
    |> put_state(:show_delete_confirm, false)
    |> put_state(:task_details_error, nil)
  end

  def action(:start_edit_title, _params, component) do
    put_state(component, :is_editing_title, true)
  end

  def action(:cancel_edit_title, _params, component) do
    task = component.state.selected_task

    component
    |> put_state(:is_editing_title, false)
    |> put_state(:edit_title, task.title)
  end

  def action(:update_edit_title, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""
    put_state(component, :edit_title, value)
  end

  def action(:save_task_title, _params, component) do
    title = component.state.edit_title

    if title == "" do
      put_state(component, :task_details_error, "Title is required")
    else
      component
      |> put_state(:is_saving_task, true)
      |> put_state(:task_details_error, nil)
      |> put_command(:update_task_title, %{
        task_id: component.state.selected_task_id,
        title: title
      })
    end
  end

  def action(:start_edit_description, _params, component) do
    put_state(component, :is_editing_description, true)
  end

  def action(:cancel_edit_description, _params, component) do
    task = component.state.selected_task

    component
    |> put_state(:is_editing_description, false)
    |> put_state(:edit_description, task.description || "")
  end

  def action(:update_edit_description, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""
    put_state(component, :edit_description, value)
  end

  def action(:save_task_description, _params, component) do
    component
    |> put_state(:is_saving_task, true)
    |> put_state(:task_details_error, nil)
    |> put_command(:update_task_description, %{
      task_id: component.state.selected_task_id,
      description: component.state.edit_description
    })
  end

  def action(:task_updated, %{task: task}, component) do
    tasks_by_column = update_task_in_map(component.state.tasks_by_column, task)

    component
    |> put_state(:is_saving_task, false)
    |> put_state(:is_editing_title, false)
    |> put_state(:is_editing_description, false)
    |> put_state(:selected_task, task)
    |> put_state(:edit_title, task.title)
    |> put_state(:edit_description, task.description || "")
    |> put_state(:tasks_by_column, tasks_by_column)
  end

  def action(:task_update_failed, %{error: error}, component) do
    component
    |> put_state(:is_saving_task, false)
    |> put_state(:task_details_error, error)
  end

  def action(:show_delete_confirm, _params, component) do
    put_state(component, :show_delete_confirm, true)
  end

  def action(:cancel_delete, _params, component) do
    put_state(component, :show_delete_confirm, false)
  end

  def action(:confirm_delete, _params, component) do
    component
    |> put_state(:is_deleting_task, true)
    |> put_state(:task_details_error, nil)
    |> put_command(:delete_task, %{task_id: component.state.selected_task_id})
  end

  def action(:task_deleted, %{task_id: task_id}, component) do
    tasks_by_column = remove_task_from_map(component.state.tasks_by_column, task_id)

    component
    |> put_state(:is_deleting_task, false)
    |> put_state(:show_task_details, false)
    |> put_state(:selected_task, nil)
    |> put_state(:selected_task_id, nil)
    |> put_state(:show_delete_confirm, false)
    |> put_state(:tasks_by_column, tasks_by_column)
  end

  def action(:task_delete_failed, %{error: error}, component) do
    component
    |> put_state(:is_deleting_task, false)
    |> put_state(:task_details_error, error)
  end

  def action(:subtasks_loaded, %{subtasks: subtasks}, component) do
    put_state(component, :subtasks, subtasks)
  end

  def action(:generate_subtasks, %{task_id: task_id}, component) do
    component
    |> put_state(:is_generating_subtasks, true)
    |> put_command(:generate_subtasks, %{task_id: task_id})
  end

  def action(:subtasks_generated, %{subtasks: subtasks, task: task}, component) do
    tasks_by_column = update_task_in_map(component.state.tasks_by_column, task)

    component
    |> put_state(:is_generating_subtasks, false)
    |> put_state(:subtasks, subtasks)
    |> put_state(:selected_task, task)
    |> put_state(:tasks_by_column, tasks_by_column)
  end

  def action(:subtask_generation_failed, %{error: error, task: task}, component) do
    tasks_by_column =
      if task do
        update_task_in_map(component.state.tasks_by_column, task)
      else
        component.state.tasks_by_column
      end

    component
    |> put_state(:is_generating_subtasks, false)
    |> put_state(:task_details_error, error)
    |> put_state(:tasks_by_column, tasks_by_column)
    |> then(fn comp -> if task, do: put_state(comp, :selected_task, task), else: comp end)
  end

  def action(:open_subtask, %{subtask_id: subtask_id}, component) do
    subtask = Enum.find(component.state.subtasks, fn s -> s.id == subtask_id end)

    if subtask do
      column_name = find_column_name_for_task(component.state.columns, component.state.tasks_by_column, subtask_id)

      component
      |> put_state(:selected_task, subtask)
      |> put_state(:selected_task_id, subtask_id)
      |> put_state(:selected_task_column_name, column_name)
      |> put_state(:edit_title, subtask.title)
      |> put_state(:edit_description, subtask.description || "")
      |> put_state(:is_editing_title, false)
      |> put_state(:is_editing_description, false)
      |> put_state(:show_delete_confirm, false)
      |> put_state(:task_details_error, nil)
      |> put_state(:subtasks, [])
      |> put_command(:load_subtasks, %{task_id: subtask_id})
    else
      component
    end
  end

  def action(:open_create_pr_modal, _params, component) do
    task = component.state.selected_task

    component
    |> put_state(:show_create_pr_modal, true)
    |> put_state(:pr_title, task.title || "")
    |> put_state(:pr_body, task.description || "")
    |> put_state(:pr_branches, [])
    |> put_state(:pr_base_branch, nil)
    |> put_state(:is_loading_branches, true)
    |> put_state(:create_pr_error, nil)
    |> put_command(:load_branches, %{task_id: task.id})
  end

  def action(:close_create_pr_modal, _params, component) do
    component
    |> put_state(:show_create_pr_modal, false)
    |> put_state(:pr_branches, [])
    |> put_state(:pr_base_branch, nil)
    |> put_state(:pr_title, "")
    |> put_state(:pr_body, "")
    |> put_state(:create_pr_error, nil)
  end

  def action(:update_pr_title, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""
    put_state(component, :pr_title, value)
  end

  def action(:update_pr_body, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""
    put_state(component, :pr_body, value)
  end

  def action(:update_base_branch, params, component) do
    value = get_in(params, [:event, :value]) || params["value"] || ""
    put_state(component, :pr_base_branch, value)
  end

  def action(:branches_loaded, %{branches: branches}, component) do
    default_branch = Enum.find(branches, fn b -> b.is_default end)
    base_branch = if default_branch, do: default_branch.name, else: if(length(branches) > 0, do: hd(branches).name)

    component
    |> put_state(:pr_branches, branches)
    |> put_state(:pr_base_branch, base_branch)
    |> put_state(:is_loading_branches, false)
  end

  def action(:submit_create_pr, _params, component) do
    title = component.state.pr_title

    if title == "" do
      put_state(component, :create_pr_error, "Title is required")
    else
      component
      |> put_state(:is_creating_pr, true)
      |> put_state(:create_pr_error, nil)
      |> put_command(:create_pr, %{
        task_id: component.state.selected_task_id,
        title: title,
        body: component.state.pr_body,
        base_branch: component.state.pr_base_branch
      })
    end
  end

  def action(:pr_created, %{pr_url: _pr_url, pr_number: _pr_number, task: task}, component) do
    tasks_by_column = update_task_in_map(component.state.tasks_by_column, task)

    component
    |> put_state(:is_creating_pr, false)
    |> put_state(:show_create_pr_modal, false)
    |> put_state(:selected_task, task)
    |> put_state(:tasks_by_column, tasks_by_column)
    |> put_state(:pr_branches, [])
    |> put_state(:pr_base_branch, nil)
    |> put_state(:pr_title, "")
    |> put_state(:pr_body, "")
  end

  def action(:pr_creation_failed, %{error: error}, component) do
    component
    |> put_state(:is_creating_pr, false)
    |> put_state(:create_pr_error, error)
  end

  # Column Settings Actions
  def action(:open_column_settings, %{column_id: column_id}, component) do
    column_id_str = to_string(column_id)
    column = Enum.find(component.state.columns, fn col -> to_string(col[:id]) == column_id_str end)

    if column do
      settings = column[:settings] || %{}

      component
      |> put_state(:show_column_settings, true)
      |> put_state(:column_settings_tab, "general")
      |> put_state(:selected_column, column)
      |> put_state(:column_settings_name, column[:name] || "")
      |> put_state(:column_settings_color, column[:color] || "#6366f1")
      |> put_state(:column_settings_description, settings["description"] || "")
      |> put_state(:column_hooks_enabled, settings["hooks_enabled"] != false)
      |> put_state(:column_concurrency_enabled, settings["max_concurrent_tasks"] != nil)
      |> put_state(:column_concurrency_limit, settings["max_concurrent_tasks"] || 3)
      |> put_state(:is_loading_column_hooks, true)
      |> put_command(:load_column_hooks, %{column_id: column_id, board_id: component.state.board_id})
    else
      component
    end
  end

  def action(:close_column_settings, _params, component) do
    component
    |> put_state(:show_column_settings, false)
    |> put_state(:selected_column, nil)
    |> put_state(:column_settings_error, nil)
    |> put_state(:column_settings_show_delete_confirm, false)
    |> put_state(:show_column_hook_picker, false)
  end

  def action(:set_column_settings_tab, %{tab: tab}, component) do
    put_state(component, :column_settings_tab, tab)
  end

  def action(:update_column_name, %{"value" => value}, component) do
    put_state(component, :column_settings_name, value)
  end

  def action(:select_column_color, %{color: color}, component) do
    put_state(component, :column_settings_color, color)
  end

  def action(:update_column_description, %{"value" => value}, component) do
    put_state(component, :column_settings_description, value)
  end

  def action(:save_column_settings, _params, component) do
    column = component.state.selected_column

    component
    |> put_state(:column_settings_is_saving, true)
    |> put_state(:column_settings_error, nil)
    |> put_command(:save_column_settings, %{
      column_id: column[:id],
      name: component.state.column_settings_name,
      color: component.state.column_settings_color,
      description: component.state.column_settings_description
    })
  end

  def action(:column_settings_saved, %{column: updated_column}, component) do
    columns =
      Enum.map(component.state.columns, fn col ->
        if col[:id] == updated_column[:id], do: updated_column, else: col
      end)

    component
    |> put_state(:columns, columns)
    |> put_state(:selected_column, updated_column)
    |> put_state(:column_settings_is_saving, false)
    |> put_state(:show_column_settings, false)
  end

  def action(:column_settings_save_failed, %{error: error}, component) do
    component
    |> put_state(:column_settings_is_saving, false)
    |> put_state(:column_settings_error, error)
  end

  def action(:show_delete_column_tasks_confirm, _params, component) do
    put_state(component, :column_settings_show_delete_confirm, true)
  end

  def action(:cancel_delete_column_tasks, _params, component) do
    put_state(component, :column_settings_show_delete_confirm, false)
  end

  def action(:confirm_delete_column_tasks, _params, component) do
    column = component.state.selected_column

    component
    |> put_state(:column_settings_is_deleting, true)
    |> put_command(:delete_column_tasks, %{column_id: column[:id]})
  end

  def action(:column_tasks_deleted, %{column_id: column_id}, component) do
    existing_key = find_matching_column_key(component.state.tasks_by_column, column_id)
    key_to_use = existing_key || column_id
    tasks_by_column = Map.put(component.state.tasks_by_column, key_to_use, [])

    component
    |> put_state(:tasks_by_column, tasks_by_column)
    |> put_state(:column_settings_is_deleting, false)
    |> put_state(:column_settings_show_delete_confirm, false)
    |> put_state(:show_column_settings, false)
  end

  def action(:column_tasks_delete_failed, %{error: error}, component) do
    component
    |> put_state(:column_settings_is_deleting, false)
    |> put_state(:column_settings_error, error)
  end

  def action(:toggle_column_hooks_enabled, _params, component) do
    new_value = not component.state.column_hooks_enabled
    column = component.state.selected_column

    component
    |> put_state(:column_hooks_enabled, new_value)
    |> put_command(:update_column_hooks_enabled, %{column_id: column[:id], enabled: new_value})
  end

  def action(:column_hooks_loaded, %{column_hooks: column_hooks, available_hooks: available_hooks}, component) do
    component
    |> put_state(:column_hooks, column_hooks)
    |> put_state(:column_available_hooks, available_hooks)
    |> put_state(:is_loading_column_hooks, false)
  end

  def action(:toggle_hook_picker, _params, component) do
    put_state(component, :show_column_hook_picker, not component.state.show_column_hook_picker)
  end

  def action(:add_column_hook, %{hook_id: hook_id}, component) do
    column = component.state.selected_column

    component
    |> put_state(:is_adding_column_hook, true)
    |> put_command(:add_column_hook, %{
      column_id: column[:id],
      hook_id: hook_id,
      position: length(component.state.column_hooks)
    })
  end

  def action(:column_hook_added, %{column_hook: column_hook}, component) do
    component
    |> put_state(:column_hooks, component.state.column_hooks ++ [column_hook])
    |> put_state(:is_adding_column_hook, false)
    |> put_state(:show_column_hook_picker, false)
  end

  def action(:column_hook_add_failed, %{error: _error}, component) do
    put_state(component, :is_adding_column_hook, false)
  end

  def action(:remove_column_hook, %{column_hook_id: column_hook_id}, component) do
    put_command(component, :remove_column_hook, %{column_hook_id: column_hook_id})
  end

  def action(:column_hook_removed, %{column_hook_id: column_hook_id}, component) do
    column_hooks = Enum.reject(component.state.column_hooks, &(&1["id"] == column_hook_id))
    put_state(component, :column_hooks, column_hooks)
  end

  def action(:toggle_hook_execute_once, %{column_hook_id: column_hook_id}, component) do
    column_hook = Enum.find(component.state.column_hooks, &(&1["id"] == column_hook_id))
    new_value = not (column_hook["execute_once"] || false)

    put_command(component, :update_column_hook, %{column_hook_id: column_hook_id, execute_once: new_value})
  end

  def action(:toggle_hook_transparent, %{column_hook_id: column_hook_id}, component) do
    column_hook = Enum.find(component.state.column_hooks, &(&1["id"] == column_hook_id))
    new_value = not (column_hook["transparent"] || false)

    put_command(component, :update_column_hook, %{column_hook_id: column_hook_id, transparent: new_value})
  end

  def action(:update_hook_sound, params, component) do
    column_hook_id = params[:column_hook_id]
    sound = get_in(params, [:event, :value]) || "ding"

    column_hook = Enum.find(component.state.column_hooks, &(&1["id"] == column_hook_id))
    current_settings = column_hook["hook_settings"] || %{}
    new_settings = Map.put(current_settings, "sound", sound)

    put_command(component, :update_column_hook, %{column_hook_id: column_hook_id, hook_settings: new_settings})
  end

  def action(:update_hook_target_column, params, component) do
    column_hook_id = params[:column_hook_id]
    target_column = get_in(params, [:event, :value]) || "next"

    column_hook = Enum.find(component.state.column_hooks, &(&1["id"] == column_hook_id))
    current_settings = column_hook["hook_settings"] || %{}
    new_settings = Map.put(current_settings, "target_column", target_column)

    put_command(component, :update_column_hook, %{column_hook_id: column_hook_id, hook_settings: new_settings})
  end

  def action(:column_hook_updated, %{column_hook: updated_hook}, component) do
    column_hooks =
      Enum.map(component.state.column_hooks, fn hook ->
        if hook["id"] == updated_hook["id"], do: updated_hook, else: hook
      end)

    put_state(component, :column_hooks, column_hooks)
  end

  def action(:toggle_concurrency_enabled, _params, component) do
    new_value = not component.state.column_concurrency_enabled
    column = component.state.selected_column

    component
    |> put_state(:column_concurrency_enabled, new_value)
    |> put_command(:update_column_concurrency, %{
      column_id: column[:id],
      enabled: new_value,
      limit: if(new_value, do: component.state.column_concurrency_limit)
    })
  end

  def action(:update_concurrency_limit, %{"value" => value}, component) do
    limit = String.to_integer(value)
    put_state(component, :column_concurrency_limit, max(1, min(100, limit)))
  end

  def action(:save_concurrency_settings, _params, component) do
    column = component.state.selected_column

    component
    |> put_state(:column_concurrency_is_saving, true)
    |> put_command(:update_column_concurrency, %{
      column_id: column[:id],
      enabled: component.state.column_concurrency_enabled,
      limit: component.state.column_concurrency_limit
    })
  end

  def action(:column_concurrency_updated, _params, component) do
    put_state(component, :column_concurrency_is_saving, false)
  end

  # ============================================================================
  # Task Change Handlers (for real-time sync via Phoenix Channels)
  # ============================================================================

  defp handle_task_changed(component, task_data, action_name) do
    task_id = task_data["id"]
    column_id = task_data["column_id"]
    tasks_by_column = component.state.tasks_by_column

    IO.inspect("=== TASK CHANGED: #{action_name} ===")
    IO.inspect("Task ID: #{task_id}, Target Column: #{column_id}")
    IO.inspect("BEFORE - Tasks by column:")
    debug_print_tasks_by_column(tasks_by_column)

    component =
      case action_name do
        "destroy" ->
          updated_tasks = remove_task_from_map(tasks_by_column, task_id)
          IO.inspect("AFTER DESTROY:")
          debug_print_tasks_by_column(updated_tasks)
          put_state(component, :tasks_by_column, updated_tasks)

        "move" ->
          updated_tasks = move_task_in_map(tasks_by_column, task_id, column_id, task_data)
          IO.inspect("AFTER MOVE:")
          debug_print_tasks_by_column(updated_tasks)

          component
          |> put_state(:tasks_by_column, updated_tasks)
          |> maybe_update_selected_task(task_id, task_data)

        _ ->
          updated_tasks = update_task_in_map(tasks_by_column, task_id, task_data)
          IO.inspect("AFTER UPDATE:")
          debug_print_tasks_by_column(updated_tasks)

          component
          |> put_state(:tasks_by_column, updated_tasks)
          |> maybe_update_selected_task(task_id, task_data)
      end

    put_state(component, :tasks_version, component.state.tasks_version + 1)
  end

  defp debug_print_tasks_by_column(tasks_by_column) do
    Enum.each(tasks_by_column, fn {col_id, tasks} ->
      task_titles = Enum.map(tasks, fn t -> t.title || t[:title] || "?" end)
      IO.inspect("  Column #{col_id}: #{length(tasks)} tasks - #{inspect(task_titles)}")
    end)
  end

  defp move_task_in_map(tasks_by_column, task_id, new_column_id, task_data) do
    tasks_by_column
    |> remove_task_from_map(task_id)
    |> add_task_to_column(new_column_id, task_data)
  end

  defp add_task_to_column(tasks_by_column, column_id, task_data) do
    existing_key = find_matching_column_key(tasks_by_column, column_id)
    key_to_use = existing_key || column_id
    current_tasks = Map.get(tasks_by_column, key_to_use, [])
    new_task = map_to_task_struct(task_data)
    sorted_tasks = Enum.sort_by([new_task | current_tasks], & &1.position)
    Map.put(tasks_by_column, key_to_use, sorted_tasks)
  end

  defp find_matching_column_key(tasks_by_column, column_id) do
    column_id_str = to_string(column_id)

    Enum.find(Map.keys(tasks_by_column), fn key ->
      to_string(key) == column_id_str
    end)
  end

  defp update_task_in_map(tasks_by_column, task_id, task_data) do
    task_id_str = to_string(task_id)

    Enum.reduce(tasks_by_column, %{}, fn {column_id, tasks}, acc ->
      updated_tasks =
        Enum.map(tasks, fn task ->
          if to_string(task.id) == task_id_str, do: map_to_task_struct(task_data), else: task
        end)

      Map.put(acc, column_id, updated_tasks)
    end)
  end

  defp maybe_update_selected_task(component, task_id, task_data) do
    selected_id_str = to_string(component.state.selected_task_id)
    task_id_str = to_string(task_id)

    if selected_id_str == task_id_str do
      put_state(component, :selected_task, map_to_task_struct(task_data))
    else
      component
    end
  end

  defp map_to_task_struct(task_data) when is_map(task_data) do
    %{
      id: task_data["id"],
      title: task_data["title"],
      description: task_data["description"],
      column_id: task_data["column_id"],
      position: task_data["position"],
      parent_task_id: task_data["parent_task_id"],
      worktree_path: task_data["worktree_path"],
      worktree_branch: task_data["worktree_branch"],
      agent_status: task_data["agent_status"],
      pr_url: task_data["pr_url"],
      pr_status: task_data["pr_status"],
      inserted_at: task_data["inserted_at"],
      updated_at: task_data["updated_at"]
    }
  end

  # ============================================================================
  # Commands
  # ============================================================================

  def command(:create_task, %{title: title, description: description, column_id: column_id}, server) do
    attrs = %{
      title: title,
      description: if(description == "", do: nil, else: description),
      column_id: column_id
    }

    case Viban.Kanban.Task.create(attrs) do
      {:ok, task} ->
        put_action(server, :task_created, %{task: serialize_task(task)})

      {:error, error} ->
        error_msg = format_error(error)
        put_action(server, :task_creation_failed, %{error: error_msg})
    end
  end

  def command(:update_task_title, %{task_id: task_id, title: title}, server) do
    case Viban.Kanban.Task.get(task_id) do
      {:ok, task} ->
        case Viban.Kanban.Task.update(task, %{title: title}) do
          {:ok, updated_task} ->
            put_action(server, :task_updated, %{task: serialize_task(updated_task)})

          {:error, error} ->
            put_action(server, :task_update_failed, %{error: format_error(error)})
        end

      {:error, error} ->
        put_action(server, :task_update_failed, %{error: format_error(error)})
    end
  end

  def command(:update_task_description, %{task_id: task_id, description: description}, server) do
    case Viban.Kanban.Task.get(task_id) do
      {:ok, task} ->
        desc = if description == "", do: nil, else: description

        case Viban.Kanban.Task.update(task, %{description: desc}) do
          {:ok, updated_task} ->
            put_action(server, :task_updated, %{task: serialize_task(updated_task)})

          {:error, error} ->
            put_action(server, :task_update_failed, %{error: format_error(error)})
        end

      {:error, error} ->
        put_action(server, :task_update_failed, %{error: format_error(error)})
    end
  end

  def command(:delete_task, %{task_id: task_id}, server) do
    case Viban.Kanban.Task.get(task_id) do
      {:ok, task} ->
        case Viban.Kanban.Task.destroy(task) do
          :ok ->
            put_action(server, :task_deleted, %{task_id: task_id})

          {:error, error} ->
            put_action(server, :task_delete_failed, %{error: format_error(error)})
        end

      {:error, error} ->
        put_action(server, :task_delete_failed, %{error: format_error(error)})
    end
  end

  def command(:load_subtasks, %{task_id: task_id}, server) do
    subtasks =
      task_id
      |> Viban.Kanban.Task.subtasks!()
      |> Enum.map(&serialize_task/1)

    put_action(server, :subtasks_loaded, %{subtasks: subtasks})
  rescue
    _ -> put_action(server, :subtasks_loaded, %{subtasks: []})
  end

  def command(:generate_subtasks, %{task_id: task_id}, server) do
    case Viban.Kanban.Task.generate_subtasks(task_id) do
      {:ok, _result} ->
        {:ok, refreshed_task} = Viban.Kanban.Task.get(task_id)

        subtasks =
          task_id
          |> Viban.Kanban.Task.subtasks!()
          |> Enum.map(&serialize_task/1)

        put_action(server, :subtasks_generated, %{
          subtasks: subtasks,
          task: serialize_task(refreshed_task)
        })

      {:error, error} ->
        task =
          case Viban.Kanban.Task.get(task_id) do
            {:ok, t} -> serialize_task(t)
            _ -> nil
          end

        put_action(server, :subtask_generation_failed, %{
          error: format_error(error),
          task: task
        })
    end
  end

  def command(:load_branches, %{task_id: task_id}, server) do
    branches =
      try do
        task_id
        |> Repository.list_branches!()
        |> Enum.map(fn branch ->
          %{
            name: branch.name,
            is_default: branch.is_default
          }
        end)
      rescue
        _ -> []
      end

    put_action(server, :branches_loaded, %{branches: branches})
  end

  def command(:create_pr, %{task_id: task_id, title: title, body: body, base_branch: base_branch}, server) do
    case Viban.Kanban.Task.create_pr(task_id, title, body, base_branch) do
      {:ok, result} ->
        {:ok, refreshed_task} = Viban.Kanban.Task.get(task_id)

        put_action(server, :pr_created, %{
          pr_url: result.pr_url,
          pr_number: result.pr_number,
          task: serialize_task(refreshed_task)
        })

      {:error, error} ->
        put_action(server, :pr_creation_failed, %{error: format_error(error)})
    end
  end

  def command(:load_settings_data, %{board_id: board_id}, server) do
    repository = load_repository(board_id)
    hooks = load_hooks(board_id)
    task_templates = load_task_templates(board_id)
    periodical_tasks = load_periodical_tasks(board_id)
    system_tools = load_system_tools()

    put_action(server, :settings_data_loaded, %{
      repository: repository,
      hooks: hooks,
      task_templates: task_templates,
      periodical_tasks: periodical_tasks,
      system_tools: system_tools
    })
  end

  def command(:save_repository, params, server) do
    %{board_id: board_id, name: name, path: path, default_branch: default_branch} = params

    result =
      if params.repository_id do
        case Repository.get(params.repository_id) do
          {:ok, repo} ->
            Repository.update(repo, %{
              name: name,
              local_path: path,
              default_branch: default_branch
            })

          error ->
            error
        end
      else
        Repository.create(%{
          name: name,
          local_path: path,
          default_branch: default_branch,
          board_id: board_id,
          provider: :local
        })
      end

    case result do
      {:ok, repo} ->
        put_action(server, :repository_saved, %{repository: serialize_repository(repo)})

      {:error, error} ->
        put_action(server, :repository_save_failed, %{error: format_error(error)})
    end
  end

  def command(:save_template, params, server) do
    %{board_id: board_id, name: name, description_template: description_template} = params

    result =
      if params.template_id do
        case TaskTemplate.get(params.template_id) do
          {:ok, template} ->
            TaskTemplate.update(template, %{
              name: name,
              description_template: if(description_template == "", do: nil, else: description_template)
            })

          error ->
            error
        end
      else
        max_position =
          board_id
          |> TaskTemplate.for_board!()
          |> Enum.map(& &1.position)
          |> Enum.max(fn -> -1 end)

        TaskTemplate.create(%{
          name: name,
          description_template: if(description_template == "", do: nil, else: description_template),
          position: max_position + 1,
          board_id: board_id
        })
      end

    case result do
      {:ok, _template} ->
        templates = load_task_templates(board_id)
        put_action(server, :template_saved, %{templates: templates})

      {:error, error} ->
        put_action(server, :template_save_failed, %{error: format_error(error)})
    end
  end

  def command(:delete_template, %{template_id: template_id}, server) do
    case TaskTemplate.get(template_id) do
      {:ok, template} ->
        board_id = template.board_id

        case TaskTemplate.destroy(template) do
          :ok ->
            templates = load_task_templates(board_id)
            put_action(server, :template_deleted, %{templates: templates})

          {:error, error} ->
            put_action(server, :template_save_failed, %{error: format_error(error)})
        end

      {:error, error} ->
        put_action(server, :template_save_failed, %{error: format_error(error)})
    end
  end

  def command(:save_hook, params, server) do
    %{board_id: board_id, name: name, hook_kind: hook_kind} = params

    result =
      if params.hook_id do
        case Hook.get(params.hook_id) do
          {:ok, hook} ->
            update_attrs = %{name: name}

            update_attrs =
              if hook_kind == "script" do
                Map.put(update_attrs, :command, params.command)
              else
                update_attrs
                |> Map.put(:agent_prompt, params.agent_prompt)
                |> Map.put(:agent_executor, String.to_existing_atom(params.agent_executor))
                |> Map.put(:agent_auto_approve, params.agent_auto_approve)
              end

            Hook.update(hook, update_attrs)

          error ->
            error
        end
      else
        if hook_kind == "script" do
          Hook.create_script_hook(%{
            name: name,
            command: params.command,
            board_id: board_id
          })
        else
          Hook.create_agent_hook(%{
            name: name,
            agent_prompt: params.agent_prompt,
            agent_executor: String.to_existing_atom(params.agent_executor),
            agent_auto_approve: params.agent_auto_approve,
            board_id: board_id
          })
        end
      end

    case result do
      {:ok, _hook} ->
        hooks = load_hooks(board_id)
        put_action(server, :hook_saved, %{hooks: hooks})

      {:error, error} ->
        put_action(server, :hook_save_failed, %{error: format_error(error)})
    end
  end

  def command(:delete_hook, %{hook_id: hook_id}, server) do
    case Hook.get(hook_id) do
      {:ok, hook} ->
        board_id = hook.board_id

        case Hook.destroy(hook) do
          :ok ->
            hooks = load_hooks(board_id)
            put_action(server, :hook_deleted, %{hooks: hooks})

          {:error, error} ->
            put_action(server, :hook_save_failed, %{error: format_error(error)})
        end

      {:error, error} ->
        put_action(server, :hook_save_failed, %{error: format_error(error)})
    end
  end

  def command(:save_periodical_task, params, server) do
    %{board_id: board_id, title: title, description: description, schedule: schedule, executor: executor} = params

    executor_atom = String.to_existing_atom(executor)

    result =
      if params.task_id do
        case PeriodicalTask.get(params.task_id) do
          {:ok, task} ->
            PeriodicalTask.update(task, %{
              title: title,
              description: if(description == "", do: nil, else: description),
              schedule: schedule,
              executor: executor_atom
            })

          error ->
            error
        end
      else
        PeriodicalTask.create(%{
          title: title,
          description: if(description == "", do: nil, else: description),
          schedule: schedule,
          executor: executor_atom,
          board_id: board_id
        })
      end

    case result do
      {:ok, _task} ->
        tasks = load_periodical_tasks(board_id)
        put_action(server, :periodical_task_saved, %{periodical_tasks: tasks})

      {:error, error} ->
        put_action(server, :periodical_task_save_failed, %{error: format_error(error)})
    end
  end

  def command(:toggle_periodical_task, %{task_id: task_id, enabled: enabled}, server) do
    case PeriodicalTask.get(task_id) do
      {:ok, task} ->
        case PeriodicalTask.update(task, %{enabled: enabled}) do
          {:ok, _updated} ->
            tasks = load_periodical_tasks(task.board_id)
            put_action(server, :periodical_task_toggled, %{periodical_tasks: tasks})

          {:error, error} ->
            put_action(server, :periodical_task_save_failed, %{error: format_error(error)})
        end

      {:error, error} ->
        put_action(server, :periodical_task_save_failed, %{error: format_error(error)})
    end
  end

  def command(:delete_periodical_task, %{task_id: task_id}, server) do
    case PeriodicalTask.get(task_id) do
      {:ok, task} ->
        board_id = task.board_id

        case PeriodicalTask.destroy(task) do
          :ok ->
            tasks = load_periodical_tasks(board_id)
            put_action(server, :periodical_task_deleted, %{periodical_tasks: tasks})

          {:error, error} ->
            put_action(server, :periodical_task_save_failed, %{error: format_error(error)})
        end

      {:error, error} ->
        put_action(server, :periodical_task_save_failed, %{error: format_error(error)})
    end
  end

  def command(:validate_cron, %{schedule: schedule}, server) do
    error = validate_cron_expression(schedule)
    put_action(server, :cron_validated, %{error: error})
  end

  # Column Settings Commands
  def command(:load_column_hooks, %{column_id: column_id, board_id: board_id}, server) do
    column_hooks = load_column_hooks(column_id)
    available_hooks = load_hooks(board_id)

    put_action(server, :column_hooks_loaded, %{
      column_hooks: column_hooks,
      available_hooks: available_hooks
    })
  end

  def command(:save_column_settings, %{column_id: column_id, name: name, color: color, description: description}, server) do
    case Viban.Kanban.Column.get(column_id) do
      {:ok, column} ->
        current_settings = column.settings || %{}
        new_settings = Map.put(current_settings, "description", description)

        update_attrs = %{
          color: color,
          settings: new_settings
        }

        update_attrs =
          if name != column.name && column.name not in ["TODO", "In Progress", "To Review", "Done", "Cancelled"] do
            Map.put(update_attrs, :name, name)
          else
            update_attrs
          end

        case Viban.Kanban.Column.update(column, update_attrs) do
          {:ok, updated_column} ->
            put_action(server, :column_settings_saved, %{column: serialize_column(updated_column)})

          {:error, error} ->
            put_action(server, :column_settings_save_failed, %{error: format_error(error)})
        end

      {:error, error} ->
        put_action(server, :column_settings_save_failed, %{error: format_error(error)})
    end
  end

  def command(:delete_column_tasks, %{column_id: column_id}, server) do
    case Viban.Kanban.Column.delete_all_tasks(column_id) do
      {:ok, _} ->
        put_action(server, :column_tasks_deleted, %{column_id: column_id})

      {:error, error} ->
        put_action(server, :column_tasks_delete_failed, %{error: format_error(error)})
    end
  rescue
    error ->
      put_action(server, :column_tasks_delete_failed, %{error: Exception.message(error)})
  end

  def command(:update_column_hooks_enabled, %{column_id: column_id, enabled: enabled}, server) do
    alias Viban.Kanban.Column

    require Logger

    Logger.info("[BoardPage] Updating hooks_enabled for column #{column_id} to #{enabled}")

    case Column.get(column_id) do
      {:ok, column} ->
        current_settings = column.settings || %{}
        new_settings = Map.put(current_settings, "hooks_enabled", enabled)

        Logger.info("[BoardPage] Current settings: #{inspect(current_settings)}")
        Logger.info("[BoardPage] New settings: #{inspect(new_settings)}")

        case Column.update(column, %{settings: new_settings}) do
          {:ok, updated_column} ->
            Logger.info("[BoardPage] Successfully updated column settings: #{inspect(updated_column.settings)}")
            server

          {:error, error} ->
            Logger.error("[BoardPage] Failed to update column settings: #{inspect(error)}")
            server
        end

      {:error, error} ->
        Logger.error("[BoardPage] Failed to get column: #{inspect(error)}")
        server
    end
  end

  def command(:add_column_hook, %{column_id: column_id, hook_id: hook_id, position: position}, server) do
    attrs = %{
      column_id: column_id,
      hook_id: hook_id,
      position: position
    }

    case ColumnHook.create(attrs) do
      {:ok, column_hook} ->
        put_action(server, :column_hook_added, %{column_hook: serialize_column_hook(column_hook)})

      {:error, error} ->
        put_action(server, :column_hook_add_failed, %{error: format_error(error)})
    end
  end

  def command(:remove_column_hook, %{column_hook_id: column_hook_id}, server) do
    case ColumnHook.get(column_hook_id) do
      {:ok, column_hook} ->
        case ColumnHook.destroy(column_hook) do
          :ok ->
            put_action(server, :column_hook_removed, %{column_hook_id: column_hook_id})

          {:error, _} ->
            server
        end

      {:error, _} ->
        server
    end
  end

  def command(:update_column_hook, params, server) do
    column_hook_id = params[:column_hook_id]

    case ColumnHook.get(column_hook_id) do
      {:ok, column_hook} ->
        update_attrs =
          params
          |> Map.delete(:column_hook_id)
          |> Map.new()

        case ColumnHook.update(column_hook, update_attrs) do
          {:ok, updated_hook} ->
            put_action(server, :column_hook_updated, %{column_hook: serialize_column_hook(updated_hook)})

          {:error, _} ->
            server
        end

      {:error, _} ->
        server
    end
  end

  def command(:update_column_concurrency, %{column_id: column_id, enabled: enabled, limit: limit}, server) do
    case Viban.Kanban.Column.get(column_id) do
      {:ok, column} ->
        current_settings = column.settings || %{}

        new_settings =
          if enabled do
            Map.put(current_settings, "max_concurrent_tasks", limit)
          else
            Map.delete(current_settings, "max_concurrent_tasks")
          end

        case Viban.Kanban.Column.update(column, %{settings: new_settings}) do
          {:ok, _} ->
            put_action(server, :column_concurrency_updated, %{})

          {:error, _} ->
            server
        end

      {:error, _} ->
        server
    end
  end

  defp load_column_hooks(column_id) do
    column_id
    |> ColumnHook.for_column!()
    |> Enum.sort_by(& &1.position)
    |> Enum.map(&serialize_column_hook/1)
  rescue
    _ -> []
  end

  defp serialize_column_hook(column_hook) do
    %{
      "id" => column_hook.id,
      "column_id" => column_hook.column_id,
      "hook_id" => column_hook.hook_id,
      "hook_type" => to_string(column_hook.hook_type),
      "position" => column_hook.position,
      "execute_once" => column_hook.execute_once || false,
      "transparent" => column_hook.transparent || false,
      "removable" => column_hook.removable,
      "hook_settings" => column_hook.hook_settings || %{}
    }
  end

  defp load_repository(board_id) do
    case Repository.for_board!(board_id) do
      [repo | _] -> serialize_repository(repo)
      [] -> nil
    end
  rescue
    _ -> nil
  end

  defp load_hooks(board_id) do
    board_id
    |> Viban.Kanban.Hook.HookService.list_all_hooks()
    |> Enum.map(&serialize_hook/1)
  rescue
    _ -> []
  end

  defp load_task_templates(board_id) do
    board_id
    |> TaskTemplate.for_board!()
    |> Enum.sort_by(& &1.position)
    |> Enum.map(&serialize_template/1)
  rescue
    _ -> []
  end

  defp load_periodical_tasks(board_id) do
    board_id
    |> PeriodicalTask.for_board!()
    |> Enum.map(&serialize_periodical_task/1)
  rescue
    _ -> []
  end

  defp load_system_tools do
    Enum.map(Viban.AppRuntime.SystemTools.list_tools!(), &serialize_system_tool/1)
  rescue
    _ -> []
  end

  defp serialize_repository(repo) do
    %{
      id: repo.id,
      name: repo.name,
      full_name: repo.full_name,
      local_path: repo.local_path,
      default_branch: repo.default_branch,
      provider: repo.provider
    }
  end

  defp serialize_hook(hook) when is_map(hook) do
    %{
      "id" => hook[:id] || hook.id,
      "name" => hook[:name] || hook.name,
      "hook_kind" => to_string(hook[:hook_kind] || hook.hook_kind || "script"),
      "command" => hook[:command] || Map.get(hook, :command),
      "agent_prompt" => hook[:agent_prompt] || Map.get(hook, :agent_prompt),
      "agent_executor" => to_string(hook[:agent_executor] || Map.get(hook, :agent_executor) || "claude_code"),
      "agent_auto_approve" => hook[:agent_auto_approve] || Map.get(hook, :agent_auto_approve) || false,
      "is_system" => hook[:is_system] || Map.get(hook, :is_system, false)
    }
  end

  defp serialize_template(template) do
    %{
      id: template.id,
      name: template.name,
      description_template: template.description_template,
      position: template.position
    }
  end

  defp serialize_periodical_task(task) do
    %{
      id: task.id,
      title: task.title,
      description: task.description,
      schedule: task.schedule,
      executor: task.executor,
      execution_count: task.execution_count,
      last_executed_at: task.last_executed_at,
      next_execution_at: task.next_execution_at,
      enabled: task.enabled
    }
  end

  defp serialize_system_tool(tool) do
    %{
      name: tool.name,
      display_name: tool.display_name,
      description: tool.description,
      version: tool.version,
      available: tool.available,
      feature: tool.feature,
      category: to_string(tool.category)
    }
  end

  defp load_board_data(board_id) do
    case Viban.Kanban.Board.get(board_id) do
      {:ok, board} ->
        columns = Viban.Kanban.Column.for_board!(board_id)

        tasks_by_column =
          Enum.reduce(columns, %{}, fn column, acc ->
            tasks = Viban.Kanban.Task.for_column!(column.id)
            Map.put(acc, column.id, tasks)
          end)

        {:ok, board, columns, tasks_by_column}

      {:error, _} ->
        {:error, "Board not found"}

      nil ->
        {:error, "Board not found"}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp serialize_board(board) do
    %{
      id: board.id,
      name: board.name,
      description: board.description
    }
  end

  defp all_tasks(tasks_by_column) do
    tasks_by_column
    |> Map.keys()
    |> Enum.flat_map(fn key -> Map.get(tasks_by_column, key, []) end)
  end

  defp serialize_column(column) do
    %{
      id: column.id,
      name: column.name,
      position: column.position,
      color: column.color,
      settings: column.settings
    }
  end

  defp serialize_tasks_by_column(tasks_by_column) do
    Enum.reduce(tasks_by_column, %{}, fn {column_id, tasks}, acc ->
      Map.put(acc, column_id, Enum.map(tasks, &serialize_task/1))
    end)
  end

  defp serialize_task(task) do
    %{
      id: task.id,
      title: task.title,
      description: task.description,
      position: task.position,
      priority: task.priority,
      agent_status: task.agent_status,
      agent_status_message: task.agent_status_message,
      in_progress: task.in_progress,
      queued_at: task.queued_at,
      pr_url: task.pr_url,
      pr_number: task.pr_number,
      pr_status: task.pr_status,
      error_message: task.error_message,
      parent_task_id: task.parent_task_id,
      is_parent: task.is_parent,
      worktree_branch: task.worktree_branch,
      subtask_generation_status: task.subtask_generation_status
    }
  end

  defp format_error(%Ash.Error.Invalid{} = error) do
    error
    |> Ash.Error.to_error_class()
    |> Exception.message()
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)

  defp validate_cron_expression(""), do: "Schedule is required"

  defp validate_cron_expression(schedule) when is_binary(schedule) do
    parts = String.split(schedule, ~r/\s+/)

    cond do
      length(parts) < 5 ->
        "Cron needs 5 fields: minute hour day month weekday"

      length(parts) > 5 ->
        "Too many fields (expected 5: minute hour day month weekday)"

      true ->
        case Crontab.CronExpression.Parser.parse(schedule) do
          {:ok, _} -> nil
          {:error, _} -> format_cron_error(parts)
        end
    end
  end

  defp validate_cron_expression(_), do: "Invalid schedule format"

  defp format_cron_error(parts) do
    [minute, hour, day, month, weekday] = Enum.take(parts, 5)

    errors =
      Enum.reject(
        [
          validate_cron_field(minute, 0, 59, "minute"),
          validate_cron_field(hour, 0, 23, "hour"),
          validate_cron_field(day, 1, 31, "day"),
          validate_cron_field(month, 1, 12, "month"),
          validate_cron_field(weekday, 0, 6, "weekday")
        ],
        &is_nil/1
      )

    case errors do
      [] -> "Invalid cron expression"
      [error] -> error
      _ -> Enum.join(errors, "; ")
    end
  end

  defp validate_cron_field("*", _min, _max, _name), do: nil

  defp validate_cron_field(value, min, max, name) do
    cond do
      String.match?(value, ~r/^\d+$/) ->
        num = String.to_integer(value)
        if num < min or num > max, do: "#{name} must be #{min}-#{max}"

      String.match?(value, ~r/^\*\/\d+$/) ->
        nil

      String.match?(value, ~r/^\d+-\d+$/) ->
        nil

      String.match?(value, ~r/^[\d,]+$/) ->
        nil

      true ->
        "Invalid #{name} value '#{value}'"
    end
  end

  defp find_task(tasks_by_column, task_id) do
    task_id_str = to_string(task_id)

    Enum.find_value(tasks_by_column, fn {_column_id, tasks} ->
      Enum.find(tasks, fn task -> to_string(task.id) == task_id_str end)
    end)
  end

  defp find_column_name_for_task(columns, tasks_by_column, task_id) do
    task_id_str = to_string(task_id)

    column_id =
      Enum.find_value(tasks_by_column, fn {col_id, tasks} ->
        if Enum.any?(tasks, fn task -> to_string(task.id) == task_id_str end), do: col_id
      end)

    if column_id do
      column_id_str = to_string(column_id)
      column = Enum.find(columns, fn col -> to_string(col.id) == column_id_str end)
      if column, do: column.name
    end
  end

  defp update_task_in_map(tasks_by_column, updated_task) do
    updated_task_id_str = to_string(updated_task.id)

    Enum.reduce(tasks_by_column, %{}, fn {column_id, tasks}, acc ->
      updated_tasks =
        Enum.map(tasks, fn task ->
          if to_string(task.id) == updated_task_id_str, do: updated_task, else: task
        end)

      Map.put(acc, column_id, updated_tasks)
    end)
  end

  defp remove_task_from_map(tasks_by_column, task_id) do
    task_id_str = to_string(task_id)

    Enum.reduce(tasks_by_column, %{}, fn {column_id, tasks}, acc ->
      filtered_tasks = Enum.reject(tasks, fn task -> to_string(task.id) == task_id_str end)
      Map.put(acc, column_id, filtered_tasks)
    end)
  end

  defp agent_status_badge_class(:thinking),
    do: "inline-flex items-center gap-1 text-xs text-blue-400 bg-blue-900/50 px-2 py-1 rounded"

  defp agent_status_badge_class(:executing),
    do: "inline-flex items-center gap-1 text-xs text-green-400 bg-green-900/50 px-2 py-1 rounded"

  defp agent_status_badge_class(:error),
    do: "inline-flex items-center gap-1 text-xs text-red-400 bg-red-900/50 px-2 py-1 rounded"

  defp agent_status_badge_class(_),
    do: "inline-flex items-center gap-1 text-xs text-gray-400 bg-gray-700 px-2 py-1 rounded"

  defp agent_status_label(:thinking), do: "Thinking"
  defp agent_status_label(:executing), do: "Executing"
  defp agent_status_label(:error), do: "Error"
  defp agent_status_label(status), do: to_string(status)

  defp pr_badge_class(:open),
    do: "inline-flex items-center gap-1 text-xs text-green-400 bg-green-900/50 px-2 py-1 rounded hover:bg-green-800/50"

  defp pr_badge_class(:merged),
    do: "inline-flex items-center gap-1 text-xs text-purple-400 bg-purple-900/50 px-2 py-1 rounded hover:bg-purple-800/50"

  defp pr_badge_class(:closed),
    do: "inline-flex items-center gap-1 text-xs text-red-400 bg-red-900/50 px-2 py-1 rounded hover:bg-red-800/50"

  defp pr_badge_class(:draft),
    do: "inline-flex items-center gap-1 text-xs text-gray-400 bg-gray-700 px-2 py-1 rounded hover:bg-gray-600"

  defp pr_badge_class(_),
    do: "inline-flex items-center gap-1 text-xs text-gray-400 bg-gray-700 px-2 py-1 rounded hover:bg-gray-600"

  defp send_button_class(message, task) do
    base = "inline-flex items-center gap-2 px-4 py-2 rounded-lg transition-colors"

    cond do
      task && (task[:agent_status] == :thinking || task.agent_status == :thinking) ->
        base <> " bg-blue-600 text-white cursor-wait"

      message == "" || message == nil ->
        base <> " bg-gray-700 text-gray-400 cursor-not-allowed"

      true ->
        base <> " bg-brand-600 hover:bg-brand-700 text-white cursor-pointer"
    end
  end
end
