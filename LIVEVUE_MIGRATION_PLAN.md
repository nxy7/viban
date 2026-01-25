# LiveVue Migration Plan

## Overview

This document provides a comprehensive, autonomous migration plan from Hologram to LiveVue.
The goal is a single Elixir binary deployment with no Node.js runtime dependency.

**Current State:** Hologram frontend with Phoenix Channels for real-time
**Target State:** LiveVue (LiveView + Vue 3) with SSR disabled

## Architecture Comparison

```
CURRENT (Hologram)                    TARGET (LiveVue)
─────────────────                     ─────────────────
~HOLO templates                  →    .vue SFC components
action(:name)                    →    Vue methods + emits
command(:name)                   →    LiveView handle_event
put_state()                      →    Vue reactive refs
Phoenix Channel (explicit)       →    LiveView PubSub (built-in)
Hologram.Page                    →    Phoenix.LiveView
Hologram.Component               →    Vue SFC or LiveComponent
```

## Prerequisites

### 1. Install LiveVue

```bash
cd backend
mix igniter.install live_vue
```

### 2. Configure for No-SSR

```elixir
# config/prod.exs
config :live_vue,
  ssr: false
```

### 3. Verify Build Works

```bash
mix assets.build
mix phx.server
```

## Migration Phases

### Phase 0: Setup & Infrastructure (Day 1)
- [ ] Install LiveVue via Igniter
- [ ] Configure SSR disabled
- [ ] Create base LiveView layout
- [ ] Set up Vue component directory structure
- [ ] Port CSS/Tailwind configuration
- [ ] Verify hot reload works

### Phase 1: Authentication & Home (Day 2-3)
- [ ] Create HomeLive module
- [ ] Create Vue components for home page UI
- [ ] Port GitHub device flow authentication
- [ ] Port board listing
- [ ] Port create board modal
- [ ] Test full auth flow

### Phase 2: Board Core (Day 4-6)
- [ ] Create BoardLive module
- [ ] Create KanbanBoard Vue component
- [ ] Create Column Vue component
- [ ] Create TaskCard Vue component
- [ ] Port basic board display
- [ ] Implement task selection/details panel

### Phase 3: Real-time & DnD (Day 7-8)
- [ ] Configure LiveView PubSub subscriptions
- [ ] Port task movement (drag & drop)
- [ ] Port real-time task updates
- [ ] Port hook execution effects (sounds)
- [ ] Test multi-client sync

### Phase 4: Task Management (Day 9-10)
- [ ] Port task CRUD operations
- [ ] Port subtask display and generation
- [ ] Port PR creation modal
- [ ] Port task editing (title, description)
- [ ] Port task deletion with confirmation

### Phase 5: Settings (Day 11-13)
- [ ] Port BoardSettingsPanel
  - [ ] General tab (repository settings)
  - [ ] Templates tab
  - [ ] Hooks tab
  - [ ] Scheduled tab
  - [ ] System tab
- [ ] Port ColumnSettingsPopup
  - [ ] General tab (name, color, description)
  - [ ] Hooks tab (add/remove/configure)
  - [ ] Concurrency tab

### Phase 6: Polish & Cleanup (Day 14)
- [ ] Port keyboard shortcuts
- [ ] Port all UI feedback (toasts, loading states)
- [ ] Remove Hologram code
- [ ] Update CLAUDE.md
- [ ] Final testing

---

## Detailed File Mapping

### Pages → LiveViews

| Hologram Page | LiveView Module | Route |
|---------------|-----------------|-------|
| `home_page.ex` | `HomeLive` | `/` |
| `board_page.ex` | `BoardLive` | `/board/:board_id` |

### Components → Vue SFCs

