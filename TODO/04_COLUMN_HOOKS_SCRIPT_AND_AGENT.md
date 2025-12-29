# Feature: Column Hooks - Script Hooks & Agent Hooks

## Overview

Extend the existing hook system to support two types of column hooks:

1. **Script Hooks**: Execute arbitrary shell scripts (with shebang support) when tasks enter/leave a column. These are powerful automation primitives that can do anything the user's system allows.

2. **Agent Hooks**: Run an AI agent with a specific prompt when tasks enter/leave a column. Perfect for automated review, PR creation, code analysis, etc.

**Primary Use Case**: An "onEntry" hook on the "To Review" column that runs the prompt: *"If this task makes any code changes, create a PR and fill in PR title and description using the repository PR template."*

## User Stories

1. **Create Script Hook**: As a user, I can create a script hook that runs any executable script when triggered.
2. **Create Agent Hook**: As a user, I can create an agent hook that runs an AI agent with a custom prompt.
3. **Shebang Support**: As a user, my script hooks respect shebangs (#!/bin/bash, #!/usr/bin/env python, etc.).
4. **Hook Triggers**: As a user, I can configure hooks to run on_entry, on_leave, or persistently.
5. **Agent Context**: As a user, agent hooks receive the task context (title, description, worktree, changes).
6. **Hook Output**: As a user, I can see the output/results of hook execution in the task chat.
7. **Hook Chaining**: As a user, I can have multiple hooks that run in sequence on the same trigger.

## Technical Design

### Data Model Changes

#### Updated Hook Resource

```elixir
# backend/lib/viban/kanban/hook.ex

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

    # Common attributes
    attribute :name, :string, allow_nil?: false

    # Hook type discriminator
    attribute :hook_kind, :atom do
      constraints one_of: [:script, :agent]
      default :script
      allow_nil? false
    end

    # Script hook attributes
    attribute :command, :string do
      description "Shell command or script path for script hooks"
      allow_nil? true
    end

    attribute :cleanup_command, :string do
      description "Command to run when persistent hook is stopped"
      allow_nil? true
    end

    # Agent hook attributes
    attribute :agent_prompt, :string do
      description "System prompt for agent hooks"
      allow_nil? true
    end

    attribute :agent_executor, :atom do
      description "Which executor to use for agent hooks"
      constraints one_of: [:claude_code, :gemini_cli, :codex, :opencode, :cursor_agent]
      default :claude_code
      allow_nil? true
    end

    attribute :agent_auto_approve, :boolean do
      description "Whether agent can auto-approve tool calls"
      default false
    end

    # Common configuration
    attribute :working_directory, :atom do
      constraints one_of: [:worktree, :project_root]
      default :worktree
    end

    attribute :timeout_ms, :integer do
      default 300_000  # 5 minutes for agent hooks
    end

    timestamps()
  end

  relationships do
    belongs_to :board, Viban.Kanban.Board
    has_many :column_hooks, Viban.Kanban.ColumnHook
  end

  validations do
    # Script hooks require command
    validate fn changeset, _context ->
      kind = Ash.Changeset.get_attribute(changeset, :hook_kind)
      command = Ash.Changeset.get_attribute(changeset, :command)

      if kind == :script and (is_nil(command) or command == "") do
        {:error, field: :command, message: "is required for script hooks"}
      else
        :ok
      end
    end

    # Agent hooks require prompt
    validate fn changeset, _context ->
      kind = Ash.Changeset.get_attribute(changeset, :hook_kind)
      prompt = Ash.Changeset.get_attribute(changeset, :agent_prompt)

      if kind == :agent and (is_nil(prompt) or prompt == "") do
        {:error, field: :agent_prompt, message: "is required for agent hooks"}
      else
        :ok
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create_script_hook do
      accept [:name, :command, :cleanup_command, :working_directory, :timeout_ms]
      argument :board_id, :uuid, allow_nil?: false

      change set_attribute(:hook_kind, :script)
      change manage_relationship(:board_id, :board, type: :append)
    end

    create :create_agent_hook do
      accept [:name, :agent_prompt, :agent_executor, :agent_auto_approve, :working_directory, :timeout_ms]
      argument :board_id, :uuid, allow_nil?: false

      change set_attribute(:hook_kind, :agent)
      change manage_relationship(:board_id, :board, type: :append)
    end

    update :update do
      accept [:name, :command, :cleanup_command, :agent_prompt, :agent_executor,
              :agent_auto_approve, :working_directory, :timeout_ms]
    end
  end
end
```

#### Database Migration

```elixir
# backend/priv/repo/migrations/YYYYMMDDHHMMSS_add_agent_hooks.exs

defmodule Viban.Repo.Migrations.AddAgentHooks do
  use Ecto.Migration

  def change do
    alter table(:hooks) do
      # Add hook kind discriminator
      add :hook_kind, :string, default: "script", null: false

      # Agent-specific fields
      add :agent_prompt, :text
      add :agent_executor, :string
      add :agent_auto_approve, :boolean, default: false

      # Make command nullable (only required for script hooks)
      modify :command, :string, null: true
    end

    # Backfill existing hooks as script hooks
    execute "UPDATE hooks SET hook_kind = 'script' WHERE hook_kind IS NULL"
  end
end
```

### Hook Execution Engine

#### Extended HookRunner

```elixir
# backend/lib/viban/kanban/actors/hook_runner.ex

defmodule Viban.Kanban.Actors.HookRunner do
  @moduledoc """
  Executes both script hooks (shell commands) and agent hooks (AI agents).
  """

  require Logger
  alias Viban.Kanban
  alias Viban.Executors.Executor

  @doc """
  Execute a hook based on its kind.
  Returns {:ok, output} or {:error, reason}
  """
  def execute(hook, task, opts \\ []) do
    case hook.hook_kind do
      :script -> execute_script(hook, task, opts)
      :agent -> execute_agent(hook, task, opts)
    end
  end

  @doc """
  Execute a script hook (existing functionality).
  """
  def execute_script(hook, task, opts) do
    working_dir = resolve_working_directory(hook.working_directory, task)
    timeout = hook.timeout_ms || 30_000

    # Build environment variables for the script
    env = build_script_env(task, hook)

    run_command(hook.command, working_dir, timeout, env)
  end

  @doc """
  Execute an agent hook - runs an AI agent with the specified prompt.
  """
  def execute_agent(hook, task, opts) do
    working_dir = resolve_working_directory(hook.working_directory, task)

    # Build the full prompt with task context
    full_prompt = build_agent_prompt(hook.agent_prompt, task)

    # Log hook execution start
    log_hook_message(task, :assistant, "Running agent hook: #{hook.name}...")

    # Execute via the Executor system
    case Executor.execute_hook(
      task.id,
      full_prompt,
      hook.agent_executor || :claude_code,
      working_directory: working_dir,
      auto_approve: hook.agent_auto_approve,
      timeout_ms: hook.timeout_ms
    ) do
      {:ok, result} ->
        log_hook_message(task, :assistant, "Agent hook completed: #{hook.name}")
        {:ok, result}

      {:error, reason} ->
        log_hook_message(task, :assistant, "Agent hook failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_agent_prompt(base_prompt, task) do
    """
    You are executing an automated hook for a task. Here is the context:

    ## Task Information
    - **Title**: #{task.title}
    - **Description**: #{task.description || "(No description)"}
    - **Status**: #{task.column.name}
    - **Worktree Path**: #{task.worktree_path || "N/A"}

    ## Your Instructions
    #{base_prompt}

    ## Important Notes
    - This is an automated hook execution, not an interactive session
    - Complete the task efficiently and report your actions
    - If you cannot complete the task, clearly explain why
    """
  end

  defp build_script_env(task, _hook) do
    [
      {"VIBAN_TASK_ID", task.id},
      {"VIBAN_TASK_TITLE", task.title},
      {"VIBAN_TASK_DESCRIPTION", task.description || ""},
      {"VIBAN_COLUMN_NAME", task.column.name},
      {"VIBAN_WORKTREE_PATH", task.worktree_path || ""},
      {"VIBAN_BOARD_ID", task.column.board_id}
    ]
  end

  defp log_hook_message(task, role, content) do
    Kanban.create_message(%{
      task_id: task.id,
      role: role,
      content: content,
      status: :completed
    })
  end

  # ... existing run_command/4 and other helper functions ...

  defp run_command(command, working_dir, timeout, env) do
    task = Task.async(fn ->
      # Create temp script file for proper shebang handling
      script_path = write_temp_script(command)

      try do
        port = Port.open({:spawn_executable, script_path}, [
          :binary,
          :exit_status,
          :stderr_to_stdout,
          {:cd, working_dir},
          {:env, env},
          {:args, []}
        ])

        collect_output(port, "")
      after
        File.rm(script_path)
      end
    end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
    end
  end

  defp write_temp_script(command) do
    path = Path.join(System.tmp_dir!(), "viban_hook_#{:erlang.unique_integer([:positive])}")

    # If command doesn't start with shebang, add bash shebang
    script_content = if String.starts_with?(command, "#!") do
      command
    else
      "#!/bin/bash\nset -e\n#{command}"
    end

    File.write!(path, script_content)
    File.chmod!(path, 0o755)
    path
  end

  defp collect_output(port, acc) do
    receive do
      {^port, {:data, data}} ->
        collect_output(port, acc <> data)
      {^port, {:exit_status, 0}} ->
        {:ok, acc}
      {^port, {:exit_status, status}} ->
        {:error, {:exit_status, status, acc}}
    end
  end

  defp resolve_working_directory(:worktree, task) do
    task.worktree_path || File.cwd!()
  end

  defp resolve_working_directory(:project_root, _task) do
    File.cwd!()
  end
end
```

#### Executor Extension for Hooks

```elixir
# backend/lib/viban/executors/executor.ex - Add hook execution

defmodule Viban.Executors.Executor do
  # ... existing code ...

  @doc """
  Execute a hook prompt without full session management.
  Used for agent hooks that run as part of column transitions.
  """
  action :execute_hook do
    argument :task_id, :uuid, allow_nil?: false
    argument :prompt, :string, allow_nil?: false
    argument :executor_type, :atom, allow_nil?: false
    argument :working_directory, :string
    argument :auto_approve, :boolean, default: false
    argument :timeout_ms, :integer, default: 300_000

    run fn input, _context ->
      task = Viban.Kanban.get_task!(input.arguments.task_id)

      # Create a hook-specific runner that's isolated from the main task runner
      case Viban.Executors.HookExecutor.run(
        task,
        input.arguments.prompt,
        input.arguments.executor_type,
        working_directory: input.arguments.working_directory,
        auto_approve: input.arguments.auto_approve,
        timeout_ms: input.arguments.timeout_ms
      ) do
        {:ok, output} -> {:ok, output}
        {:error, reason} -> {:error, reason}
      end
    end
  end
end
```

#### Hook-Specific Executor

```elixir
# backend/lib/viban/executors/hook_executor.ex

defmodule Viban.Executors.HookExecutor do
  @moduledoc """
  Specialized executor for running hooks.
  Unlike the main Runner, this doesn't manage interactive sessions
  but runs a single prompt to completion.
  """

  require Logger

  def run(task, prompt, executor_type, opts \\ []) do
    working_dir = Keyword.get(opts, :working_directory, task.worktree_path || File.cwd!())
    auto_approve = Keyword.get(opts, :auto_approve, false)
    timeout = Keyword.get(opts, :timeout_ms, 300_000)

    # Build the command based on executor type
    {executable, args} = build_command(executor_type, prompt, working_dir, auto_approve)

    Logger.info("Executing hook with #{executor_type}: #{prompt |> String.slice(0, 100)}...")

    # Run synchronously with timeout
    task_ref = Task.async(fn ->
      port = Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        {:cd, working_dir},
        {:args, args}
      ])

      collect_output(port, "")
    end)

    case Task.yield(task_ref, timeout) || Task.shutdown(task_ref) do
      {:ok, {:ok, output}} ->
        Logger.info("Hook completed successfully")
        {:ok, output}

      {:ok, {:error, reason}} ->
        Logger.error("Hook failed: #{inspect(reason)}")
        {:error, reason}

      nil ->
        Logger.error("Hook timed out after #{timeout}ms")
        {:error, :timeout}
    end
  end

  defp build_command(:claude_code, prompt, _working_dir, auto_approve) do
    args = ["--print", "--output-format", "text"]
    args = if auto_approve, do: args ++ ["--dangerously-skip-permissions"], else: args
    args = args ++ ["--prompt", prompt]

    {find_executable("claude"), args}
  end

  defp build_command(:gemini_cli, prompt, _working_dir, _auto_approve) do
    {find_executable("gemini"), ["--prompt", prompt]}
  end

  defp build_command(:codex, prompt, _working_dir, auto_approve) do
    args = if auto_approve, do: ["--auto-approve"], else: []
    args = args ++ [prompt]

    {find_executable("codex"), args}
  end

  defp build_command(:opencode, prompt, _working_dir, _auto_approve) do
    {find_executable("opencode"), ["--prompt", prompt]}
  end

  defp build_command(:cursor_agent, prompt, _working_dir, _auto_approve) do
    {find_executable("cursor"), ["--prompt", prompt]}
  end

  defp find_executable(name) do
    case System.find_executable(name) do
      nil -> raise "Executable '#{name}' not found in PATH"
      path -> path
    end
  end

  defp collect_output(port, acc) do
    receive do
      {^port, {:data, data}} ->
        collect_output(port, acc <> data)
      {^port, {:exit_status, 0}} ->
        {:ok, acc}
      {^port, {:exit_status, status}} ->
        {:error, {:exit_status, status, acc}}
    end
  end
end
```

### Frontend Changes

#### Updated Hook Types

```typescript
// frontend/src/lib/types/hook.ts

export type HookKind = "script" | "agent";

export type AgentExecutor =
  | "claude_code"
  | "gemini_cli"
  | "codex"
  | "opencode"
  | "cursor_agent";

export interface Hook {
  id: string;
  board_id: string;
  name: string;
  hook_kind: HookKind;

  // Script hook fields
  command: string | null;
  cleanup_command: string | null;

  // Agent hook fields
  agent_prompt: string | null;
  agent_executor: AgentExecutor | null;
  agent_auto_approve: boolean;

  // Common fields
  working_directory: "worktree" | "project_root";
  timeout_ms: number;

  inserted_at: string;
  updated_at: string;
}
```

#### Hook Creation Modal

```tsx
// frontend/src/components/CreateHookModal.tsx

import { createSignal, Show } from "solid-js";
import { Modal } from "./ui/Modal";

interface Props {
  boardId: string;
  onClose: () => void;
  onCreated: (hook: Hook) => void;
}

export function CreateHookModal(props: Props) {
  const [hookKind, setHookKind] = createSignal<HookKind>("script");
  const [name, setName] = createSignal("");

  // Script fields
  const [command, setCommand] = createSignal("");
  const [cleanupCommand, setCleanupCommand] = createSignal("");

  // Agent fields
  const [agentPrompt, setAgentPrompt] = createSignal("");
  const [agentExecutor, setAgentExecutor] = createSignal<AgentExecutor>("claude_code");
  const [autoApprove, setAutoApprove] = createSignal(false);

  // Common fields
  const [workingDirectory, setWorkingDirectory] = createSignal<"worktree" | "project_root">("worktree");
  const [timeoutMs, setTimeoutMs] = createSignal(300000);

  const handleSubmit = async (e: Event) => {
    e.preventDefault();

    const basePayload = {
      board_id: props.boardId,
      name: name(),
      working_directory: workingDirectory(),
      timeout_ms: timeoutMs(),
    };

    let payload;
    if (hookKind() === "script") {
      payload = {
        ...basePayload,
        hook_kind: "script",
        command: command(),
        cleanup_command: cleanupCommand() || null,
      };
    } else {
      payload = {
        ...basePayload,
        hook_kind: "agent",
        agent_prompt: agentPrompt(),
        agent_executor: agentExecutor(),
        agent_auto_approve: autoApprove(),
      };
    }

    const hook = await createHook(payload);
    props.onCreated(hook);
    props.onClose();
  };

  return (
    <Modal onClose={props.onClose}>
      <form onSubmit={handleSubmit} class="space-y-4">
        <h2 class="text-xl font-semibold">Create Hook</h2>

        {/* Hook Kind Selector */}
        <div class="flex gap-2 p-1 bg-zinc-800 rounded-lg">
          <button
            type="button"
            onClick={() => setHookKind("script")}
            class={`flex-1 px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              hookKind() === "script"
                ? "bg-zinc-600 text-white"
                : "text-zinc-400 hover:text-white"
            }`}
          >
            <TerminalIcon class="w-4 h-4 inline mr-2" />
            Script Hook
          </button>
          <button
            type="button"
            onClick={() => setHookKind("agent")}
            class={`flex-1 px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              hookKind() === "agent"
                ? "bg-purple-600 text-white"
                : "text-zinc-400 hover:text-white"
            }`}
          >
            <SparklesIcon class="w-4 h-4 inline mr-2" />
            Agent Hook
          </button>
        </div>

        {/* Name */}
        <div>
          <label class="block text-sm font-medium text-zinc-300 mb-1">
            Hook Name
          </label>
          <input
            type="text"
            value={name()}
            onInput={(e) => setName(e.currentTarget.value)}
            placeholder={hookKind() === "script" ? "e.g., Run Tests" : "e.g., Create PR on Review"}
            class="w-full px-3 py-2 bg-zinc-800 border border-zinc-700 rounded-md"
            required
          />
        </div>

        {/* Script-specific fields */}
        <Show when={hookKind() === "script"}>
          <div>
            <label class="block text-sm font-medium text-zinc-300 mb-1">
              Command
            </label>
            <textarea
              value={command()}
              onInput={(e) => setCommand(e.currentTarget.value)}
              placeholder={`#!/bin/bash
