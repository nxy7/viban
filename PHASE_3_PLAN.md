# Phase 3: LLM Integration - Implementation Plan

## Overview

Building on the Kanban MVP (Phase 1) and Hook System (Phase 2), this phase adds **LLM-powered task execution**. Tasks can now communicate with AI models to perform coding work, with real-time streaming of responses to the user interface.

**New Features:**
- Chat interface on task details page for user-LLM communication
- Real-time streaming of LLM responses via Phoenix Channels
- Message history persistence with full conversation context
- Agent status tracking (`status` + `statusMessage` fields on Task)
- Message queuing for rate limiting and reliability
- Provider abstraction layer for easy multi-model support (starting with Claude Code)

**Tech Stack Additions:**
- **LangChain for Elixir** - Unified LLM provider abstraction with streaming support
- **Phoenix Channels** - Real-time streaming of LLM responses to frontend
- **Oban** - Job queue for message processing and retry logic

---

## Architecture: Mental Model for LLM Integration

### Core Concepts

#### 1. Message Resource

A **Message** represents a single exchange in the conversation:

```elixir
%Message{
  id: "uuid",
  task_id: "task-uuid",
  role: :user | :assistant | :system,
  content: "The message text",
  status: :pending | :processing | :completed | :failed,
  metadata: %{},  # Provider-specific data (tokens, model, etc.)
  inserted_at: ~U[...],
  updated_at: ~U[...]
}
```

#### 2. Task Agent Status Fields

Tasks gain two new fields for real-time agent status:

| Field | Type | Purpose |
|-------|------|---------|
| `agent_status` | enum | Current agent state: `idle`, `thinking`, `executing`, `waiting_for_user`, `error` |
| `agent_status_message` | string | Human-readable status message (e.g., "Running tests...", "Waiting for API response") |

#### 3. Streaming Architecture

**Why NOT Electric Sync for streaming?**

Electric Sync excels at syncing database state, but streaming LLM output character-by-character through DB writes would:
- Create excessive database load
- Introduce latency from write → sync → render cycle
- Potentially lose ordering guarantees for rapid updates

**Solution: Hybrid Approach**

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Data Flow                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  User Input ──► Oban Job ──► LangChain ──► LLM Provider              │
│       │                          │              │                     │
│       │                          │              ▼                     │
│       │                          │     Streaming Response             │
│       │                          │              │                     │
│       │                          ▼              │                     │
│       │                   Phoenix Channel ◄─────┘                     │
│       │                          │                                    │
│       │                          ▼                                    │
│       │                   Frontend (real-time)                        │
│       │                          │                                    │
│       │                          ▼                                    │
│       │              On completion: Save to DB                        │
│       │                          │                                    │
│       ▼                          ▼                                    │
│  Electric Sync ◄──────── Message Record                              │
│       │                                                               │
│       ▼                                                               │
│  Full History (reload, other clients)                                │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

**Key Insight:** Stream via Phoenix Channels for real-time UX, persist to DB on completion for history/sync.

#### 4. Provider Abstraction with LangChain

LangChain for Elixir provides a unified interface across LLM providers:

```elixir
# Configuration for different providers
%{
  claude: %LangChain.ChatModels.ChatAnthropic{
    model: "claude-sonnet-4-20250514",
    stream: true
  },
  openai: %LangChain.ChatModels.ChatOpenAI{
    model: "gpt-4o",
    stream: true
  },
  # Future: local models via Ollama, etc.
}
```

Benefits:
- Single interface for all providers
- Built-in streaming support with callbacks
- Tool/function calling abstraction
- Easy to add new providers without code changes

#### 5. Message Queue with Oban

All LLM requests go through Oban for:
- **Rate limiting**: Respect provider API limits
- **Retry logic**: Automatic retry on transient failures
- **Persistence**: Jobs survive server restarts
- **Observability**: Built-in job monitoring

```elixir
%Oban.Job{
  worker: Viban.Workers.LLMMessageWorker,
  args: %{
    task_id: "...",
    message_id: "...",
    provider: "claude"
  },
  queue: :llm_messages,
  max_attempts: 3
}
```

---

## Phase 3: Backend Implementation

### 3.1 Dependencies

**File:** `backend/mix.exs`

```elixir
defp deps do
  [
    # ... existing deps ...
    {:langchain, "~> 0.4"},
    {:oban, "~> 2.18"}
  ]
end
```

### 3.2 Message Resource

