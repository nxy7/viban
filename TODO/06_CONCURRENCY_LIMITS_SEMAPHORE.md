# Feature: In-Progress Task Concurrency Limits (Semaphore System)

## Overview

Add the ability to limit how many tasks can be actively executing (in_progress=true) within the "In Progress" column at any given time. This creates a queue-like system where tasks must acquire a "slot" before they can start execution.

**Why This Matters**:
- Prevent resource exhaustion from too many concurrent AI agents
- Control API costs by limiting parallel LLM calls
- Ensure system stability under heavy workloads
- Enable prioritization (first-in-first-out by default)

## User Stories

1. **Set Concurrency Limit**: As a user, I can set a maximum number of concurrent in-progress tasks for the In Progress column.
2. **Disable Limit**: As a user, I can disable the limit (set to unlimited) which is the default behavior.
3. **Queue Visualization**: As a user, I can see which tasks are queued vs actively running.
4. **Queue Position**: As a user, I can see a task's position in the queue.
5. **Priority Override**: As a user, I can move a queued task to the front of the queue.
6. **Automatic Start**: As a user, when a running task completes, the next queued task automatically starts.
7. **Manual Start**: As a user, I can manually start a queued task (bumping it to front of queue).

## Technical Design

### Core Concept: Semaphore as Column Setting

The concurrency limit is stored as a column setting and enforced by a semaphore-like mechanism in the BoardActor.

### Data Model Changes

#### Column Settings Extension

```elixir
# backend/lib/viban/kanban/column.ex

# Add to settings map schema (from Feature 05):
# settings: %{
#   "max_concurrent_tasks" => integer | nil,  # nil = unlimited
#   ...
# }
```

#### Task Queue State

```elixir
# backend/lib/viban/kanban/task.ex

# Add new attributes for queue management
attributes do
  # ... existing attributes ...

  # Queue status: nil (not queued), or timestamp when queued
  attribute :queued_at, :utc_datetime do
    allow_nil? true
    description "When task entered the queue (nil if not queued or running)"
  end

  # Explicit queue position for priority override
  attribute :queue_priority, :integer do
    default 0
    description "Higher = higher priority. 0 = normal FIFO ordering"
  end
end
```

#### Database Migration

```elixir
# backend/priv/repo/migrations/YYYYMMDDHHMMSS_add_task_queue_fields.exs

defmodule Viban.Repo.Migrations.AddTaskQueueFields do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :queued_at, :utc_datetime
      add :queue_priority, :integer, default: 0
    end

    # Index for efficient queue ordering
    create index(:tasks, [:column_id, :queue_priority, :queued_at])
  end
end
```

### Semaphore Implementation

#### Column Semaphore GenServer

