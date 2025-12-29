# Executor System Architecture Plan

## Problem Statement

The current implementation uses LangChain to call the Anthropic API directly, which:
1. Requires API keys to be configured
2. Doesn't leverage local CLI tools the user already has authenticated (Claude Code, Gemini CLI, etc.)
3. Doesn't match how Vibe Kanban works (spawning CLI subprocesses)

## Goals

1. **CLI-first approach**: Spawn local CLI tools (Claude Code, Gemini CLI, Codex, etc.) as subprocesses
2. **Unified interface**: Create an abstraction that works for both CLI executors AND API-based providers
3. **Ash Resource integration**: Model executors as Ash Resources with generic actions for future extensibility
4. **Streaming output**: Support real-time streaming of executor output to the frontend

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Ash Domain: Viban.Executors               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐   ┌─────────────────┐   ┌──────────────┐  │
│  │ Executor        │   │ ExecutorSession │   │ ExecutorLog  │  │
│  │ (no data layer) │   │ (persisted)     │   │ (persisted)  │  │
│  │                 │   │                 │   │              │  │
│  │ Generic Actions:│   │ - id            │   │ - id         │  │
│  │ - :list_available│  │ - task_id       │   │ - session_id │  │
│  │ - :execute      │   │ - executor_type │   │ - content    │  │
│  │ - :send_input   │   │ - status        │   │ - log_type   │  │
│  │ - :stop         │   │ - pid (virtual) │   │ - timestamp  │  │
│  └─────────────────┘   └─────────────────┘   └──────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Executor Behaviour                           │
├─────────────────────────────────────────────────────────────────┤
│  @callback available?() :: boolean                              │
│  @callback build_command(prompt, opts) :: {binary, [binary]}    │
│  @callback parse_output(binary) :: parsed_output                │
│  @callback capabilities() :: [atom]                             │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ ClaudeCode    │   │ GeminiCLI     │   │ Codex         │
│ Executor      │   │ Executor      │   │ Executor      │
│               │   │               │   │               │
│ claude -p ... │   │ npx gemini... │   │ codex ...     │
└───────────────┘   └───────────────┘   └───────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   ExecutorRunner (GenServer)                    │
├─────────────────────────────────────────────────────────────────┤
│  - Manages subprocess lifecycle via Port/ExPTY                  │
│  - Streams stdout/stderr to Phoenix Channel                     │
│  - Handles process termination and cleanup                      │
│  - Stores logs in ExecutorLog                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│               Phoenix Channel: task:{task_id}                   │
├─────────────────────────────────────────────────────────────────┤
│  Events:                                                        │
│  - executor_started    { session_id, executor_type }            │
│  - executor_output     { session_id, content, type }            │
│  - executor_completed  { session_id, exit_code }                │
│  - executor_error      { session_id, error }                    │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation Plan

### Phase 1: Core Executor Infrastructure

#### 1.1 Create Executor Behaviour
```elixir
defmodule Viban.Executors.Behaviour do
  @callback name() :: String.t()
  @callback available?() :: boolean()
  @callback build_command(prompt :: String.t(), opts :: keyword()) ::
    {executable :: String.t(), args :: [String.t()]}
  @callback default_opts() :: keyword()
  @callback capabilities() :: [:streaming | :interactive | :mcp_support]
end
```

#### 1.2 Create Executor Implementations
- `Viban.Executors.ClaudeCode` - Claude Code CLI (`claude -p`)
- `Viban.Executors.GeminiCLI` - Gemini CLI (`npx @google/gemini-cli`)
- `Viban.Executors.Codex` - OpenAI Codex
- `Viban.Executors.OpenCode` - SST OpenCode

#### 1.3 Create ExecutorRunner GenServer
Uses Elixir Ports (or ExPTY for interactive mode) to:
- Spawn subprocess with the built command
- Stream stdout/stderr in real-time
- Handle process lifecycle
- Broadcast to Phoenix Channel

### Phase 2: Ash Resource Integration