| Hologram Component | Vue Component | Notes |
|-------------------|---------------|-------|
| `main_layout.ex` | `layouts/root.html.heex` | LiveView layout |
| `board_card.ex` | `BoardCard.vue` | Simple card |
| `column.ex` | `KanbanColumn.vue` | Column container |
| `task_card.ex` | `TaskCard.vue` | Draggable task |
| `create_board_modal.ex` | `CreateBoardModal.vue` | Stateful modal |
| `device_flow_modal.ex` | `DeviceFlowModal.vue` | Auth flow |
| `create_pr_modal.ex` | `CreatePRModal.vue` | PR form |
| `subtask_list.ex` | `SubtaskList.vue` | Subtask display |
| `user_menu.ex` | `UserMenu.vue` | Dropdown menu |
| `board_settings_panel.ex` | `BoardSettingsPanel.vue` | Complex settings |
| `column_settings_popup.ex` | `ColumnSettingsPopup.vue` | Column config |
| `ui/*.ex` (12 files) | `ui/*.vue` | UI primitives |

### JavaScript Files

| Current JS | Target | Migration |
|------------|--------|-----------|
| `app.js` (audio) | `audio.ts` | Keep, integrate with Vue |
| `keyboard-shortcuts.js` | `useKeyboard.ts` | Vue composable |
| `phoenix-channels.js` | Remove | Use LiveView |
| `kanban-dnd.js` | `useDragDrop.ts` | Vue + SortableJS |
| `task-interactions.js` | Remove | Vue event handlers |
| `device-flow-polling.js` | Remove | LiveView handles |
| `sortablejs.js` | Keep | Used by DnD |

---

## Implementation Details

### Phase 0: Setup & Infrastructure

#### 0.1 Install LiveVue

```bash
cd /Users/dawiddanieluk/viban/backend
mix igniter.install live_vue
```

This will:
- Add `live_vue` to mix.exs
- Set up Vite configuration
- Create assets structure
- Configure esbuild replacement

#### 0.2 Directory Structure

Create the following structure:

```
backend/
├── assets/
│   ├── js/
│   │   ├── app.js           # Main entry (LiveVue will modify)
│   │   ├── vue/
│   │   │   ├── components/  # Vue SFCs
│   │   │   │   ├── ui/      # UI primitives
│   │   │   │   ├── board/   # Board-related
│   │   │   │   ├── auth/    # Auth-related
│   │   │   │   └── settings/# Settings panels
│   │   │   └── composables/ # Vue composables
│   │   └── audio.ts         # Audio system
│   └── css/
│       └── app.css          # Tailwind
├── lib/
│   └── viban_web/
│       └── live/            # LiveView modules
│           ├── home_live.ex
│           ├── board_live.ex
│           └── components/  # LiveComponents (if needed)
```

#### 0.3 Configure No-SSR

```elixir
# config/dev.exs
config :live_vue,
  vite_host: "http://localhost:5173",
  ssr: false

# config/prod.exs
config :live_vue,
  ssr: false
```

#### 0.4 Base Layout

Create `lib/viban_web/components/layouts/root.html.heex`:

```heex
<!DOCTYPE html>
<html lang="en" class="h-full bg-gray-950">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <.live_title><%= assigns[:page_title] || "Viban" %></.live_title>
    <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
    <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}></script>
  </head>
  <body class="h-full antialiased text-white">
    <%= @inner_content %>
  </body>
</html>
```

---

### Phase 1: Authentication & Home

#### 1.1 HomeLive Module

Create `lib/viban_web/live/home_live.ex`:

```elixir
defmodule VibanWeb.HomeLive do
  use VibanWeb, :live_view

  alias Viban.Kanban.Board
  alias Viban.Accounts.User
  alias Viban.Auth.DeviceFlow

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"]

    socket =
      socket
      |> assign(:user, nil)
      |> assign(:boards, [])
      |> assign(:loading, true)
      |> assign(:show_create_modal, false)
      |> assign(:show_device_flow_modal, false)
      |> assign(:device_flow, %{status: :idle, user_code: nil, verification_uri: nil, error: nil})

    if connected?(socket) and user_id do
      send(self(), {:load_user, user_id})
    end

    {:ok, socket}
  end

  @impl true
  def handle_info({:load_user, user_id}, socket) do
    case User.get(user_id) do
      {:ok, user} ->
        boards = Board.for_user!(user_id)
        {:noreply, assign(socket, user: user, boards: boards, loading: false)}
      {:error, _} ->
        {:noreply, assign(socket, loading: false)}
    end
  end

  # Device flow handlers
  @impl true
  def handle_event("start_auth", _, socket) do
    case DeviceFlow.request_device_code() do
      {:ok, %{user_code: code, verification_uri: uri, device_code: device_code, interval: interval}} ->
        send(self(), {:poll_token, device_code, interval})
        {:noreply, assign(socket, :device_flow, %{
          status: :pending,
          user_code: code,
          verification_uri: uri,
          error: nil
        })}
      {:error, reason} ->
        {:noreply, assign(socket, :device_flow, %{socket.assigns.device_flow | status: :error, error: reason})}
    end
  end

  def handle_event("show_create_modal", _, socket) do
    {:noreply, assign(socket, :show_create_modal, true)}
  end

  def handle_event("hide_create_modal", _, socket) do
    {:noreply, assign(socket, :show_create_modal, false)}
  end

  def handle_event("create_board", %{"name" => name, "description" => desc, "repo" => repo}, socket) do
    user_id = socket.assigns.user.id

    case Board.create_with_repository(name, desc, user_id, repo) do
      {:ok, _board} ->
        boards = Board.for_user!(user_id)
        {:noreply, socket |> assign(:boards, boards) |> assign(:show_create_modal, false)}
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  # ... more handlers

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950">
      <.vue
        v-component="HomePage"
        user={@user}
        boards={@boards}
        loading={@loading}
        show_create_modal={@show_create_modal}
        show_device_flow_modal={@show_device_flow_modal}
        device_flow={@device_flow}
        v-on:start_auth="start_auth"
        v-on:show_create_modal="show_create_modal"
        v-on:hide_create_modal="hide_create_modal"
        v-on:create_board="create_board"
      />
    </div>
    """
  end
end
```

#### 1.2 HomePage Vue Component

Create `assets/js/vue/components/HomePage.vue`:

```vue
<script setup lang="ts">
import { computed } from 'vue'
import BoardCard from './board/BoardCard.vue'
import CreateBoardModal from './auth/CreateBoardModal.vue'
import DeviceFlowModal from './auth/DeviceFlowModal.vue'
import UserMenu from './UserMenu.vue'
import LoadingSpinner from './ui/LoadingSpinner.vue'

interface Props {
  user: any | null
  boards: any[]
  loading: boolean
  showCreateModal: boolean
  showDeviceFlowModal: boolean
  deviceFlow: {
    status: 'idle' | 'pending' | 'success' | 'error'
    userCode: string | null
    verificationUri: string | null
    error: string | null
  }
}

const props = defineProps<Props>()
const emit = defineEmits(['startAuth', 'showCreateModal', 'hideCreateModal', 'createBoard'])

const isAuthenticated = computed(() => !!props.user)
</script>

<template>
  <div class="min-h-screen bg-gray-950">
    <!-- Header -->
    <header class="border-b border-gray-800 px-6 py-4">
      <div class="flex items-center justify-between">
        <h1 class="text-xl font-bold text-white">Viban</h1>
        <UserMenu v-if="user" :user="user" />
        <button v-else @click="emit('startAuth')" class="btn-primary">
          Sign in with GitHub
        </button>
      </div>
    </header>

    <!-- Main Content -->
    <main class="p-6">
      <LoadingSpinner v-if="loading" />

      <template v-else-if="isAuthenticated">
        <div class="flex items-center justify-between mb-6">
          <h2 class="text-lg font-semibold">Your Boards</h2>
          <button @click="emit('showCreateModal')" class="btn-primary">
            New Board
          </button>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <BoardCard
            v-for="board in boards"
            :key="board.id"
            :board="board"
          />
        </div>

        <p v-if="boards.length === 0" class="text-gray-400 text-center py-12">
          No boards yet. Create your first board to get started.
        </p>
      </template>

      <template v-else>
        <div class="text-center py-20">
          <h2 class="text-2xl font-bold mb-4">Welcome to Viban</h2>
          <p class="text-gray-400 mb-8">Sign in to manage your kanban boards</p>
          <button @click="emit('startAuth')" class="btn-primary btn-lg">
            Sign in with GitHub
          </button>
        </div>
      </template>
    </main>

    <!-- Modals -->
    <CreateBoardModal
      v-if="showCreateModal"
      @close="emit('hideCreateModal')"
      @create="emit('createBoard', $event)"
    />

    <DeviceFlowModal
      v-if="showDeviceFlowModal"
      :status="deviceFlow.status"
      :user-code="deviceFlow.userCode"
      :verification-uri="deviceFlow.verificationUri"
      :error="deviceFlow.error"
      @close="emit('hideDeviceFlowModal')"
      @retry="emit('startAuth')"
    />
  </div>
</template>
```

