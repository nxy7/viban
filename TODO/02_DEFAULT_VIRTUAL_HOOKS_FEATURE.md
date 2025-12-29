# Feature: Default/Virtual Hooks System

## Overview

Create a system of "virtual" hooks that are always available, up-to-date, and cannot be deleted by users. These system hooks are defined in code rather than the database, providing built-in functionality that ships with the application.

## User Stories

1. **Default Hooks Available**: As a user, I see a set of default system hooks available in the hook picker without creating them.
2. **Non-Deletable**: As a user, I cannot delete system hooks (they're managed by the application).
3. **Always Up-to-Date**: As a user, system hooks are automatically updated when I upgrade the application.
4. **Attachable Like Regular Hooks**: As a user, I can attach system hooks to columns just like regular hooks.
5. **Mix With Custom**: As a user, I can use both system hooks and my custom hooks together.

## Technical Design

### Architecture Decision: Virtual vs Hybrid

**Option A: Pure Virtual (Recommended)**
- System hooks exist only in code
- Database stores only references (IDs) to system hooks via ColumnHook
- Pros: Clean, always consistent, no migration needed for new hooks
- Cons: Requires special handling in queries

**Option B: Hybrid (Seed-based)**
- System hooks are seeded into database with special `is_system` flag
- Pros: Uniform query model
- Cons: Migration complexity, sync issues, versioning problems

**Recommendation**: Option A - Pure Virtual with computed attributes

### Backend Changes

#### 1. System Hook Behaviour

```elixir
# backend/lib/viban/kanban/system_hooks/behaviour.ex

defmodule Viban.Kanban.SystemHooks.Behaviour do
  @moduledoc """
  Behaviour for system hooks. All system hooks must implement this behaviour.
  """

  @doc "Unique identifier for the hook (format: system:<name>)"
  @callback id() :: String.t()

  @doc "Human-readable name"
  @callback name() :: String.t()

  @doc "Description of what the hook does"
  @callback description() :: String.t()

  @doc "Execute the hook for a task/column transition"
  @callback execute(task :: Task.t(), column :: Column.t(), opts :: keyword()) ::
              :ok | {:error, term()}

  @doc "Optional cleanup when hook is detached or task leaves column"
  @callback cleanup(task :: Task.t(), column :: Column.t()) :: :ok | {:error, term()}

  @optional_callbacks [cleanup: 2]
end
```

#### 2. System Hook Registry

```elixir
# backend/lib/viban/kanban/system_hooks/registry.ex

defmodule Viban.Kanban.SystemHooks.Registry do
  @moduledoc """
  Registry of all available system hooks.
  System hooks are virtual - they exist in code, not in the database.
  """

  alias Viban.Kanban.SystemHooks.{
    RefinePromptHook,
    RunTestsHook,
    LintCodeHook,
    NotifySlackHook
  }

  @system_hooks [
    RefinePromptHook,
    RunTestsHook,
    LintCodeHook,
    NotifySlackHook
  ]

  @doc "Get all available system hooks"
  def all do
    Enum.map(@system_hooks, &to_hook_map/1)
  end

  @doc "Get a system hook by ID"
  def get(id) when is_binary(id) do
    case Enum.find(@system_hooks, fn hook -> hook.id() == id end) do
      nil -> {:error, :not_found}
      hook -> {:ok, to_hook_map(hook)}
    end
  end

  @doc "Check if an ID is a system hook"
  def system_hook?(id) when is_binary(id) do
    String.starts_with?(id, "system:")
  end

  @doc "Get the module for a system hook ID"
  def get_module(id) when is_binary(id) do
    Enum.find(@system_hooks, fn hook -> hook.id() == id end)
  end

  @doc "Execute a system hook"
  def execute(id, task, column, opts \\ []) do
    case get_module(id) do
      nil -> {:error, :not_found}
      module -> module.execute(task, column, opts)
    end
  end

  defp to_hook_map(module) do
    %{
      id: module.id(),
      name: module.name(),
      description: module.description(),
      is_system: true,
      # System hooks don't have these
      command: nil,
      cleanup_command: nil,
      working_directory: nil,
      timeout_ms: nil
    }
  end
end
```

#### 3. Example System Hooks

```elixir
# backend/lib/viban/kanban/system_hooks/refine_prompt_hook.ex

defmodule Viban.Kanban.SystemHooks.RefinePromptHook do
  @behaviour Viban.Kanban.SystemHooks.Behaviour

  @impl true
  def id, do: "system:refine-prompt"

  @impl true
  def name, do: "Auto-Refine Task Description"

  @impl true
  def description do
    "Uses AI to automatically improve the task description with success criteria, " <>
    "clear requirements, and proper markdown formatting when the task enters this column."
  end

  @impl true
  def execute(task, _column, _opts) do
    # Skip if already has a well-structured description
    if task.description && String.length(task.description) > 500 do
      :ok
    else
      %{task_id: task.id, auto_apply: true}
      |> Viban.Workers.RefinePromptWorker.new()
      |> Oban.insert()

      :ok
    end
  end
end

# backend/lib/viban/kanban/system_hooks/run_tests_hook.ex

defmodule Viban.Kanban.SystemHooks.RunTestsHook do
  @behaviour Viban.Kanban.SystemHooks.Behaviour

  @impl true
  def id, do: "system:run-tests"

  @impl true
  def name, do: "Run Test Suite"

  @impl true
  def description do
    "Automatically runs the project's test suite when a task enters this column. " <>
    "Detects and runs the appropriate test command (mix test, npm test, pytest, etc.)"
  end

  @impl true
  def execute(task, _column, _opts) do
    # This would be implemented with the HookRunner
    # Detect test command based on project files
    test_command = detect_test_command(task.worktree_path)

    case Viban.Kanban.Actors.HookRunner.run_once(%{
      command: test_command,
      working_directory: task.worktree_path || ".",
      timeout_ms: 300_000  # 5 minutes for tests
    }) do
      {:ok, _output} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp detect_test_command(worktree_path) do
    path = worktree_path || "."
    cond do
      File.exists?(Path.join(path, "mix.exs")) -> "mix test"
      File.exists?(Path.join(path, "package.json")) -> "npm test"
      File.exists?(Path.join(path, "pytest.ini")) -> "pytest"
      File.exists?(Path.join(path, "Cargo.toml")) -> "cargo test"
      true -> "echo 'No test runner detected'"
    end
  end
end

# backend/lib/viban/kanban/system_hooks/lint_code_hook.ex

defmodule Viban.Kanban.SystemHooks.LintCodeHook do
  @behaviour Viban.Kanban.SystemHooks.Behaviour

  @impl true
  def id, do: "system:lint-code"

  @impl true
  def name, do: "Lint & Format Code"

  @impl true
  def description do
    "Runs code linting and formatting checks. " <>
    "Detects the project type and runs appropriate linters (mix format, eslint, etc.)"
  end

  @impl true
  def execute(task, _column, _opts) do
    lint_command = detect_lint_command(task.worktree_path)

    case Viban.Kanban.Actors.HookRunner.run_once(%{
      command: lint_command,
      working_directory: task.worktree_path || ".",
      timeout_ms: 60_000
    }) do
      {:ok, _output} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp detect_lint_command(worktree_path) do
    path = worktree_path || "."
    cond do
      File.exists?(Path.join(path, "mix.exs")) -> "mix format --check-formatted"
      File.exists?(Path.join(path, ".eslintrc.json")) -> "npx eslint ."
      File.exists?(Path.join(path, "pyproject.toml")) -> "ruff check ."
      true -> "echo 'No linter detected'"
    end
  end
end
```

#### 4. Modified Hook Resource

```elixir
# backend/lib/viban/kanban/hook.ex

# Add a virtual attribute to indicate system hooks
# and modify queries to merge system hooks

defmodule Viban.Kanban.Hook do
  use Ash.Resource,
    otp_app: :viban,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "hooks"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :command, :string, allow_nil?: false
    attribute :cleanup_command, :string
    attribute :working_directory, :atom, constraints: [one_of: [:worktree, :project_root]]
    attribute :timeout_ms, :integer, default: 30_000
    timestamps()
  end

  relationships do
    belongs_to :board, Viban.Kanban.Board
    has_many :column_hooks, Viban.Kanban.ColumnHook
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :command, :cleanup_command, :working_directory, :timeout_ms]
      argument :board_id, :uuid, allow_nil?: false
      change manage_relationship(:board_id, :board, type: :append)
    end

    update :update do
      accept [:name, :command, :cleanup_command, :working_directory, :timeout_ms]
    end

    # Custom action to list all hooks (database + system)
    read :list_all_for_board do
      argument :board_id, :uuid, allow_nil?: false

      prepare fn query, context ->
        # This returns only DB hooks, system hooks are merged in the service layer
        Ash.Query.filter(query, board_id == ^context.arguments.board_id)
      end
    end
  end
end
```

#### 5. Hook Service (Merges Virtual + DB)

```elixir
# backend/lib/viban/kanban/services/hook_service.ex

defmodule Viban.Kanban.Services.HookService do
  @moduledoc """
  Service layer for hooks that merges system (virtual) hooks with database hooks.
  """

  alias Viban.Kanban
  alias Viban.Kanban.SystemHooks.Registry

  @doc """
  List all available hooks for a board (system + custom).
  System hooks come first, then custom hooks sorted by name.
  """
  def list_all_hooks(board_id) do
    # Get database hooks
    db_hooks =
      Kanban.Hook
      |> Ash.Query.filter(board_id == ^board_id)
      |> Ash.read!()
      |> Enum.map(&db_hook_to_map/1)

    # Get system hooks
    system_hooks = Registry.all()

    # Merge: system hooks first
    system_hooks ++ db_hooks
  end

  @doc """
  Get a hook by ID (handles both system and database hooks).
  """
  def get_hook(id) do
    if Registry.system_hook?(id) do
      Registry.get(id)
    else
      case Kanban.get_hook(id) do
        {:ok, hook} -> {:ok, db_hook_to_map(hook)}
        error -> error
      end
    end
  end

  @doc """
  Execute a hook (handles both system and database hooks).
  """
  def execute_hook(hook_id, task, column, opts \\ []) do
    if Registry.system_hook?(hook_id) do
      Registry.execute(hook_id, task, column, opts)
    else
      # Regular hook execution via HookRunner
      {:ok, hook} = Kanban.get_hook(hook_id)
      execute_db_hook(hook, task, opts)
    end
  end

  defp execute_db_hook(hook, task, _opts) do
    working_dir = case hook.working_directory do
      :worktree -> task.worktree_path || "."
      :project_root -> "."
      _ -> "."
    end

    Viban.Kanban.Actors.HookRunner.run_once(%{
      command: hook.command,
      working_directory: working_dir,
      timeout_ms: hook.timeout_ms || 30_000
    })
  end

  defp db_hook_to_map(hook) do
    %{
      id: hook.id,
      name: hook.name,
      description: nil,  # DB hooks don't have descriptions yet
      command: hook.command,
      cleanup_command: hook.cleanup_command,
      working_directory: hook.working_directory,
      timeout_ms: hook.timeout_ms,
      is_system: false
    }
  end
end
```

#### 6. Modified ColumnHook Resource

```elixir
# backend/lib/viban/kanban/column_hook.ex

# The column_hook table stores references to both system hooks (by string ID)
# and database hooks (by UUID)

defmodule Viban.Kanban.ColumnHook do
  use Ash.Resource,
    otp_app: :viban,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "column_hooks"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id

    # This can be either a UUID (for DB hooks) or a string (for system hooks like "system:refine-prompt")
    attribute :hook_id, :string, allow_nil?: false

    attribute :hook_type, :atom do
      constraints one_of: [:on_entry, :on_leave, :persistent]
      allow_nil? false
    end

    attribute :position, :integer, default: 0

    timestamps()
  end

  relationships do
    belongs_to :column, Viban.Kanban.Column, allow_nil?: false
    # Note: No direct relationship to Hook since it could be a system hook
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:hook_id, :hook_type, :position]
      argument :column_id, :uuid, allow_nil?: false
      change manage_relationship(:column_id, :column, type: :append)
    end

    update :update do
      accept [:hook_type, :position]
    end
  end

  # Add validation that hook_id is either a valid UUID or a valid system hook ID
  validations do
    validate fn changeset, _context ->
      hook_id = Ash.Changeset.get_attribute(changeset, :hook_id)

      cond do
        hook_id == nil ->
          :ok

        Viban.Kanban.SystemHooks.Registry.system_hook?(hook_id) ->
          :ok

        match?({:ok, _}, Ecto.UUID.cast(hook_id)) ->
          :ok

        true ->
          {:error, field: :hook_id, message: "must be a valid hook ID"}
      end
    end
  end
end
```

#### 7. Migration for hook_id Type Change

```elixir
# backend/priv/repo/migrations/YYYYMMDDHHMMSS_change_hook_id_to_string.exs

defmodule Viban.Repo.Migrations.ChangeHookIdToString do
  use Ecto.Migration

  def change do
    # Change hook_id from UUID to string to support system hook IDs
    alter table(:column_hooks) do
      modify :hook_id, :string, from: :uuid
    end

    # Remove foreign key constraint since we can't have FK to non-existent rows
    drop_if_exists constraint(:column_hooks, :column_hooks_hook_id_fkey)
  end
end
```

### Frontend Changes

#### 1. Hook Types Update

```typescript
// frontend/src/lib/generated/ash.ts (or manual types)

export interface Hook {
  id: string;
  name: string;
  description: string | null;
  command: string | null;
  cleanup_command: string | null;
  working_directory: "worktree" | "project_root" | null;
  timeout_ms: number | null;
  is_system: boolean;
}
```

#### 2. Hook Picker Component

```tsx
// frontend/src/components/HookPicker.tsx

import { createResource, For, Show } from "solid-js";
import { fetchAllHooks } from "../lib/hooks";

interface Props {
  boardId: string;
  selectedHookId: string | null;
  onSelect: (hookId: string) => void;
}

export function HookPicker(props: Props) {
  const [hooks] = createResource(() => props.boardId, fetchAllHooks);

  return (
    <div class="space-y-2">
      <Show when={hooks.loading}>
        <div class="text-zinc-400 text-sm">Loading hooks...</div>
      </Show>

      <Show when={hooks()}>
        {/* System Hooks Section */}
        <div class="mb-4">
          <h4 class="text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
            System Hooks
          </h4>
          <div class="space-y-1">
            <For each={hooks()!.filter(h => h.is_system)}>
              {(hook) => (
                <HookOption
                  hook={hook}
                  selected={props.selectedHookId === hook.id}
                  onSelect={() => props.onSelect(hook.id)}
                />
              )}
            </For>
          </div>
        </div>

        {/* Custom Hooks Section */}
        <div>
          <h4 class="text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
            Custom Hooks
          </h4>
          <Show
            when={hooks()!.filter(h => !h.is_system).length > 0}
            fallback={
              <div class="text-zinc-500 text-sm italic">
                No custom hooks. Create one in Board Settings.
              </div>
            }
          >
            <div class="space-y-1">
              <For each={hooks()!.filter(h => !h.is_system)}>
                {(hook) => (
                  <HookOption
                    hook={hook}
                    selected={props.selectedHookId === hook.id}
                    onSelect={() => props.onSelect(hook.id)}
                  />
                )}
              </For>
            </div>
          </Show>
        </div>
      </Show>
    </div>
  );
}

function HookOption(props: { hook: Hook; selected: boolean; onSelect: () => void }) {
  return (
    <button
      onClick={props.onSelect}
      class={`w-full text-left p-2 rounded-md transition-colors ${
        props.selected
          ? "bg-purple-600/20 border border-purple-500"
          : "bg-zinc-800 hover:bg-zinc-700 border border-transparent"
      }`}
    >
      <div class="flex items-center gap-2">
        <Show when={props.hook.is_system}>
          <span class="text-purple-400" title="System Hook">
            <SystemIcon class="w-4 h-4" />
          </span>
        </Show>
        <span class="font-medium">{props.hook.name}</span>
      </div>
      <Show when={props.hook.description}>
        <p class="text-xs text-zinc-400 mt-1 line-clamp-2">
          {props.hook.description}
        </p>
      </Show>
    </button>
  );
}
```

#### 3. Modified Hook Manager

```tsx
// frontend/src/components/HookManager.tsx

// Update to show system hooks as non-editable, non-deletable

export function HookManager(props: { boardId: string }) {
  // ... existing code ...

  return (
    <div>
      <For each={hooks()}>
        {(hook) => (
          <div class="flex items-center justify-between p-3 bg-zinc-800 rounded-lg">
            <div>
              <div class="flex items-center gap-2">
                <Show when={hook.is_system}>
                  <span class="px-1.5 py-0.5 text-xs bg-purple-600/20 text-purple-400 rounded">
                    System
                  </span>
                </Show>
                <span class="font-medium">{hook.name}</span>
              </div>
              <Show when={hook.description}>
                <p class="text-sm text-zinc-400 mt-1">{hook.description}</p>
              </Show>
            </div>

            {/* Only show edit/delete for non-system hooks */}
            <Show when={!hook.is_system}>
              <div class="flex gap-2">
                <button onClick={() => editHook(hook)} class="text-zinc-400 hover:text-white">
                  <EditIcon />
                </button>
                <button onClick={() => deleteHook(hook.id)} class="text-zinc-400 hover:text-red-400">
                  <TrashIcon />
                </button>
              </div>
            </Show>
          </div>
        )}
      </For>
    </div>
  );
}
```

### API Changes

#### New Endpoint for Listing All Hooks

```elixir
# backend/lib/viban_web/controllers/hook_controller.ex

defmodule VibanWeb.HookController do
  use VibanWeb, :controller

  alias Viban.Kanban.Services.HookService

  def index(conn, %{"board_id" => board_id}) do
    hooks = HookService.list_all_hooks(board_id)
    json(conn, %{hooks: hooks})
  end
end

# Add to router
scope "/api", VibanWeb do
  get "/boards/:board_id/hooks", HookController, :index
end
```

## Implementation Steps

### Phase 1: Backend Infrastructure (Day 1)
1. Create `SystemHooks.Behaviour` module
2. Create `SystemHooks.Registry` module
3. Implement first system hook: `RefinePromptHook`
4. Create `HookService` to merge system + DB hooks

### Phase 2: Database Changes (Day 1)
1. Create migration to change `hook_id` type
2. Update `ColumnHook` resource with validation
3. Test storing system hook references

### Phase 3: Integration (Day 2)
1. Update `TaskActor` to use `HookService` for execution
2. Update hook execution flow to handle both types
3. Add API endpoint for listing all hooks

### Phase 4: Frontend (Day 2)
1. Update types for system hooks
2. Create `HookPicker` component with sections
3. Update `HookManager` to show system hooks as read-only
4. Test hook attachment workflow

### Phase 5: Additional System Hooks (Day 3)
1. Implement `RunTestsHook`
2. Implement `LintCodeHook`
3. Add any other useful default hooks
4. Test all hooks with real tasks

## Success Criteria

- [ ] System hooks appear in hook picker without database entries
- [ ] System hooks cannot be edited or deleted
- [ ] System hooks can be attached to columns like regular hooks
- [ ] System hooks execute correctly on column transitions
- [ ] New system hooks can be added by only changing code
- [ ] System hooks and custom hooks can coexist on same column

## System Hooks to Include (Initial Set)

1. **`system:refine-prompt`** - AI task description refinement
2. **`system:run-tests`** - Detect and run test suite
3. **`system:lint-code`** - Run linter/formatter checks
4. **`system:create-branch`** - Auto-create git branch from task title
5. **`system:notify-complete`** - Send notification when task reaches Done

## Future Considerations

1. **System Hook Configuration**: Allow per-attachment config (e.g., test timeout)
2. **System Hook Templates**: System hooks with customizable parameters
3. **Hook Marketplace**: Eventually allow installing community hooks
4. **Hook Versioning**: Track which version of system hook was used

## Technical Considerations

1. **ID Collision**: System hook IDs must never collide with UUIDs (prefix with `system:`)
2. **Serialization**: Frontend must handle both UUID and string IDs
3. **Cleanup**: System hooks may need cleanup functions (handled by behaviour)
4. **Async Execution**: Some system hooks are async (Oban jobs), others sync
5. **Error Handling**: System hook errors should be graceful, not block task flow
