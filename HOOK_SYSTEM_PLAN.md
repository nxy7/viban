# Kanban Hook System - Phase 2 Implementation Plan

## Overview

Building on the Kanban MVP, this phase adds a **hook system with lifecycle management** that allows columns to execute shell commands when tasks enter/leave, with proper cleanup handling. We also add **git worktree integration** for task isolation and **MCP exposure via Ash AI** to allow AI agents to manage tasks.

**New Features:**
- Column hooks with `on_entry`, `on_leave`, and persistent `hooks` (running during task presence)
- Automatic hook deduplication (skip re-running when moving between columns with same hooks)
- Git worktree creation per task for isolated development environments
- Project-repository associations
- Actor-based state management using `Phoenix.Sync.Shape` for reactive task/column monitoring
- MCP server exposing Kanban actions to AI agents

**Tech Stack Additions:**
- **Phoenix.Sync.Shape** - For subscribing to database changes in GenServers
- **Ash AI** - For MCP integration
- **System.cmd/3** - For executing shell hooks

---

## Architecture: Mental Model for Hook System

### Core Concepts

#### 1. Hook Definition

A **Hook** is a named, reusable shell command configuration:

```elixir
%Hook{
  id: "docker-compose-up",
  name: "Docker Compose",
  command: "docker compose up -d",
  cleanup_command: "docker compose down",  # Optional
  working_directory: :worktree,             # :worktree | :project_root | absolute path
  timeout_ms: 30_000
}
```

It can be any script if user provides SHEBANG

#### 2. Column Hook Configuration

Each column can reference hooks in three ways:

| Hook Type | When Executed | Example |
|-----------|---------------|---------|
| `on_entry` | Once when task enters column | "Send Slack notification" |
| `on_leave` | Once when task leaves column | "Archive build artifacts" |
| `hooks` | Started on entry, cleaned up on leave | "docker compose up -d" / "docker compose down" |

#### 3. Hook Lifecycle & Deduplication

**Key Insight:** Persistent hooks (`hooks`) should NOT be cleaned up when moving between columns that share the same hook.

```
Column A (hooks: [docker])  →  Column B (hooks: [docker])
    Task enters A: docker compose up -d
    Task moves A→B: NO cleanup, NO restart (same hook)
    Task leaves B for C (no docker hook): docker compose down
```

**Order of Operations on Task Move (A → B):**

1. Calculate hook diff: `leaving_hooks = A.hooks - B.hooks`, `entering_hooks = B.hooks - A.hooks`
2. Run `A.on_leave` commands
3. Run cleanup for `leaving_hooks` (hooks in A but not in B)
4. Run `B.on_entry` commands
5. Start `entering_hooks` (hooks in B but not in A)

#### 4. Actor Model

Two types of actors manage the system:

```
┌─────────────────────────────────────────────────────────────┐
│                    Supervision Tree                          │
├─────────────────────────────────────────────────────────────┤
│  BoardSupervisor (per board)                                │
│    ├── BoardActor (subscribes to columns/tasks shapes)      │
│    │     └── Spawns/terminates TaskActors on task changes   │
│    │                                                         │
│    └── TaskActors (one per task, DynamicSupervisor)         │
│          ├── TaskActor[task-1] (manages hooks for task 1)   │
│          ├── TaskActor[task-2] (manages hooks for task 2)   │
│          └── ...                                            │
└─────────────────────────────────────────────────────────────┘
```

**BoardActor Responsibilities:**
- Subscribe to `Phoenix.Sync.Shape` for tasks in this board
- On task insert: spawn TaskActor
- On task delete: terminate TaskActor (triggers cleanup)
- On task update (column change): notify TaskActor

**TaskActor Responsibilities:**
- Track current column and running hooks
- On column change: calculate hook diff, run cleanup/startup
- Maintain worktree path
- On termination: cleanup all running hooks, optionally delete worktree

---

## Phase 2: Backend Implementation

