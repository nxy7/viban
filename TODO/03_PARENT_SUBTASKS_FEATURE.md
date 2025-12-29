# Feature: Parent Tasks & Subtasks with AI Orchestration

## Overview

Enable hierarchical task structures where a parent task can have multiple subtasks. Parent tasks serve as "big picture" orchestrators that can:
- Have subtasks manually created or AI-generated
- Manage the lifecycle of subtasks
- Respond to questions from subtask agents
- Provide oversight and coordination

This creates a multi-agent architecture where the parent task acts as a supervisor/architect and subtasks are worker agents.

## User Stories

1. **Create Parent Task**: As a user, I can create a task that will become a parent when subtasks are added.
2. **Manual Subtasks**: As a user, I can manually create subtasks under a parent task.
3. **AI-Generated Subtasks**: As a user, I can click "Generate Subtasks" to have AI break down the parent task into smaller subtasks.
4. **Subtask View**: As a user, I can see all subtasks of a parent task in a nested view.
5. **Parent Oversight**: As a user, I can enable "Manage Subtasks" mode where the parent task's agent helps coordinate subtask work.
6. **Subtask Communication**: As a subtask agent, I can ask questions to the parent task when blocked.
7. **Progress Tracking**: As a user, I can see overall progress based on subtask completion.

## Technical Design

### Data Model

#### Database Schema Changes

```sql
-- Add parent-child relationship to tasks
ALTER TABLE tasks ADD COLUMN parent_task_id UUID REFERENCES tasks(id) ON DELETE CASCADE;
ALTER TABLE tasks ADD COLUMN is_parent BOOLEAN DEFAULT FALSE;
ALTER TABLE tasks ADD COLUMN subtask_generation_status VARCHAR(50); -- null, generating, completed, failed

-- Index for efficient subtask queries
CREATE INDEX idx_tasks_parent_task_id ON tasks(parent_task_id);

-- Track subtask order
ALTER TABLE tasks ADD COLUMN subtask_position INTEGER DEFAULT 0;
```

#### Updated Task Resource

```elixir
# backend/lib/viban/kanban/task.ex

defmodule Viban.Kanban.Task do
  use Ash.Resource,
    otp_app: :viban,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer

  attributes do
    # ... existing attributes ...

    # Parent-subtask relationship
    attribute :is_parent, :boolean, default: false
    attribute :subtask_position, :integer, default: 0
    attribute :subtask_generation_status, :atom do
      constraints one_of: [:generating, :completed, :failed]
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :column, Viban.Kanban.Column
    belongs_to :parent_task, Viban.Kanban.Task, allow_nil?: true
    has_many :subtasks, Viban.Kanban.Task, destination_attribute: :parent_task_id
    has_many :messages, Viban.Kanban.Message
  end

  calculations do
    # Calculate completion percentage based on subtasks
    calculate :subtask_progress, :map, Viban.Kanban.Calculations.SubtaskProgress
    calculate :subtask_count, :integer, expr(count(subtasks))
    calculate :completed_subtask_count, :integer, expr(
      count(subtasks, query: [filter: column.name == "Done"])
    )
  end

  actions do
    # ... existing actions ...

    # Create a subtask under a parent
    create :create_subtask do
      accept [:title, :description, :priority]
      argument :parent_task_id, :uuid, allow_nil?: false

      change fn changeset, _context ->
        parent_id = Ash.Changeset.get_argument(changeset, :parent_task_id)

        changeset
        |> Ash.Changeset.change_attribute(:parent_task_id, parent_id)
        |> Ash.Changeset.after_action(fn _changeset, subtask ->
          # Mark parent as is_parent if not already
          parent = Viban.Kanban.get_task!(parent_id)
          unless parent.is_parent do
            Viban.Kanban.update_task(parent, %{is_parent: true})
          end
          {:ok, subtask}
        end)
      end

      # Subtask inherits parent's column initially
      change fn changeset, _context ->
        parent_id = Ash.Changeset.get_argument(changeset, :parent_task_id)
        parent = Viban.Kanban.get_task!(parent_id)
        Ash.Changeset.change_attribute(changeset, :column_id, parent.column_id)
      end
    end

    # Generate subtasks using AI
    action :generate_subtasks, :update do
      argument :task_id, :uuid, allow_nil?: false

      change fn changeset, _context ->
        task_id = Ash.Changeset.get_argument(changeset, :task_id)

        # Enqueue the generation job
        %{task_id: task_id}
        |> Viban.Workers.SubtaskGenerationWorker.new()
        |> Oban.insert()

        Ash.Changeset.change_attribute(changeset, :subtask_generation_status, :generating)
      end
    end

    # Action for parent to manage subtasks
    update :enable_management do
      change set_attribute(:agent_status, "executing")
      change set_attribute(:agent_status_message, "Managing subtasks...")
    end
  end
end
```