**File:** `backend/lib/viban/kanban/message.ex`

```elixir
defmodule Viban.Kanban.Message do
  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  postgres do
    table "messages"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :role, :atom,
      constraints: [one_of: [:user, :assistant, :system]],
      allow_nil?: false

    attribute :content, :string, allow_nil?: false

    attribute :status, :atom,
      constraints: [one_of: [:pending, :processing, :completed, :failed]],
      default: :pending

    attribute :metadata, :map, default: %{}

    # For ordering within a conversation
    attribute :sequence, :integer, allow_nil?: false

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :task, Viban.Kanban.Task, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:role, :content, :status, :metadata, :task_id]

      change fn changeset, _context ->
        # Auto-increment sequence within task
        task_id = Ash.Changeset.get_attribute(changeset, :task_id)
        next_seq = get_next_sequence(task_id)
        Ash.Changeset.force_change_attribute(changeset, :sequence, next_seq)
      end
    end

    update :update do
      accept [:content, :status, :metadata]
    end

    update :complete do
      accept [:content, :metadata]
      change set_attribute(:status, :completed)
    end

    update :fail do
      accept [:metadata]
      change set_attribute(:status, :failed)
    end

    read :for_task do
      argument :task_id, :uuid, allow_nil?: false
      filter expr(task_id == ^arg(:task_id))
      prepare build(sort: [sequence: :asc])
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :complete
    define :fail
    define :for_task, args: [:task_id]
    define :destroy
  end

  defp get_next_sequence(task_id) do
    case Viban.Kanban.Message.for_task!(task_id) |> List.last() do
      nil -> 1
      last -> last.sequence + 1
    end
  end
end
```

### 3.3 Update Task Resource

**File:** `backend/lib/viban/kanban/task.ex` (additions)

Add agent status fields:

```elixir
attributes do
  # ... existing attributes ...

  attribute :agent_status, :atom,
    constraints: [one_of: [:idle, :thinking, :executing, :waiting_for_user, :error]],
    default: :idle

  attribute :agent_status_message, :string
end

relationships do
  # ... existing relationships ...
  has_many :messages, Viban.Kanban.Message
end

actions do
  # ... existing actions ...

  update :update_agent_status do
    accept [:agent_status, :agent_status_message]
  end
end

code_interface do
  # ... existing definitions ...
  define :update_agent_status
end
```

### 3.4 LLM Provider Configuration

**File:** `backend/lib/viban/llm/config.ex`

```elixir
defmodule Viban.LLM.Config do
  @moduledoc """
  LLM provider configuration and factory.

  Designed for easy extension to support multiple providers.
  """

  alias LangChain.ChatModels.ChatAnthropic

  @type provider :: :claude | :openai | :ollama

  @doc """
  Get a configured chat model for the given provider.
  """
  def get_chat_model(provider, opts \\ [])

  def get_chat_model(:claude, opts) do
    %ChatAnthropic{
      model: opts[:model] || default_model(:claude),
      stream: Keyword.get(opts, :stream, true),
      api_key: api_key(:claude)
    }
  end

  # Future provider implementations
  # def get_chat_model(:openai, opts) do ... end
  # def get_chat_model(:ollama, opts) do ... end

  def default_model(:claude), do: "claude-sonnet-4-20250514"

  defp api_key(:claude) do
    Application.get_env(:viban, :anthropic_api_key) ||
      System.get_env("ANTHROPIC_API_KEY") ||
      raise "ANTHROPIC_API_KEY not configured"
  end

  @doc """
  List available providers.
  """
  def available_providers do
    [:claude]  # Expand as more are implemented
  end

  @doc """
  Check if a provider is available and configured.
  """
  def provider_available?(provider) do
    provider in available_providers() and has_credentials?(provider)
  end

  defp has_credentials?(:claude) do
    !is_nil(Application.get_env(:viban, :anthropic_api_key)) or
      !is_nil(System.get_env("ANTHROPIC_API_KEY"))
  end
end
```

### 3.5 LLM Service

**File:** `backend/lib/viban/llm/service.ex`

