defmodule VibanWeb.Live.BoardLive.TaskPanelComponent do
  @moduledoc """
  LiveComponent for the task details panel.
  Manages its own state for chat, activity feed, and panel UI.
  """

  use VibanWeb, :live_component

  alias Viban.Executors.Executor
  alias Viban.KanbanLite.ExecutorSession
  alias Viban.KanbanLite.HookExecution
  alias Viban.KanbanLite.Message
  alias Viban.KanbanLite.Task

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:activity_feed, [])
     |> assign(:executor_sessions, [])
     |> assign(:hook_executions, [])
     |> assign(:subtasks, [])
     |> assign(:executors, [])
     |> assign(:chat_input, "")
     |> assign(:selected_executor, "claude_code")
     |> assign(:panel_fullscreen, false)
     |> assign(:details_hidden, false)
     |> assign(:chat_images, [])
     |> assign(:is_sending, false)}
  end

  @impl true
  def update(%{task_message: message}, socket) do
    {:ok, handle_task_message(message, socket)}
  end

  def update(%{task: task, columns: columns, board: board, on_close: on_close}, socket) do
    socket = assign(socket, :task, task)
    socket = assign(socket, :columns, columns)
    socket = assign(socket, :board, board)
    socket = assign(socket, :on_close, on_close)

    socket =
      if task_changed?(socket, task) || socket.assigns[:activity_feed] == [] do
        load_task_data(socket, task.id)
      else
        socket
      end

    {:ok, socket}
  end

  defp task_changed?(socket, new_task) do
    case Map.get(socket.assigns, :task) do
      nil -> true
      old_task -> old_task.id != new_task.id
    end
  end

  defp load_task_data(socket, task_id) do
    messages = load_messages(task_id)
    executor_sessions = load_executor_sessions(task_id)
    hook_executions = load_hook_executions(task_id)
    subtasks = load_subtasks(task_id)
    executors = load_executors()
    task = socket.assigns.task
    activity_feed = build_activity_feed(messages, executor_sessions, hook_executions, task)

    socket
    |> assign(:activity_feed, activity_feed)
    |> assign(:executor_sessions, executor_sessions)
    |> assign(:hook_executions, hook_executions)
    |> assign(:subtasks, subtasks)
    |> assign(:executors, executors)
    |> assign(:chat_input, "")
    |> assign(:chat_images, [])
  end

  # ============================================================================
  # Render
  # ============================================================================

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :is_running, is_task_running(assigns.executor_sessions))
    assigns = assign(assigns, :agent_status, get_agent_status(assigns.task, assigns.executor_sessions))

    ~H"""
    <div
      id="task-details-panel"
      class={[
        "fixed inset-y-0 right-0 z-40 flex flex-col bg-gray-900 border-l border-gray-800 shadow-xl transition-all duration-300",
        @panel_fullscreen && "inset-0 border-l-0",
        !@panel_fullscreen && "w-[48rem]"
      ]}
      phx-hook="TaskPanelShortcuts"
      phx-target={@myself}
    >
      <.panel_header
        task={@task}
        agent_status={@agent_status}
        panel_fullscreen={@panel_fullscreen}
        details_hidden={@details_hidden}
        on_close={@on_close}
        myself={@myself}
      />

      <div class="flex-1 flex overflow-hidden">
        <.activity_section
          activity_feed={@activity_feed}
          executors={@executors}
          selected_executor={@selected_executor}
          chat_input={@chat_input}
          chat_images={@chat_images}
          is_sending={@is_sending}
          is_running={@is_running}
          myself={@myself}
        />

        <.details_sidebar
          :if={!@details_hidden}
          task={@task}
          columns={@columns}
          subtasks={@subtasks}
          hook_executions={@hook_executions}
          myself={@myself}
        />
      </div>
    </div>
    """
  end

  # ============================================================================
  # Panel Header
  # ============================================================================

  attr :task, :map, required: true
  attr :agent_status, :atom, required: true
  attr :panel_fullscreen, :boolean, required: true
  attr :details_hidden, :boolean, required: true
  attr :on_close, :any, required: true
  attr :myself, :any, required: true

  defp panel_header(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-4 border-b border-gray-800 flex-shrink-0">
      <div class="flex items-center gap-3 min-w-0 flex-1">
        <.agent_status_badge status={@agent_status} task={@task} />
        <h2 class="text-lg font-semibold text-white truncate">{@task.title}</h2>
      </div>
      <div class="flex items-center gap-1">
        <button
          phx-click="toggle_details"
          phx-target={@myself}
          class="p-2 text-gray-400 hover:text-white transition-colors"
          title={if @details_hidden, do: "Show details (Ctrl+H)", else: "Hide details (Ctrl+H)"}
        >
          <.icon name={if @details_hidden, do: "hero-eye", else: "hero-eye-slash"} class="h-4 w-4" />
        </button>
        <button
          phx-click="toggle_fullscreen"
          phx-target={@myself}
          class="p-2 text-gray-400 hover:text-white transition-colors"
          title={if @panel_fullscreen, do: "Exit fullscreen (f)", else: "Fullscreen (f)"}
        >
          <.icon
            name={
              if @panel_fullscreen, do: "hero-arrows-pointing-in", else: "hero-arrows-pointing-out"
            }
            class="h-4 w-4"
          />
        </button>
        <button
          phx-click={@on_close}
          class="p-2 text-gray-400 hover:text-white transition-colors"
          title="Close (Esc)"
        >
          <.icon name="hero-x-mark" class="h-5 w-5" />
        </button>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Activity Section (Feed + Chat Input)
  # ============================================================================

  attr :activity_feed, :list, required: true
  attr :executors, :list, required: true
  attr :selected_executor, :string, required: true
  attr :chat_input, :string, required: true
  attr :chat_images, :list, required: true
  attr :is_sending, :boolean, required: true
  attr :is_running, :boolean, required: true
  attr :myself, :any, required: true

  defp activity_section(assigns) do
    ~H"""
    <div class="flex-1 flex flex-col overflow-hidden">
      <div id="activity-feed" class="flex-1 overflow-y-auto p-4 space-y-3" phx-hook="ScrollToBottom">
        <.activity_item :for={item <- @activity_feed} item={item} />

        <div :if={@activity_feed == []} class="text-center text-gray-500 py-8">
          <.icon name="hero-chat-bubble-left-right" class="h-8 w-8 mx-auto mb-2 opacity-50" />
          <p>No activity yet</p>
          <p class="text-sm">Send a message to start working with AI</p>
        </div>
      </div>

      <.chat_input
        executors={@executors}
        selected_executor={@selected_executor}
        chat_input={@chat_input}
        chat_images={@chat_images}
        is_sending={@is_sending}
        is_running={@is_running}
        myself={@myself}
      />
    </div>
    """
  end

  # ============================================================================
  # Chat Input
  # ============================================================================

  attr :executors, :list, required: true
  attr :selected_executor, :string, required: true
  attr :chat_input, :string, required: true
  attr :chat_images, :list, required: true
  attr :is_sending, :boolean, required: true
  attr :is_running, :boolean, required: true
  attr :myself, :any, required: true

  defp chat_input(assigns) do
    ~H"""
    <div class="border-t border-gray-800 p-4 flex-shrink-0">
      <form phx-submit="send_chat_message" phx-target={@myself} class="space-y-3">
        <div class="flex gap-2">
          <select
            name="executor_type"
            class="rounded-lg border border-gray-700 bg-gray-800 text-white px-3 py-2 text-sm focus:border-brand-500 focus:ring-1 focus:ring-brand-500 focus:outline-none"
            phx-change="select_executor"
            phx-target={@myself}
          >
            <option
              :for={exec <- @executors}
              value={exec.type}
              selected={exec.type == @selected_executor}
            >
              {exec.name}
            </option>
            <option :if={@executors == []} value="claude_code">Claude Code</option>
          </select>
          <div class="flex-1 relative">
            <textarea
              id="chat-input"
              name="prompt"
              value={@chat_input}
              phx-keydown="chat_keydown"
              phx-target={@myself}
              phx-update="ignore"
              rows="2"
              placeholder="Send a message to the AI..."
              class="w-full rounded-lg border border-gray-700 bg-gray-800 text-white px-3 py-2 text-sm focus:border-brand-500 focus:ring-1 focus:ring-brand-500 focus:outline-none resize-none pr-20"
              disabled={@is_sending}
            />
            <div class="absolute right-2 bottom-2 flex items-center gap-1">
              <button
                type="button"
                phx-click="attach_image"
                phx-target={@myself}
                class="p-1.5 text-gray-400 hover:text-white transition-colors"
                title="Attach image"
                disabled={@is_sending}
              >
                <.icon name="hero-photo" class="h-4 w-4" />
              </button>
              <button
                type="submit"
                class="p-1.5 text-brand-400 hover:text-brand-300 transition-colors disabled:opacity-50"
                disabled={@is_sending}
              >
                <.icon name="hero-paper-airplane" class="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>

        <div :if={@chat_images != []} class="flex flex-wrap gap-2">
          <div :for={{img, idx} <- Enum.with_index(@chat_images)} class="relative">
            <img src={img.data} class="h-16 w-16 object-cover rounded border border-gray-700" />
            <button
              type="button"
              phx-click="remove_chat_image"
              phx-value-index={idx}
              phx-target={@myself}
              class="absolute -top-1 -right-1 p-0.5 bg-red-500 rounded-full text-white hover:bg-red-600"
            >
              <.icon name="hero-x-mark" class="h-3 w-3" />
            </button>
          </div>
        </div>

        <div :if={@is_running} class="flex items-center justify-between">
          <span class="text-sm text-gray-400">
            <.spinner class="h-4 w-4 inline mr-2" /> Running...
          </span>
          <button
            type="button"
            phx-click="stop_executor"
            phx-target={@myself}
            class="text-sm text-red-400 hover:text-red-300"
          >
            Stop
          </button>
        </div>
      </form>
    </div>
    """
  end

  # ============================================================================
  # Details Sidebar
  # ============================================================================

  attr :task, :map, required: true
  attr :columns, :list, required: true
  attr :subtasks, :list, required: true
  attr :hook_executions, :list, required: true
  attr :myself, :any, required: true

  defp details_sidebar(assigns) do
    ~H"""
    <div class="w-72 border-l border-gray-800 overflow-y-auto flex-shrink-0">
      <div class="p-4 space-y-6">
        <.field_title task={@task} myself={@myself} />
        <.field_column task={@task} columns={@columns} myself={@myself} />
        <.field_description task={@task} myself={@myself} />
        <.field_branch :if={@task.worktree_branch} task={@task} myself={@myself} />
        <.field_pull_request :if={@task.pr_url} task={@task} />
        <.field_subtasks
          :if={@task.is_parent || @subtasks != []}
          task={@task}
          subtasks={@subtasks}
          columns={@columns}
          myself={@myself}
        />
        <.field_error
          :if={@task.agent_status == :error && @task.error_message}
          task={@task}
          myself={@myself}
        />
        <.field_actions task={@task} myself={@myself} />
        <.field_hook_executions :if={@hook_executions != []} hook_executions={@hook_executions} />
      </div>
    </div>
    """
  end

  # ============================================================================
  # Sidebar Field Components
  # ============================================================================

  defp field_title(assigns) do
    ~H"""
    <div>
      <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">
        Title
      </label>
      <input
        type="text"
        value={@task.title}
        phx-blur="update_task_title"
        phx-target={@myself}
        class="w-full rounded-lg border border-gray-700 bg-gray-800 text-white px-3 py-2 text-sm focus:border-brand-500 focus:ring-1 focus:ring-brand-500 focus:outline-none"
      />
    </div>
    """
  end

  defp field_column(assigns) do
    ~H"""
    <div>
      <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">
        Column
      </label>
      <form phx-change="move_task_to_column" phx-target={@myself}>
        <select
          name="column_id"
          class="w-full rounded-lg border border-gray-700 bg-gray-800 text-white px-3 py-2 text-sm focus:border-brand-500 focus:ring-1 focus:ring-brand-500 focus:outline-none"
        >
          <option :for={column <- @columns} value={column.id} selected={column.id == @task.column_id}>
            {column.name}
          </option>
        </select>
      </form>
    </div>
    """
  end

  defp field_description(assigns) do
    ~H"""
    <div>
      <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">
        Description
      </label>
      <textarea
        phx-blur="update_task_description"
        phx-target={@myself}
        rows="4"
        class="w-full rounded-lg border border-gray-700 bg-gray-800 text-white px-3 py-2 text-sm focus:border-brand-500 focus:ring-1 focus:ring-brand-500 focus:outline-none resize-none"
        placeholder="Add a description..."
      >{@task.description}</textarea>
    </div>
    """
  end

  defp field_branch(assigns) do
    ~H"""
    <div>
      <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">
        Branch
      </label>
      <div class="flex items-center gap-2">
        <code class="text-sm text-brand-400 truncate flex-1">{@task.worktree_branch}</code>
        <button
          :if={@task.worktree_path}
          phx-click="open_in_editor"
          phx-target={@myself}
          class="p-1 text-gray-400 hover:text-white"
          title="Open in editor"
        >
          <.icon name="hero-code-bracket-square" class="h-4 w-4" />
        </button>
        <button
          :if={@task.worktree_path}
          phx-click="open_in_folder"
          phx-target={@myself}
          class="p-1 text-gray-400 hover:text-white"
          title="Open folder"
        >
          <.icon name="hero-folder-open" class="h-4 w-4" />
        </button>
      </div>
    </div>
    """
  end

  defp field_pull_request(assigns) do
    ~H"""
    <div>
      <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">
        Pull Request
      </label>
      <a
        href={@task.pr_url}
        target="_blank"
        rel="noopener noreferrer"
        class="flex items-center gap-2 text-sm text-brand-400 hover:text-brand-300"
      >
        <.pr_icon status={@task.pr_status} /> PR #{@task.pr_number}
        <.icon name="hero-arrow-top-right-on-square" class="h-3 w-3" />
      </a>
    </div>
    """
  end

  defp field_subtasks(assigns) do
    ~H"""
    <div>
      <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">
        Subtasks ({length(@subtasks)})
      </label>
      <div class="space-y-1">
        <div
          :for={subtask <- @subtasks}
          class="flex items-center gap-2 p-2 rounded bg-gray-800/50 text-sm"
        >
          <input
            type="checkbox"
            checked={subtask_completed?(@columns, subtask)}
            phx-click="toggle_subtask"
            phx-value-subtask_id={subtask.id}
            phx-target={@myself}
            class="rounded border-gray-600 bg-gray-800 text-brand-500 focus:ring-brand-500"
          />
          <span class={subtask_completed?(@columns, subtask) && "line-through text-gray-500"}>
            {subtask.title}
          </span>
        </div>
      </div>
      <button
        phx-click="generate_subtasks"
        phx-target={@myself}
        class="mt-2 text-xs text-brand-400 hover:text-brand-300"
        disabled={@task.subtask_generation_status == :generating}
      >
        <.spinner :if={@task.subtask_generation_status == :generating} class="h-3 w-3 inline mr-1" />
        {if @task.subtask_generation_status == :generating,
          do: "Generating...",
          else: "+ Generate subtasks with AI"}
      </button>
    </div>
    """
  end

  defp field_error(assigns) do
    ~H"""
    <div>
      <label class="block text-xs font-medium text-red-500 uppercase tracking-wide mb-2">Error</label>
      <div class="p-2 rounded bg-red-500/10 border border-red-500/30 text-sm text-red-300">
        {@task.error_message}
      </div>
      <button
        phx-click="clear_error"
        phx-target={@myself}
        class="mt-2 text-xs text-gray-400 hover:text-white"
      >
        Clear error
      </button>
    </div>
    """
  end

  defp field_actions(assigns) do
    ~H"""
    <div class="pt-4 border-t border-gray-800">
      <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">
        Actions
      </label>
      <div class="grid grid-cols-2 gap-2">
        <.button
          :if={!@task.worktree_path}
          variant="secondary"
          size="sm"
          phx-click="create_worktree"
          phx-target={@myself}
          class="justify-center"
        >
          <.icon name="hero-code-bracket" class="h-4 w-4" /> Branch
        </.button>
        <.button
          :if={@task.worktree_path && !@task.pr_url}
          variant="secondary"
          size="sm"
          phx-click="show_pr_modal"
          phx-target={@myself}
          class="justify-center"
        >
          <.icon name="hero-arrow-up-tray" class="h-4 w-4" /> Create PR
        </.button>
        <.button
          variant="secondary"
          size="sm"
          phx-click="duplicate_task"
          phx-target={@myself}
          class="justify-center"
        >
          <.icon name="hero-document-duplicate" class="h-4 w-4" /> Duplicate
        </.button>
        <.button
          variant="danger"
          size="sm"
          phx-click="delete_task"
          phx-target={@myself}
          class="justify-center"
        >
          <.icon name="hero-trash" class="h-4 w-4" /> Delete
        </.button>
      </div>
    </div>
    """
  end

  defp field_hook_executions(assigns) do
    ~H"""
    <div>
      <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">
        Recent Hooks ({length(@hook_executions)})
      </label>
      <div class="space-y-1 max-h-40 overflow-y-auto">
        <div
          :for={hook <- Enum.take(@hook_executions, 5)}
          class="flex items-center gap-2 p-2 rounded bg-gray-800/50 text-xs"
        >
          <.hook_status_icon status={hook.status} />
          <span class="truncate flex-1">{hook.hook_name}</span>
          <span class="text-gray-500">{format_relative_time(hook.queued_at)}</span>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Activity Item Components
  # ============================================================================

  defp activity_item(%{item: %{type: :message}} = assigns) do
    ~H"""
    <div class={[
      "rounded-lg p-3",
      @item.role == :user && "bg-gray-800 ml-8",
      @item.role == :assistant && "bg-brand-900/30 border border-brand-500/20 mr-8",
      @item.role == :system && "bg-gray-800/50 text-gray-400 text-sm"
    ]}>
      <div class="flex items-start gap-2">
        <div
          :if={@item.role == :user}
          class="w-6 h-6 rounded-full bg-gray-700 flex items-center justify-center flex-shrink-0"
        >
          <.icon name="hero-user" class="h-3 w-3 text-gray-400" />
        </div>
        <div
          :if={@item.role == :assistant}
          class="w-6 h-6 rounded-full bg-brand-500/20 flex items-center justify-center flex-shrink-0"
        >
          <.icon name="hero-cpu-chip" class="h-3 w-3 text-brand-400" />
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-sm text-white whitespace-pre-wrap break-words">{@item.content}</div>
          <div class="text-xs text-gray-500 mt-1">{format_time(@item.timestamp)}</div>
        </div>
      </div>
    </div>
    """
  end

  defp activity_item(%{item: %{type: :session_start}} = assigns) do
    ~H"""
    <div class="flex items-center gap-2 text-xs text-gray-500 py-1">
      <div class="flex-1 border-t border-gray-800"></div>
      <span class="flex items-center gap-1">
        <.icon name="hero-play" class="h-3 w-3 text-green-400" />
        {@item.executor_type} started
      </span>
      <div class="flex-1 border-t border-gray-800"></div>
    </div>
    """
  end

  defp activity_item(%{item: %{type: :session_end}} = assigns) do
    ~H"""
    <div class="flex items-center gap-2 text-xs text-gray-500 py-1">
      <div class="flex-1 border-t border-gray-800"></div>
      <span class={[
        "flex items-center gap-1",
        @item.status == :completed && "text-green-400",
        @item.status == :failed && "text-red-400",
        @item.status == :stopped && "text-yellow-400"
      ]}>
        <.icon :if={@item.status == :completed} name="hero-check-circle" class="h-3 w-3" />
        <.icon :if={@item.status == :failed} name="hero-x-circle" class="h-3 w-3" />
        <.icon :if={@item.status == :stopped} name="hero-stop-circle" class="h-3 w-3" />
        {@item.executor_type} {Atom.to_string(@item.status)}
        <span :if={@item.exit_code}>(exit {@item.exit_code})</span>
      </span>
      <div class="flex-1 border-t border-gray-800"></div>
    </div>
    """
  end

  defp activity_item(%{item: %{type: :hook_execution}} = assigns) do
    ~H"""
    <div class="flex items-center gap-2 text-xs py-1 px-2 rounded bg-gray-800/50">
      <.hook_status_icon status={@item.status} />
      <span class="text-gray-400">Hook: {@item.hook_name}</span>
      <span :if={@item.status == :failed && @item.error_message} class="text-red-400 truncate flex-1">
        - {@item.error_message}
      </span>
    </div>
    """
  end

  defp activity_item(%{item: %{type: :task_created}} = assigns) do
    ~H"""
    <div class="flex items-center gap-2 text-xs text-gray-500 py-1">
      <div class="flex-1 border-t border-gray-800"></div>
      <span class="flex items-center gap-1">
        <.icon name="hero-plus-circle" class="h-3 w-3" /> Task created
      </span>
      <div class="flex-1 border-t border-gray-800"></div>
    </div>
    """
  end

  defp activity_item(assigns) do
    ~H"""
    <div class="text-xs text-gray-500">{inspect(@item)}</div>
    """
  end

  # ============================================================================
  # Helper Components
  # ============================================================================

  defp agent_status_badge(assigns) do
    ~H"""
    <div
      :if={@status != :idle}
      class={[
        "flex items-center gap-1.5 px-2 py-1 rounded-full text-xs font-medium",
        @status == :executing && "bg-brand-500/20 text-brand-400",
        @status == :thinking && "bg-blue-500/20 text-blue-400",
        @status == :error && "bg-red-500/20 text-red-400"
      ]}
    >
      <.spinner :if={@status == :executing} class="h-3 w-3" />
      <.icon :if={@status == :thinking} name="hero-chat-bubble-left-ellipsis" class="h-3 w-3" />
      <.icon :if={@status == :error} name="hero-exclamation-circle" class="h-3 w-3" />
      <span :if={@status == :executing}>{@task.agent_status_message || "Working..."}</span>
      <span :if={@status == :thinking}>Waiting for input</span>
      <span :if={@status == :error}>Error</span>
    </div>
    """
  end

  defp hook_status_icon(assigns) do
    ~H"""
    <span class={[
      "flex-shrink-0",
      @status == :completed && "text-green-400",
      @status == :failed && "text-red-400",
      @status == :running && "text-brand-400",
      @status == :pending && "text-yellow-400",
      @status in [:cancelled, :skipped] && "text-gray-500"
    ]}>
      <.spinner :if={@status == :running} class="h-3 w-3" />
      <.icon :if={@status == :completed} name="hero-check-circle-mini" class="h-3 w-3" />
      <.icon :if={@status == :failed} name="hero-x-circle-mini" class="h-3 w-3" />
      <.icon :if={@status == :pending} name="hero-clock-mini" class="h-3 w-3" />
      <.icon :if={@status in [:cancelled, :skipped]} name="hero-minus-circle-mini" class="h-3 w-3" />
    </span>
    """
  end

  defp pr_icon(assigns) do
    ~H"""
    <svg class="h-3 w-3" viewBox="0 0 16 16" fill="currentColor">
      <path d="M1.5 3.25a2.25 2.25 0 1 1 3 2.122v5.256a2.251 2.251 0 1 1-1.5 0V5.372A2.25 2.25 0 0 1 1.5 3.25Zm5.677-.177L9.573.677A.25.25 0 0 1 10 .854V2.5h1A2.5 2.5 0 0 1 13.5 5v5.628a2.251 2.251 0 1 1-1.5 0V5a1 1 0 0 0-1-1h-1v1.646a.25.25 0 0 1-.427.177L7.177 3.427a.25.25 0 0 1 0-.354Z" />
    </svg>
    """
  end

  # ============================================================================
  # Event Handlers
  # ============================================================================

  @impl true
  def handle_event("toggle_details", _params, socket) do
    {:noreply, assign(socket, :details_hidden, !socket.assigns.details_hidden)}
  end

  def handle_event("toggle_fullscreen", _params, socket) do
    {:noreply, assign(socket, :panel_fullscreen, !socket.assigns.panel_fullscreen)}
  end

  def handle_event("select_executor", %{"executor_type" => executor_type}, socket) do
    {:noreply, assign(socket, :selected_executor, executor_type)}
  end

  def handle_event("chat_keydown", %{"key" => "Enter", "shiftKey" => false}, socket) do
    {:noreply, push_event(socket, "submit_chat", %{})}
  end

  def handle_event("chat_keydown", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("attach_image", _params, socket) do
    {:noreply, put_flash(socket, :info, "Image upload coming soon")}
  end

  def handle_event("remove_chat_image", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    images = List.delete_at(socket.assigns.chat_images, index)
    {:noreply, assign(socket, :chat_images, images)}
  end

  def handle_event("send_chat_message", %{"prompt" => prompt} = params, socket) when prompt != "" do
    task = socket.assigns.task
    executor_type = params["executor_type"] || socket.assigns.selected_executor

    case Message.create(%{
           task_id: task.id,
           role: :user,
           content: prompt,
           metadata: %{images: socket.assigns.chat_images}
         }) do
      {:ok, message} ->
        activity_item = %{
          id: message.id,
          type: :message,
          role: :user,
          content: prompt,
          metadata: message.metadata,
          timestamp: message.inserted_at
        }

        Phoenix.PubSub.broadcast(
          Viban.PubSub,
          "task:#{task.id}",
          {:new_message, message, executor_type}
        )

        {:noreply,
         socket
         |> assign(:activity_feed, socket.assigns.activity_feed ++ [activity_item])
         |> assign(:chat_input, "")
         |> assign(:chat_images, [])
         |> assign(:is_sending, true)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to send message")}
    end
  end

  def handle_event("send_chat_message", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("stop_executor", _params, socket) do
    task = socket.assigns.task

    running_session = Enum.find(socket.assigns.executor_sessions, &(&1.status in [:running, :pending]))

    if running_session do
      case ExecutorSession.stop(running_session) do
        {:ok, _} ->
          Phoenix.PubSub.broadcast(Viban.PubSub, "task:#{task.id}", :executor_stopped)
          {:noreply, put_flash(socket, :info, "Executor stopped")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to stop executor")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_task_title", %{"value" => title}, socket) do
    notify_parent({:update_task, socket.assigns.task.id, %{title: title}})
    {:noreply, socket}
  end

  def handle_event("update_task_description", %{"value" => description}, socket) do
    notify_parent(
      {:update_task, socket.assigns.task.id, %{description: if(description == "", do: nil, else: description)}}
    )

    {:noreply, socket}
  end

  def handle_event("move_task_to_column", %{"column_id" => column_id}, socket) do
    notify_parent({:move_task, socket.assigns.task.id, column_id})
    {:noreply, socket}
  end

  def handle_event("create_worktree", _params, socket) do
    notify_parent({:create_worktree, socket.assigns.task.id})
    {:noreply, socket}
  end

  def handle_event("show_pr_modal", _params, socket) do
    notify_parent({:show_pr_modal, socket.assigns.task})
    {:noreply, socket}
  end

  def handle_event("duplicate_task", _params, socket) do
    notify_parent({:duplicate_task, socket.assigns.task.id})
    {:noreply, socket}
  end

  def handle_event("delete_task", _params, socket) do
    notify_parent({:delete_task, socket.assigns.task.id})
    {:noreply, socket}
  end

  def handle_event("generate_subtasks", _params, socket) do
    notify_parent({:generate_subtasks, socket.assigns.task.id})
    {:noreply, socket}
  end

  def handle_event("toggle_subtask", %{"subtask_id" => subtask_id}, socket) do
    notify_parent({:toggle_subtask, subtask_id, socket.assigns.columns})
    {:noreply, socket}
  end

  def handle_event("clear_error", _params, socket) do
    notify_parent({:clear_error, socket.assigns.task.id})
    {:noreply, socket}
  end

  def handle_event("open_in_editor", _params, socket) do
    if path = socket.assigns.task.worktree_path do
      System.cmd("code", [path], stderr_to_stdout: true)
    end

    {:noreply, socket}
  end

  def handle_event("open_in_folder", _params, socket) do
    if path = socket.assigns.task.worktree_path do
      System.cmd("open", [path], stderr_to_stdout: true)
    end

    {:noreply, socket}
  end

  # ============================================================================
  # PubSub Message Handling (called from parent)
  # ============================================================================

  def handle_task_message({:new_message, message, _executor_type}, socket) do
    if socket.assigns.task.id == message.task_id do
      activity_item = %{
        id: message.id,
        type: :message,
        role: message.role,
        content: message.content,
        metadata: message.metadata,
        timestamp: message.inserted_at
      }

      socket
      |> update(:activity_feed, fn feed ->
        if Enum.any?(feed, &(&1.id == message.id)), do: feed, else: feed ++ [activity_item]
      end)
      |> assign(:is_sending, message.role == :user)
    else
      socket
    end
  end

  def handle_task_message({:executor_session_started, session}, socket) do
    if socket.assigns.task.id == session.task_id do
      activity_item = %{
        id: "#{session.id}-start",
        type: :session_start,
        executor_type: session.executor_type,
        prompt: session.prompt,
        timestamp: session.started_at || session.inserted_at
      }

      socket
      |> update(:executor_sessions, fn sessions -> [session | sessions] end)
      |> update(:activity_feed, fn feed -> feed ++ [activity_item] end)
      |> assign(:is_sending, true)
    else
      socket
    end
  end

  def handle_task_message({:executor_session_completed, session}, socket) do
    if socket.assigns.task.id == session.task_id do
      activity_item = %{
        id: "#{session.id}-end",
        type: :session_end,
        executor_type: session.executor_type,
        status: session.status,
        exit_code: session.exit_code,
        error_message: session.error_message,
        timestamp: session.completed_at
      }

      socket
      |> update(:executor_sessions, fn sessions ->
        Enum.map(sessions, fn s -> if s.id == session.id, do: session, else: s end)
      end)
      |> update(:activity_feed, fn feed -> feed ++ [activity_item] end)
      |> assign(:is_sending, false)
    else
      socket
    end
  end

  def handle_task_message(:executor_stopped, socket) do
    assign(socket, :is_sending, false)
  end

  def handle_task_message({:hook_execution_update, hook}, socket) do
    if socket.assigns.task.id == hook.task_id do
      update(socket, :hook_executions, fn hooks ->
        case Enum.find_index(hooks, &(&1.id == hook.id)) do
          nil -> [hook | hooks]
          idx -> List.replace_at(hooks, idx, hook)
        end
      end)
    else
      socket
    end
  end

  def handle_task_message({:subtasks_generated, parent_task_id}, socket) do
    if socket.assigns.task.id == parent_task_id do
      subtasks = load_subtasks(parent_task_id)
      assign(socket, :subtasks, subtasks)
    else
      socket
    end
  end

  def handle_task_message(_, socket), do: socket

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp load_messages(task_id) do
    case Message.for_task(task_id) do
      {:ok, messages} -> messages
      _ -> []
    end
  end

  defp load_executor_sessions(task_id) do
    case ExecutorSession.for_task(task_id) do
      {:ok, sessions} -> sessions
      _ -> []
    end
  end

  defp load_hook_executions(task_id) do
    case HookExecution.history_for_task(task_id) do
      {:ok, executions} -> executions
      _ -> []
    end
  end

  defp load_subtasks(task_id) do
    case Task.subtasks(task_id) do
      {:ok, subtasks} -> subtasks
      _ -> []
    end
  end

  defp load_executors do
    case Executor.list_available() do
      {:ok, executors} -> executors
      _ -> []
    end
  end

  defp build_activity_feed(messages, sessions, hook_executions, task) do
    message_events =
      Enum.map(messages, fn msg ->
        %{
          id: msg.id,
          type: :message,
          role: msg.role,
          content: msg.content,
          metadata: msg.metadata,
          timestamp: msg.inserted_at
        }
      end)

    session_events =
      Enum.flat_map(sessions, fn session ->
        events = [
          %{
            id: "#{session.id}-start",
            type: :session_start,
            executor_type: session.executor_type,
            prompt: session.prompt,
            timestamp: session.started_at || session.inserted_at
          }
        ]

        if session.completed_at do
          events ++
            [
              %{
                id: "#{session.id}-end",
                type: :session_end,
                executor_type: session.executor_type,
                status: session.status,
                exit_code: session.exit_code,
                error_message: session.error_message,
                timestamp: session.completed_at
              }
            ]
        else
          events
        end
      end)

    hook_events =
      Enum.map(hook_executions, fn hook ->
        %{
          id: hook.id,
          type: :hook_execution,
          hook_name: hook.hook_name,
          status: hook.status,
          error_message: hook.error_message,
          started_at: hook.started_at,
          completed_at: hook.completed_at,
          timestamp: hook.queued_at
        }
      end)

    task_created = [
      %{
        id: "task-created-#{task.id}",
        type: :task_created,
        title: task.title,
        timestamp: task.inserted_at
      }
    ]

    Enum.sort_by(message_events ++ session_events ++ hook_events ++ task_created, & &1.timestamp, {:asc, DateTime})
  end

  defp is_task_running(sessions) do
    Enum.any?(sessions, fn s -> s.status in [:running, :pending] end)
  end

  defp get_agent_status(task, sessions) do
    cond do
      task.agent_status == :error -> :error
      Enum.any?(sessions, &(&1.status == :running)) -> :executing
      task.agent_status == :thinking -> :thinking
      true -> :idle
    end
  end

  defp subtask_completed?(columns, subtask) do
    done_column = Enum.find(columns, fn c -> String.downcase(c.name) in ["done", "completed"] end)
    done_column && subtask.column_id == done_column.id
  end

  defp format_time(nil), do: ""
  defp format_time(datetime), do: Calendar.strftime(datetime, "%H:%M")

  defp format_relative_time(nil), do: ""

  defp format_relative_time(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86_400)}d ago"
    end
  end
end