---

### Phase 2: Board Core

#### 2.1 BoardLive Module

Create `lib/viban_web/live/board_live.ex`:

```elixir
defmodule VibanWeb.BoardLive do
  use VibanWeb, :live_view

  alias Viban.Kanban.{Board, Column, Task}

  @impl true
  def mount(%{"board_id" => board_id}, session, socket) do
    user_id = session["user_id"]

    socket =
      socket
      |> assign(:board_id, board_id)
      |> assign(:user_id, user_id)
      |> assign(:board, nil)
      |> assign(:columns, [])
      |> assign(:tasks_by_column, %{})
      |> assign(:loading, true)
      |> assign(:selected_task, nil)
      |> assign(:show_settings, false)
      |> assign(:settings_tab, "general")

    if connected?(socket) do
      # Subscribe to real-time updates
      Phoenix.PubSub.subscribe(Viban.PubSub, "kanban_lite:board:#{board_id}")
      send(self(), :load_board)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_board, socket) do
    board_id = socket.assigns.board_id

    with {:ok, board} <- Board.get(board_id),
         columns <- Ash.read!(Column, filter: [board_id: board_id], sort: :position) do

      tasks_by_column =
        columns
        |> Enum.map(fn col ->
          tasks = Ash.read!(Task, filter: [column_id: col.id], sort: :position)
          {col.id, tasks}
        end)
        |> Map.new()

      {:noreply, assign(socket,
        board: board,
        columns: columns,
        tasks_by_column: tasks_by_column,
        loading: false
      )}
    else
      _ -> {:noreply, assign(socket, loading: false, error: "Board not found")}
    end
  end

  # Real-time task updates
  @impl true
  def handle_info({:task_changed, %{task: task, action: action}}, socket) do
    tasks_by_column = update_tasks(socket.assigns.tasks_by_column, task, action)
    {:noreply, assign(socket, :tasks_by_column, tasks_by_column)}
  end

  def handle_info({:hook_executed, payload}, socket) do
    # Push hook effects to client
    {:noreply, push_event(socket, "hook_executed", payload)}
  end

  # Event handlers
  @impl true
  def handle_event("move_task", %{"task_id" => task_id, "column_id" => column_id, "prev_task_id" => prev, "next_task_id" => next}, socket) do
    with {:ok, task} <- Task.get(task_id),
         {:ok, _} <- Task.move(task, %{
           column_id: column_id,
           after_task_id: normalize_id(prev),
           before_task_id: normalize_id(next)
         }) do
      {:noreply, socket}
    else
      {:error, reason} -> {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def handle_event("create_task", %{"title" => title, "description" => desc, "column_id" => column_id}, socket) do
    case Task.create(%{title: title, description: desc, column_id: column_id}) do
      {:ok, _task} -> {:noreply, socket}
      {:error, reason} -> {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def handle_event("select_task", %{"task_id" => task_id}, socket) do
    task = get_task_from_assigns(socket.assigns.tasks_by_column, task_id)
    {:noreply, assign(socket, :selected_task, task)}
  end

  def handle_event("close_task_details", _, socket) do
    {:noreply, assign(socket, :selected_task, nil)}
  end

  # ... more handlers for all task operations

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gray-950">
      <.vue
        v-component="BoardPage"
        board={@board}
        columns={@columns}
        tasks_by_column={@tasks_by_column}
        loading={@loading}
        selected_task={@selected_task}
        show_settings={@show_settings}
        settings_tab={@settings_tab}
        v-on:move_task="move_task"
        v-on:create_task="create_task"
        v-on:select_task="select_task"
        v-on:close_task_details="close_task_details"
        v-on:update_task="update_task"
        v-on:delete_task="delete_task"
        v-on:open_settings="open_settings"
        v-on:close_settings="close_settings"
        v-hook:hook_executed="handleHookExecuted"
      />
    </div>
    """
  end

  defp normalize_id(nil), do: nil
  defp normalize_id(""), do: nil
  defp normalize_id(id), do: id

  defp update_tasks(tasks_by_column, task, "destroy") do
    Enum.map(tasks_by_column, fn {col_id, tasks} ->
      {col_id, Enum.reject(tasks, &(&1.id == task.id))}
    end)
    |> Map.new()
  end

  defp update_tasks(tasks_by_column, task, _action) do
    # Remove from old column, add to new
    tasks_by_column
    |> Enum.map(fn {col_id, tasks} ->
      tasks = Enum.reject(tasks, &(&1.id == task.id))
      if col_id == task.column_id do
        {col_id, insert_task_sorted(tasks, task)}
      else
        {col_id, tasks}
      end
    end)
    |> Map.new()
  end

  defp insert_task_sorted(tasks, task) do
    (tasks ++ [task])
    |> Enum.sort_by(& &1.position)
  end
end
```