### Subtask Generation Service

```elixir
# backend/lib/viban/llm/subtask_generation_service.ex

defmodule Viban.LLM.SubtaskGenerationService do
  @moduledoc """
  Service for AI-powered subtask generation from parent task descriptions.
  """

  alias Viban.LLM.Config
  alias LangChain.ChatModels.ChatAnthropic
  alias LangChain.Message
  alias LangChain.Tools.Tool

  @system_prompt """
  You are a task breakdown specialist. Your job is to analyze a parent task and break it down
  into smaller, actionable subtasks.

  Guidelines for subtask generation:
  1. Each subtask should be independently completable
  2. Subtasks should be atomic - focused on one specific thing
  3. Order subtasks logically (dependencies should come first)
  4. Include 3-8 subtasks typically (fewer for simple tasks, more for complex)
  5. Each subtask needs a clear, actionable title
  6. Subtask descriptions should include:
     - What needs to be done
     - Any relevant technical details
     - Success criteria

  You have access to tools to create subtasks. Use them to create the breakdown.
  """

  @doc """
  Generate subtasks for a parent task.
  Returns {:ok, subtask_ids} or {:error, reason}
  """
  def generate_subtasks(parent_task, opts \\ []) do
    board = Viban.Kanban.get_board!(parent_task.board_id)

    # Build tools for subtask creation
    tools = build_tools(parent_task)

    messages = [
      Message.new_system!(@system_prompt),
      Message.new_user!(build_prompt(parent_task, board))
    ]

    chat_model = Config.chat_model()
    |> Map.put(:tools, tools)

    # Run the agent loop
    run_agent_loop(chat_model, messages, parent_task, [])
  end

  defp build_tools(parent_task) do
    [
      Tool.new!(%{
        name: "create_subtask",
        description: "Create a subtask under the parent task",
        parameters: [
          Tool.param!(:title, :string, "Clear, actionable title for the subtask", required: true),
          Tool.param!(:description, :string, "Detailed description with success criteria", required: true),
          Tool.param!(:priority, :string, "Priority: low, medium, or high", required: true)
        ],
        function: fn args ->
          create_subtask(parent_task.id, args)
        end
      }),
      Tool.new!(%{
        name: "finish_breakdown",
        description: "Call this when you've finished creating all subtasks",
        parameters: [],
        function: fn _args ->
          {:finish, :ok}
        end
      })
    ]
  end

  defp create_subtask(parent_id, %{"title" => title, "description" => desc, "priority" => priority}) do
    case Viban.Kanban.create_subtask(%{
      title: title,
      description: desc,
      priority: String.to_existing_atom(priority),
      parent_task_id: parent_id
    }) do
      {:ok, subtask} ->
        {:ok, "Created subtask: #{subtask.id}"}
      {:error, reason} ->
        {:error, "Failed to create subtask: #{inspect(reason)}"}
    end
  end

  defp build_prompt(task, board) do
    """
    Please break down this parent task into subtasks:

    **Board**: #{board.name}
    **Task Title**: #{task.title}
    **Task Description**:
    #{task.description || "(No description provided - infer from title)"}

    Analyze the task and create appropriate subtasks using the create_subtask tool.
    When done, call finish_breakdown.
    """
  end

  defp run_agent_loop(chat_model, messages, parent_task, created_ids, iteration \\ 0) do
    if iteration > 20 do
      {:error, :max_iterations_exceeded}
    else
      case ChatAnthropic.call(chat_model, messages) do
        {:ok, response} ->
          handle_response(response, chat_model, messages, parent_task, created_ids, iteration)
        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp handle_response(response, chat_model, messages, parent_task, created_ids, iteration) do
    case response do
      %{tool_calls: []} ->
        # No more tool calls, we're done
        {:ok, created_ids}

      %{tool_calls: tool_calls} ->
        # Execute tool calls
        {new_ids, tool_results, should_finish} =
          Enum.reduce(tool_calls, {created_ids, [], false}, fn call, {ids, results, finish} ->
            case execute_tool_call(call) do
              {:finish, :ok} ->
                {ids, results ++ [%{id: call.id, result: "Finished"}], true}
              {:ok, result} ->
                new_id = extract_id(result)
                {ids ++ [new_id], results ++ [%{id: call.id, result: result}], finish}
              {:error, err} ->
                {ids, results ++ [%{id: call.id, result: "Error: #{err}"}], finish}
            end
          end)

        if should_finish do
          {:ok, new_ids}
        else
          # Continue the loop with tool results
          new_messages = messages ++ [
            response,
            Message.new_tool_result!(tool_results)
          ]
          run_agent_loop(chat_model, new_messages, parent_task, new_ids, iteration + 1)
        end
    end
  end
end
```