```elixir
defmodule Viban.LLM.Service do
  @moduledoc """
  Service for executing LLM requests with streaming support.
  """

  alias LangChain.Chains.LLMChain
  alias LangChain.Message
  alias Viban.LLM.Config
  alias Viban.Kanban.Task
  alias Viban.Kanban.Message, as: KanbanMessage

  require Logger

  @doc """
  Execute an LLM request for a task, streaming results via the provided callback.

  ## Options
  - `:provider` - LLM provider (default: :claude)
  - `:on_delta` - Callback for streaming deltas: fn delta -> :ok end
  - `:on_complete` - Callback when complete: fn full_response -> :ok end
  - `:on_error` - Callback on error: fn error -> :ok end
  """
  def execute(task_id, user_message, opts \\ []) do
    provider = Keyword.get(opts, :provider, :claude)
    on_delta = Keyword.get(opts, :on_delta, fn _ -> :ok end)
    on_complete = Keyword.get(opts, :on_complete, fn _ -> :ok end)
    on_error = Keyword.get(opts, :on_error, fn _ -> :ok end)

    # Update task status
    Task.update_agent_status!(task_id, %{
      agent_status: :thinking,
      agent_status_message: "Processing request..."
    })

    # Build conversation history
    history = build_conversation_history(task_id)

    # Add the new user message
    messages = history ++ [Message.new_user!(user_message)]

    # Get configured chat model
    chat_model = Config.get_chat_model(provider, stream: true)

    # Create chain with streaming callbacks
    {:ok, chain} = LLMChain.new(%{
      llm: chat_model,
      verbose: false
    })

    # Accumulator for streaming response
    accumulated = %{content: "", chunks: []}

    # Execute with streaming
    case LLMChain.run(chain, messages,
      callbacks: %{
        on_llm_new_delta: fn _model, delta ->
          # Broadcast delta to channel
          on_delta.(delta)
          :ok
        end
      }
    ) do
      {:ok, _chain, response} ->
        full_content = extract_content(response)
        on_complete.(full_content)

        Task.update_agent_status!(task_id, %{
          agent_status: :idle,
          agent_status_message: nil
        })

        {:ok, full_content}

      {:error, reason} ->
        Logger.error("LLM execution failed: #{inspect(reason)}")
        on_error.(reason)

        Task.update_agent_status!(task_id, %{
          agent_status: :error,
          agent_status_message: "Error: #{inspect(reason)}"
        })

        {:error, reason}
    end
  end

  defp build_conversation_history(task_id) do
    KanbanMessage.for_task!(task_id)
    |> Enum.filter(&(&1.status == :completed))
    |> Enum.map(fn msg ->
      case msg.role do
        :user -> Message.new_user!(msg.content)
        :assistant -> Message.new_assistant!(msg.content)
        :system -> Message.new_system!(msg.content)
      end
    end)
  end

  defp extract_content(response) when is_list(response) do
    response
    |> Enum.map(&extract_content/1)
    |> Enum.join("")
  end

  defp extract_content(%LangChain.Message{content: content}), do: content
  defp extract_content(%LangChain.MessageDelta{content: content}), do: content || ""
  defp extract_content(other), do: to_string(other)
end
```

### 3.6 Oban Worker for Message Processing

**File:** `backend/lib/viban/workers/llm_message_worker.ex`

```elixir
defmodule Viban.Workers.LLMMessageWorker do
  @moduledoc """
  Oban worker for processing LLM message requests.

  Handles queuing, rate limiting, and retry logic.
  """

  use Oban.Worker,
    queue: :llm_messages,
    max_attempts: 3,
    unique: [period: 30]

  alias Viban.LLM.Service
  alias Viban.Kanban.Message
  alias Viban.Kanban.Task
  alias ViBanWeb.Endpoint

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    %{
      "task_id" => task_id,
      "message_id" => message_id,
      "provider" => provider
    } = args

    provider_atom = String.to_existing_atom(provider)

    # Get the user message
    user_message = Message.get!(message_id)

    # Update message status to processing
    Message.update!(user_message, %{status: :processing})

    # Create placeholder for assistant response
    {:ok, assistant_message} = Message.create(%{
      task_id: task_id,
      role: :assistant,
      content: "",
      status: :processing
    })

    # Channel topic for this task
    topic = "task:#{task_id}"

    # Execute LLM with streaming
    result = Service.execute(task_id, user_message.content,
      provider: provider_atom,
      on_delta: fn delta ->
        # Broadcast delta to subscribed clients
        Endpoint.broadcast!(topic, "llm_delta", %{
          message_id: assistant_message.id,
          delta: delta.content || ""
        })
      end,
      on_complete: fn full_response ->
        # Save completed message
        Message.complete!(assistant_message, %{
          content: full_response,
          metadata: %{
            provider: provider,
            completed_at: DateTime.utc_now()
          }
        })

        # Mark user message as completed
        Message.complete!(user_message, %{})

        # Broadcast completion
        Endpoint.broadcast!(topic, "llm_complete", %{
          message_id: assistant_message.id,
          content: full_response
        })
      end,
      on_error: fn error ->
        # Mark messages as failed
        Message.fail!(assistant_message, %{
          metadata: %{error: inspect(error)}
        })
        Message.fail!(user_message, %{
          metadata: %{error: inspect(error)}
        })

        # Broadcast error
        Endpoint.broadcast!(topic, "llm_error", %{
          message_id: assistant_message.id,
          error: inspect(error)
        })
      end
    )

    case result do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Enqueue a new message for LLM processing.
  """
  def enqueue(task_id, message_id, opts \\ []) do
    provider = Keyword.get(opts, :provider, "claude")

    %{
      task_id: task_id,
      message_id: message_id,
      provider: to_string(provider)
    }
    |> __MODULE__.new()
    |> Oban.insert()
  end
end
```

