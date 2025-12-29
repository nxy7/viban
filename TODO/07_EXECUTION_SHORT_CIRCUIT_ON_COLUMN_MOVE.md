# Feature: Execution Short-Circuit on Column Move

## Overview

When a task card that is currently "In Progress" (actively executing with an AI agent) is moved to another column (e.g., Todo, In Review, Done, Cancelled), the system should immediately terminate the running agent/execution and stop all associated processes.

**Why This Matters**:
- User control: Allow users to abort tasks that are taking too long or going in wrong direction
- Resource management: Free up compute resources when task is no longer needed
- Cost control: Stop LLM API calls for cancelled/deprioritized work
- Clean state: Ensure the system doesn't have orphaned running processes

## User Stories

1. **Abort by Moving**: As a user, when I drag an in-progress card to any other column, the executing agent should stop immediately.
2. **Feedback on Stop**: As a user, I want to see visual feedback that the execution was terminated.
3. **Partial Work Preserved**: As a user, any partial work (commits, branches, files) created before termination should be preserved.
4. **Re-startable**: As a user, I should be able to move the task back to In Progress to start fresh execution.
5. **Cancel Confirmation**: As a user, I may want an optional confirmation dialog before stopping execution (configurable).

## Technical Design

### Core Concept: Column Change Detection + Agent Termination

When a task moves out of the "In Progress" column while `in_progress=true`, the system must:
1. Detect the column change event
2. Look up the active workspace session for this task
3. Send termination signal to the running agent
4. Clean up resources and update task state

### Detection Points

#### Option A: BoardActor Task Update Handler

```elixir
# backend/lib/viban/kanban/actors/board_actor.ex

# In handle_info for task updates:
def handle_info({:task_updated, task_id, old_state, new_state}, state) do
  # Check if task moved OUT of in_progress column while executing
  if was_executing?(old_state) and column_changed?(old_state, new_state) do
    # Task moved while executing - trigger termination
    terminate_task_execution(task_id, state)
  end

  {:noreply, state}
end

defp was_executing?(task_state) do
  task_state.in_progress == true and
  task_state.column_slug == "inprogress"
end

defp column_changed?(old_state, new_state) do
  old_state.column_id != new_state.column_id
end
```

#### Option B: Ash Change Hook on Task

```elixir
# backend/lib/viban/kanban/task.ex

changes do
  change fn changeset, _context ->
    # Only on updates with column_id change
    if Ash.Changeset.changing_attribute?(changeset, :column_id) do
      old_column_id = get_data(changeset, :column_id)
      old_in_progress = get_data(changeset, :in_progress)

      if old_in_progress == true do
        # Schedule termination after commit
        Ash.Changeset.after_action(changeset, fn changeset, result ->
          Task.async(fn ->
            Viban.Execution.terminate_task_session(result.id)
          end)
          {:ok, result}
        end)
      else
        changeset
      end
    else
      changeset
    end
  end, on: :update
end
```

### Workspace Session Termination

#### WorkspaceSession GenServer Extension

```elixir
# backend/lib/viban/execution/workspace_session.ex

defmodule Viban.Execution.WorkspaceSession do
  use GenServer

  # Add termination handling

  def terminate_session(session_id, reason \\ :user_cancelled) do
    GenServer.call(via_tuple(session_id), {:terminate, reason})
  end

  # Handle termination request
  def handle_call({:terminate, reason}, _from, state) do
    # 1. Send SIGTERM to agent process
    terminate_agent_process(state.agent_pid)

    # 2. Update session state
    new_state = %{state |
      status: :terminated,
      terminated_at: DateTime.utc_now(),
      termination_reason: reason
    }

    # 3. Broadcast termination event
    broadcast_termination(state.task_id, reason)

    # 4. Clean up resources
    cleanup_resources(state)

    {:reply, :ok, new_state}
  end

  defp terminate_agent_process(nil), do: :ok
  defp terminate_agent_process(pid) when is_pid(pid) do
    # Send graceful termination signal first
    send(pid, :terminate)

    # Wait briefly for graceful shutdown
    Process.sleep(1000)

    # Force kill if still alive
    if Process.alive?(pid) do
      Process.exit(pid, :kill)
    end
  end

  defp terminate_agent_process(os_pid) when is_integer(os_pid) do
    # For OS-level processes (Claude Code, etc.)
    # First try SIGTERM
    System.cmd("kill", ["-TERM", to_string(os_pid)], stderr_to_stdout: true)

    Process.sleep(2000)

    # Then SIGKILL if needed
    case System.cmd("ps", ["-p", to_string(os_pid)], stderr_to_stdout: true) do
      {_, 0} ->
        # Still alive, force kill
        System.cmd("kill", ["-9", to_string(os_pid)], stderr_to_stdout: true)
      _ ->
        :ok
    end
  end
end
```