# Your script here
npm run test`}
              rows={6}
              class="w-full px-3 py-2 bg-zinc-800 border border-zinc-700 rounded-md font-mono text-sm"
              required
            />
            <p class="text-xs text-zinc-500 mt-1">
              Supports shebangs (#!/bin/bash, #!/usr/bin/env python, etc.)
            </p>
          </div>

          <div>
            <label class="block text-sm font-medium text-zinc-300 mb-1">
              Cleanup Command (optional)
            </label>
            <input
              type="text"
              value={cleanupCommand()}
              onInput={(e) => setCleanupCommand(e.currentTarget.value)}
              placeholder="e.g., docker-compose down"
              class="w-full px-3 py-2 bg-zinc-800 border border-zinc-700 rounded-md font-mono text-sm"
            />
          </div>
        </Show>

        {/* Agent-specific fields */}
        <Show when={hookKind() === "agent"}>
          <div>
            <label class="block text-sm font-medium text-zinc-300 mb-1">
              Agent Prompt
            </label>
            <textarea
              value={agentPrompt()}
              onInput={(e) => setAgentPrompt(e.currentTarget.value)}
              placeholder="If this task makes any code changes, create a PR and fill in PR title and description using the repository PR template."
              rows={6}
              class="w-full px-3 py-2 bg-zinc-800 border border-zinc-700 rounded-md"
              required
            />
            <p class="text-xs text-zinc-500 mt-1">
              The agent will receive full task context (title, description, worktree, etc.)
            </p>
          </div>

          <div>
            <label class="block text-sm font-medium text-zinc-300 mb-1">
              Agent Executor
            </label>
            <select
              value={agentExecutor()}
              onChange={(e) => setAgentExecutor(e.currentTarget.value as AgentExecutor)}
              class="w-full px-3 py-2 bg-zinc-800 border border-zinc-700 rounded-md"
            >
              <option value="claude_code">Claude Code</option>
              <option value="gemini_cli">Gemini CLI</option>
              <option value="codex">Codex</option>
              <option value="opencode">OpenCode</option>
              <option value="cursor_agent">Cursor Agent</option>
            </select>
          </div>

          <div class="flex items-center gap-2">
            <input
              type="checkbox"
              id="autoApprove"
              checked={autoApprove()}
              onChange={(e) => setAutoApprove(e.currentTarget.checked)}
              class="w-4 h-4 rounded bg-zinc-800 border-zinc-700"
            />
            <label for="autoApprove" class="text-sm text-zinc-300">
              Auto-approve tool calls (use with caution)
            </label>
          </div>
        </Show>

        {/* Common fields */}
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-zinc-300 mb-1">
              Working Directory
            </label>
            <select
              value={workingDirectory()}
              onChange={(e) => setWorkingDirectory(e.currentTarget.value as "worktree" | "project_root")}
              class="w-full px-3 py-2 bg-zinc-800 border border-zinc-700 rounded-md"
            >
              <option value="worktree">Task Worktree</option>
              <option value="project_root">Project Root</option>
            </select>
          </div>

          <div>
            <label class="block text-sm font-medium text-zinc-300 mb-1">
              Timeout (seconds)
            </label>
            <input
              type="number"
              value={timeoutMs() / 1000}
              onInput={(e) => setTimeoutMs(parseInt(e.currentTarget.value) * 1000)}
              min={10}
              max={3600}
              class="w-full px-3 py-2 bg-zinc-800 border border-zinc-700 rounded-md"
            />
          </div>
        </div>

        {/* Actions */}
        <div class="flex justify-end gap-2 pt-4">
          <button
            type="button"
            onClick={props.onClose}
            class="px-4 py-2 text-sm text-zinc-400 hover:text-white"
          >
            Cancel
          </button>
          <button
            type="submit"
            class="px-4 py-2 text-sm bg-purple-600 hover:bg-purple-700 text-white rounded-md"
          >
            Create Hook
          </button>
        </div>
      </form>
    </Modal>
  );
}
```