### Oban Worker for Subtask Generation

```elixir
# backend/lib/viban/workers/subtask_generation_worker.ex

defmodule Viban.Workers.SubtaskGenerationWorker do
  use Oban.Worker, queue: :llm_messages, max_attempts: 3

  alias Viban.Kanban
  alias Viban.LLM.SubtaskGenerationService

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"task_id" => task_id}}) do
    task = Kanban.get_task!(task_id)

    # Update status to generating
    Kanban.update_task(task, %{
      subtask_generation_status: :generating,
      agent_status: "thinking",
      agent_status_message: "Breaking down task into subtasks..."
    })

    case SubtaskGenerationService.generate_subtasks(task) do
      {:ok, subtask_ids} ->
        Kanban.update_task(task, %{
          subtask_generation_status: :completed,
          is_parent: true,
          agent_status: "idle",
          agent_status_message: nil
        })

        # Broadcast completion
        Phoenix.PubSub.broadcast(
          Viban.PubSub,
          "task:#{task_id}:subtasks",
          {:subtasks_generated, subtask_ids}
        )

        :ok

      {:error, reason} ->
        Kanban.update_task(task, %{
          subtask_generation_status: :failed,
          agent_status: "error",
          agent_status_message: "Failed to generate subtasks: #{inspect(reason)}"
        })

        {:error, reason}
    end
  end
end
```

### Parent Task Management (Orchestration)