```elixir
# backend/lib/viban/kanban/actors/column_semaphore.ex

defmodule Viban.Kanban.Actors.ColumnSemaphore do
  @moduledoc """
  Manages concurrency limits for a column.

  Acts as a semaphore that:
  - Tracks currently running tasks
  - Queues tasks when at capacity
  - Releases slots when tasks complete
  - Automatically starts next queued task

  Only active when column has max_concurrent_tasks setting.
  """

  use GenServer
  require Logger

  alias Viban.Kanban
  alias Phoenix.PubSub

  defstruct [
    :column_id,
    :max_concurrent,
    :running_tasks,    # MapSet of task_ids currently running
    :queue             # :queue of task_ids waiting
  ]

  # Client API

  def start_link(column_id) do
    GenServer.start_link(__MODULE__, column_id, name: via_tuple(column_id))
  end

  def via_tuple(column_id) do
    {:via, Registry, {Viban.Kanban.ActorRegistry, {:column_semaphore, column_id}}}
  end

  @doc """
  Request to start execution for a task.
  Returns :ok if slot acquired, {:queued, position} if queued.
  """
  def request_start(column_id, task_id) do
    case GenServer.whereis(via_tuple(column_id)) do
      nil ->
        # No semaphore = no limits
        :ok
      pid ->
        GenServer.call(pid, {:request_start, task_id})
    end
  end

  @doc """
  Notify that a task has completed (releases slot).
  """
  def task_completed(column_id, task_id) do
    case GenServer.whereis(via_tuple(column_id)) do
      nil -> :ok
      pid -> GenServer.cast(pid, {:task_completed, task_id})
    end
  end

  @doc """
  Move a task to the front of the queue.
  """
  def prioritize(column_id, task_id) do
    case GenServer.whereis(via_tuple(column_id)) do
      nil -> {:error, :no_semaphore}
      pid -> GenServer.call(pid, {:prioritize, task_id})
    end
  end

  @doc """
  Update the max concurrent limit.
  """
  def update_limit(column_id, new_limit) do
    case GenServer.whereis(via_tuple(column_id)) do
      nil -> {:error, :no_semaphore}
      pid -> GenServer.call(pid, {:update_limit, new_limit})
    end
  end

  @doc """
  Get current queue status.
  """
  def get_status(column_id) do
    case GenServer.whereis(via_tuple(column_id)) do
      nil -> {:ok, %{limited: false}}
      pid -> GenServer.call(pid, :get_status)
    end
  end

  # Server Callbacks

  @impl true
  def init(column_id) do
    column = Kanban.get_column!(column_id)
    max = get_in(column.settings || %{}, ["max_concurrent_tasks"])

    if is_nil(max) or max < 1 do
      # No valid limit, don't start semaphore
      :ignore
    else
      # Subscribe to task updates in this column
      PubSub.subscribe(Viban.PubSub, "column:#{column_id}:tasks")

      # Find currently running tasks
      running = column
        |> Kanban.list_tasks_in_column()
        |> Enum.filter(& &1.in_progress)
        |> Enum.map(& &1.id)
        |> MapSet.new()

      # Find queued tasks (ordered by priority then queued_at)
      queued = column
        |> Kanban.list_tasks_in_column()
        |> Enum.filter(& &1.queued_at != nil)
        |> Enum.sort_by(&{-(&1.queue_priority || 0), &1.queued_at})
        |> Enum.map(& &1.id)
        |> :queue.from_list()

      state = %__MODULE__{
        column_id: column_id,
        max_concurrent: max,
        running_tasks: running,
        queue: queued
      }

      Logger.info("ColumnSemaphore started for column #{column_id} with limit #{max}")

      {:ok, state}
    end
  end

  @impl true
  def handle_call({:request_start, task_id}, _from, state) do
    cond do
      # Already running
      MapSet.member?(state.running_tasks, task_id) ->
        {:reply, :ok, state}

      # Has capacity
      MapSet.size(state.running_tasks) < state.max_concurrent ->
        new_running = MapSet.put(state.running_tasks, task_id)
        {:reply, :ok, %{state | running_tasks: new_running}}

      # At capacity, queue it
      true ->
        # Add to queue
        new_queue = :queue.in(task_id, state.queue)
        position = :queue.len(new_queue)

        # Mark task as queued in database
        queue_task(task_id)

        Logger.info("Task #{task_id} queued at position #{position}")

        {:reply, {:queued, position}, %{state | queue: new_queue}}
    end
  end

  @impl true
  def handle_call({:prioritize, task_id}, _from, state) do
    # Remove from current position and add to front
    queue_list = :queue.to_list(state.queue)

    if task_id in queue_list do
      new_list = [task_id | List.delete(queue_list, task_id)]
      new_queue = :queue.from_list(new_list)

      # Update priority in database
      update_task_priority(task_id, 1000)

      {:reply, :ok, %{state | queue: new_queue}}
    else
      {:reply, {:error, :not_in_queue}, state}
    end
  end

  @impl true
  def handle_call({:update_limit, new_limit}, _from, state) do
    Logger.info("Updating concurrency limit from #{state.max_concurrent} to #{new_limit}")

    new_state = %{state | max_concurrent: new_limit}

    # If we now have more capacity, start queued tasks
    new_state = maybe_start_queued(new_state)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      limited: true,
      max_concurrent: state.max_concurrent,
      running_count: MapSet.size(state.running_tasks),
      running_tasks: MapSet.to_list(state.running_tasks),
      queue_length: :queue.len(state.queue),
      queued_tasks: :queue.to_list(state.queue)
    }
    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_cast({:task_completed, task_id}, state) do
    if MapSet.member?(state.running_tasks, task_id) do
      Logger.info("Task #{task_id} completed, releasing slot")

      new_running = MapSet.delete(state.running_tasks, task_id)
      new_state = %{state | running_tasks: new_running}

      # Try to start next queued task
      new_state = maybe_start_queued(new_state)

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  # Handle task leaving the column
  @impl true
  def handle_info({:task_left_column, task_id}, state) do
    # Remove from running or queue
    new_running = MapSet.delete(state.running_tasks, task_id)
    queue_list = :queue.to_list(state.queue) |> List.delete(task_id)
    new_queue = :queue.from_list(queue_list)

    new_state = %{state | running_tasks: new_running, queue: new_queue}
    new_state = maybe_start_queued(new_state)

    {:noreply, new_state}
  end

  # Private Functions

  defp maybe_start_queued(state) do
    available_slots = state.max_concurrent - MapSet.size(state.running_tasks)

    if available_slots > 0 and not :queue.is_empty(state.queue) do
      {{:value, next_task_id}, new_queue} = :queue.out(state.queue)

      Logger.info("Starting queued task #{next_task_id}")

      # Clear queued status and trigger execution
      start_queued_task(next_task_id)

      new_running = MapSet.put(state.running_tasks, next_task_id)
      new_state = %{state | running_tasks: new_running, queue: new_queue}

      # Recursively start more if we still have capacity
      maybe_start_queued(new_state)
    else
      state
    end
  end

  defp queue_task(task_id) do
    task = Kanban.get_task!(task_id)
    Kanban.update_task(task, %{
      queued_at: DateTime.utc_now(),
      agent_status: :idle,
      agent_status_message: "Waiting in queue..."
    })
  end

  defp start_queued_task(task_id) do
    task = Kanban.get_task!(task_id)

    # Clear queue status
    Kanban.update_task(task, %{
      queued_at: nil,
      queue_priority: 0
    })

    # Trigger execution via BoardActor/TaskActor
    PubSub.broadcast(Viban.PubSub, "task:#{task_id}:execute", :start_execution)
  end

  defp update_task_priority(task_id, priority) do
    task = Kanban.get_task!(task_id)
    Kanban.update_task(task, %{queue_priority: priority})
  end
end
```

