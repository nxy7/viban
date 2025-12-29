# TODO 11: Create Task Modal Enhancements & Hook Execution Controls

## Overview

This feature adds three enhancements:
1. **Refine button in Create Task Modal** - AI-powered description refinement before creating
2. **Autostart toggle** - Option to immediately move task to "In Progress" after creation
3. **Execute-once flag for hooks** - Prevent hooks from running multiple times when task bounces between columns

## Design Philosophy

### Third Hook Category: "Action Hooks"

Currently we have:
- **Script hooks**: Shell commands (`hook_kind: :script`)
- **Agent hooks**: AI agents (`hook_kind: :agent`)

We'll introduce a third category:
- **Action hooks**: Predefined internal actions (`hook_kind: :action`)

Action hooks are system-defined actions that manipulate the Viban system itself (move tasks, update states, etc.). They're different from script/agent hooks because they don't run external processes - they call internal Elixir functions.

The "Autostart" functionality will be implemented as an action hook called `system:move-to-in-progress` that can be attached to the TODO column's `on_entry` hooks.

---

## Part 1: Refine Button in Create Task Modal

### Frontend Changes

**File: `src/components/CreateTaskModal.tsx`**

Add a "Refine with AI" button next to the description field that:
1. Takes current title + description
2. Calls the existing `/api/tasks/:task_id/refine` endpoint (need a new endpoint for pre-creation refinement)
3. Updates the description field with refined content
4. Shows loading state during refinement

**New Backend Endpoint**

Since we can't use the existing refine endpoint (requires task_id), create a new endpoint:

```
POST /api/tasks/refine-preview
Body: { title: string, description?: string }
Response: { ok: true, refined_description: string }
```

**File: `lib/viban_web/controllers/task_controller.ex`**

Add `refine_preview` action that calls `Viban.LLM.TaskRefiner.refine/2` directly without requiring an existing task.

---

## Part 2: Autostart Toggle

### Approach: Implement as Action Hook

Rather than adding special "autostart" logic to CreateTaskModal, we'll:
1. Create a new action hook type
2. Create a system action hook: `system:move-to-in-progress`
3. Let users attach this hook to TODO column's `on_entry` hooks
4. In CreateTaskModal, add a toggle that temporarily attaches/enables this hook for the created task

### Backend Changes

**1. Add action hook support to Hook schema**

**File: `lib/viban/kanban/hook.ex`**

```elixir
attribute :hook_kind, :atom do
  constraints one_of: [:script, :agent, :action]  # Add :action
  default :script
end

# For action hooks, store the action identifier
attribute :action_name, :string do
  description "For action hooks: the internal action to execute"
end
```

**2. Create Action Hook Registry**

**File: `lib/viban/kanban/action_hooks/registry.ex`**

```elixir
defmodule Viban.Kanban.ActionHooks.Registry do
  @moduledoc """
  Registry of available action hooks.
  Action hooks are predefined internal actions (not scripts or AI agents).
  """

  @actions %{
    "move-to-in-progress" => Viban.Kanban.ActionHooks.MoveToInProgress,
    "move-to-todo" => Viban.Kanban.ActionHooks.MoveToTodo,
    "move-to-done" => Viban.Kanban.ActionHooks.MoveToDone
  }

  def execute(action_name, task, column, opts) do
    case Map.get(@actions, action_name) do
      nil -> {:error, :unknown_action}
      module -> module.execute(task, column, opts)
    end
  end

  def all_actions do
    # Return list of available actions with metadata
  end
end
```

**3. Create MoveToInProgress Action**

**File: `lib/viban/kanban/action_hooks/move_to_in_progress.ex`**

```elixir
defmodule Viban.Kanban.ActionHooks.MoveToInProgress do
  @behaviour Viban.Kanban.ActionHooks.Behaviour

  def execute(task, _column, _opts) do
    # Find "In Progress" column
    case find_in_progress_column(task) do
      {:ok, in_progress_column} ->
        # Move task to that column
        Viban.Kanban.Task.move(task, %{
          column_id: in_progress_column.id,
          position: calculate_position(in_progress_column)
        })
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**4. Update System Hooks Registry**

**File: `lib/viban/kanban/system_hooks/registry.ex`**

Add action hooks as system hooks with prefix `system:action:`:
- `system:action:move-to-in-progress`
- `system:action:move-to-todo`
- `system:action:move-to-done`

### Frontend Changes

**File: `src/components/CreateTaskModal.tsx`**

Add toggle:
```tsx
const [autostart, setAutostart] = createSignal(false);

// In form:
<div class="flex items-center gap-2">
  <input
    type="checkbox"
    checked={autostart()}
    onChange={(e) => setAutostart(e.target.checked)}
  />
  <label>Start immediately (move to In Progress)</label>
</div>

// In handleSubmit:
const task = await createTask(input);
if (autostart()) {
  await moveTaskToColumn(task.id, inProgressColumnId);
}
```

Alternative: Create task directly in "In Progress" column when autostart is checked.

---

## Part 3: Execute-Once Flag for Hooks

### Problem

When a task bounces between columns (e.g., TODO → In Progress → TODO → In Progress), `on_entry` hooks run every time the task enters a column. Some hooks should only run once per task.

### Solution: Add `execute_once` flag to ColumnHook

**File: `priv/repo/migrations/XXXXXX_add_execute_once_to_column_hooks.exs`**

```elixir
alter table(:column_hooks) do
  add :execute_once, :boolean, default: false