### 3.7 Phoenix Channel for Task Chat

**File:** `backend/lib/viban_web/channels/task_channel.ex`

```elixir
defmodule VibanWeb.TaskChannel do
  use Phoenix.Channel

  alias Viban.Kanban.{Task, Message}
  alias Viban.Workers.LLMMessageWorker

  @impl true
  def join("task:" <> task_id, _params, socket) do
    # Verify task exists
    case Task.get(task_id) do
      {:ok, task} ->
        socket = assign(socket, :task_id, task_id)
        {:ok, %{task_id: task_id}, socket}

      {:error, _} ->
        {:error, %{reason: "task_not_found"}}
    end
  end

  @impl true
  def handle_in("send_message", %{"content" => content, "provider" => provider}, socket) do
    task_id = socket.assigns.task_id

    # Create user message
    {:ok, message} = Message.create(%{
      task_id: task_id,
      role: :user,
      content: content,
      status: :pending
    })

    # Enqueue for LLM processing
    {:ok, _job} = LLMMessageWorker.enqueue(task_id, message.id, provider: provider)

    # Broadcast the user message to all subscribers
    broadcast!(socket, "new_message", %{
      id: message.id,
      role: :user,
      content: content,
      status: :pending,
      sequence: message.sequence
    })

    {:reply, {:ok, %{message_id: message.id}}, socket}
  end

  @impl true
  def handle_in("get_history", _params, socket) do
    task_id = socket.assigns.task_id
    messages = Message.for_task!(task_id)

    {:reply, {:ok, %{messages: serialize_messages(messages)}}, socket}
  end

  defp serialize_messages(messages) do
    Enum.map(messages, fn msg ->
      %{
        id: msg.id,
        role: msg.role,
        content: msg.content,
        status: msg.status,
        sequence: msg.sequence,
        inserted_at: msg.inserted_at
      }
    end)
  end
end
```

### 3.8 Channel Socket Setup

**File:** `backend/lib/viban_web/channels/user_socket.ex`

```elixir
defmodule VibanWeb.UserSocket do
  use Phoenix.Socket

  channel "task:*", VibanWeb.TaskChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    # For MVP, allow all connections
    # Future: Add authentication
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
```

### 3.9 Oban Configuration

**File:** `backend/config/config.exs` (additions)

```elixir
config :viban, Oban,
  repo: Viban.Repo,
  queues: [
    default: 10,
    llm_messages: 5  # Limit concurrent LLM requests
  ],
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)}
  ]
```

**File:** `backend/lib/viban/application.ex` (additions)

```elixir
children = [
  # ... existing children ...
  {Oban, Application.fetch_env!(:viban, Oban)}
]
```

### 3.10 Database Migrations

**Migration for messages table:**

```elixir
defmodule Viban.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :task_id, references(:tasks, type: :uuid, on_delete: :delete_all), null: false
      add :role, :string, null: false
      add :content, :text, null: false
      add :status, :string, null: false, default: "pending"
      add :metadata, :map, default: %{}
      add :sequence, :integer, null: false

      timestamps()
    end

    create index(:messages, [:task_id])
    create index(:messages, [:task_id, :sequence])
  end
end
```

**Migration for task agent status fields:**

```elixir
defmodule Viban.Repo.Migrations.AddAgentStatusToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :agent_status, :string, default: "idle"
      add :agent_status_message, :string
    end
  end
end
```

