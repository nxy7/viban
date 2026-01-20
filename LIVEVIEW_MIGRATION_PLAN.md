# LiveView + SQLite Migration Plan

## Goal
Create a parallel LiveView implementation that:
1. Replaces SolidJS frontend with Phoenix LiveView
2. Replaces Postgres + Electric SQL with SQLite
3. Maintains identical visual appearance
4. Enables single-binary deployment via Burrito (no Caddy/HTTP2 requirement)

## Architecture Overview

### Current Stack
```
Browser                          Server
┌─────────────────┐             ┌─────────────────┐
│ SolidJS (700KB) │◄──Electric──│ Phoenix + Ash   │
│ SQLite WASM     │   WebSocket │ Electric Server │
│ Electric Client │             │ Postgres        │
└─────────────────┘             └─────────────────┘
```

### New Stack
```
Browser                          Server
┌─────────────────┐             ┌─────────────────┐
│ LiveView (30KB) │◄──WebSocket─│ Phoenix + Ash   │
│ Morphdom        │             │ SQLite          │
│ JS Hooks        │             │ Litestream      │
└─────────────────┘             └─────────────────┘
```

## Phase 1: Foundation Setup

### 1.1 Add Dependencies
```elixir
# mix.exs
{:ash_sqlite, "~> 0.2"},
{:ecto_sqlite3, "~> 0.17"},
{:exqlite, "~> 0.27"},
```

### 1.2 Create SQLite Repo
```elixir
# lib/viban/repo_sqlite.ex
defmodule Viban.RepoSqlite do
  use Ecto.Repo,
    otp_app: :viban,
    adapter: Ecto.Adapters.SQLite3
end
```

### 1.3 Configure SQLite
```elixir
# config/config.exs
config :viban, Viban.RepoSqlite,
  database: "priv/viban.db",
  pool_size: 1,
  journal_mode: :wal
```

### 1.4 Create LiveView Domain
Create a parallel domain that uses SQLite instead of Postgres. This allows both to coexist during development.

```
lib/viban/
├── kanban/              # Existing (Postgres)
└── kanban_lite/         # New (SQLite)
    ├── board.ex
    ├── column.ex
    ├── task.ex
    ├── hook.ex
    ├── column_hook.ex
    ├── repository.ex
    ├── task_event.ex
    ├── periodical_task.ex
    └── task_template.ex
```

**Decision**: Initially duplicate resources with `AshSqlite` data layer. Later, can make data layer configurable.

## Phase 2: LiveView Structure

### 2.1 Router Setup
```elixir
# lib/viban_web/router.ex
scope "/live", VibanWeb.Live do
  pipe_through [:browser, :require_authenticated_user]

  live "/", HomeLive, :index
  live "/board/:board_id", BoardLive, :show
  live "/board/:board_id/task/:task_id", BoardLive, :task
  live "/board/:board_id/settings", BoardLive, :settings
  live "/board/:board_id/settings/:tab", BoardLive, :settings
end
```

### 2.2 LiveView Module Structure
```
lib/viban_web/live/
├── home_live.ex                    # Board list
├── home_live.html.heex
├── board_live.ex                   # Main board view
├── board_live.html.heex
└── components/
    ├── kanban_board.ex             # Board with columns
    ├── kanban_column.ex            # Single column
    ├── task_card.ex                # Task card
    ├── task_details_panel.ex       # Right panel
    ├── activity_feed.ex            # Task activity
    ├── chat_input.ex               # Executor input
    ├── subtask_list.ex             # Subtasks
    ├── llm_todo_list.ex            # AI progress
    ├── agent_status.ex             # Status badge
    ├── create_task_modal.ex        # Create task form
    ├── create_pr_modal.ex          # Create PR form
    ├── board_settings.ex           # Settings panel
    ├── column_settings.ex          # Column config
    ├── hook_manager.ex             # Hook CRUD
    └── ui/
        ├── button.ex
        ├── input.ex
        ├── textarea.ex
        ├── modal.ex
        ├── side_panel.ex
        ├── notification.ex
        └── icons.ex
```