#### Hook List with Kind Indicator

```tsx
// frontend/src/components/HookManager.tsx (updated)

export function HookManager(props: { boardId: string }) {
  const [hooks] = createResource(() => props.boardId, fetchHooks);
  const [showCreateModal, setShowCreateModal] = createSignal(false);

  return (
    <div class="space-y-4">
      <div class="flex justify-between items-center">
        <h3 class="text-lg font-semibold">Hooks</h3>
        <button
          onClick={() => setShowCreateModal(true)}
          class="px-3 py-1.5 text-sm bg-zinc-700 hover:bg-zinc-600 rounded-md"
        >
          + Create Hook
        </button>
      </div>

      <div class="space-y-2">
        <For each={hooks()} fallback={
          <div class="text-center py-8 text-zinc-500">
            No hooks yet. Create one to automate column transitions.
          </div>
        }>
          {(hook) => (
            <div class="flex items-center justify-between p-3 bg-zinc-800 rounded-lg">
              <div class="flex items-center gap-3">
                {/* Kind indicator */}
                <div class={`p-2 rounded-lg ${
                  hook.hook_kind === "agent"
                    ? "bg-purple-600/20"
                    : "bg-zinc-700"
                }`}>
                  <Show
                    when={hook.hook_kind === "agent"}
                    fallback={<TerminalIcon class="w-4 h-4 text-zinc-400" />}
                  >
                    <SparklesIcon class="w-4 h-4 text-purple-400" />
                  </Show>
                </div>

                <div>
                  <div class="flex items-center gap-2">
                    <span class="font-medium">{hook.name}</span>
                    <span class={`px-1.5 py-0.5 text-xs rounded ${
                      hook.hook_kind === "agent"
                        ? "bg-purple-600/20 text-purple-400"
                        : "bg-zinc-700 text-zinc-400"
                    }`}>
                      {hook.hook_kind === "agent" ? "Agent" : "Script"}
                    </span>
                  </div>
                  <p class="text-sm text-zinc-500 mt-0.5 max-w-md truncate">
                    {hook.hook_kind === "agent"
                      ? hook.agent_prompt
                      : hook.command}
                  </p>
                </div>
              </div>

              <div class="flex gap-2">
                <button
                  onClick={() => editHook(hook)}
                  class="text-zinc-400 hover:text-white"
                >
                  <EditIcon class="w-4 h-4" />
                </button>
                <button
                  onClick={() => deleteHook(hook.id)}
                  class="text-zinc-400 hover:text-red-400"
                >
                  <TrashIcon class="w-4 h-4" />
                </button>
              </div>
            </div>
          )}
        </For>
      </div>

      <Show when={showCreateModal()}>
        <CreateHookModal
          boardId={props.boardId}
          onClose={() => setShowCreateModal(false)}
          onCreated={() => refetch()}
        />
      </Show>
    </div>
  );
}
```