```elixir
# backend/lib/viban/kanban/actors/parent_task_actor.ex

defmodule Viban.Kanban.Actors.ParentTaskActor do
  @moduledoc """
  Actor that manages subtasks when "Manage Subtasks" mode is enabled.
  Acts as an orchestrator/supervisor for subtask agents.
  """

  use GenServer

  alias Viban.Kanban
  alias Viban.LLM.Service, as: LLMService

  defstruct [:task_id, :board_id, :subtask_ids, :managing, :pending_questions]

  def start_link(task_id) do
    GenServer.start_link(__MODULE__, task_id, name: via_tuple(task_id))
  end

  def via_tuple(task_id) do
    {:via, Registry, {Viban.Kanban.ActorRegistry, {:parent_task, task_id}}}
  end

  # API

  def enable_management(task_id) do
    GenServer.call(via_tuple(task_id), :enable_management)
  end

  def disable_management(task_id) do
    GenServer.call(via_tuple(task_id), :disable_management)
  end

  def subtask_question(task_id, subtask_id, question) do
    GenServer.cast(via_tuple(task_id), {:subtask_question, subtask_id, question})
  end

  def subtask_completed(task_id, subtask_id) do
    GenServer.cast(via_tuple(task_id), {:subtask_completed, subtask_id})
  end

  # Callbacks

  @impl true
  def init(task_id) do
    task = Kanban.get_task!(task_id, load: [:subtasks])

    state = %__MODULE__{
      task_id: task_id,
      board_id: task.column.board_id,
      subtask_ids: Enum.map(task.subtasks, & &1.id),
      managing: false,
      pending_questions: []
    }

    # Subscribe to subtask events
    Phoenix.PubSub.subscribe(Viban.PubSub, "parent_task:#{task_id}")

    {:ok, state}
  end

  @impl true
  def handle_call(:enable_management, _from, state) do
    task = Kanban.get_task!(state.task_id)

    # Update parent task status
    Kanban.update_task(task, %{
      agent_status: "executing",
      agent_status_message: "Managing subtasks..."
    })

    # Start monitoring subtasks
    for subtask_id <- state.subtask_ids do
      Phoenix.PubSub.subscribe(Viban.PubSub, "task:#{subtask_id}:questions")
    end

    {:reply, :ok, %{state | managing: true}}
  end

  @impl true
  def handle_call(:disable_management, _from, state) do
    task = Kanban.get_task!(state.task_id)

    Kanban.update_task(task, %{
      agent_status: "idle",
      agent_status_message: nil
    })

    {:reply, :ok, %{state | managing: false}}
  end

  @impl true
  def handle_cast({:subtask_question, subtask_id, question}, state) do
    if state.managing do
      # Queue the question
      new_state = %{state |
        pending_questions: state.pending_questions ++ [{subtask_id, question}]
      }

      # Process the question
      process_question(state.task_id, subtask_id, question)

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:subtask_completed, subtask_id}, state) do
    if state.managing do
      # Check if all subtasks are done
      task = Kanban.get_task!(state.task_id, load: [:subtasks])
      all_done = Enum.all?(task.subtasks, fn st ->
        st.column.name == "Done" or st.column.name == "Cancelled"
      end)

      if all_done do
        # Notify user that all subtasks are complete
        Kanban.update_task(task, %{
          agent_status: "waiting_for_user",
          agent_status_message: "All subtasks completed! Ready for review."
        })
      end
    end

    {:noreply, state}
  end

  defp process_question(parent_task_id, subtask_id, question) do
    parent_task = Kanban.get_task!(parent_task_id)
    subtask = Kanban.get_task!(subtask_id)

    # Create a message in the parent's chat
    {:ok, user_msg} = Kanban.create_message(%{
      task_id: parent_task_id,
      role: :system,
      content: """
      **Subtask Question from: #{subtask.title}**

      #{question}

      Please provide guidance for this subtask.
      """,
      status: :completed
    })

    # Enqueue LLM response
    %{task_id: parent_task_id, respond_to_subtask: subtask_id}
    |> Viban.Workers.ParentResponseWorker.new()
    |> Oban.insert()
  end
end
```

### Inter-Task Communication via MCP

For agents to communicate with each other, we'll leverage Ash AI's MCP functionality:

```elixir
# backend/lib/viban/kanban/mcp/task_communication.ex

defmodule Viban.Kanban.MCP.TaskCommunication do
  @moduledoc """
  MCP tools for task-to-task communication.
  Allows subtask agents to ask questions to parent tasks.
  """

  use AshAi.Tool

  @impl true
  def tools do
    [
      ask_parent_task(),
      report_progress(),
      request_clarification()
    ]
  end

  defp ask_parent_task do
    %{
      name: "ask_parent_task",
      description: """
      Ask a question to the parent task's agent for guidance.
      Use when you're blocked or need architectural decisions.
      """,
      parameters: [
        %{name: "question", type: "string", description: "Your question for the parent task", required: true},
        %{name: "context", type: "string", description: "Relevant context about what you're working on", required: false}
      ],
      handler: fn %{"question" => question} = params, context ->
        subtask_id = context.task_id
        subtask = Viban.Kanban.get_task!(subtask_id)

        if subtask.parent_task_id do
          Viban.Kanban.Actors.ParentTaskActor.subtask_question(
            subtask.parent_task_id,
            subtask_id,
            question
          )
          {:ok, "Question sent to parent task. You'll receive guidance shortly."}
        else
          {:error, "This task has no parent task."}
        end
      end
    }
  end

  defp report_progress do
    %{
      name: "report_progress_to_parent",
      description: "Report progress on this subtask to the parent task",
      parameters: [
        %{name: "status", type: "string", description: "Current status: working, blocked, completed", required: true},
        %{name: "summary", type: "string", description: "Brief summary of progress", required: true}
      ],
      handler: fn params, context ->
        # Implementation
        {:ok, "Progress reported to parent task."}
      end
    }
  end
end
```

### Frontend Components

#### Parent Task View

```tsx
// frontend/src/components/ParentTaskView.tsx

import { createSignal, createResource, For, Show } from "solid-js";
import { SubtaskCard } from "./SubtaskCard";
import { GenerateSubtasksButton } from "./GenerateSubtasksButton";

interface Props {
  task: Task;
}

export function ParentTaskView(props: Props) {
  const [subtasks] = createResource(() => props.task.id, fetchSubtasks);
  const [isManaging, setIsManaging] = createSignal(false);

  const toggleManagement = async () => {
    if (isManaging()) {
      await disableParentManagement(props.task.id);
      setIsManaging(false);
    } else {
      await enableParentManagement(props.task.id);
      setIsManaging(true);
    }
  };

  const progress = () => {
    const subs = subtasks();
    if (!subs || subs.length === 0) return 0;
    const done = subs.filter(s => s.column?.name === "Done").length;
    return Math.round((done / subs.length) * 100);
  };

  return (
    <div class="space-y-4">
      {/* Header */}
      <div class="flex items-center justify-between">
        <h3 class="text-lg font-semibold flex items-center gap-2">
          <ParentIcon class="w-5 h-5 text-blue-400" />
          Subtasks
        </h3>

        <div class="flex items-center gap-2">
          <Show when={subtasks()?.length > 0}>
            <div class="text-sm text-zinc-400">
              {progress()}% complete
            </div>
            <div class="w-24 h-2 bg-zinc-700 rounded-full overflow-hidden">
              <div
                class="h-full bg-green-500 transition-all"
                style={{ width: `${progress()}%` }}
              />
            </div>
          </Show>
        </div>
      </div>

      {/* Progress Bar */}
      <Show when={subtasks()?.length > 0}>
        <div class="h-1 bg-zinc-700 rounded-full overflow-hidden">
          <div
            class="h-full bg-gradient-to-r from-blue-500 to-green-500 transition-all duration-500"
            style={{ width: `${progress()}%` }}
          />
        </div>
      </Show>

      {/* Subtask List */}
      <div class="space-y-2">
        <For each={subtasks()} fallback={
          <div class="text-center py-8 text-zinc-500">
            <p>No subtasks yet</p>
            <p class="text-sm mt-1">Create subtasks manually or generate them with AI</p>
          </div>
        }>
          {(subtask) => (
            <SubtaskCard
              subtask={subtask}
              parentId={props.task.id}
              isManaged={isManaging()}
            />
          )}
        </For>
      </div>

      {/* Actions */}
      <div class="flex gap-2 pt-4 border-t border-zinc-700">
        <button
          onClick={() => openCreateSubtaskModal(props.task.id)}
          class="flex-1 px-3 py-2 bg-zinc-700 hover:bg-zinc-600 rounded-md text-sm"
        >
          + Add Subtask
        </button>

        <GenerateSubtasksButton
          taskId={props.task.id}
          disabled={props.task.subtask_generation_status === "generating"}
        />

        <Show when={subtasks()?.length > 0}>
          <button
            onClick={toggleManagement}
            class={`px-3 py-2 rounded-md text-sm ${
              isManaging()
                ? "bg-purple-600 text-white"
                : "bg-zinc-700 hover:bg-zinc-600"
            }`}
          >
            {isManaging() ? "Stop Managing" : "Manage Subtasks"}
          </button>
        </Show>
      </div>
    </div>
  );
}
```