### 2.3 Component Pattern
```elixir
defmodule VibanWeb.Live.Components.TaskCard do
  use VibanWeb, :live_component

  # Stateless function component for simple rendering
  attr :task, :map, required: true
  attr :selected, :boolean, default: false

  def task_card(assigns) do
    ~H"""
    <div
      id={"task-#{@task.id}"}
      class={task_classes(@task, @selected)}
      style={task_glow_style(@task)}
      phx-click="select_task"
      phx-value-id={@task.id}
      data-task-id={@task.id}
      data-sortable-item
    >
      <!-- Task content -->
    </div>
    """
  end
end
```

## Phase 3: JavaScript Hooks

### 3.1 Drag and Drop Hook
```javascript
// assets/js/hooks/sortable.js
import Sortable from 'sortablejs';

export const SortableHook = {
  mounted() {
    const group = this.el.dataset.sortableGroup;

    this.sortable = new Sortable(this.el, {
      group: group,
      animation: 150,
      ghostClass: 'opacity-50',
      dragClass: 'rotate-2',

      onEnd: (evt) => {
        const taskId = evt.item.dataset.taskId;
        const toColumnId = evt.to.dataset.columnId;
        const beforeId = evt.item.nextElementSibling?.dataset.taskId;
        const afterId = evt.item.previousElementSibling?.dataset.taskId;

        this.pushEvent("move_task", {
          task_id: taskId,
          column_id: toColumnId,
          before_task_id: beforeId,
          after_task_id: afterId
        });
      }
    });
  },

  destroyed() {
    this.sortable?.destroy();
  }
};
```

### 3.2 Image Paste Hook
```javascript
// assets/js/hooks/image_paste.js
export const ImagePasteHook = {
  mounted() {
    this.el.addEventListener('paste', async (e) => {
      const items = e.clipboardData?.items;
      if (!items) return;

      for (const item of items) {
        if (item.type.startsWith('image/')) {
          e.preventDefault();
          const file = item.getAsFile();
          const base64 = await this.fileToBase64(file);
          const id = `img-${Date.now()}`;

          // Insert placeholder at cursor
          const textarea = this.el;
          const start = textarea.selectionStart;
          const before = textarea.value.substring(0, start);
          const after = textarea.value.substring(textarea.selectionEnd);
          textarea.value = before + `![${id}]()` + after;

          // Push image data to server
          this.pushEvent("image_pasted", { id, data: base64, mimeType: item.type });
        }
      }
    });
  },

  fileToBase64(file) {
    return new Promise((resolve) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.readAsDataURL(file);
    });
  }
};
```

### 3.3 Auto-resize Textarea Hook
```javascript
// assets/js/hooks/auto_resize.js
export const AutoResizeHook = {
  mounted() {
    this.resize();
    this.el.addEventListener('input', () => this.resize());
  },

  resize() {
    this.el.style.height = 'auto';
    this.el.style.height = this.el.scrollHeight + 'px';
  }
};
```

### 3.4 Keyboard Shortcuts Hook
```javascript
// assets/js/hooks/keyboard_shortcuts.js
export const KeyboardShortcutsHook = {
  mounted() {
    this.handleKeydown = (e) => {
      // Don't trigger in inputs
      if (e.target.matches('input, textarea, [contenteditable]')) return;

      switch(e.key) {
        case 'n':
          this.pushEvent("shortcut", { key: "new_task" });
          break;
        case '/':
          e.preventDefault();
          this.pushEvent("shortcut", { key: "search" });
          break;
        case ',':
          this.pushEvent("shortcut", { key: "settings" });
          break;
        case '?':
          if (e.shiftKey) this.pushEvent("shortcut", { key: "help" });
          break;
        case 'Escape':
          this.pushEvent("shortcut", { key: "escape" });
          break;
      }
    };

    window.addEventListener('keydown', this.handleKeydown);
  },

  destroyed() {
    window.removeEventListener('keydown', this.handleKeydown);
  }
};
```