### 2.1 New Ash Resources

#### Hook Resource

**File:** `backend/lib/viban/kanban/hook.ex`

```elixir
defmodule Viban.Kanban.Hook do
  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  postgres do
    table "hooks"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :command, :string, allow_nil?: false
    attribute :cleanup_command, :string  # Optional
    attribute :working_directory, :atom,
      constraints: [one_of: [:worktree, :project_root]],
      default: :worktree
    attribute :timeout_ms, :integer, default: 30_000
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :board, Viban.Kanban.Board, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :command, :cleanup_command, :working_directory, :timeout_ms, :board_id]
    end

    update :update do
      accept [:name, :command, :cleanup_command, :working_directory, :timeout_ms]
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
  end
end
```

#### ColumnHook Join Resource (for persistent hooks)

**File:** `backend/lib/viban/kanban/column_hook.ex`

```elixir
defmodule Viban.Kanban.ColumnHook do
  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  postgres do
    table "column_hooks"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :hook_type, :atom,
      constraints: [one_of: [:on_entry, :on_leave, :persistent]],
      allow_nil?: false
    attribute :position, :integer, default: 0  # Execution order
  end

  relationships do
    belongs_to :column, Viban.Kanban.Column, allow_nil?: false
    belongs_to :hook, Viban.Kanban.Hook, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:hook_type, :position, :column_id, :hook_id]
    end
  end
end
```

#### Repository Resource

**File:** `backend/lib/viban/kanban/repository.ex`

```elixir
defmodule Viban.Kanban.Repository do
  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  postgres do
    table "repositories"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :path, :string, allow_nil?: false  # Absolute path to git repo
    attribute :default_branch, :string, default: "main"
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :board, Viban.Kanban.Board, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :path, :default_branch, :board_id]
    end

    update :update do
      accept [:name, :path, :default_branch]
    end
  end
end
```

#### Update Task Resource (add worktree tracking)

**File:** `backend/lib/viban/kanban/task.ex` (modifications)

Add to attributes:
```elixir
attribute :worktree_path, :string  # Path to git worktree for this task
attribute :worktree_branch, :string  # Branch name for this task
```

Add new action:
```elixir
update :assign_worktree do
  accept [:worktree_path, :worktree_branch]
end
```

### 2.2 Update Board Resource

Add relationship to repositories:
```elixir
relationships do
  has_many :columns, Viban.Kanban.Column
  has_many :repositories, Viban.Kanban.Repository
  has_many :hooks, Viban.Kanban.Hook
end
```

### 2.3 Update Column Resource

Add relationship to column_hooks:
```elixir
relationships do
  belongs_to :board, Viban.Kanban.Board, allow_nil?: false
  has_many :tasks, Viban.Kanban.Task
  has_many :column_hooks, Viban.Kanban.ColumnHook
end
```

### 2.4 Update Kanban Domain

**File:** `backend/lib/viban/kanban.ex`

```elixir
defmodule Viban.Kanban do
  use Ash.Domain,
    extensions: [AshTypescript.Domain, AshAi]

  resources do
    resource Viban.Kanban.Board
    resource Viban.Kanban.Column
    resource Viban.Kanban.Task
    resource Viban.Kanban.Hook
    resource Viban.Kanban.ColumnHook
    resource Viban.Kanban.Repository
  end

  # MCP Tool Definitions
  tools do
    tool :list_boards, Viban.Kanban.Board, :read
    tool :create_task, Viban.Kanban.Task, :create
    tool :update_task, Viban.Kanban.Task, :update
    tool :move_task, Viban.Kanban.Task, :move
    tool :delete_task, Viban.Kanban.Task, :destroy
    tool :list_tasks, Viban.Kanban.Task, :read
    tool :list_columns, Viban.Kanban.Column, :read
  end
end
```

### 2.5 Database Migrations

Create migrations for:
- `hooks` table
- `column_hooks` join table
- `repositories` table
- Add `worktree_path` and `worktree_branch` to `tasks` table