### Integration with Task Lifecycle

#### TaskActor Hook Execution

```elixir
# backend/lib/viban/kanban/actors/task_actor.ex - Updated hook handling

defp execute_column_hooks(task, old_column, new_column) do
  # Get hooks that need to run
  on_leave_hooks = get_column_hooks(old_column, :on_leave)
  on_entry_hooks = get_column_hooks(new_column, :on_entry)

  # Execute on_leave hooks first
  for hook <- on_leave_hooks do
    case HookRunner.execute(hook, task) do
      {:ok, output} ->
        Logger.info("Hook #{hook.name} completed: #{String.slice(output, 0, 100)}")
      {:error, reason} ->
        Logger.warning("Hook #{hook.name} failed: #{inspect(reason)}")
        # on_leave hooks failing doesn't block the transition
    end
  end

  # Execute on_entry hooks - these CAN block the transition
  for hook <- on_entry_hooks do
    case HookRunner.execute(hook, task) do
      {:ok, output} ->
        Logger.info("Hook #{hook.name} completed")
        :ok
      {:error, reason} ->
        Logger.error("Hook #{hook.name} failed, blocking transition: #{inspect(reason)}")
        # Optionally: move task back or set error state
        update_task_error(task, "Hook '#{hook.name}' failed: #{inspect(reason)}")
        throw {:hook_failed, hook.name, reason}
    end
  end

  :ok
catch
  {:hook_failed, name, reason} ->
    {:error, {:hook_failed, name, reason}}
end
```