### 3.5 Hook Registration
```javascript
// assets/js/app.js
import { SortableHook } from './hooks/sortable';
import { ImagePasteHook } from './hooks/image_paste';
import { AutoResizeHook } from './hooks/auto_resize';
import { KeyboardShortcutsHook } from './hooks/keyboard_shortcuts';

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: {
    Sortable: SortableHook,
    ImagePaste: ImagePasteHook,
    AutoResize: AutoResizeHook,
    KeyboardShortcuts: KeyboardShortcutsHook,
  },
  params: { _csrf_token: csrfToken }
});
```

## Phase 4: Real-time Updates

### 4.1 PubSub Topics
```elixir
# lib/viban/kanban_lite/pubsub.ex
defmodule Viban.KanbanLite.PubSub do
  @pubsub Viban.PubSub

  def subscribe_board(board_id) do
    Phoenix.PubSub.subscribe(@pubsub, "board:#{board_id}")
  end

  def broadcast_task_update(board_id, task) do
    Phoenix.PubSub.broadcast(@pubsub, "board:#{board_id}", {:task_updated, task})
  end

  def broadcast_task_moved(board_id, task, from_column, to_column) do
    Phoenix.PubSub.broadcast(@pubsub, "board:#{board_id}", {:task_moved, task, from_column, to_column})
  end

  def broadcast_executor_output(task_id, output) do
    Phoenix.PubSub.broadcast(@pubsub, "task:#{task_id}", {:executor_output, output})
  end

  # ... more broadcast functions
end
```

### 4.2 LiveView Subscriptions
```elixir
defmodule VibanWeb.Live.BoardLive do
  use VibanWeb, :live_view

  def mount(%{"board_id" => board_id}, _session, socket) do
    if connected?(socket) do
      Viban.KanbanLite.PubSub.subscribe_board(board_id)
    end

    board = load_board(board_id)
    columns = load_columns(board_id)
    tasks = load_tasks(board_id)

    {:ok, assign(socket,
      board: board,
      columns: columns,
      tasks: tasks,
      tasks_by_column: group_tasks_by_column(tasks, columns),
      selected_task_id: nil,
      search_query: ""
    )}
  end

  def handle_info({:task_updated, task}, socket) do
    # Update task in assigns
    {:noreply, update_task_in_socket(socket, task)}
  end

  def handle_info({:task_moved, task, _from, _to}, socket) do
    {:noreply, update_task_in_socket(socket, task)}
  end

  def handle_info({:executor_output, output}, socket) do
    {:noreply, stream_insert(socket, :activity, output)}
  end
end
```

### 4.3 Ash Notifiers for PubSub
```elixir
# lib/viban/kanban_lite/task/task_notifier.ex
defmodule Viban.KanbanLite.Task.TaskNotifier do
  use Ash.Notifier

  def notify(%Ash.Notifier.Notification{resource: resource, action: action, data: task}) do
    board_id = get_board_id(task)

    case action.name do
      :create -> broadcast_task_created(board_id, task)
      :update -> broadcast_task_updated(board_id, task)
      :move -> broadcast_task_moved(board_id, task)
      :destroy -> broadcast_task_deleted(board_id, task.id)
      _ -> :ok
    end
  end
end
```

## Phase 5: UI Components (HEEx)

### 5.1 Design System Components
Port the SolidJS design system to function components:

```elixir
# lib/viban_web/components/ui.ex
defmodule VibanWeb.Components.UI do
  use Phoenix.Component

  # Button component matching SolidJS version
  attr :variant, :string, default: "primary"
  attr :size, :string, default: "md"
  attr :disabled, :boolean, default: false
  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      class={[
        "inline-flex items-center justify-center font-medium rounded-md transition-colors",
        "focus:outline-none focus:ring-2 focus:ring-brand-500 focus:ring-offset-2 focus:ring-offset-gray-900",
        button_variant_classes(@variant),
        button_size_classes(@size),
        @disabled && "opacity-50 cursor-not-allowed",
        @class
      ]}
      disabled={@disabled}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  defp button_variant_classes("primary"), do: "bg-brand-600 hover:bg-brand-700 text-white"
  defp button_variant_classes("secondary"), do: "bg-gray-800 hover:bg-gray-700 text-gray-300"
  defp button_variant_classes("danger"), do: "bg-red-600 hover:bg-red-700 text-white"
  defp button_variant_classes("ghost"), do: "bg-transparent hover:bg-gray-800 text-gray-400 hover:text-white"

  defp button_size_classes("sm"), do: "px-3 py-1.5 text-sm"
  defp button_size_classes("md"), do: "px-4 py-2 text-sm"
  defp button_size_classes("lg"), do: "px-6 py-3 text-base"

  # Input component
  attr :type, :string, default: "text"
  attr :variant, :string, default: "default"
  attr :size, :string, default: "md"
  attr :class, :string, default: ""
  attr :rest, :global

  def input(assigns) do
    ~H"""
    <input
      type={@type}
      class={[
        "border rounded-lg text-white placeholder-gray-500",
        "focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent",
        "transition-colors disabled:opacity-50 disabled:cursor-not-allowed",
        input_variant_classes(@variant),
        input_size_classes(@size),
        @class
      ]}
      {@rest}
    />
    """
  end

  defp input_variant_classes("default"), do: "bg-gray-800 border-gray-700"
  defp input_variant_classes("dark"), do: "bg-gray-900 border-gray-700"

  defp input_size_classes("sm"), do: "px-3 py-1.5 text-sm"
  defp input_size_classes("md"), do: "px-3 py-2 text-sm"
  defp input_size_classes("lg"), do: "px-4 py-3 text-base"

  # Modal component
  attr :show, :boolean, default: false
  attr :on_close, :any, default: nil
  slot :inner_block, required: true
  slot :title

  def modal(assigns) do
    ~H"""
    <div
      :if={@show}
      class="fixed inset-0 z-50 flex items-center justify-center"
      phx-window-keydown="close_modal"
      phx-key="Escape"
    >
      <div class="fixed inset-0 bg-black/50 backdrop-blur-sm" phx-click="close_modal" />
      <div class="relative bg-gray-900 border border-gray-800 rounded-md shadow-2xl w-full max-w-md mx-4 animate-in fade-in zoom-in-95 duration-200">
        <div :if={@title != []} class="flex items-center justify-between p-4 border-b border-gray-800">
          <h3 class="text-lg font-semibold text-white">
            <%= render_slot(@title) %>
          </h3>
          <button phx-click="close_modal" class="text-gray-400 hover:text-white">
            <.icon name="x" class="w-5 h-5" />
          </button>
        </div>
        <div class="p-4">
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end
end
```

### 5.2 Task Card Component
```elixir
# lib/viban_web/live/components/task_card.ex
defmodule VibanWeb.Live.Components.TaskCard do
  use VibanWeb, :html

  attr :task, :map, required: true
  attr :selected, :boolean, default: false
  attr :highlight_parent, :boolean, default: false
  attr :highlight_child, :boolean, default: false

  def task_card(assigns) do
    ~H"""
    <div
      id={"task-#{@task.id}"}
      class={[
        "relative border rounded-md p-3 cursor-pointer transition-all duration-150",
        "hover:border-gray-600 hover:bg-gray-800",
        task_border_class(@task, @highlight_parent, @highlight_child),
        @selected && "ring-2 ring-brand-500"
      ]}
      style={task_glow_style(@task, @highlight_parent, @highlight_child)}
      phx-click="select_task"
      phx-value-id={@task.id}
      data-task-id={@task.id}
    >
      <div class="flex items-start justify-between gap-2">
        <h4 class="text-sm font-medium text-white line-clamp-2">
          <%= @task.title %>
        </h4>
        <.task_status_badge task={@task} />
      </div>

      <div :if={@task.description} class="mt-2 text-xs text-gray-400 line-clamp-2">
        <%= truncate_description(@task.description) %>
      </div>

      <div :if={@task.pr_url} class="mt-2">
        <.pr_badge task={@task} />
      </div>
    </div>
    """
  end

  defp task_border_class(task, highlight_parent, highlight_child) do
    cond do
      highlight_parent -> "border-purple-500/70 bg-purple-900/20"
      highlight_child -> "border-purple-500/50 bg-purple-900/10"
      task.agent_status == :error -> "border-red-500/50 bg-gray-800/50"
      task.in_progress -> "border-brand-500/50 bg-gray-800/50"
      task.queued_at != nil -> "border-yellow-500/50 bg-gray-800/50 opacity-75"
      true -> "border-gray-700 bg-gray-800/50"
    end
  end

  defp task_glow_style(task, highlight_parent, highlight_child) do
    glow = cond do
      highlight_parent ->
        "0 0 25px rgba(147, 51, 234, 0.6), 0 0 50px rgba(147, 51, 234, 0.3)"
      highlight_child ->
        "0 0 15px rgba(147, 51, 234, 0.4), 0 0 30px rgba(147, 51, 234, 0.2)"
      task.agent_status == :error ->
        "0 0 20px rgba(239, 68, 68, 0.5), 0 0 40px rgba(239, 68, 68, 0.2)"
      task.in_progress ->
        "0 0 20px rgba(139, 92, 246, 0.5), 0 0 40px rgba(139, 92, 246, 0.2)"
      task.queued_at != nil ->
        "0 0 15px rgba(234, 179, 8, 0.3), 0 0 30px rgba(234, 179, 8, 0.1)"
      true ->
        "none"
    end
    "box-shadow: #{glow}"
  end
end
```