### 2.6 Actor Implementation

#### Board Supervisor

**File:** `backend/lib/viban/kanban/actors/board_supervisor.ex`

```elixir
defmodule Viban.Kanban.Actors.BoardSupervisor do
  use Supervisor

  def start_link(board_id) do
    Supervisor.start_link(__MODULE__, board_id, name: via_tuple(board_id))
  end

  def via_tuple(board_id) do
    {:via, Registry, {Viban.Kanban.ActorRegistry, {:board_supervisor, board_id}}}
  end

  @impl true
  def init(board_id) do
    children = [
      {DynamicSupervisor, name: task_supervisor_name(board_id), strategy: :one_for_one},
      {Viban.Kanban.Actors.BoardActor, board_id}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  defp task_supervisor_name(board_id) do
    {:via, Registry, {Viban.Kanban.ActorRegistry, {:task_supervisor, board_id}}}
  end
end
```

#### Board Actor

**File:** `backend/lib/viban/kanban/actors/board_actor.ex`

```elixir
defmodule Viban.Kanban.Actors.BoardActor do
  use GenServer
  require Logger

  alias Viban.Kanban.Task
  alias Viban.Kanban.Actors.TaskActor

  def start_link(board_id) do
    GenServer.start_link(__MODULE__, board_id, name: via_tuple(board_id))
  end

  def via_tuple(board_id) do
    {:via, Registry, {Viban.Kanban.ActorRegistry, {:board_actor, board_id}}}
  end

  @impl true
  def init(board_id) do
    # Start shape for tasks in this board
    {:ok, shape_pid} = Phoenix.Sync.Shape.start_link(
      Ecto.Query.from(t in Task, where: t.board_id == ^board_id),
      name: shape_name(board_id)
    )

    # Subscribe to changes
    ref = Phoenix.Sync.Shape.subscribe(shape_name(board_id))

    # Spawn actors for existing tasks
    spawn_existing_task_actors(board_id)

    {:ok, %{board_id: board_id, shape_ref: ref, shape_pid: shape_pid}}
  end

  @impl true
  def handle_info({:sync, ref, {:insert, {_key, task}}}, %{shape_ref: ref} = state) do
    Logger.info("Task inserted: #{task.id}")
    spawn_task_actor(state.board_id, task)
    {:noreply, state}
  end

  def handle_info({:sync, ref, {:update, {_key, task}}}, %{shape_ref: ref} = state) do
    Logger.info("Task updated: #{task.id}")
    notify_task_actor(task)
    {:noreply, state}
  end

  def handle_info({:sync, ref, {:delete, {_key, task}}}, %{shape_ref: ref} = state) do
    Logger.info("Task deleted: #{task.id}")
    terminate_task_actor(state.board_id, task.id)
    {:noreply, state}
  end

  def handle_info({:sync, ref, :up_to_date}, %{shape_ref: ref} = state) do
    {:noreply, state}
  end

  def handle_info({:sync, ref, :must_refetch}, %{shape_ref: ref} = state) do
    Logger.warn("Shape must refetch for board #{state.board_id}")
    {:noreply, state}
  end

  # Private functions
  defp shape_name(board_id), do: {:via, Registry, {Viban.Kanban.ActorRegistry, {:task_shape, board_id}}}

  defp spawn_existing_task_actors(board_id) do
    # Load existing tasks and spawn actors
    Task.read!()
    |> Enum.filter(&(&1.board_id == board_id))
    |> Enum.each(&spawn_task_actor(board_id, &1))
  end

  defp spawn_task_actor(board_id, task) do
    DynamicSupervisor.start_child(
      task_supervisor_name(board_id),
      {TaskActor, {board_id, task}}
    )
  end

  defp notify_task_actor(task) do
    case Registry.lookup(Viban.Kanban.ActorRegistry, {:task_actor, task.id}) do
      [{pid, _}] -> GenServer.cast(pid, {:task_updated, task})
      [] -> :ok
    end
  end

  defp terminate_task_actor(board_id, task_id) do
    case Registry.lookup(Viban.Kanban.ActorRegistry, {:task_actor, task_id}) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(task_supervisor_name(board_id), pid)
      [] -> :ok
    end
  end

  defp task_supervisor_name(board_id) do
    {:via, Registry, {Viban.Kanban.ActorRegistry, {:task_supervisor, board_id}}}
  end
end
```

