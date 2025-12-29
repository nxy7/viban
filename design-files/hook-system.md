# Hook System

Hooks are automated actions that execute when tasks enter columns.

## Core Concepts

### Column Hooks
- Hooks are attached to columns, not tasks
- Multiple hooks per column, executed in order (by position)
- Each hook can be configured per-column with specific settings

### Execution Pipeline
1. Task enters column (via drag, API, or another hook)
2. System creates HookExecution records for all column hooks
3. HookExecutionServer processes hooks sequentially
4. Each hook completes, fails, or is skipped
5. Results broadcast to all connected clients

## Hook Properties

### Configuration
- **position**: Execution order (lower = first)
- **execute_once**: Only run once per task lifetime
- **transparent**: Continue pipeline even if hook fails
- **removable**: Whether user can remove this hook
- **hook_settings**: Hook-specific configuration (JSON)

### Execution States
- **pending**: Queued, waiting to run
- **running**: Currently executing
- **completed**: Finished successfully
- **failed**: Finished with error
- **skipped**: Not executed (due to error in pipeline, disabled, etc.)

## System Hooks

### Auto-Start (`system:auto-start`)
- Column: TODO
- Behavior: If task has `auto_start: true`, moves task to "In Progress"
- Execute once: Yes
- Use case: Immediate execution of new tasks

### Execute AI (`system:execute-ai`)
- Column: In Progress
- Behavior: Processes message queue using AI agent (Claude Code or Gemini CLI)
- Creates worktree if needed
- Handles message queue (multiple messages processed sequentially)
- Returns `{:await_executor, task_id}` to pause pipeline until AI completes

### Move Task (`system:move-task`)
- Column: In Progress (configured to move to "To Review")
- Behavior: Moves task to configured target column
- Settings: `target_column` (column name)
- Transparent: Yes (continues even if move fails)
- Triggers hooks on destination column

### Play Sound (`system:play-sound`)
- Column: To Review
- Behavior: Broadcasts sound event to frontend
- Settings: `sound` (sound name, e.g., "woof", "ding")
- Transparent: Yes
- Frontend handles actual audio playback

## Hook Execution Flow

```
Task enters column
       |
       v
Queue HookExecution records
       |
       v
+------------------+
| Hook 1 (pending) |
| Hook 2 (pending) |
| Hook 3 (pending) |
+------------------+
       |
       v
Execute Hook 1
       |
   +---+---+
   |       |
success  failure
   |       |
   v       v
Hook 2   If transparent: Hook 2
         If not: Skip remaining, set task error
```

## Real-Time Broadcasting

Hook events broadcast via Phoenix PubSub:
- Channel: `kanban_lite:board:{board_id}`
- Event: `{:hook_executed, payload}`

Payload structure:
```elixir
%{
  execution_id: "uuid",
  hook_id: "system:play-sound",
  hook_name: "Play Sound",
  task_id: "uuid",
  triggering_column_id: "uuid",
  status: :completed | :failed | :skipped,
  effects: %{play_sound: %{sound: "woof"}},
  error_message: nil | "error text",
  skip_reason: nil | :error | :disabled | :column_change
}
```

## Error Handling

### Non-Transparent Hook Failure
1. Hook fails
2. Task enters error state
3. Remaining hooks skipped with `skip_reason: :error`
4. User must clear error before task can be moved

### Transparent Hook Failure
1. Hook fails (logged)
2. Pipeline continues to next hook
3. Task does not enter error state

## Column Hook Configuration UI

### Per-Column Settings
- Enable/disable all hooks for column
- List of attached hooks with drag reorder
- Add hook button (select from available hooks)
- Remove hook button (if removable)
- Configure hook settings (hook-specific form)

### Hook Settings Forms
- Move Task: Target column dropdown
- Play Sound: Sound selector
- Execute AI: (no settings currently)