### 5.3 Kanban Board Component
```elixir
# lib/viban_web/live/components/kanban_board.ex
defmodule VibanWeb.Live.Components.KanbanBoard do
  use VibanWeb, :html

  attr :columns, :list, required: true
  attr :tasks_by_column, :map, required: true
  attr :selected_task_id, :string, default: nil
  attr :search_query, :string, default: ""

  def kanban_board(assigns) do
    ~H"""
    <div
      id="kanban-board"
      class="flex gap-4 h-full overflow-x-auto p-4"
      phx-hook="KeyboardShortcuts"
    >
      <.kanban_column
        :for={column <- @columns}
        column={column}
        tasks={Map.get(@tasks_by_column, column.id, [])}
        selected_task_id={@selected_task_id}
        search_query={@search_query}
      />
    </div>
    """
  end

  attr :column, :map, required: true
  attr :tasks, :list, required: true
  attr :selected_task_id, :string, default: nil
  attr :search_query, :string, default: ""

  def kanban_column(assigns) do
    filtered_tasks = filter_tasks(assigns.tasks, assigns.search_query)
    assigns = assign(assigns, :filtered_tasks, filtered_tasks)

    ~H"""
    <div class="flex-shrink-0 w-72 bg-gray-900/50 rounded-lg">
      <div class="p-3 border-b border-gray-800">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <div class="w-3 h-3 rounded-full" style={"background-color: #{@column.color}"} />
            <h3 class="font-medium text-white"><%= @column.name %></h3>
            <span class="text-xs text-gray-500">(<%= length(@filtered_tasks) %>)</span>
          </div>
          <button
            phx-click="open_column_settings"
            phx-value-id={@column.id}
            class="text-gray-400 hover:text-white"
          >
            <.icon name="settings" class="w-4 h-4" />
          </button>
        </div>
      </div>

      <div
        id={"column-#{@column.id}-tasks"}
        class="p-2 space-y-2 min-h-[200px]"
        phx-hook="Sortable"
        data-sortable-group="tasks"
        data-column-id={@column.id}
      >
        <.task_card
          :for={task <- @filtered_tasks}
          task={task}
          selected={task.id == @selected_task_id}
        />
      </div>

      <div :if={@column.name == "TODO"} class="p-2 border-t border-gray-800">
        <button
          phx-click="open_create_task"
          phx-value-column-id={@column.id}
          class="w-full py-2 text-sm text-gray-400 hover:text-white hover:bg-gray-800 rounded transition-colors"
        >
          + Add Task
        </button>
      </div>
    </div>
    """
  end

  defp filter_tasks(tasks, ""), do: tasks
  defp filter_tasks(tasks, query) do
    query = String.downcase(query)
    Enum.filter(tasks, fn task ->
      String.contains?(String.downcase(task.title || ""), query) ||
      String.contains?(String.downcase(task.description || ""), query)
    end)
  end
end
```