#### Task Actor

**File:** `backend/lib/viban/kanban/actors/task_actor.ex`

```elixir
defmodule Viban.Kanban.Actors.TaskActor do
  use GenServer, restart: :transient
  require Logger

  alias Viban.Kanban.{Column, Hook, ColumnHook}
  alias Viban.Kanban.Actors.HookRunner

  def start_link({board_id, task}) do
    GenServer.start_link(__MODULE__, {board_id, task}, name: via_tuple(task.id))
  end

  def via_tuple(task_id) do
    {:via, Registry, {Viban.Kanban.ActorRegistry, {:task_actor, task_id}}}
  end

  @impl true
  def init({board_id, task}) do
    state = %{
      board_id: board_id,
      task_id: task.id,
      current_column_id: task.column_id,
      worktree_path: task.worktree_path,
      running_hooks: %{}  # %{hook_id => pid}
    }

    # Create worktree if needed
    state = maybe_create_worktree(state, task)

    # Start initial hooks for current column
    state = start_column_hooks(state, task.column_id)

    {:ok, state}
  end

  @impl true
  def handle_cast({:task_updated, new_task}, state) do
    if new_task.column_id != state.current_column_id do
      Logger.info("Task #{state.task_id} moved from #{state.current_column_id} to #{new_task.column_id}")
      state = handle_column_change(state, state.current_column_id, new_task.column_id)
      {:noreply, %{state | current_column_id: new_task.column_id}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("TaskActor #{state.task_id} terminating: #{inspect(reason)}")

    # Cleanup all running hooks
    Enum.each(state.running_hooks, fn {hook_id, pid} ->
      HookRunner.cleanup(pid, get_hook(hook_id), state.worktree_path)
    end)

    :ok
  end

  # Private functions

  defp handle_column_change(state, old_column_id, new_column_id) do
    old_hooks = get_persistent_hook_ids(old_column_id)
    new_hooks = get_persistent_hook_ids(new_column_id)

    leaving_hooks = MapSet.difference(old_hooks, new_hooks)
    entering_hooks = MapSet.difference(new_hooks, old_hooks)

    # 1. Run on_leave for old column
    run_on_leave_hooks(old_column_id, state.worktree_path)

    # 2. Cleanup leaving hooks
    state = Enum.reduce(leaving_hooks, state, fn hook_id, acc ->
      cleanup_hook(acc, hook_id)
    end)

    # 3. Run on_entry for new column
    run_on_entry_hooks(new_column_id, state.worktree_path)

    # 4. Start entering hooks
    Enum.reduce(entering_hooks, state, fn hook_id, acc ->
      start_hook(acc, hook_id)
    end)
  end

  defp get_persistent_hook_ids(column_id) do
    ColumnHook.read!()
    |> Enum.filter(&(&1.column_id == column_id && &1.hook_type == :persistent))
    |> Enum.map(& &1.hook_id)
    |> MapSet.new()
  end

  defp run_on_entry_hooks(column_id, worktree_path) do
    get_hooks_by_type(column_id, :on_entry)
    |> Enum.each(&HookRunner.run_once(&1, worktree_path))
  end

  defp run_on_leave_hooks(column_id, worktree_path) do
    get_hooks_by_type(column_id, :on_leave)
    |> Enum.each(&HookRunner.run_once(&1, worktree_path))
  end

  defp get_hooks_by_type(column_id, type) do
    ColumnHook.read!()
    |> Enum.filter(&(&1.column_id == column_id && &1.hook_type == type))
    |> Enum.sort_by(& &1.position)
    |> Enum.map(&get_hook(&1.hook_id))
  end

  defp start_hook(state, hook_id) do
    hook = get_hook(hook_id)
    {:ok, pid} = HookRunner.start_persistent(hook, state.worktree_path)
    %{state | running_hooks: Map.put(state.running_hooks, hook_id, pid)}
  end

  defp cleanup_hook(state, hook_id) do
    case Map.get(state.running_hooks, hook_id) do
      nil -> state
      pid ->
        hook = get_hook(hook_id)
        HookRunner.cleanup(pid, hook, state.worktree_path)
        %{state | running_hooks: Map.delete(state.running_hooks, hook_id)}
    end
  end

  defp get_hook(hook_id) do
    Hook.get!(hook_id)
  end

  defp start_column_hooks(state, column_id) do
    # Run on_entry hooks
    run_on_entry_hooks(column_id, state.worktree_path)

    # Start persistent hooks
    get_persistent_hook_ids(column_id)
    |> Enum.reduce(state, &start_hook(&2, &1))
  end

  defp maybe_create_worktree(state, task) do
    if is_nil(task.worktree_path) do
      # Create worktree
      worktree_path = create_worktree(state.board_id, task.id)
      # Update task with worktree info
      Viban.Kanban.Task.assign_worktree!(task.id, %{
        worktree_path: worktree_path,
        worktree_branch: "task/#{task.id}"
      })
      %{state | worktree_path: worktree_path}
    else
      state
    end
  end

  defp create_worktree(board_id, task_id) do
    # Get repository for board
    repo = Viban.Kanban.Repository.read!()
           |> Enum.find(&(&1.board_id == board_id))

    if repo do
      worktree_base = Application.get_env(:viban, :worktree_base_path, "/tmp/viban/worktrees")
      worktree_path = Path.join([worktree_base, to_string(board_id), to_string(task_id)])
      branch_name = "task/#{task_id}"

      # Create worktree directory
      File.mkdir_p!(Path.dirname(worktree_path))

      # Create git worktree
      {_, 0} = System.cmd("git", [
        "-C", repo.path,
        "worktree", "add",
        "-b", branch_name,
        worktree_path,
        repo.default_branch
      ])

      worktree_path
    else
      Logger.warn("No repository configured for board #{board_id}")
      nil
    end
  end
end
```