### Integration with Existing Actors

#### BoardActor Updates

```elixir
# backend/lib/viban/kanban/actors/board_actor.ex

defmodule Viban.Kanban.Actors.BoardActor do
  # ... existing code ...

  # Start semaphores for columns with limits
  defp start_column_semaphores(board) do
    for column <- board.columns,
        max = get_in(column.settings || %{}, ["max_concurrent_tasks"]),
        is_integer(max) and max >= 1 do
      DynamicSupervisor.start_child(
        {:via, Registry, {Viban.Kanban.ActorRegistry, {:board_supervisor, board.id}}},
        {Viban.Kanban.Actors.ColumnSemaphore, column.id}
      )
    end
  end

  # Handle column settings updates
  def handle_info({:column_settings_updated, column_id, settings}, state) do
    max = get_in(settings, ["max_concurrent_tasks"])

    if is_integer(max) and max >= 1 do
      # Start semaphore if not running
      case GenServer.whereis(ColumnSemaphore.via_tuple(column_id)) do
        nil ->
          DynamicSupervisor.start_child(
            {:via, Registry, {Viban.Kanban.ActorRegistry, {:board_supervisor, state.board_id}}},
            {ColumnSemaphore, column_id}
          )
        pid ->
          # Update existing semaphore
          ColumnSemaphore.update_limit(column_id, max)
      end
    else
      # Stop semaphore if limit removed
      case GenServer.whereis(ColumnSemaphore.via_tuple(column_id)) do
        nil -> :ok
        pid -> GenServer.stop(pid, :normal)
      end
    end

    {:noreply, state}
  end
end
```

#### Executor Integration

```elixir
# backend/lib/viban/executors/executor.ex

defmodule Viban.Executors.Executor do
  # ... existing code ...

  action :execute do
    # ... existing arguments ...

    run fn input, _context ->
      task = Viban.Kanban.get_task!(input.arguments.task_id)
      column = task.column

      # Check semaphore before starting
      case Viban.Kanban.Actors.ColumnSemaphore.request_start(column.id, task.id) do
        :ok ->
          # Proceed with execution
          do_execute(task, input.arguments)

        {:queued, position} ->
          # Task was queued, don't start execution
          Logger.info("Task #{task.id} queued at position #{position}")
          {:ok, %{status: :queued, position: position}}
      end
    end
  end

  defp do_execute(task, args) do
    # ... existing execution logic ...
  end
end
```