### 3.11 Sync Controller Updates

**File:** `backend/lib/viban_web/controllers/kanban_sync_controller.ex` (additions)

```elixir
def messages(conn, params) do
  sync_render(conn, params, Viban.Kanban.Message)
end
```

Add route in `router.ex`:
```elixir
get "/api/shapes/messages", KanbanSyncController, :messages
```

---

## Phase 3: Frontend Implementation

### 3.1 Phoenix Channel Client

**File:** `frontend/src/lib/socket.ts`

```typescript
import { Socket, Channel } from "phoenix";

const SOCKET_URL = "ws://localhost:4000/socket";

class SocketManager {
  private socket: Socket | null = null;
  private channels: Map<string, Channel> = new Map();

  connect(): Socket {
    if (!this.socket) {
      this.socket = new Socket(SOCKET_URL, {
        params: {},
      });
      this.socket.connect();
    }
    return this.socket;
  }

  joinTaskChannel(
    taskId: string,
    handlers: {
      onMessage?: (msg: any) => void;
      onDelta?: (data: { message_id: string; delta: string }) => void;
      onComplete?: (data: { message_id: string; content: string }) => void;
      onError?: (data: { message_id: string; error: string }) => void;
    }
  ): Channel {
    const topic = `task:${taskId}`;

    if (this.channels.has(topic)) {
      return this.channels.get(topic)!;
    }

    const socket = this.connect();
    const channel = socket.channel(topic);

    channel
      .join()
      .receive("ok", () => console.log(`Joined ${topic}`))
      .receive("error", (resp) => console.error(`Failed to join ${topic}`, resp));

    // Set up event handlers
    if (handlers.onMessage) {
      channel.on("new_message", handlers.onMessage);
    }
    if (handlers.onDelta) {
      channel.on("llm_delta", handlers.onDelta);
    }
    if (handlers.onComplete) {
      channel.on("llm_complete", handlers.onComplete);
    }
    if (handlers.onError) {
      channel.on("llm_error", handlers.onError);
    }

    this.channels.set(topic, channel);
    return channel;
  }

  leaveTaskChannel(taskId: string): void {
    const topic = `task:${taskId}`;
    const channel = this.channels.get(topic);
    if (channel) {
      channel.leave();
      this.channels.delete(topic);
    }
  }

  sendMessage(taskId: string, content: string, provider: string = "claude"): Promise<{ message_id: string }> {
    const channel = this.channels.get(`task:${taskId}`);
    if (!channel) {
      throw new Error(`Not connected to task ${taskId}`);
    }

    return new Promise((resolve, reject) => {
      channel
        .push("send_message", { content, provider })
        .receive("ok", resolve)
        .receive("error", reject);
    });
  }

  getHistory(taskId: string): Promise<{ messages: Message[] }> {
    const channel = this.channels.get(`task:${taskId}`);
    if (!channel) {
      throw new Error(`Not connected to task ${taskId}`);
    }

    return new Promise((resolve, reject) => {
      channel
        .push("get_history", {})
        .receive("ok", resolve)
        .receive("error", reject);
    });
  }
}

export const socketManager = new SocketManager();
```

### 3.2 useTaskChat Hook

**File:** `frontend/src/lib/useTaskChat.ts`