#### Hook Runner

**File:** `backend/lib/viban/kanban/actors/hook_runner.ex`

```elixir
defmodule Viban.Kanban.Actors.HookRunner do
  require Logger

  @doc """
  Run a one-time hook (on_entry or on_leave)
  """
  def run_once(hook, worktree_path) do
    working_dir = get_working_dir(hook, worktree_path)

    Logger.info("Running hook: #{hook.name} in #{working_dir}")

    case System.cmd("sh", ["-c", hook.command],
           cd: working_dir,
           stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("Hook #{hook.name} completed: #{output}")
        :ok
      {output, code} ->
        Logger.error("Hook #{hook.name} failed (#{code}): #{output}")
        {:error, output}
    end
  end

  @doc """
  Start a persistent hook (background process)
  """
  def start_persistent(hook, worktree_path) do
    working_dir = get_working_dir(hook, worktree_path)

    Logger.info("Starting persistent hook: #{hook.name} in #{working_dir}")

    # Start process in background
    port = Port.open({:spawn, hook.command}, [
      :binary,
      :exit_status,
      {:cd, working_dir}
    ])

    {:ok, port}
  end

  @doc """
  Cleanup a persistent hook
  """
  def cleanup(port, hook, worktree_path) do
    # First, try graceful cleanup command
    if hook.cleanup_command do
      working_dir = get_working_dir(hook, worktree_path)
      Logger.info("Running cleanup for hook: #{hook.name}")

      System.cmd("sh", ["-c", hook.cleanup_command],
        cd: working_dir,
        stderr_to_stdout: true)
    end

    # Then close the port
    if is_port(port) and Port.info(port) do
      Port.close(port)
    end

    :ok
  end

  defp get_working_dir(hook, worktree_path) do
    case hook.working_directory do
      :worktree -> worktree_path || File.cwd!()
      :project_root -> File.cwd!()
      path when is_binary(path) -> path
    end
  end
end
```