## Phase 6: Tailwind Configuration

### 6.1 Copy Tailwind Config
```javascript
// assets/tailwind.config.js
module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/viban_web.ex",
    "../lib/viban_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          50: "#f5f3ff",
          100: "#ede9fe",
          200: "#ddd6fe",
          300: "#c4b5fd",
          400: "#a78bfa",
          500: "#8b5cf6",
          600: "#7c3aed",
          700: "#6d28d9",
          800: "#5b21b6",
          900: "#4c1d95",
          950: "#2e1065"
        }
      },
      animation: {
        'in': 'in 0.2s ease-out',
      },
      keyframes: {
        in: {
          '0%': { opacity: '0', transform: 'scale(0.95)' },
          '100%': { opacity: '1', transform: 'scale(1)' },
        }
      }
    }
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography"),
  ]
}
```

### 6.2 Base Styles
```css
/* assets/css/app.css */
@import "tailwindcss/base";
@import "tailwindcss/components";
@import "tailwindcss/utilities";

:root {
  color-scheme: dark;
}

body {
  @apply bg-[#0f0f1a] text-gray-100;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}

/* Custom scrollbar for dark theme */
::-webkit-scrollbar {
  @apply w-2 h-2;
}

::-webkit-scrollbar-track {
  @apply bg-gray-900;
}

::-webkit-scrollbar-thumb {
  @apply bg-gray-700 rounded;
}

::-webkit-scrollbar-thumb:hover {
  @apply bg-gray-600;
}

/* Line clamp utilities */
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.line-clamp-6 {
  display: -webkit-box;
  -webkit-line-clamp: 6;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
```

## Phase 7: SQLite Data Layer

### 7.1 Resource Configuration
```elixir
# lib/viban/kanban_lite/task.ex
defmodule Viban.KanbanLite.Task do
  use Ash.Resource,
    domain: Viban.KanbanLite,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "tasks"
    repo Viban.RepoSqlite
  end

  # ... rest of resource definition (same as Postgres version)
end
```

### 7.2 Migrations
```elixir
# priv/repo_sqlite/migrations/001_create_tables.exs
defmodule Viban.RepoSqlite.Migrations.CreateTables do
  use Ecto.Migration

  def change do
    # Boards
    create table(:boards, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :user_id, :binary_id, null: false
      timestamps()
    end

    create unique_index(:boards, [:user_id, :name])

    # Columns
    create table(:columns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :position, :integer, default: 0
      add :color, :string, default: "#6366f1"
      add :settings, :text  # JSON encoded
      add :board_id, references(:boards, type: :binary_id, on_delete: :delete_all)
      timestamps()
    end

    create unique_index(:columns, [:board_id, :name])
    create unique_index(:columns, [:board_id, :position])

    # Tasks
    create table(:tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :position, :string, default: "a0"
      add :priority, :string, default: "medium"
      add :worktree_path, :string
      add :worktree_branch, :string
      add :custom_branch_name, :string
      add :agent_status, :string, default: "idle"
      add :agent_status_message, :string
      add :in_progress, :boolean, default: false
      add :error_message, :text
      add :queued_at, :utc_datetime_usec
      add :queue_priority, :integer, default: 0
      add :pr_url, :string
      add :pr_number, :integer
      add :pr_status, :string
      add :is_parent, :boolean, default: false
      add :subtask_position, :integer, default: 0
      add :subtask_generation_status, :string
      add :executed_hooks, :text  # JSON array
      add :message_queue, :text   # JSON array
      add :description_images, :text  # JSON array
      add :auto_start, :boolean, default: false
      add :column_id, references(:columns, type: :binary_id, on_delete: :delete_all)
      add :parent_task_id, references(:tasks, type: :binary_id, on_delete: :nilify_all)
      add :periodical_task_id, :binary_id
      timestamps()
    end

    create unique_index(:tasks, [:worktree_path], where: "worktree_path IS NOT NULL")
    create index(:tasks, [:column_id])
    create index(:tasks, [:parent_task_id])

    # ... more tables (hooks, column_hooks, repositories, task_events, etc.)
  end
end
```