#### 2.2 BoardPage Vue Component

Create `assets/js/vue/components/BoardPage.vue`:

```vue
<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import KanbanColumn from './board/KanbanColumn.vue'
import TaskDetailsPanel from './board/TaskDetailsPanel.vue'
import BoardSettingsPanel from './settings/BoardSettingsPanel.vue'
import LoadingSpinner from './ui/LoadingSpinner.vue'
import { useDragDrop } from '../composables/useDragDrop'
import { useKeyboard } from '../composables/useKeyboard'
import { useAudio } from '../composables/useAudio'

interface Props {
  board: any
  columns: any[]
  tasksByColumn: Record<string, any[]>
  loading: boolean
  selectedTask: any | null
  showSettings: boolean
  settingsTab: string
}

const props = defineProps<Props>()
const emit = defineEmits([
  'moveTask',
  'createTask',
  'selectTask',
  'closeTaskDetails',
  'updateTask',
  'deleteTask',
  'openSettings',
  'closeSettings'
])

const searchQuery = ref('')
const { playSound } = useAudio()

// Keyboard shortcuts
useKeyboard({
  '/': () => document.querySelector<HTMLInputElement>('#search')?.focus(),
  'Escape': () => {
    if (props.selectedTask) emit('closeTaskDetails')
    else if (props.showSettings) emit('closeSettings')
  },
  ',': () => emit('openSettings')
})

// Handle hook effects from server
const handleHookExecuted = (payload: any) => {
  if (payload.effects?.play_sound) {
    playSound(payload.effects.play_sound.sound)
  }
}

// Expose for LiveView hook
defineExpose({ handleHookExecuted })

const filteredColumns = computed(() => {
  if (!searchQuery.value) return props.columns

  return props.columns.map(col => ({
    ...col,
    tasks: (props.tasksByColumn[col.id] || []).filter(task =>
      task.title.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
      task.description?.toLowerCase().includes(searchQuery.value.toLowerCase())
    )
  }))
})
</script>

<template>
  <div class="h-screen flex flex-col bg-gray-950">
    <!-- Header -->
    <header class="border-b border-gray-800 px-6 py-3 flex items-center justify-between">
      <div class="flex items-center gap-4">
        <a href="/" class="text-gray-400 hover:text-white">← Boards</a>
        <h1 class="text-lg font-semibold text-white">{{ board?.name }}</h1>
      </div>
      <div class="flex items-center gap-4">
        <input
          id="search"
          type="text"
          v-model="searchQuery"
          placeholder="Search tasks... (/)"
          class="bg-gray-800 border border-gray-700 rounded-lg px-3 py-1.5 text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500"
        />
        <button @click="emit('openSettings')" class="btn-ghost">
          Settings (,)
        </button>
      </div>
    </header>

    <!-- Main Board -->
    <main class="flex-1 overflow-x-auto p-4">
      <LoadingSpinner v-if="loading" class="mx-auto mt-20" />

      <div v-else class="flex gap-4 h-full" data-kanban-board>
        <KanbanColumn
          v-for="column in columns"
          :key="column.id"
          :column="column"
          :tasks="tasksByColumn[column.id] || []"
          :search-query="searchQuery"
          @create-task="emit('createTask', $event)"
          @select-task="emit('selectTask', $event)"
          @move-task="emit('moveTask', $event)"
        />
      </div>
    </main>

    <!-- Task Details Panel -->
    <TaskDetailsPanel
      v-if="selectedTask"
      :task="selectedTask"
      @close="emit('closeTaskDetails')"
      @update="emit('updateTask', $event)"
      @delete="emit('deleteTask', $event)"
    />

    <!-- Settings Panel -->
    <BoardSettingsPanel
      v-if="showSettings"
      :board="board"
      :active-tab="settingsTab"
      @close="emit('closeSettings')"
    />
  </div>
</template>
```