### 2.7 Registry and Application Setup

**File:** `backend/lib/viban/application.ex` (additions)

```elixir
children = [
  # ... existing children ...

  # Actor Registry
  {Registry, keys: :unique, name: Viban.Kanban.ActorRegistry},

  # Board Supervisor Manager (starts supervisors for active boards)
  Viban.Kanban.Actors.BoardManager
]
```

#### Board Manager

**File:** `backend/lib/viban/kanban/actors/board_manager.ex`

```elixir
defmodule Viban.Kanban.Actors.BoardManager do
  use GenServer
  require Logger

  alias Viban.Kanban.Board
  alias Viban.Kanban.Actors.BoardSupervisor

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Subscribe to board changes
    {:ok, shape_pid} = Phoenix.Sync.Shape.start_link(Board, name: :boards_shape)
    ref = Phoenix.Sync.Shape.subscribe(:boards_shape)

    # Start supervisors for existing boards
    start_existing_board_supervisors()

    {:ok, %{shape_ref: ref}}
  end

  @impl true
  def handle_info({:sync, ref, {:insert, {_key, board}}}, %{shape_ref: ref} = state) do
    Logger.info("Board created: #{board.id}")
    start_board_supervisor(board.id)
    {:noreply, state}
  end

  def handle_info({:sync, ref, {:delete, {_key, board}}}, %{shape_ref: ref} = state) do
    Logger.info("Board deleted: #{board.id}")
    stop_board_supervisor(board.id)
    {:noreply, state}
  end

  def handle_info({:sync, ref, _}, %{shape_ref: ref} = state) do
    {:noreply, state}
  end

  defp start_existing_board_supervisors do
    Board.read!()
    |> Enum.each(&start_board_supervisor(&1.id))
  end

  defp start_board_supervisor(board_id) do
    DynamicSupervisor.start_child(
      Viban.Kanban.Actors.BoardDynamicSupervisor,
      {BoardSupervisor, board_id}
    )
  end

  defp stop_board_supervisor(board_id) do
    case Registry.lookup(Viban.Kanban.ActorRegistry, {:board_supervisor, board_id}) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(Viban.Kanban.Actors.BoardDynamicSupervisor, pid)
      [] -> :ok
    end
  end
end
```

### 2.8 MCP Integration with Ash AI

**Installation:**

Add to `mix.exs`:
```elixir
{:ash_ai, "~> 0.3"}
```

**Router setup:**

**File:** `backend/lib/viban_web/router.ex` (additions)

```elixir
# Development MCP (in dev block)
if Mix.env() == :dev do
  plug AshAi.Mcp.Dev,
    protocol_version_statement: "2024-11-05",
    otp_app: :viban
end

# Production MCP route
scope "/mcp" do
  forward "/", AshAi.Mcp.Router,
    tools: [
      :list_boards,
      :create_task,
      :update_task,
      :move_task,
      :delete_task,
      :list_tasks,
      :list_columns
    ],
    protocol_version_statement: "2024-11-05",
    otp_app: :viban
end
```

### 2.9 Sync Controller Updates

Add shape endpoints for new resources:

**File:** `backend/lib/viban_web/controllers/kanban_sync_controller.ex` (additions)

```elixir
def hooks(conn, params) do
  sync_render(conn, params, Viban.Kanban.Hook)
end

def column_hooks(conn, params) do
  sync_render(conn, params, Viban.Kanban.ColumnHook)
end

def repositories(conn, params) do
  sync_render(conn, params, Viban.Kanban.Repository)
end
```