#### TaskActor Updates

```elixir
# backend/lib/viban/kanban/actors/task_actor.ex

defmodule Viban.Kanban.Actors.TaskActor do
  # ... existing code ...

  # Subscribe to execution trigger
  def init(task_id) do
    # ... existing init ...
    PubSub.subscribe(Viban.PubSub, "task:#{task_id}:execute")
    # ...
  end

  # Handle deferred execution from semaphore
  def handle_info(:start_execution, state) do
    task = Kanban.get_task!(state.task_id)

    # Re-trigger the execution that was originally requested
    case state.pending_execution do
      nil ->
        {:noreply, state}

      {executor_type, prompt, opts} ->
        Executor.execute(task.id, prompt, executor_type, opts)
        {:noreply, %{state | pending_execution: nil}}
    end
  end

  # When task completes, notify semaphore
  def handle_info({:task_completed, task_id}, state) do
    task = Kanban.get_task!(task_id)
    ColumnSemaphore.task_completed(task.column_id, task_id)
    {:noreply, state}
  end
end
```

### Frontend Changes

#### Column Settings - Concurrency Tab

```tsx
// frontend/src/components/ColumnSettingsPopup/ConcurrencySettings.tsx

interface Props {
  column: Column;
}

export function ConcurrencySettings(props: Props) {
  const isInProgressColumn = () => props.column.name === "In Progress";

  // Only show for In Progress column
  if (!isInProgressColumn()) {
    return (
      <div class="text-center py-8 text-zinc-500">
        <p>Concurrency limits are only available for the "In Progress" column.</p>
      </div>
    );
  }

  const [enabled, setEnabled] = createSignal(
    props.column.settings?.max_concurrent_tasks != null
  );
  const [limit, setLimit] = createSignal(
    props.column.settings?.max_concurrent_tasks || 3
  );
  const [isSaving, setIsSaving] = createSignal(false);

  // Get queue status
  const [queueStatus] = createResource(
    () => props.column.id,
    async (columnId) => {
      const res = await fetch(`/api/columns/${columnId}/queue-status`);
      return res.json();
    }
  );

  const handleSave = async () => {
    setIsSaving(true);
    try {
      await updateColumnSettings(props.column.id, {
        max_concurrent_tasks: enabled() ? limit() : null,
      });
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div class="space-y-6">
      {/* Enable/Disable Toggle */}
      <div class="flex items-center justify-between">
        <div>
          <h4 class="font-medium text-zinc-200">Limit Concurrent Tasks</h4>
          <p class="text-sm text-zinc-500">
            Control how many tasks can run simultaneously
          </p>
        </div>
        <Toggle
          checked={enabled()}
          onChange={(checked) => {
            setEnabled(checked);
            if (!checked) {
              // Save immediately when disabling
              updateColumnSettings(props.column.id, {
                max_concurrent_tasks: null,
              });
            }
          }}
        />
      </div>

      {/* Limit Configuration */}
      <Show when={enabled()}>
        <div class="space-y-4 pl-4 border-l-2 border-purple-500/30">
          <div>
            <label class="block text-sm font-medium text-zinc-300 mb-2">
              Maximum Concurrent Tasks
            </label>
            <div class="flex items-center gap-3">
              <input
                type="number"
                min={1}
                max={100}
                value={limit()}
                onInput={(e) => setLimit(parseInt(e.currentTarget.value) || 1)}
                class="w-24 px-3 py-2 bg-zinc-900 border border-zinc-700 rounded-md text-center"
              />
              <span class="text-zinc-400">tasks at once</span>
            </div>
          </div>

          {/* Current Status */}
          <Show when={queueStatus()}>
            <div class="bg-zinc-900/50 rounded-lg p-4 space-y-2">
              <h5 class="text-sm font-medium text-zinc-300">Current Status</h5>

              <div class="flex items-center gap-4">
                <div class="flex items-center gap-2">
                  <div class="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
                  <span class="text-sm text-zinc-400">
                    {queueStatus().running_count} running
                  </span>
                </div>

                <Show when={queueStatus().queue_length > 0}>
                  <div class="flex items-center gap-2">
                    <div class="w-2 h-2 rounded-full bg-yellow-500" />
                    <span class="text-sm text-zinc-400">
                      {queueStatus().queue_length} queued
                    </span>
                  </div>
                </Show>
              </div>

              {/* Capacity indicator */}
              <div class="h-2 bg-zinc-700 rounded-full overflow-hidden">
                <div
                  class="h-full bg-gradient-to-r from-green-500 to-green-600 transition-all"
                  style={{
                    width: `${(queueStatus().running_count / limit()) * 100}%`,
                  }}
                />
              </div>
              <p class="text-xs text-zinc-500">
                {queueStatus().running_count} of {limit()} slots used
              </p>
            </div>
          </Show>

          {/* Save button */}
          <button
            onClick={handleSave}
            disabled={isSaving()}
            class="w-full py-2 text-sm bg-purple-600 hover:bg-purple-700
                   disabled:opacity-50 rounded-md font-medium"
          >
            {isSaving() ? "Saving..." : "Save Limit"}
          </button>
        </div>
      </Show>

      {/* Info box */}
      <div class="bg-blue-500/10 border border-blue-500/20 rounded-lg p-3">
        <p class="text-sm text-blue-300">
          <InfoIcon class="w-4 h-4 inline mr-1" />
          When the limit is reached, new tasks will queue and start automatically
          when a slot becomes available.
        </p>
      </div>
    </div>
  );
}
```