#### 2.3 KanbanColumn Vue Component

Create `assets/js/vue/components/board/KanbanColumn.vue`:

```vue
<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import TaskCard from './TaskCard.vue'
import Sortable from 'sortablejs'

interface Props {
  column: { id: string; name: string; color: string }
  tasks: any[]
  searchQuery: string
}

const props = defineProps<Props>()
const emit = defineEmits(['createTask', 'selectTask', 'moveTask'])

const taskListRef = ref<HTMLElement>()
let sortable: Sortable | null = null

const filteredTasks = computed(() => {
  if (!props.searchQuery) return props.tasks
  const query = props.searchQuery.toLowerCase()
  return props.tasks.filter(task =>
    task.title.toLowerCase().includes(query) ||
    task.description?.toLowerCase().includes(query)
  )
})

onMounted(() => {
  if (taskListRef.value) {
    sortable = Sortable.create(taskListRef.value, {
      group: 'tasks',
      animation: 150,
      handle: '[data-drag-handle]',
      ghostClass: 'opacity-50',
      onEnd: (evt) => {
        const taskId = evt.item.dataset.taskId
        const columnId = evt.to.dataset.columnId
        const prevTaskId = evt.item.previousElementSibling?.dataset.taskId
        const nextTaskId = evt.item.nextElementSibling?.dataset.taskId

        emit('moveTask', {
          task_id: taskId,
          column_id: columnId,
          prev_task_id: prevTaskId || null,
          next_task_id: nextTaskId || null
        })
      }
    })
  }
})

onUnmounted(() => {
  sortable?.destroy()
})

const showCreateInput = ref(false)
const newTaskTitle = ref('')

const handleCreateTask = () => {
  if (newTaskTitle.value.trim()) {
    emit('createTask', {
      title: newTaskTitle.value,
      column_id: props.column.id
    })
    newTaskTitle.value = ''
    showCreateInput.value = false
  }
}
</script>

<template>
  <div
    class="flex-shrink-0 w-80 bg-gray-900 rounded-xl border border-gray-800 flex flex-col"
    :style="{ borderTopColor: column.color, borderTopWidth: '3px' }"
  >
    <!-- Column Header -->
    <div class="px-4 py-3 border-b border-gray-800 flex items-center justify-between">
      <h3 class="font-medium text-white">{{ column.name }}</h3>
      <span class="text-sm text-gray-500">{{ filteredTasks.length }}</span>
    </div>

    <!-- Task List -->
    <div
      ref="taskListRef"
      :data-column-id="column.id"
      class="flex-1 overflow-y-auto p-2 space-y-2 min-h-[100px]"
    >
      <TaskCard
        v-for="task in filteredTasks"
        :key="task.id"
        :task="task"
        @click="emit('selectTask', { task_id: task.id })"
      />
    </div>

    <!-- Add Task -->
    <div class="p-2 border-t border-gray-800">
      <template v-if="showCreateInput">
        <input
          v-model="newTaskTitle"
          @keydown.enter="handleCreateTask"
          @keydown.escape="showCreateInput = false"
          placeholder="Task title..."
          class="w-full bg-gray-800 border border-gray-700 rounded px-3 py-2 text-sm text-white focus:outline-none focus:ring-2 focus:ring-brand-500"
          autofocus
        />
      </template>
      <button
        v-else
        @click="showCreateInput = true"
        class="w-full text-left px-3 py-2 text-sm text-gray-400 hover:text-white hover:bg-gray-800 rounded transition-colors"
      >
        + Add task
      </button>
    </div>
  </div>
</template>
```