Add routes in `router.ex`:
```elixir
get "/api/shapes/hooks", KanbanSyncController, :hooks
get "/api/shapes/column_hooks", KanbanSyncController, :column_hooks
get "/api/shapes/repositories", KanbanSyncController, :repositories
```

---

## Phase 3: Frontend Updates

### 3.1 Update useKanban.ts

Add collections for new resources:

```typescript
export const hooksCollection = createCollection(
  electricCollectionOptions<Hook>({
    id: "hooks",
    getKey: (item) => item.id,
    shapeOptions: { url: `${API_URL}/api/shapes/hooks` },
  })
);

export const columnHooksCollection = createCollection(
  electricCollectionOptions<ColumnHook>({
    id: "column_hooks",
    getKey: (item) => item.id,
    shapeOptions: { url: `${API_URL}/api/shapes/column_hooks` },
  })
);

export const repositoriesCollection = createCollection(
  electricCollectionOptions<Repository>({
    id: "repositories",
    getKey: (item) => item.id,
    shapeOptions: { url: `${API_URL}/api/shapes/repositories` },
  })
);
```

### 3.2 Hook Management UI

**File:** `frontend/src/components/HookManager.tsx`

Component for managing hooks on a board (CRUD operations).

**File:** `frontend/src/components/ColumnHookConfig.tsx`

Component for configuring which hooks are attached to a column and their type (on_entry, on_leave, persistent).

### 3.3 Repository Configuration

**File:** `frontend/src/components/RepositoryConfig.tsx`

Component for associating a repository with a board.

### 3.4 Task Details Updates

Update `TaskDetailsPanel.tsx` to show:
- Worktree path (if configured)
- Currently running hooks
- Hook execution logs

---

## Implementation Order (TODO List)

### Backend Tasks

- [ ] **B1:** Add ash_ai dependency to mix.exs
- [ ] **B2:** Create Hook resource
- [ ] **B3:** Create ColumnHook join resource
- [ ] **B4:** Create Repository resource
- [ ] **B5:** Update Task resource (add worktree fields)
- [ ] **B6:** Update Board resource (add relationships)
- [ ] **B7:** Update Column resource (add relationships)
- [ ] **B8:** Update Kanban domain with new resources and MCP tools
- [ ] **B9:** Generate and run migrations
- [ ] **B10:** Create Actor Registry in application.ex
- [ ] **B11:** Create BoardDynamicSupervisor
- [ ] **B12:** Create BoardManager (subscribes to boards)
- [ ] **B13:** Create BoardSupervisor
- [ ] **B14:** Create BoardActor (subscribes to tasks)
- [ ] **B15:** Create TaskActor (manages hooks lifecycle)
- [ ] **B16:** Create HookRunner (executes shell commands)
- [ ] **B17:** Add sync controller endpoints for new resources
- [ ] **B18:** Add routes for new sync shapes
- [ ] **B19:** Configure MCP router in dev/prod
- [ ] **B20:** Generate TypeScript types with AshTypescript
- [ ] **B21:** Create seed data with sample hooks

### Frontend Tasks

- [ ] **F1:** Import new auto-generated types
- [ ] **F2:** Add Electric collections for hooks, column_hooks, repositories
- [ ] **F3:** Create HookManager component
- [ ] **F4:** Create ColumnHookConfig component
- [ ] **F5:** Create RepositoryConfig component
- [ ] **F6:** Update TaskDetailsPanel with worktree info
- [ ] **F7:** Add board settings page for hook/repo configuration
- [ ] **F8:** Style all new components with Tailwind

### Integration Testing

- [ ] **T1:** Test creating task creates worktree
- [ ] **T2:** Test moving task to column with hook executes hook
- [ ] **T3:** Test moving between columns with same hook doesn't re-execute
- [ ] **T4:** Test moving to column without hook runs cleanup
- [ ] **T5:** Test task deletion runs all cleanups
- [ ] **T6:** Test MCP endpoints with Claude Desktop / Cursor