```typescript
import { createSignal, createEffect, onCleanup } from "solid-js";
import { socketManager } from "./socket";

interface ChatMessage {
  id: string;
  role: "user" | "assistant" | "system";
  content: string;
  status: "pending" | "processing" | "completed" | "failed";
  sequence: number;
  isStreaming?: boolean;
}

export function useTaskChat(taskId: () => string | undefined) {
  const [messages, setMessages] = createSignal<ChatMessage[]>([]);
  const [isConnected, setIsConnected] = createSignal(false);
  const [streamingContent, setStreamingContent] = createSignal<Map<string, string>>(new Map());

  createEffect(() => {
    const id = taskId();
    if (!id) return;

    // Join channel and set up handlers
    socketManager.joinTaskChannel(id, {
      onMessage: (msg) => {
        setMessages((prev) => [...prev, msg]);
      },
      onDelta: ({ message_id, delta }) => {
        setStreamingContent((prev) => {
          const newMap = new Map(prev);
          const current = newMap.get(message_id) || "";
          newMap.set(message_id, current + delta);
          return newMap;
        });
      },
      onComplete: ({ message_id, content }) => {
        // Update message with final content
        setMessages((prev) =>
          prev.map((m) =>
            m.id === message_id
              ? { ...m, content, status: "completed", isStreaming: false }
              : m
          )
        );
        // Clear streaming content
        setStreamingContent((prev) => {
          const newMap = new Map(prev);
          newMap.delete(message_id);
          return newMap;
        });
      },
      onError: ({ message_id, error }) => {
        setMessages((prev) =>
          prev.map((m) =>
            m.id === message_id
              ? { ...m, status: "failed", isStreaming: false }
              : m
          )
        );
      },
    });

    setIsConnected(true);

    // Load history
    socketManager.getHistory(id).then(({ messages: history }) => {
      setMessages(history);
    });

    onCleanup(() => {
      socketManager.leaveTaskChannel(id);
      setIsConnected(false);
    });
  });

  const sendMessage = async (content: string, provider: string = "claude") => {
    const id = taskId();
    if (!id) return;

    const { message_id } = await socketManager.sendMessage(id, content, provider);

    // Add placeholder for assistant response
    setMessages((prev) => [
      ...prev,
      {
        id: message_id + "-response",
        role: "assistant",
        content: "",
        status: "processing",
        sequence: prev.length + 1,
        isStreaming: true,
      },
    ]);
  };

  // Computed messages with streaming content merged
  const displayMessages = () => {
    const streaming = streamingContent();
    return messages().map((msg) => {
      if (msg.isStreaming && streaming.has(msg.id)) {
        return { ...msg, content: streaming.get(msg.id)! };
      }
      return msg;
    });
  };

  return {
    messages: displayMessages,
    sendMessage,
    isConnected,
  };
}
```

### 3.3 Chat Interface Component

**File:** `frontend/src/components/TaskChat.tsx`

```tsx
import { createSignal, For, Show } from "solid-js";
import { useTaskChat } from "../lib/useTaskChat";

interface TaskChatProps {
  taskId: string;
}

export function TaskChat(props: TaskChatProps) {
  const { messages, sendMessage, isConnected } = useTaskChat(() => props.taskId);
  const [input, setInput] = createSignal("");
  const [isSending, setIsSending] = createSignal(false);

  const handleSubmit = async (e: Event) => {
    e.preventDefault();
    const content = input().trim();
    if (!content || isSending()) return;

    setIsSending(true);
    setInput("");

    try {
      await sendMessage(content);
    } finally {
      setIsSending(false);
    }
  };

  return (
    <div class="flex flex-col h-full">
      {/* Connection status */}
      <div class="px-4 py-2 border-b border-gray-200 dark:border-gray-700">
        <span
          class={`inline-flex items-center text-xs ${
            isConnected() ? "text-green-600" : "text-red-600"
          }`}
        >
          <span
            class={`w-2 h-2 rounded-full mr-2 ${
              isConnected() ? "bg-green-500" : "bg-red-500"
            }`}
          />
          {isConnected() ? "Connected" : "Disconnected"}
        </span>
      </div>

      {/* Messages */}
      <div class="flex-1 overflow-y-auto p-4 space-y-4">
        <For each={messages()}>
          {(message) => (
            <div
              class={`flex ${
                message.role === "user" ? "justify-end" : "justify-start"
              }`}
            >
              <div
                class={`max-w-[80%] rounded-lg px-4 py-2 ${
                  message.role === "user"
                    ? "bg-indigo-600 text-white"
                    : "bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100"
                }`}
              >
                <p class="whitespace-pre-wrap">{message.content}</p>
                <Show when={message.isStreaming}>
                  <span class="inline-block w-2 h-4 bg-current animate-pulse ml-1" />
                </Show>
                <Show when={message.status === "failed"}>
                  <p class="text-red-400 text-xs mt-1">Failed to send</p>
                </Show>
              </div>
            </div>
          )}
        </For>
      </div>

      {/* Input */}
      <form onSubmit={handleSubmit} class="p-4 border-t border-gray-200 dark:border-gray-700">
        <div class="flex gap-2">
          <input
            type="text"
            value={input()}
            onInput={(e) => setInput(e.currentTarget.value)}
            placeholder="Type a message..."
            disabled={!isConnected() || isSending()}
            class="flex-1 rounded-lg border border-gray-300 dark:border-gray-600 px-4 py-2
                   focus:outline-none focus:ring-2 focus:ring-indigo-500
                   disabled:opacity-50 disabled:cursor-not-allowed
                   dark:bg-gray-800 dark:text-white"
          />
          <button
            type="submit"
            disabled={!isConnected() || isSending() || !input().trim()}
            class="px-4 py-2 bg-indigo-600 text-white rounded-lg
                   hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed
                   transition-colors"
          >
            {isSending() ? "Sending..." : "Send"}
          </button>
        </div>
      </form>
    </div>
  );
}
```