#### Task Card - Queue Status

```tsx
// frontend/src/components/TaskCard.tsx

interface Props {
  task: Task;
}

export function TaskCard(props: Props) {
  const isQueued = () => props.task.queued_at != null;
  const isRunning = () => props.task.in_progress;

  // Queue position from task or calculated
  const queuePosition = () => {
    // This would come from the backend or be calculated client-side
    return props.task.queue_position || null;
  };

  return (
    <div
      class={`p-3 rounded-lg border transition-all ${
        isQueued()
          ? "bg-zinc-800/50 border-zinc-700/50 opacity-70"  // Queued: semi-transparent
          : isRunning()
          ? "bg-zinc-800 border-blue-500/50"  // Running: highlighted
          : "bg-zinc-800 border-zinc-700"      // Normal
      }`}
    >
      <div class="flex items-start justify-between gap-2">
        <h4 class="font-medium text-zinc-100 line-clamp-2">
          {props.task.title}
        </h4>

        {/* Status badge */}
        <Show when={isQueued()}>
          <span class="flex items-center gap-1 px-1.5 py-0.5 text-xs
                       bg-yellow-500/20 text-yellow-400 rounded shrink-0">
            <ClockIcon class="w-3 h-3" />
            <Show when={queuePosition()} fallback="Queued">
              #{queuePosition()}
            </Show>
          </span>
        </Show>

        <Show when={isRunning() && !isQueued()}>
          <span class="flex items-center gap-1 px-1.5 py-0.5 text-xs
                       bg-blue-500/20 text-blue-400 rounded shrink-0">
            <RunningIcon class="w-3 h-3 animate-spin" />
            Running
          </span>
        </Show>
      </div>

      {/* Queue message */}
      <Show when={isQueued()}>
        <p class="text-xs text-zinc-500 mt-2 flex items-center gap-1">
          <ClockIcon class="w-3 h-3" />
          Waiting for available slot...
          <button
            onClick={() => prioritizeTask(props.task.id)}
            class="text-purple-400 hover:text-purple-300 ml-auto"
            title="Move to front of queue"
          >
            Prioritize
          </button>
        </p>
      </Show>

      {/* Agent status */}
      <Show when={props.task.agent_status !== "idle" && !isQueued()}>
        <div class="mt-2 text-xs text-zinc-400">
          <AgentStatusIndicator
            status={props.task.agent_status}
            message={props.task.agent_status_message}
          />
        </div>
      </Show>
    </div>
  );
}
```

#### Column Header - Queue Indicator