### Agent-Specific Termination

Different AI coding agents have different termination mechanisms:

#### Claude Code Termination

```elixir
# backend/lib/viban/execution/agents/claude_code.ex

defmodule Viban.Execution.Agents.ClaudeCode do
  def terminate(session) do
    # Claude Code runs as a subprocess
    # Need to kill the process group to ensure all children die

    case session.os_pid do
      nil -> :ok
      pid ->
        # Kill entire process group
        System.cmd("kill", ["-TERM", "-#{pid}"], stderr_to_stdout: true)

        Process.sleep(2000)

        # Force kill if needed
        System.cmd("kill", ["-9", "-#{pid}"], stderr_to_stdout: true)
    end
  end
end
```

#### Generic Agent Termination Interface

```elixir
# backend/lib/viban/execution/agent_behaviour.ex

defmodule Viban.Execution.AgentBehaviour do
  @callback terminate(session :: map()) :: :ok | {:error, term()}
  @callback graceful_shutdown_timeout() :: non_neg_integer()
end
```

### Frontend Integration

#### Drag-and-Drop Handler Update

```typescript
// frontend/src/components/TaskCard.tsx or Board.tsx

const handleDragEnd = async (result: DropResult) => {
  const { source, destination, draggableId } = result;

  if (!destination) return;

  const taskId = draggableId;
  const sourceColumn = source.droppableId;
  const destColumn = destination.droppableId;

  // Check if moving from in-progress
  const task = tasks.find(t => t.id === taskId);

  if (task?.in_progress && sourceColumn === 'inprogress' && destColumn !== 'inprogress') {
    // Show confirmation dialog (if enabled)
    if (settings.confirmExecutionCancel) {
      const confirmed = await showConfirmDialog({
        title: 'Stop Execution?',
        message: 'This task is currently executing. Moving it will stop the running agent. Continue?',
        confirmText: 'Stop & Move',
        cancelText: 'Cancel'
      });

      if (!confirmed) return;
    }
  }

  // Proceed with move - backend will handle termination
  await moveTask(taskId, destColumn);
};
```

#### Real-time Termination Feedback

```typescript
// frontend/src/hooks/useTaskSubscription.ts

// Subscribe to termination events via WebSocket/Phoenix Channel

channel.on('execution_terminated', (payload) => {
  const { task_id, reason, terminated_at } = payload;

  // Update task state
  updateTaskState(task_id, {
    in_progress: false,
    execution_status: 'terminated',
    last_execution_ended_at: terminated_at
  });

  // Show notification
  toast.info(`Task execution stopped: ${reason}`);
});
```

### State Machine Update

```elixir
# Extend task execution state machine

# States:
#   :idle -> :queued -> :running -> :completed
#                    -> :terminated (new)
#                    -> :failed

# Transitions:
#   :running -> :terminated  (on column move or manual stop)
#   :terminated -> :queued   (on move back to in-progress with concurrency limit)
#   :terminated -> :running  (on move back to in-progress without limit)
```

### Database Changes

```elixir
# backend/priv/repo/migrations/YYYYMMDDHHMMSS_add_execution_termination_fields.exs

defmodule Viban.Repo.Migrations.AddExecutionTerminationFields do
  use Ecto.Migration

  def change do
    alter table(:workspace_sessions) do
      add :terminated_at, :utc_datetime
      add :termination_reason, :string  # "user_cancelled", "column_moved", "timeout", etc.
    end

    # For task execution history
    create table(:task_execution_history) do
      add :task_id, references(:tasks, type: :uuid, on_delete: :delete_all)
      add :workspace_session_id, references(:workspace_sessions, type: :uuid)
      add :started_at, :utc_datetime
      add :ended_at, :utc_datetime
      add :end_reason, :string  # "completed", "terminated", "failed"
      add :commits_created, {:array, :string}  # Git commit SHAs

      timestamps()
    end

    create index(:task_execution_history, [:task_id])
  end
end
```

### API Endpoint for Manual Stop

```elixir
# backend/lib/viban_web/controllers/execution_controller.ex

defmodule VibanWeb.ExecutionController do
  use VibanWeb, :controller

  def stop(conn, %{"task_id" => task_id}) do
    case Viban.Execution.terminate_task_session(task_id, :manual_stop) do
      :ok ->
        json(conn, %{status: "stopped"})
      {:error, :not_running} ->
        conn
        |> put_status(404)
        |> json(%{error: "No active execution for this task"})
      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: to_string(reason)})
    end
  end
end
```

### MCP Tool Extension