### 3.4 Update TaskDetailsPanel

**File:** `frontend/src/components/TaskDetailsPanel.tsx` (additions)

Add the chat interface to the task details panel:

```tsx
import { TaskChat } from "./TaskChat";

// Inside the component, add a tab or section for chat:
<div class="mt-6 border-t border-gray-200 dark:border-gray-700 pt-4">
  <h3 class="text-lg font-medium mb-4">Agent Chat</h3>
  <div class="h-96">
    <TaskChat taskId={task.id} />
  </div>
</div>
```

### 3.5 Agent Status Display

**File:** `frontend/src/components/AgentStatus.tsx`

```tsx
import { Show } from "solid-js";

interface AgentStatusProps {
  status: "idle" | "thinking" | "executing" | "waiting_for_user" | "error";
  message?: string;
}

const statusConfig = {
  idle: { label: "Idle", color: "gray", icon: "○" },
  thinking: { label: "Thinking", color: "blue", icon: "◐", animate: true },
  executing: { label: "Executing", color: "green", icon: "◉", animate: true },
  waiting_for_user: { label: "Waiting", color: "yellow", icon: "◎" },
  error: { label: "Error", color: "red", icon: "✕" },
};

export function AgentStatus(props: AgentStatusProps) {
  const config = () => statusConfig[props.status];

  return (
    <div class="flex items-center gap-2">
      <span
        class={`text-${config().color}-500 ${
          config().animate ? "animate-pulse" : ""
        }`}
      >
        {config().icon}
      </span>
      <span class="text-sm font-medium">{config().label}</span>
      <Show when={props.message}>
        <span class="text-sm text-gray-500 dark:text-gray-400">
          - {props.message}
        </span>
      </Show>
    </div>
  );
}
```

### 3.6 Electric Sync for Messages

**File:** `frontend/src/lib/useKanban.ts` (additions)

```typescript
export const messagesCollection = createCollection(
  electricCollectionOptions<Message>({
    id: "messages",
    getKey: (item) => item.id,
    shapeOptions: { url: `${API_URL}/api/shapes/messages` },
  })
);

export function useTaskMessages(taskId: () => string | undefined) {
  return useLiveQuery(() => {
    const id = taskId();
    if (!id) return [];

    return messagesCollection
      .filter((m) => m.task_id === id)
      .sort((a, b) => a.sequence - b.sequence);
  });
}
```

---

## Implementation Order (TODO List)

### Backend Tasks

- [ ] **B1:** Add LangChain and Oban dependencies to `mix.exs`
- [ ] **B2:** Configure Oban in `config.exs` and `application.ex`
- [ ] **B3:** Create Message resource with all attributes and actions
- [ ] **B4:** Update Task resource with `agent_status` and `agent_status_message` fields
- [ ] **B5:** Update Kanban domain with Message resource
- [ ] **B6:** Generate and run database migrations
- [ ] **B7:** Create LLM Config module (provider factory)
- [ ] **B8:** Create LLM Service module (execution with streaming)
- [ ] **B9:** Create LLMMessageWorker Oban job
- [ ] **B10:** Create UserSocket with channel routing
- [ ] **B11:** Create TaskChannel for chat functionality
- [ ] **B12:** Add message sync controller endpoint and route
- [ ] **B13:** Generate TypeScript types with AshTypescript
- [ ] **B14:** Add environment variable configuration for API keys
- [ ] **B15:** Write tests for LLM service and worker

### Frontend Tasks

- [ ] **F1:** Install Phoenix JS client (`npm install phoenix`)
- [ ] **F2:** Create Socket manager utility
- [ ] **F3:** Create useTaskChat hook
- [ ] **F4:** Create TaskChat component with input and message display
- [ ] **F5:** Create AgentStatus component
- [ ] **F6:** Update TaskDetailsPanel to include chat interface
- [ ] **F7:** Add Electric sync collection for messages
- [ ] **F8:** Style chat interface with Tailwind
- [ ] **F9:** Add loading and error states
- [ ] **F10:** Handle reconnection gracefully