```tsx
// frontend/src/components/KanbanColumn.tsx (updated header)

// In the header section:
<div class="flex items-center gap-2">
  <h3 class="font-semibold text-zinc-100">{props.column.name}</h3>
  <span class="text-xs text-zinc-500 bg-zinc-800 px-1.5 py-0.5 rounded">
    {taskCount()}
  </span>

  {/* Concurrency indicator for In Progress column */}
  <Show when={props.column.name === "In Progress" && hasConcurrencyLimit()}>
    <ConcurrencyIndicator
      running={runningCount()}
      queued={queuedCount()}
      limit={concurrencyLimit()}
    />
  </Show>
</div>

// ConcurrencyIndicator component
function ConcurrencyIndicator(props: {
  running: number;
  queued: number;
  limit: number;
}) {
  const atCapacity = () => props.running >= props.limit;

  return (
    <div class="flex items-center gap-1">
      {/* Running indicator */}
      <span class={`text-xs px-1.5 py-0.5 rounded flex items-center gap-1 ${
        atCapacity()
          ? "bg-yellow-500/20 text-yellow-400"
          : "bg-green-500/20 text-green-400"
      }`}>
        <Show when={props.running > 0}>
          <RunningIcon class="w-3 h-3 animate-pulse" />
        </Show>
        {props.running}/{props.limit}
      </span>

      {/* Queued indicator */}
      <Show when={props.queued > 0}>
        <span class="text-xs px-1.5 py-0.5 rounded bg-zinc-700 text-zinc-400
                     flex items-center gap-1">
          <ClockIcon class="w-3 h-3" />
          +{props.queued}
        </span>
      </Show>
    </div>
  );
}
```

### API Endpoints

```elixir
# backend/lib/viban_web/router.ex

scope "/api", VibanWeb do
  pipe_through :api

  # Queue status
  get "/columns/:id/queue-status", ColumnController, :queue_status

  # Task prioritization
  post "/tasks/:id/prioritize", TaskController, :prioritize
end

# backend/lib/viban_web/controllers/column_controller.ex

def queue_status(conn, %{"id" => column_id}) do
  case ColumnSemaphore.get_status(column_id) do
    {:ok, status} ->
      json(conn, status)
    {:error, :no_semaphore} ->
      json(conn, %{limited: false})
  end
end

# backend/lib/viban_web/controllers/task_controller.ex

def prioritize(conn, %{"id" => task_id}) do
  task = Kanban.get_task!(task_id)

  case ColumnSemaphore.prioritize(task.column_id, task_id) do
    :ok ->
      json(conn, %{success: true})
    {:error, reason} ->
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: inspect(reason)})
  end
end
```

### Real-Time Updates

```elixir
# backend/lib/viban_web/channels/board_channel.ex

# Subscribe to queue updates
def join("board:" <> board_id, _params, socket) do
  # ... existing join logic ...

  # Subscribe to queue status changes
  PubSub.subscribe(Viban.PubSub, "board:#{board_id}:queue")

  {:ok, socket}
end

# Broadcast queue changes
def handle_info({:queue_updated, column_id, status}, socket) do
  push(socket, "queue_updated", %{
    column_id: column_id,
    status: status
  })
  {:noreply, socket}
end
```

```typescript
// frontend/src/lib/useBoard.ts

// Subscribe to queue updates
channel.on("queue_updated", (payload) => {
  updateColumnQueueStatus(payload.column_id, payload.status);
});
```

## Visual Design

### Queued Task Appearance

```
┌─────────────────────────────────────────┐
│  Normal Task                            │
│  ┌─────────────────────────────────────┐
│  │ Implement user auth          🔵     │ ← Solid, full opacity
│  │                                     │
│  │ 🤖 Thinking...                      │
│  └─────────────────────────────────────┘
│                                         │
│  Queued Task                            │
│  ┌─────────────────────────────────────┐
│  │ Add payment flow         ⏱️ #2     │ ← Semi-transparent
│  │                                     │    with queue position
│  │ Waiting for available slot...       │
│  │                     [Prioritize]    │
│  └─────────────────────────────────────┘
└─────────────────────────────────────────┘
```

### Column Header with Queue Status

```
┌─────────────────────────────────────────────────┐
│ In Progress  (5)  🟢 2/3  ⏱️+2  ⚙️              │
│              │    └────┘  └──┘   │              │
│              │      │      │     └── Settings    │
│              │      │      └── 2 queued          │
│              │      └── 2 running of 3 max       │
│              └── Total tasks                     │
└─────────────────────────────────────────────────┘
```

### Concurrency Settings Panel

