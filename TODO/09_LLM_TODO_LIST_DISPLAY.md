# Feature: LLM Todo List Display

## Overview

Some LLMs (like Claude Code) maintain internal todo lists to track their progress on tasks. We should capture and display these todo lists in real-time so users can see what the agent is working on and what's remaining.

## User Stories

1. **Progress Visibility**: As a user, I can see the agent's internal todo list to understand what steps it's planning and executing.
2. **Real-time Updates**: As a user, I see the todo list update in real-time as the agent marks items complete or adds new ones.
3. **Task Correlation**: As a user, I can correlate the agent's todos with the overall task being worked on.

## Technical Design

### Data Model

Add a field to track LLM todos on task executions:

```elixir
# backend/lib/viban/kanban/task_execution.ex

defmodule Viban.Kanban.TaskExecution do
  use Ash.Resource,
    otp_app: :viban,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    # Existing fields...
    attribute :status, :atom, constraints: [one_of: [:pending, :running, :completed, :failed, :cancelled]]
    attribute :output, :string
    attribute :error, :string

    # New: LLM's internal todo list
    attribute :llm_todos, {:array, :map} do
      default []
      description "The LLM's internal todo list items"
    end

    timestamps()
  end
end
```

### Todo Item Structure

```typescript
// frontend/src/types.ts

interface LLMTodoItem {
  content: string;        // The todo text (imperative form)
  activeForm: string;     // Present continuous form (e.g., "Running tests")
  status: "pending" | "in_progress" | "completed";
}

interface TaskExecution {
  id: string;
  status: "pending" | "running" | "completed" | "failed" | "cancelled";
  output: string;
  error: string | null;
  llm_todos: LLMTodoItem[];
  // ...
}
```

### Capturing Todos from Claude Code

Claude Code outputs todo list updates in a structured format. We need to parse these from the agent output stream:

```elixir
# backend/lib/viban/agents/output_parser.ex

defmodule Viban.Agents.OutputParser do
  @moduledoc """
  Parses structured output from LLM agents.
  """

  @doc """
  Extract todo list updates from Claude Code output.
  Claude Code uses TodoWrite tool which outputs JSON.
  """
  def extract_todos(output) when is_binary(output) do
    # Look for TodoWrite tool output patterns
    # Format: {"todos": [{"content": "...", "status": "...", "activeForm": "..."}]}

    case Regex.scan(~r/\{"todos":\s*\[.*?\]\}/s, output) do
      [] -> nil
      matches ->
        matches
        |> List.last()
        |> hd()
        |> Jason.decode()
        |> case do
          {:ok, %{"todos" => todos}} -> todos
          _ -> nil
        end
    end
  end

  @doc """
  Parse streaming output and extract latest todo state.
  """
  def parse_streaming_todos(stream_chunk, current_todos) do
    case extract_todos(stream_chunk) do
      nil -> current_todos
      new_todos -> new_todos
    end
  end
end
```

### Real-time Updates via Phoenix Channel

```elixir
# backend/lib/viban_web/channels/task_channel.ex

defmodule VibanWeb.TaskChannel do
  use VibanWeb, :channel

  # Existing handlers...

  @doc """
  Broadcast todo list update to subscribers.
  """
  def broadcast_todos_update(task_id, execution_id, todos) do
    VibanWeb.Endpoint.broadcast(
      "task:#{task_id}",
      "todos_updated",
      %{
        execution_id: execution_id,
        todos: todos
      }
    )
  end
end
```

### Frontend Components

#### Todo List Display Component