### Integration Testing

- [ ] **T1:** Test sending a message creates user message in DB
- [ ] **T2:** Test LLM response streams to channel
- [ ] **T3:** Test completed message is saved to DB
- [ ] **T4:** Test message history loads on channel join
- [ ] **T5:** Test agent status updates during processing
- [ ] **T6:** Test error handling and retry logic
- [ ] **T7:** Test multiple clients see same conversation

---

## File Structure After Implementation

```
backend/
├── lib/
│   ├── viban/
│   │   ├── application.ex              # Updated with Oban
│   │   ├── kanban.ex                   # Updated with Message resource
│   │   ├── kanban/
│   │   │   ├── task.ex                 # Updated with agent status
│   │   │   └── message.ex              # NEW: Message resource
│   │   ├── llm/
│   │   │   ├── config.ex               # NEW: Provider configuration
│   │   │   └── service.ex              # NEW: LLM execution service
│   │   └── workers/
│   │       └── llm_message_worker.ex   # NEW: Oban job for LLM
│   └── viban_web/
│       ├── channels/
│       │   ├── user_socket.ex          # NEW: WebSocket endpoint
│       │   └── task_channel.ex         # NEW: Task chat channel
│       └── controllers/
│           └── kanban_sync_controller.ex  # Updated with messages

frontend/
├── src/
│   ├── lib/
│   │   ├── socket.ts                   # NEW: Phoenix channel client
│   │   ├── useTaskChat.ts              # NEW: Chat hook
│   │   └── useKanban.ts                # Updated with messages
│   └── components/
│       ├── TaskChat.tsx                # NEW: Chat interface
│       ├── AgentStatus.tsx             # NEW: Status display
│       └── TaskDetailsPanel.tsx        # Updated with chat
```

---

## Configuration

### Environment Variables

```bash
# backend/.env
ANTHROPIC_API_KEY=sk-ant-...

# Future providers
# OPENAI_API_KEY=sk-...
```

### Elixir Config

```elixir
# config/runtime.exs
config :viban,
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY")
```

---

## Handling Long Conversations

### Potential Issues

1. **Context window limits**: Claude has token limits per request
2. **Database growth**: Messages accumulate over time
3. **Memory usage**: Loading full history for long conversations

### Mitigations

1. **Conversation summarization** (future): Periodically summarize old messages
2. **Sliding window**: Only send last N messages + system prompt
3. **Pagination**: Load message history in chunks
4. **Archival**: Move old completed conversations to cold storage

### Implementation Note

For MVP, we accept these limitations. The LangChain library handles token counting, and we can add summarization logic later:

```elixir
# Future enhancement in Service.execute/3
defp build_conversation_history(task_id, max_tokens \\ 100_000) do
  messages = KanbanMessage.for_task!(task_id)

  # Simple approach: take last N messages that fit
  messages
  |> Enum.reverse()
  |> Enum.reduce_while({[], 0}, fn msg, {acc, tokens} ->
    msg_tokens = estimate_tokens(msg.content)
    if tokens + msg_tokens > max_tokens do
      {:halt, {acc, tokens}}
    else
      {:cont, {[msg | acc], tokens + msg_tokens}}
    end
  end)
  |> elem(0)
end
```

---

## Success Criteria Verification

| Criteria | How to Verify |
|----------|---------------|
| Task details page has text input | Open task details, see chat input at bottom |
| User text is sent to LLM | Type message, see it appear in chat, see "thinking" status |
| LLM response streams in real-time | Watch response appear character by character |
| Full message history persists | Refresh page, see previous messages load |
| Messages can be queued | Send multiple messages quickly, they process in order |

---

## Future Enhancements (Post-MVP)

1. **Multi-provider support**: Add OpenAI, Ollama, local models
2. **Tool/function calling**: Let LLM execute code actions
3. **Conversation branching**: Fork conversations to try different approaches
4. **Cost tracking**: Track token usage and costs per task
5. **System prompts**: Customizable prompts per project/board
6. **File attachments**: Upload code files for context
7. **Code execution**: Sandboxed execution of generated code

---

## References

- [LangChain for Elixir](https://github.com/brainlid/langchain) - LLM provider abstraction
- [Oban Documentation](https://hexdocs.pm/oban) - Job queue
- [Phoenix Channels](https://hexdocs.pm/phoenix/channels.html) - Real-time communication
- [Anthropic API](https://docs.anthropic.com/) - Claude API reference