---

### Phase 3: Real-time & DnD

Real-time is already set up via LiveView PubSub in Phase 2. The key pieces:

1. **Server subscribes** in `mount`:
   ```elixir
   Phoenix.PubSub.subscribe(Viban.PubSub, "kanban_lite:board:#{board_id}")
   ```

2. **Server handles broadcasts** in `handle_info`:
   ```elixir
   def handle_info({:task_changed, %{task: task, action: action}}, socket)
   ```

3. **Client receives updates** via LiveView's automatic assign diffing

4. **Hook effects** pushed via `push_event`:
   ```elixir
   {:noreply, push_event(socket, "hook_executed", payload)}
   ```

5. **Vue handles effects**:
   ```typescript
   const handleHookExecuted = (payload) => {
     if (payload.effects?.play_sound) {
       playSound(payload.effects.play_sound.sound)
     }
   }
   ```

---

### Phase 4-6: Remaining Components

Follow the same pattern for remaining features:
- Create LiveView event handlers that call Ash actions
- Create Vue components that receive props and emit events
- Use composables for shared logic (audio, keyboard, drag-drop)

---

## Testing Checklist

### Phase 0: Setup
- [ ] `mix phx.server` starts without errors
- [ ] Vite dev server runs
- [ ] Hot reload works
- [ ] CSS (Tailwind) loads correctly

### Phase 1: Auth & Home
- [ ] Home page loads
- [ ] GitHub device flow works
- [ ] User can sign in
- [ ] Boards list after login
- [ ] Create board modal works
- [ ] Board creation succeeds

### Phase 2: Board Core
- [ ] Board page loads with columns
- [ ] Tasks display in columns
- [ ] Task cards render correctly
- [ ] Task selection shows details panel

### Phase 3: Real-time
- [ ] Drag-drop moves tasks
- [ ] Move persists to database
- [ ] Other clients see updates
- [ ] Hook sounds play

### Phase 4: Task Management
- [ ] Create task works
- [ ] Edit title/description works
- [ ] Delete task works
- [ ] Subtasks display
- [ ] Generate subtasks works
- [ ] Create PR works

### Phase 5: Settings
- [ ] Board settings panel opens
- [ ] All tabs work
- [ ] Repository settings save
- [ ] Task templates CRUD
- [ ] Hooks CRUD
- [ ] Periodical tasks CRUD
- [ ] Column settings work
- [ ] Column hooks configurable

### Phase 6: Polish
- [ ] Keyboard shortcuts work
- [ ] Loading states display
- [ ] Error messages display
- [ ] No console errors
- [ ] Production build works
- [ ] Single binary deployment works

---

## Cleanup After Migration

Once LiveVue is working:

1. **Remove Hologram code:**
   ```bash
   rm -rf lib/viban_web/hologram/
   ```

2. **Remove Hologram dependency:**
   ```elixir
   # mix.exs - remove :hologram
   ```

3. **Remove old JS:**
   ```bash
   rm assets/js/phoenix-channels.js
   rm assets/js/device-flow-polling.js
   rm assets/js/task-interactions.js
   ```

4. **Update router:**
   - Remove Hologram plug
   - Use LiveView routes only

5. **Update CLAUDE.md:**
   - Remove Hologram documentation
   - Add LiveVue patterns

---

## Rollback Plan

If migration fails:
1. Hologram code is still present during migration
2. Can switch back by reverting router changes
3. Keep Hologram working until LiveVue is verified

---

## Notes for Autonomous Work

1. **Always test after each phase** before moving to next
2. **Commit after each working phase** for easy rollback
3. **Keep Hologram working** until Phase 6 cleanup
4. **Use `mix compile --warnings-as-errors`** to catch issues early
5. **Check browser console** for JavaScript errors
6. **Test in incognito** to avoid session issues
7. **If stuck on a phase**, move to next and return later

---

## Commands Reference

```bash
# Start development
cd backend && mix phx.server

# Compile check
mix compile --warnings-as-errors

# Format code
mix format

# Run tests
mix test

# Build for production
mix assets.deploy && mix release

# Check release works
_build/prod/rel/viban/bin/viban start
```