```tsx
// frontend/src/components/LLMTodoList.tsx

import { For, Show } from "solid-js";

interface Props {
  todos: LLMTodoItem[];
  isRunning: boolean;
}

export function LLMTodoList(props: Props) {
  const completedCount = () => props.todos.filter(t => t.status === "completed").length;
  const totalCount = () => props.todos.length;
  const currentTask = () => props.todos.find(t => t.status === "in_progress");

  return (
    <Show when={props.todos.length > 0}>
      <div class="bg-zinc-800/50 rounded-lg p-3 space-y-2">
        {/* Header with progress */}
        <div class="flex items-center justify-between">
          <span class="text-xs font-medium text-zinc-400 uppercase tracking-wide">
            Agent Progress
          </span>
          <span class="text-xs text-zinc-500">
            {completedCount()}/{totalCount()}
          </span>
        </div>

        {/* Progress bar */}
        <div class="h-1 bg-zinc-700 rounded-full overflow-hidden">
          <div
            class="h-full bg-gradient-to-r from-purple-500 to-blue-500 transition-all duration-300"
            style={{ width: `${(completedCount() / totalCount()) * 100}%` }}
          />
        </div>

        {/* Current task indicator */}
        <Show when={currentTask() && props.isRunning}>
          <div class="flex items-center gap-2 text-sm text-blue-400">
            <div class="w-2 h-2 bg-blue-400 rounded-full animate-pulse" />
            <span>{currentTask()!.activeForm}</span>
          </div>
        </Show>

        {/* Todo list */}
        <div class="space-y-1 max-h-48 overflow-y-auto">
          <For each={props.todos}>
            {(todo) => (
              <div
                class={`flex items-start gap-2 text-sm py-1 ${
                  todo.status === "completed"
                    ? "text-zinc-500"
                    : todo.status === "in_progress"
                    ? "text-blue-300"
                    : "text-zinc-300"
                }`}
              >
                {/* Status icon */}
                <div class="mt-0.5 flex-shrink-0">
                  <Show when={todo.status === "completed"}>
                    <CheckIcon class="w-4 h-4 text-green-500" />
                  </Show>
                  <Show when={todo.status === "in_progress"}>
                    <div class="w-4 h-4 border-2 border-blue-400 border-t-transparent rounded-full animate-spin" />
                  </Show>
                  <Show when={todo.status === "pending"}>
                    <div class="w-4 h-4 border border-zinc-600 rounded" />
                  </Show>
                </div>

                {/* Todo text */}
                <span class={todo.status === "completed" ? "line-through" : ""}>
                  {todo.content}
                </span>
              </div>
            )}
          </For>
        </div>
      </div>
    </Show>
  );
}
```

#### Integration in Card Details

```tsx
// frontend/src/components/CardDetailsSidePanel.tsx

import { LLMTodoList } from "./LLMTodoList";

export function CardDetailsSidePanel(props: Props) {
  // ... existing code ...

  return (
    <div class="...">
      {/* ... header ... */}

      <div class="p-4 space-y-4">
        {/* Task info */}
        <TaskInfo task={task()} />

        {/* LLM Todo List - shown during execution */}
        <Show when={currentExecution()}>
          <LLMTodoList
            todos={currentExecution()!.llm_todos}
            isRunning={currentExecution()!.status === "running"}
          />
        </Show>

        {/* Execution output */}
        <ExecutionOutput execution={currentExecution()} />
      </div>
    </div>
  );
}
```

### Compact View for Task Card

Show a mini progress indicator on the task card itself:

```tsx
// frontend/src/components/TaskCard.tsx

export function TaskCard(props: { task: Task }) {
  const execution = () => props.task.current_execution;
  const todos = () => execution()?.llm_todos || [];
  const progress = () => {
    if (todos().length === 0) return 0;
    return (todos().filter(t => t.status === "completed").length / todos().length) * 100;
  };

  return (
    <div class="...">
      {/* ... card content ... */}

      {/* Mini progress bar */}
      <Show when={execution()?.status === "running" && todos().length > 0}>
        <div class="mt-2 space-y-1">
          <div class="h-1 bg-zinc-700 rounded-full overflow-hidden">
            <div
              class="h-full bg-blue-500 transition-all duration-300"
              style={{ width: `${progress()}%` }}
            />
          </div>
          <Show when={todos().find(t => t.status === "in_progress")}>
            <p class="text-xs text-zinc-500 truncate">
              {todos().find(t => t.status === "in_progress")!.activeForm}
            </p>
          </Show>
        </div>
      </Show>
    </div>
  );
}
```

## Implementation Steps

### Phase 1: Data Model
1. Add `llm_todos` field to TaskExecution resource
2. Create database migration
3. Update TaskExecution actions to accept todos updates

### Phase 2: Output Parsing
1. Create OutputParser module for extracting todos
2. Integrate parser into agent execution pipeline
3. Update execution record when todos change

### Phase 3: Real-time Updates
1. Add `todos_updated` event to TaskChannel
2. Broadcast updates when todos change
3. Update frontend to subscribe to todo updates

### Phase 4: Frontend Components
1. Create LLMTodoList component
2. Integrate into CardDetailsSidePanel
3. Add mini progress to TaskCard

### Phase 5: Polish
1. Add animations for state transitions
2. Handle edge cases (empty todos, rapid updates)
3. Test with actual Claude Code execution

## Success Criteria

- [ ] LLM todos are captured from agent output
- [ ] Todos update in real-time during execution
- [ ] Completed/in-progress/pending states displayed correctly
- [ ] Progress bar shows accurate completion percentage
- [ ] Current task shows "active form" text
- [ ] Task cards show mini progress indicator
- [ ] Works with different LLM agents (graceful fallback if no todos)

## Notes

- Not all LLMs support structured todo output - component should gracefully hide when no todos available
- Claude Code's TodoWrite tool outputs JSON that we can parse
- Consider caching final todo state for completed executions for history view