```
┌────────────────────────────────────┐
│ Concurrency                        │
├────────────────────────────────────┤
│                                    │
│ Limit Concurrent Tasks      [ON]   │
│ Control how many tasks can run     │
│                                    │
│ ┌────────────────────────────────┐ │
│ │ Maximum Concurrent Tasks       │ │
│ │                                │ │
│ │ [ 3 ] tasks at once            │ │
│ │                                │ │
│ │ ┌────────────────────────────┐ │ │
│ │ │ Current Status             │ │ │
│ │ │                            │ │ │
│ │ │ 🟢 2 running   ⏱️ 1 queued │ │ │
│ │ │                            │ │ │
│ │ │ ████████░░░░░░░░  2/3     │ │ │
│ │ │ 2 of 3 slots used          │ │ │
│ │ └────────────────────────────┘ │ │
│ │                                │ │
│ │ [       Save Limit       ]     │ │
│ └────────────────────────────────┘ │
│                                    │
│ ┌────────────────────────────────┐ │
│ │ ℹ️ When the limit is reached,  │ │
│ │ new tasks will queue and start │ │
│ │ automatically when a slot      │ │
│ │ becomes available.             │ │
│ └────────────────────────────────┘ │
└────────────────────────────────────┘
```

## Implementation Steps

### Phase 1: Database & Models (Day 1)
1. Create migration for task queue fields
2. Update Task resource with queued_at and queue_priority
3. Ensure Column settings support max_concurrent_tasks
4. Test model changes

### Phase 2: Semaphore GenServer (Day 2)
1. Create ColumnSemaphore GenServer
2. Implement request_start, task_completed, prioritize
3. Add queue management logic
4. Test semaphore in isolation

### Phase 3: Actor Integration (Day 2-3)
1. Update BoardActor to start/stop semaphores
2. Integrate with Executor to check semaphore
3. Add PubSub for execution triggers
4. Test full execution flow

### Phase 4: Frontend - Settings (Day 3)
1. Add ConcurrencySettings to ColumnSettingsPopup
2. Add queue status API and display
3. Add save functionality

### Phase 5: Frontend - Visualization (Day 4)
1. Update TaskCard for queued state
2. Add ConcurrencyIndicator to column header
3. Add prioritize button functionality
4. Add real-time queue updates

### Phase 6: Polish & Testing (Day 5)
1. Add animations for queue transitions
2. Handle edge cases (task deletion while queued, etc.)
3. Add comprehensive tests
4. Documentation

## Success Criteria

- [ ] User can enable concurrency limit for In Progress column
- [ ] Limit can be set to any positive integer (1+)
- [ ] Limit can be disabled (returns to unlimited)
- [ ] Tasks beyond limit are queued with visible indicator
- [ ] Queued tasks show their position in queue
- [ ] Queue position updates in real-time
- [ ] Completed task automatically starts next queued task
- [ ] User can prioritize a queued task
- [ ] Queued tasks appear semi-transparent
- [ ] Running tasks show normal state (not queued)
- [ ] Feature doesn't break existing functionality when disabled

## Technical Considerations

1. **Race Conditions**: Use GenServer to ensure atomic slot allocation
2. **Persistence**: Queue state reconstructed on restart from database
3. **Task Deletion**: Remove from queue when task is deleted
4. **Column Change**: Clear queue status when task moves out of column
5. **Multiple Boards**: Each board/column has independent semaphore
6. **Memory**: Clean up semaphore when column limit is removed

## Edge Cases to Handle

1. **Task deleted while queued**: Remove from queue, don't trigger execution
2. **Task moved to different column while queued**: Remove from queue
3. **Limit reduced below current running count**: Don't kill running tasks, just prevent new starts
4. **Limit increased**: Immediately start queued tasks up to new limit
5. **Server restart**: Reconstruct queue from database on startup
6. **Task manually moved to Done while queued**: Remove from queue

## Future Enhancements

1. **Priority Levels**: Support multiple priority levels (high, normal, low)
2. **Time-based Scheduling**: Schedule task execution for specific times
3. **Resource-based Limits**: Limit based on API cost, not just count
4. **Per-Executor Limits**: Different limits for different executors
5. **Queue Visualization**: Dedicated queue view/panel
6. **Queue Analytics**: Track wait times, throughput, etc.
7. **Auto-scaling**: Dynamically adjust limits based on system load