## Example Use Cases

### 1. Auto-Create PR on Review Entry

```
Hook Name: Create PR for Code Changes
Hook Kind: Agent
Agent Prompt: |
  Check if this task has any uncommitted code changes in the worktree.
  If there are changes:
  1. Create a new branch named after the task title (slugified)
  2. Commit all changes with a descriptive message
  3. Push the branch to the remote
  4. Create a Pull Request using the repository's PR template
  5. Fill in the PR title and description based on the task description

  If there are no changes, report that no PR is needed.
Trigger: on_entry for "To Review" column
```

### 2. Run Linter Before Review

```
Hook Name: Lint Check
Hook Kind: Script
Command: |
  #!/bin/bash
  set -e

  if [ -f "package.json" ]; then
    npm run lint
  elif [ -f "mix.exs" ]; then
    mix format --check-formatted
  fi
Trigger: on_entry for "To Review" column
```

### 3. Notify Slack on Done

```
Hook Name: Slack Notification
Hook Kind: Script
Command: |
  #!/bin/bash
  curl -X POST "$SLACK_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"Task completed: $VIBAN_TASK_TITLE\"}"
Trigger: on_entry for "Done" column
```

### 4. Auto-Deploy on Done

```
Hook Name: Deploy to Staging
Hook Kind: Agent
Agent Prompt: |
  Deploy the changes from this task to the staging environment.
  1. Merge the task's PR if it exists and is approved
  2. Run the deployment script
  3. Verify the deployment succeeded
  4. Report the deployment status
Trigger: on_entry for "Done" column
```