#### Subtask Card Component

```tsx
// frontend/src/components/SubtaskCard.tsx

interface Props {
  subtask: Task;
  parentId: string;
  isManaged: boolean;
}

export function SubtaskCard(props: Props) {
  const statusColor = () => {
    switch (props.subtask.column?.name) {
      case "Done": return "bg-green-500";
      case "In Progress": return "bg-blue-500";
      case "To Review": return "bg-yellow-500";
      case "Cancelled": return "bg-zinc-500";
      default: return "bg-zinc-600";
    }
  };

  return (
    <div class="flex items-center gap-3 p-3 bg-zinc-800 rounded-lg hover:bg-zinc-750 transition-colors">
      {/* Status indicator */}
      <div class={`w-2 h-2 rounded-full ${statusColor()}`} />

      {/* Content */}
      <div class="flex-1 min-w-0">
        <div class="font-medium truncate">{props.subtask.title}</div>
        <div class="text-xs text-zinc-500">{props.subtask.column?.name}</div>
      </div>

      {/* Agent status */}
      <Show when={props.subtask.agent_status !== "idle"}>
        <div class="flex items-center gap-1 text-xs text-zinc-400">
          <Show when={props.subtask.agent_status === "thinking"}>
            <Spinner class="w-3 h-3" />
            <span>Thinking...</span>
          </Show>
          <Show when={props.subtask.agent_status === "waiting_for_user"}>
            <QuestionIcon class="w-3 h-3 text-yellow-400" />
            <span>Needs input</span>
          </Show>
        </div>
      </Show>

      {/* Management indicator */}
      <Show when={props.isManaged}>
        <div class="text-purple-400" title="Managed by parent">
          <LinkIcon class="w-4 h-4" />
        </div>
      </Show>

      {/* Actions */}
      <button
        onClick={() => openTaskDetails(props.subtask.id)}
        class="text-zinc-400 hover:text-white"
      >
        <ChevronRightIcon class="w-5 h-5" />
      </button>
    </div>
  );
}
```

#### Generate Subtasks Button

```tsx
// frontend/src/components/GenerateSubtasksButton.tsx

interface Props {
  taskId: string;
  disabled?: boolean;
}

export function GenerateSubtasksButton(props: Props) {
  const [isGenerating, setIsGenerating] = createSignal(false);

  const handleGenerate = async () => {
    setIsGenerating(true);
    try {
      await generateSubtasks(props.taskId);
      // The UI will update via Electric sync when subtasks are created
    } catch (error) {
      console.error("Failed to generate subtasks:", error);
    } finally {
      setIsGenerating(false);
    }
  };

  return (
    <button
      onClick={handleGenerate}
      disabled={props.disabled || isGenerating()}
      class="flex items-center gap-2 px-3 py-2 bg-purple-600 hover:bg-purple-700
             disabled:opacity-50 disabled:cursor-not-allowed rounded-md text-sm"
    >
      <Show when={isGenerating() || props.disabled} fallback={<SparklesIcon class="w-4 h-4" />}>
        <Spinner class="w-4 h-4" />
      </Show>
      {isGenerating() || props.disabled ? "Generating..." : "Generate Subtasks"}
    </button>
  );
}
```