end
```

**File: `lib/viban/kanban/column_hook.ex`**

```elixir
attribute :execute_once, :boolean do
  default false
  description "If true, only execute once per task (track execution in task metadata)"
end
```

### Tracking Execution

**Option A: Task metadata field**

Add `executed_hooks` field to Task (JSONB array of hook_ids that have been executed for this task):

```elixir
# In task.ex
attribute :executed_hooks, {:array, :string} do
  default []
  description "List of hook IDs that have been executed for this task (for execute_once hooks)"
end
```

**Option B: Separate tracking table**

Create `task_hook_executions` table:
```sql
CREATE TABLE task_hook_executions (
  task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
  column_hook_id UUID REFERENCES column_hooks(id) ON DELETE CASCADE,
  executed_at TIMESTAMP,
  PRIMARY KEY (task_id, column_hook_id)
);
```

**Recommendation**: Option A (task metadata) is simpler and sufficient for this use case.

### Hook Execution Logic Update

**File: `lib/viban/kanban/actors/task_actor.ex`**

In `run_on_entry_hooks/3`:

```elixir
defp run_on_entry_hooks(column_id, worktree_path, task_id) do
  task = Task.get!(task_id)
  executed_hooks = task.executed_hooks || []

  get_hooks_by_type(column_id, :on_entry)
  |> Enum.filter(fn {column_hook, hook} ->
    # Skip if execute_once and already executed
    not (column_hook.execute_once and column_hook.id in executed_hooks)
  end)
  |> Enum.reduce_while(:ok, fn {column_hook, hook}, _acc ->
    case HookRunner.run_once(hook, worktree_path) do
      {:ok, _} ->
        # Mark as executed if execute_once
        if column_hook.execute_once do
          Task.update(task, %{
            executed_hooks: [column_hook.id | executed_hooks]
          })
        end
        {:cont, :ok}
      {:error, reason} ->
        set_task_error(task_id, hook.name, reason)
        {:halt, {:error, hook.name, reason}}
    end
  end)
end
```

### Frontend UI

**File: `src/components/ColumnHookConfig.tsx`**

Add checkbox in hook configuration:
```tsx
<div class="flex items-center gap-2">
  <input
    type="checkbox"
    checked={hook.execute_once}
    onChange={...}
  />
  <label class="text-sm text-gray-400">
    Execute only once per task
  </label>
</div>
```

---

## Implementation Order

1. **Part 1: Refine in Create Modal** (simplest, standalone)
   - Add `refine_preview` endpoint
   - Update CreateTaskModal with refine button

2. **Part 3: Execute-once flag** (needed before Part 2)
   - Add migration for `execute_once` field
   - Update ColumnHook resource
   - Update TaskActor execution logic
   - Add tracking to Task resource
   - Update frontend ColumnHookConfig

3. **Part 2: Autostart / Action Hooks** (most complex)
   - Add `:action` hook kind
   - Create ActionHooks registry and behaviour
   - Implement MoveToInProgress action
   - Register as system hooks
   - Update frontend CreateTaskModal with autostart toggle
   - Update HookManager to show action hooks

---

## Summary of Files to Modify/Create

### Backend - New Files
- `lib/viban/kanban/action_hooks/behaviour.ex`
- `lib/viban/kanban/action_hooks/registry.ex`
- `lib/viban/kanban/action_hooks/move_to_in_progress.ex`
- `lib/viban/kanban/action_hooks/move_to_todo.ex`
- `lib/viban/kanban/action_hooks/move_to_done.ex`
- `priv/repo/migrations/XXXXXX_add_execute_once_to_column_hooks.exs`
- `priv/repo/migrations/XXXXXX_add_executed_hooks_to_tasks.exs`

### Backend - Modified Files
- `lib/viban/kanban/hook.ex` - Add `:action` kind, `action_name` field
- `lib/viban/kanban/column_hook.ex` - Add `execute_once` field
- `lib/viban/kanban/task.ex` - Add `executed_hooks` field
- `lib/viban/kanban/actors/task_actor.ex` - Check execute_once before running
- `lib/viban/kanban/system_hooks/registry.ex` - Add action hooks
- `lib/viban_web/controllers/task_controller.ex` - Add `refine_preview`
- `lib/viban_web/router.ex` - Add route for refine_preview

### Frontend - Modified Files
- `src/components/CreateTaskModal.tsx` - Refine button, autostart toggle
- `src/components/ColumnHookConfig.tsx` - Execute-once checkbox
- `src/components/HookManager.tsx` - Show action hooks
- `src/lib/useKanban.ts` - Add types and API functions

---

## Alternative Consideration: Simpler Autostart

If action hooks feel over-engineered for just "autostart", a simpler approach:

1. Add `autostart` boolean to CreateTaskModal
2. When checked, create task directly in "In Progress" column instead of TODO
3. No new hook types needed

However, the action hook approach is more composable:
- Users can chain actions (e.g., refine → move to in progress)
- Reusable for other column transitions
- Consistent with existing hook system
- Can be configured per-column in settings

**Recommendation**: Implement action hooks for long-term flexibility, but keep the CreateTaskModal autostart simple (just change target column).