## Implementation Steps

### Phase 1: Database & Models (Day 1)
1. Create migration to add agent hook fields
2. Update Hook resource with validations
3. Add new create actions for each hook type
4. Test model validations

### Phase 2: Execution Engine (Day 2)
1. Extend HookRunner for agent hooks
2. Create HookExecutor module
3. Add executor action for hooks
4. Test both script and agent execution

### Phase 3: Frontend - Hook CRUD (Day 3)
1. Update Hook types
2. Create CreateHookModal with kind selector
3. Update HookManager to show hook kinds
4. Add edit functionality for both types

### Phase 4: Integration (Day 4)
1. Update TaskActor hook execution
2. Test full lifecycle with both hook types
3. Add output logging to task chat
4. Handle errors gracefully

### Phase 5: Polish & Testing (Day 5)
1. Add hook execution status indicators
2. Improve error messages
3. Add hook templates/presets
4. Write tests
5. Documentation

## Success Criteria

- [ ] User can create script hooks with shebang-supported commands
- [ ] User can create agent hooks with custom prompts
- [ ] Script hooks execute in the correct working directory
- [ ] Agent hooks receive full task context
- [ ] Hook output appears in task chat
- [ ] Failed hooks don't silently break transitions
- [ ] Both hook types can be assigned to any column trigger
- [ ] Auto-approve option works for agent hooks
- [ ] Timeout handling works for both types

## Technical Considerations

1. **Security**: Agent hooks with auto_approve can execute arbitrary commands - warn users
2. **Timeouts**: Agent hooks may take longer; default to 5 minutes vs 30 seconds for scripts
3. **Concurrency**: Multiple hooks on same trigger run sequentially
4. **Error Recovery**: On-entry hook failures should be clearly reported
5. **Resource Usage**: Agent hooks consume API credits - track/limit usage
6. **Output Size**: Limit/truncate hook output logged to chat

## Future Enhancements

1. **Hook Templates**: Pre-built agent prompts for common use cases
2. **Conditional Hooks**: Only run hook if certain conditions are met
3. **Hook Metrics**: Track execution time, success rate, etc.
4. **Hook Chains**: Visual workflow builder for complex automations
5. **Hook Marketplace**: Share and install community hooks