### Electric Sync Updates

Add subtask queries to the Electric sync:

```typescript
// frontend/src/lib/useKanban.ts

// Add subtask sync
export function useSubtasks(parentTaskId: string) {
  const db = useDatabase();

  const subtasks = useLiveQuery(
    db.tasks.liveMany({
      where: {
        parent_task_id: parentTaskId
      },
      orderBy: {
        subtask_position: "asc"
      }
    })
  );

  return subtasks;
}
```

## Implementation Steps

### Phase 1: Database & Model (Day 1-2)
1. Create migration for parent-child relationship
2. Update Task resource with new attributes
3. Add relationships (parent_task, subtasks)
4. Add calculations for progress tracking
5. Update Electric sync shapes

### Phase 2: Subtask Generation (Day 2-3)
1. Create `SubtaskGenerationService` with tool-use
2. Create `SubtaskGenerationWorker` Oban job
3. Test generation with various task types
4. Add channel broadcasts for generation status

### Phase 3: Frontend - Basic UI (Day 3-4)
1. Create `ParentTaskView` component
2. Create `SubtaskCard` component
3. Create `GenerateSubtasksButton` component
4. Integrate into `TaskDetailsPanel`
5. Add manual subtask creation modal

### Phase 4: Parent Management (Day 4-5)
1. Create `ParentTaskActor` GenServer
2. Implement question routing system
3. Create `ParentResponseWorker` for LLM responses
4. Add management toggle UI

### Phase 5: Inter-Agent Communication (Day 5-6)
1. Set up MCP tools for task communication
2. Integrate with Ash AI
3. Test subtask -> parent questions
4. Test parent -> subtask guidance

### Phase 6: Polish & Testing (Day 6-7)
1. Add drag-drop reordering for subtasks
2. Add bulk actions (move all subtasks)
3. Add keyboard navigation
4. Comprehensive testing
5. Documentation

## Success Criteria

- [ ] User can manually create subtasks under a parent task
- [ ] User can click "Generate Subtasks" and AI creates appropriate breakdown
- [ ] Subtask progress is displayed on parent task
- [ ] User can enable "Manage Subtasks" mode
- [ ] Subtask agents can ask questions routed to parent
- [ ] Parent agent can respond and guide subtasks
- [ ] All subtasks completing triggers parent notification
- [ ] Works with existing hook system

## Database Migration

```elixir
# backend/priv/repo/migrations/YYYYMMDDHHMMSS_add_parent_subtask_relationship.exs

defmodule Viban.Repo.Migrations.AddParentSubtaskRelationship do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :parent_task_id, references(:tasks, on_delete: :delete_all)
      add :is_parent, :boolean, default: false
      add :subtask_position, :integer, default: 0
      add :subtask_generation_status, :string
    end

    create index(:tasks, [:parent_task_id])
    create index(:tasks, [:parent_task_id, :subtask_position])
  end
end
```

## Technical Considerations

1. **Circular References**: Prevent task from being its own parent/ancestor
2. **Deep Nesting**: Initially limit to one level (parent -> subtasks), can expand later
3. **Column Inheritance**: Decide if subtasks move with parent or independently
4. **Worktree Sharing**: Subtasks may share parent's worktree or have their own
5. **Concurrency**: Multiple subtask agents may ask questions simultaneously
6. **Context Window**: Parent task needs full context of all subtasks for good guidance
7. **Cleanup**: When parent is deleted, cascade delete subtasks

## Future Enhancements

1. **Multi-Level Hierarchy**: Allow subtasks to have their own subtasks
2. **Dependency Tracking**: Mark dependencies between subtasks
3. **Auto-Sequencing**: AI suggests optimal subtask execution order
4. **Parallel Execution**: Run independent subtasks simultaneously
5. **Progress Reports**: Periodic summaries from parent to user
6. **Template Subtasks**: Save subtask patterns for reuse
7. **Cross-Board Subtasks**: Subtasks that span multiple boards