## Phase 8: Implementation Order

### Week 1: Foundation
1. [ ] Add SQLite dependencies and configure
2. [ ] Create Viban.RepoSqlite
3. [ ] Create Viban.KanbanLite domain with SQLite resources
4. [ ] Run migrations, verify data layer works
5. [ ] Set up LiveView routes

### Week 2: Core UI
1. [ ] Create base UI components (button, input, modal, etc.)
2. [ ] Create BoardLive with basic structure
3. [ ] Create KanbanBoard and KanbanColumn components
4. [ ] Create TaskCard component
5. [ ] Implement basic navigation

### Week 3: Interactivity
1. [ ] Add Sortable.js drag-drop hook
2. [ ] Implement task movement with position calculation
3. [ ] Create TaskDetailsPanel
4. [ ] Add keyboard shortcuts hook
5. [ ] Implement search/filter

### Week 4: Task Details
1. [ ] Title/description editing
2. [ ] Activity feed with streaming
3. [ ] Chat input with image paste
4. [ ] Executor output streaming via PubSub
5. [ ] Subtask list

### Week 5: Modals & Settings
1. [ ] CreateTaskModal
2. [ ] CreatePRModal
3. [ ] BoardSettings panel
4. [ ] ColumnSettings popup
5. [ ] HookManager

### Week 6: Polish & Integration
1. [ ] Notification system
2. [ ] Error handling
3. [ ] Loading states
4. [ ] Animations/transitions
5. [ ] Test and fix edge cases

## File Structure Summary

```
lib/
├── viban/
│   ├── repo_sqlite.ex                 # SQLite Ecto Repo
│   └── kanban_lite/                   # SQLite-backed domain
│       ├── domain.ex
│       ├── board.ex
│       ├── column.ex
│       ├── task.ex
│       ├── hook.ex
│       ├── column_hook.ex
│       ├── repository.ex
│       ├── task_event.ex
│       ├── message.ex
│       ├── hook_execution.ex
│       ├── executor_session.ex
│       ├── executor_message.ex
│       ├── periodical_task.ex
│       ├── task_template.ex
│       └── pubsub.ex
│
└── viban_web/
    ├── components/
    │   └── ui.ex                      # Design system components
    │
    └── live/
        ├── home_live.ex
        ├── home_live.html.heex
        ├── board_live.ex
        ├── board_live.html.heex
        └── components/
            ├── kanban_board.ex
            ├── task_card.ex
            ├── task_details_panel.ex
            ├── activity_feed.ex
            ├── chat_input.ex
            ├── subtask_list.ex
            ├── llm_todo_list.ex
            ├── agent_status.ex
            ├── create_task_modal.ex
            ├── create_pr_modal.ex
            ├── board_settings.ex
            ├── column_settings.ex
            └── hook_manager.ex

assets/
├── css/
│   └── app.css
├── js/
│   ├── app.js
│   └── hooks/
│       ├── sortable.js
│       ├── image_paste.js
│       ├── auto_resize.js
│       └── keyboard_shortcuts.js
└── tailwind.config.js

priv/
└── repo_sqlite/
    └── migrations/
        └── 001_create_tables.exs
```

## Success Criteria

1. **Visual Parity**: UI looks identical to SolidJS version
2. **Feature Parity**: All features work (drag-drop, chat, hooks, etc.)
3. **Real-time**: Updates propagate to all connected clients
4. **Performance**: Page loads < 500ms, interactions < 200ms
5. **Deployment**: Single binary via Burrito, no Caddy needed
6. **Data Migration**: Can import from Postgres if needed

## Open Questions

1. **Offline Support**: Accept that offline won't work, or add service worker?
2. **Data Migration**: Need tool to migrate Postgres → SQLite?
3. **Coexistence**: Keep both frontends during transition, or hard switch?
4. **Auth**: Reuse existing auth or simplify for single-user?