---

## File Structure After Implementation

```
backend/
├── lib/
│   ├── viban/
│   │   ├── application.ex              # Updated with registry + managers
│   │   ├── kanban.ex                   # Updated with AshAi extension
│   │   └── kanban/
│   │       ├── board.ex                # Updated relationships
│   │       ├── column.ex               # Updated relationships
│   │       ├── task.ex                 # Updated with worktree fields
│   │       ├── hook.ex                 # NEW: Hook resource
│   │       ├── column_hook.ex          # NEW: Join table
│   │       ├── repository.ex           # NEW: Repository resource
│   │       └── actors/
│   │           ├── board_manager.ex    # NEW: Manages board supervisors
│   │           ├── board_supervisor.ex # NEW: Supervises board actors
│   │           ├── board_actor.ex      # NEW: Subscribes to task changes
│   │           ├── task_actor.ex       # NEW: Manages task hooks
│   │           └── hook_runner.ex      # NEW: Executes shell commands
│   └── viban_web/
│       ├── router.ex                   # Updated with MCP routes
│       └── controllers/
│           └── kanban_sync_controller.ex  # Updated with new shapes

frontend/
├── src/
│   ├── lib/
│   │   └── useKanban.ts               # Updated with new collections
│   └── components/
│       ├── HookManager.tsx            # NEW: Hook CRUD
│       ├── ColumnHookConfig.tsx       # NEW: Column hook assignment
│       ├── RepositoryConfig.tsx       # NEW: Repo configuration
│       └── TaskDetailsPanel.tsx       # Updated with worktree info
```

---

## Verification Checkpoints

| Phase | Command | Expected Result |
|-------|---------|-----------------|
| B1-B9 | `mix compile` | No errors |
| B9 | `mix ash.codegen && mix ecto.migrate` | New tables created |
| B10-B19 | `mix phx.server` | Actors start for existing boards |
| B19 | `curl localhost:4000/ash_ai/mcp` | MCP endpoint responds |
| B20 | `mix ash_typescript.generate` | New types generated |
| F1-F8 | `bun run build` | No TS errors |

---

## MVP Test Scenario

1. **Create a board** with a repository configured
2. **Create hooks:**
   - "Touch Test" hook: `command: "touch test_file"`, `cleanup: "rm test_file"`
3. **Configure columns:**
   - TODO: no hooks
   - IN PROGRESS: persistent hook "Touch Test"
   - IN REVIEW: persistent hook "Touch Test" (same hook!)
   - DONE: on_entry hook "Touch Test"
4. **Create task in TODO** → Verify worktree created
5. **Move task to IN PROGRESS** → Verify `test_file` exists in worktree
6. **Move task to IN REVIEW** → Verify `test_file` still exists (no cleanup because same hook)
7. **Move task to DONE** → Verify cleanup ran (test_file removed) then on_entry ran (test_file created again)

---

## Notes

- **Phoenix.Sync.Shape** is used for reactive database subscriptions in actors
- **Ash AI MCP** exposes Kanban actions to AI agents (Claude Desktop, Cursor, etc.)
- Hook deduplication is handled by comparing hook IDs across columns
- Worktrees are created lazily when task actor starts
- All hook execution happens in the TaskActor, ensuring proper lifecycle management
- Registry pattern allows looking up actors by board_id or task_id

## References

- [Phoenix.Sync.Client Documentation](https://hexdocs.pm/phoenix_sync/Phoenix.Sync.Client.html)
- [Phoenix.Sync.Shape Documentation](https://hexdocs.pm/phoenix_sync/Phoenix.Sync.Shape.html)
- [Ash AI MCP Documentation](https://hexdocs.pm/ash_ai/AshAi.Mcp.html)
- [Ash AI README](https://preview.hex.pm/preview/ash_ai/show/README.md)