#### 2.1 Executor Resource (No Data Layer)
```elixir
defmodule Viban.Executors.Executor do
  use Ash.Resource,
    domain: Viban.Executors,
    data_layer: Ash.DataLayer.Simple

  attributes do
    attribute :name, :string
    attribute :type, :atom
    attribute :available, :boolean
    attribute :capabilities, {:array, :atom}
  end

  actions do
    action :list_available, {:array, :struct} do
      constraints instance_of: __MODULE__
      run fn _input, _context ->
        executors = Viban.Executors.Registry.list_available()
        {:ok, executors}
      end
    end

    action :execute, :struct do
      argument :task_id, :uuid, allow_nil?: false
      argument :prompt, :string, allow_nil?: false
      argument :executor_type, :atom, allow_nil?: false
      argument :working_directory, :string

      run fn input, _context ->
        Viban.Executors.Runner.start(
          input.arguments.task_id,
          input.arguments.executor_type,
          input.arguments.prompt,
          working_directory: input.arguments.working_directory
        )
      end
    end
  end
end
```

#### 2.2 ExecutorSession Resource (Persisted)
Tracks running/completed executor sessions for a task.

#### 2.3 ExecutorLog Resource (Persisted)
Stores output logs for each session for later review.

### Phase 3: Phoenix Channel Integration

#### 3.1 Update TaskChannel
- Add `start_executor` event handler
- Add `stop_executor` event handler
- Broadcast executor events to subscribers

#### 3.2 Update Frontend
- Replace chat-based UI with executor-based UI
- Show real-time executor output
- Allow selecting executor type
- Show executor status/progress

### Phase 4: Remove Old LLM Code

#### 4.1 Remove LangChain Integration
- Delete `lib/viban/llm/` directory
- Delete `Viban.Workers.LLMMessageWorker`
- Remove `langchain` from mix.exs dependencies

#### 4.2 Update Message Resource
Keep messages for logging executor interactions, but change the model:
- User prompt → executor input
- Assistant response → executor output
- Status tracking → executor session status

## File Structure

```
lib/viban/executors/
├── executor.ex              # Ash Resource (no data layer)
├── executor_session.ex      # Ash Resource (persisted)
├── executor_log.ex          # Ash Resource (persisted)
├── behaviour.ex             # Executor behaviour definition
├── registry.ex              # Registry of available executors
├── runner.ex                # GenServer managing subprocess
├── implementations/
│   ├── claude_code.ex       # Claude Code CLI
│   ├── gemini_cli.ex        # Gemini CLI
│   ├── codex.ex             # OpenAI Codex
│   └── opencode.ex          # SST OpenCode
└── domain.ex                # Ash Domain
```

## Key Libraries

1. **Elixir Ports** - Basic subprocess management (sufficient for `-p` print mode)
2. **[ExPTY](https://github.com/cocoa-xu/ExPTY)** - For interactive PTY support (future enhancement)
3. **[Porcelain](https://github.com/alco/porcelain)** - Alternative for more complex subprocess needs

## Claude Code Integration Details

For Claude Code specifically, we'll use:
```bash
claude -p "prompt" \
  --output-format stream-json \
  --dangerously-skip-permissions \
  --max-turns 50
```

The `stream-json` output format provides structured events we can parse and stream to the frontend.

## Future Extensibility

### API-Based Executors
The same Executor behaviour can be implemented for API-based providers:
```elixir
defmodule Viban.Executors.AnthropicAPI do
  @behaviour Viban.Executors.Behaviour

  # Instead of building a CLI command, this would make HTTP requests
  # to the Anthropic API and stream responses
end
```

### Custom Executors
Users could define custom executors via configuration:
```elixir
config :viban, :custom_executors, [
  %{
    name: "my-script",
    command: "./scripts/ai-helper.sh",
    args: ["--prompt", "{prompt}"]
  }
]
```

## Migration Path

1. Implement new executor system alongside existing LLM code
2. Add feature flag to switch between old/new system
3. Test with Claude Code executor
4. Remove old LLM code once verified working
5. Add additional executor implementations

## Open Questions

1. Should we use ExPTY for full interactive mode, or is print mode (`-p`) sufficient?
   - **Recommendation**: Start with print mode, add interactive later if needed

2. How to handle executor configuration (API keys for API-based executors)?
   - **Recommendation**: Use Ash Resource attributes and environment variables

3. Should executor logs be stored as Messages or separate ExecutorLog?
   - **Recommendation**: Separate ExecutorLog for cleaner separation of concerns