```elixir
# backend/lib/viban/mcp/tools/stop_task_execution.ex

defmodule Viban.Mcp.Tools.StopTaskExecution do
  @moduledoc """
  MCP tool to stop a running task execution.
  """

  def definition do
    %{
      name: "stop_task_execution",
      description: "Stop the execution of a running task. Use this when you need to abort a task that is currently being worked on by an agent.",
      parameters: %{
        type: "object",
        properties: %{
          task_id: %{
            type: "string",
            format: "uuid",
            description: "The ID of the task to stop"
          },
          reason: %{
            type: "string",
            description: "Optional reason for stopping (for audit trail)"
          }
        },
        required: ["task_id"]
      }
    }
  end

  def execute(%{"task_id" => task_id} = params) do
    reason = Map.get(params, "reason", "mcp_tool_call")

    case Viban.Execution.terminate_task_session(task_id, reason) do
      :ok ->
        %{success: true, message: "Task execution stopped"}
      {:error, :not_running} ->
        %{success: false, error: "Task is not currently executing"}
      {:error, reason} ->
        %{success: false, error: to_string(reason)}
    end
  end
end
```

## Edge Cases & Error Handling

### 1. Race Condition: Execution Completes During Move

```elixir
def terminate_task_session(task_id, reason) do
  case lookup_active_session(task_id) do
    nil ->
      # Already completed or never started
      {:error, :not_running}
    session ->
      # Use lock or compare-and-swap to prevent race
      with :ok <- acquire_termination_lock(task_id),
           :ok <- do_terminate(session, reason) do
        release_termination_lock(task_id)
        :ok
      end
  end
end
```

### 2. Zombie Process Detection

```elixir
# Periodic health check for running sessions
defmodule Viban.Execution.SessionHealthCheck do
  use GenServer

  def handle_info(:check_health, state) do
    Enum.each(active_sessions(), fn session ->
      unless process_alive?(session.os_pid) do
        # Process died unexpectedly - clean up
        mark_session_failed(session.id, :process_died)
        update_task_status(session.task_id, :failed)
      end
    end)

    schedule_next_check()
    {:noreply, state}
  end
end
```

### 3. Preserving Partial Work

When terminating, ensure:
- Git commits are preserved (they're already in the repo)
- Any uncommitted changes are stashed or preserved somehow
- Log the state at termination for debugging

```elixir
defp cleanup_resources(state) do
  # Stash any uncommitted work before cleanup
  if state.workspace_path do
    System.cmd("git", ["stash", "push", "-m", "Auto-stash on termination"],
               cd: state.workspace_path)
  end

  # Log final state
  Logger.info("Session #{state.id} terminated. Workspace: #{state.workspace_path}")
end
```

## UI/UX Considerations

### Visual Indicators

1. **Stopping State**: Show a "Stopping..." state briefly while termination is in progress
2. **Terminated Badge**: Mark recently terminated tasks with a visual indicator
3. **History Access**: Allow users to see execution history including terminated runs

### Optional Confirmation Dialog

Settings option to show confirmation before stopping:
- Default: ON for first few uses, then prompt to disable
- Can be disabled in project settings
- Keyboard shortcut to force-move without confirmation (Shift+Drag?)

## Testing Plan

### Unit Tests

1. Termination signal is sent when task column changes
2. Agent process is properly killed
3. Session state is updated correctly
4. Task status reflects termination

### Integration Tests

1. Full flow: Start task → Execute → Move column → Verify stopped
2. Race condition: Complete just as move happens
3. Concurrent terminations don't cause issues

### E2E Tests

1. Drag card from In Progress to Done → Verify execution stops
2. Drag card from In Progress to Todo → Verify can restart later
3. Confirm dialog appears and works correctly

## Implementation Order

1. **Phase 1: Core Termination Logic**
   - Add termination method to WorkspaceSession
   - Implement agent process killing
   - Add change hook to detect column moves

2. **Phase 2: State & Persistence**
   - Add database fields for termination tracking
   - Implement execution history table
   - Add API endpoint for manual stop

3. **Phase 3: Frontend Integration**
   - Update drag-and-drop handler
   - Add real-time termination feedback
   - Implement confirmation dialog

4. **Phase 4: MCP & Polish**
   - Add MCP tool for programmatic stopping
   - Add visual indicators
   - Implement execution history view

## Dependencies

- **Feature 06 (Concurrency Limits)**: Termination should release semaphore slots
- **Workspace Session System**: Must have session tracking already in place
- **Phoenix Channels**: For real-time termination feedback

## Open Questions

1. Should we preserve the git branch when terminated, or offer option to delete?
2. How long to wait for graceful shutdown before SIGKILL?
3. Should terminated tasks automatically retry if moved back to In Progress?
4. Do we need different behavior for different termination reasons (user vs system)?
