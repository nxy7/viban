import { createMemo, createResource, createSignal, For, Show } from "solid-js";
import {
  type AgentExecutor,
  type CombinedHook,
  type CreateAgentHookInput,
  type CreateScriptHookInput,
  createAgentHook,
  createScriptHook,
  deleteHook,
  fetchAllHooks,
  type HookKind,
  updateHook,
} from "~/lib/useKanban";
import ErrorBanner from "./ui/ErrorBanner";
import {
  EditIcon,
  SparklesIcon,
  SystemIcon,
  TerminalIcon,
  TrashIcon,
} from "./ui/Icons";

/** Maximum character length to show for agent prompt preview */
const AGENT_PROMPT_PREVIEW_LENGTH = 100;

/** Display labels for agent executors */
const AGENT_EXECUTOR_LABELS: Record<AgentExecutor, string> = {
  claude_code: "Claude Code",
  gemini_cli: "Gemini CLI",
  codex: "Codex",
  opencode: "OpenCode",
  cursor_agent: "Cursor Agent",
};

interface HookManagerProps {
  boardId: string;
}

export default function HookManager(props: HookManagerProps) {
  // Use createResource to fetch combined hooks from API
  const [allHooks, { refetch }] = createResource(
    () => props.boardId,
    fetchAllHooks,
  );

  const [isCreating, setIsCreating] = createSignal(false);
  const [editingHook, setEditingHook] = createSignal<CombinedHook | null>(null);
  const [error, setError] = createSignal<string | null>(null);

  // Form state
  const [hookKind, setHookKind] = createSignal<HookKind>("script");
  const [name, setName] = createSignal("");
  // Script fields
  const [command, setCommand] = createSignal("");
  // Agent fields
  const [agentPrompt, setAgentPrompt] = createSignal("");
  const [agentExecutor, setAgentExecutor] =
    createSignal<AgentExecutor>("claude_code");
  const [agentAutoApprove, setAgentAutoApprove] = createSignal(false);
  const [isSaving, setIsSaving] = createSignal(false);

  // Split hooks into system and custom using createMemo for efficiency
  const systemHooks = createMemo(() =>
    (allHooks() ?? []).filter((h) => h.is_system),
  );
  const customHooks = createMemo(() =>
    (allHooks() ?? []).filter((h) => !h.is_system),
  );

  const resetForm = () => {
    setHookKind("script");
    setName("");
    setCommand("");
    setAgentPrompt("");
    setAgentExecutor("claude_code");
    setAgentAutoApprove(false);
    setError(null);
  };

  const startCreate = () => {
    resetForm();
    setIsCreating(true);
    setEditingHook(null);
  };

  const startEdit = (hook: CombinedHook) => {
    // Don't allow editing system hooks
    if (hook.is_system) return;

    setHookKind(hook.hook_kind || "script");
    setName(hook.name);
    setCommand(hook.command || "");
    setAgentPrompt(hook.agent_prompt || "");
    setAgentExecutor(hook.agent_executor || "claude_code");
    setAgentAutoApprove(hook.agent_auto_approve || false);
    setEditingHook(hook);
    setIsCreating(false);
    setError(null);
  };

  const cancelEdit = () => {
    resetForm();
    setIsCreating(false);
    setEditingHook(null);
  };

  const handleSave = async () => {
    if (!name().trim()) {
      setError("Name is required");
      return;
    }

    if (hookKind() === "script" && !command().trim()) {
      setError("Command is required for script hooks");
      return;
    }

    if (hookKind() === "agent" && !agentPrompt().trim()) {
      setError("Prompt is required for agent hooks");
      return;
    }

    setIsSaving(true);
    setError(null);

    try {
      if (isCreating()) {
        if (hookKind() === "script") {
          const input: CreateScriptHookInput = {
            name: name().trim(),
            command: command().trim(),
            board_id: props.boardId,
          };
          await createScriptHook(input);
        } else {
          const input: CreateAgentHookInput = {
            name: name().trim(),
            agent_prompt: agentPrompt().trim(),
            agent_executor: agentExecutor(),
            agent_auto_approve: agentAutoApprove(),
            board_id: props.boardId,
          };
          await createAgentHook(input);
        }
      } else {
        const hookToEdit = editingHook();
        if (!hookToEdit) return;
        await updateHook(hookToEdit.id, {
          name: name().trim(),
          command: hookKind() === "script" ? command().trim() : undefined,
          agent_prompt:
            hookKind() === "agent" ? agentPrompt().trim() : undefined,
          agent_executor: hookKind() === "agent" ? agentExecutor() : undefined,
          agent_auto_approve:
            hookKind() === "agent" ? agentAutoApprove() : undefined,
        });
      }
      cancelEdit();
      refetch();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to save hook");
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async (hookId: string) => {
    if (!confirm("Are you sure you want to delete this hook?")) return;

    try {
      await deleteHook(hookId);
      refetch();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to delete hook");
    }
  };

  /** Get display label for an agent executor */
  const getExecutorLabel = (
    executor: AgentExecutor | null | undefined,
  ): string =>
    executor
      ? (AGENT_EXECUTOR_LABELS[executor] ?? "Claude Code")
      : "Claude Code";

  return (
    <div class="space-y-4">
      <div class="flex justify-between items-center">
        <h3 class="text-lg font-semibold text-white">Hooks</h3>
        <Show when={!isCreating() && !editingHook()}>
          <button
            onClick={startCreate}
            class="px-3 py-1.5 bg-brand-600 hover:bg-brand-700 text-white text-sm rounded-lg transition-colors"
          >
            Add Hook
          </button>
        </Show>
      </div>

      <ErrorBanner message={error()} />

      {/* Create/Edit Form */}
      <Show when={isCreating() || editingHook()}>
        <div class="p-4 bg-gray-800 border border-gray-700 rounded-lg space-y-4">
          <h4 class="text-sm font-medium text-gray-300">
            {isCreating() ? "Create Hook" : "Edit Hook"}
          </h4>

          {/* Hook Kind Selector */}
          <Show when={isCreating()}>
            <div class="flex gap-2 p-1 bg-gray-900 rounded-lg">
              <button
                type="button"
                onClick={() => setHookKind("script")}
                class={`flex-1 px-4 py-2 rounded-md text-sm font-medium transition-colors flex items-center justify-center gap-2 ${
                  hookKind() === "script"
                    ? "bg-gray-700 text-white"
                    : "text-gray-400 hover:text-white"
                }`}
              >
                <TerminalIcon class="w-4 h-4 text-gray-400" />
                Script Hook
              </button>
              <button
                type="button"
                onClick={() => setHookKind("agent")}
                class={`flex-1 px-4 py-2 rounded-md text-sm font-medium transition-colors flex items-center justify-center gap-2 ${
                  hookKind() === "agent"
                    ? "bg-purple-600 text-white"
                    : "text-gray-400 hover:text-white"
                }`}
              >
                <SparklesIcon class="w-4 h-4 text-purple-400" />
                Agent Hook
              </button>
            </div>
          </Show>

          {/* Name */}
          <div>
            <label class="block text-sm text-gray-400 mb-1">Name</label>
            <input
              type="text"
              value={name()}
              onInput={(e) => setName(e.currentTarget.value)}
              placeholder={
                hookKind() === "script"
                  ? "e.g., Run Tests"
                  : "e.g., Create PR on Review"
              }
              class="w-full px-3 py-2 bg-gray-900 border border-gray-700 rounded-lg text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
          </div>

          {/* Script-specific fields */}
          <Show when={hookKind() === "script"}>
            <div>
              <label class="block text-sm text-gray-400 mb-1">Command</label>
              <textarea
                value={command()}
                onInput={(e) => setCommand(e.currentTarget.value)}
                placeholder={`#!/bin/bash\n# Your script here\nnpm run test`}
                rows={4}
                class="w-full px-3 py-2 bg-gray-900 border border-gray-700 rounded-lg text-white text-sm font-mono focus:outline-none focus:ring-2 focus:ring-brand-500 resize-none"
              />
              <p class="text-xs text-gray-500 mt-1">
                Supports shebangs (#!/bin/bash, #!/usr/bin/env python, etc.)
              </p>
            </div>
          </Show>

          {/* Agent-specific fields */}
          <Show when={hookKind() === "agent"}>
            <div>
              <label class="block text-sm text-gray-400 mb-1">
                Agent Prompt
              </label>
              <textarea
                value={agentPrompt()}
                onInput={(e) => setAgentPrompt(e.currentTarget.value)}
                placeholder="If this task makes any code changes, create a PR and fill in the title and description using the repository PR template."
                rows={5}
                class="w-full px-3 py-2 bg-gray-900 border border-gray-700 rounded-lg text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 resize-none"
              />
              <p class="text-xs text-gray-500 mt-1">
                The agent will receive full task context (title, description,
                worktree, etc.)
              </p>
            </div>

            <div>
              <label class="block text-sm text-gray-400 mb-1">
                Agent Executor
              </label>
              <select
                value={agentExecutor()}
                onChange={(e) =>
                  setAgentExecutor(e.currentTarget.value as AgentExecutor)
                }
                class="w-full px-3 py-2 bg-gray-900 border border-gray-700 rounded-lg text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
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
                checked={agentAutoApprove()}
                onChange={(e) => setAgentAutoApprove(e.currentTarget.checked)}
                class="w-4 h-4 rounded bg-gray-900 border-gray-700"
              />
              <label for="autoApprove" class="text-sm text-gray-300">
                Auto-approve tool calls (use with caution)
              </label>
            </div>
          </Show>

          <div class="flex gap-2 pt-2">
            <button
              onClick={cancelEdit}
              class="flex-1 py-2 px-4 bg-gray-700 hover:bg-gray-600 text-gray-300 rounded-lg text-sm transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleSave}
              disabled={isSaving()}
              class="flex-1 py-2 px-4 bg-brand-600 hover:bg-brand-700 disabled:bg-brand-800 disabled:cursor-not-allowed text-white rounded-lg text-sm transition-colors"
            >
              {isSaving() ? "Saving..." : "Save Hook"}
            </button>
          </div>
        </div>
      </Show>

      {/* Hook List */}
      <Show when={allHooks.loading}>
        <div class="text-gray-400 text-sm">Loading hooks...</div>
      </Show>

      {/* System Hooks Section */}
      <Show when={systemHooks().length > 0}>
        <div class="space-y-2">
          <h4 class="text-xs font-medium text-gray-500 uppercase tracking-wider">
            System Hooks
          </h4>
          <For each={systemHooks()}>
            {(hook) => (
              <div class="p-3 bg-gray-800 border border-purple-500/30 rounded-lg">
                <div class="flex justify-between items-start">
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2">
                      <SystemIcon class="w-4 h-4 text-purple-400" />
                      <span class="font-medium text-white">{hook.name}</span>
                      <span class="px-1.5 py-0.5 text-xs bg-purple-600/20 text-purple-400 rounded">
                        System
                      </span>
                    </div>
                    <Show when={hook.description}>
                      <div class="text-xs text-gray-400 mt-1.5">
                        {hook.description}
                      </div>
                    </Show>
                  </div>
                </div>
              </div>
            )}
          </For>
        </div>
      </Show>

      {/* Custom Hooks Section */}
      <div class="space-y-2">
        <Show when={systemHooks().length > 0}>
          <h4 class="text-xs font-medium text-gray-500 uppercase tracking-wider mt-4">
            Custom Hooks
          </h4>
        </Show>

        <Show
          when={
            !allHooks.loading && customHooks().length === 0 && !isCreating()
          }
        >
          <div class="text-gray-500 text-sm text-center py-4">
            No custom hooks configured. Click "Add Hook" to create one.
          </div>
        </Show>

        <For each={customHooks()}>
          {(hook) => (
            <div
              class={`p-3 bg-gray-800 border rounded-lg ${
                editingHook()?.id === hook.id
                  ? "border-brand-500"
                  : hook.hook_kind === "agent"
                    ? "border-purple-500/30"
                    : "border-gray-700"
              }`}
            >
              <div class="flex justify-between items-start">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2">
                    <Show
                      when={hook.hook_kind === "agent"}
                      fallback={<TerminalIcon class="w-4 h-4 text-gray-400" />}
                    >
                      <SparklesIcon class="w-4 h-4 text-purple-400" />
                    </Show>
                    <span class="font-medium text-white">{hook.name}</span>
                    <span
                      class={`px-1.5 py-0.5 text-xs rounded ${
                        hook.hook_kind === "agent"
                          ? "bg-purple-600/20 text-purple-400"
                          : "bg-gray-700 text-gray-400"
                      }`}
                    >
                      {hook.hook_kind === "agent" ? "Agent" : "Script"}
                    </span>
                  </div>
                  <div class="text-xs text-gray-400 font-mono truncate mt-1 max-w-md">
                    {hook.hook_kind === "agent"
                      ? (hook.agent_prompt?.slice(
                          0,
                          AGENT_PROMPT_PREVIEW_LENGTH,
                        ) ?? "") +
                        ((hook.agent_prompt?.length ?? 0) >
                        AGENT_PROMPT_PREVIEW_LENGTH
                          ? "..."
                          : "")
                      : hook.command}
                  </div>
                  <Show when={hook.hook_kind === "agent"}>
                    <div class="flex gap-2 mt-2 text-xs text-gray-500">
                      <span class="px-2 py-0.5 bg-gray-700 rounded">
                        {getExecutorLabel(hook.agent_executor)}
                      </span>
                      <Show when={hook.agent_auto_approve}>
                        <span class="px-2 py-0.5 bg-yellow-500/20 text-yellow-400 rounded">
                          Auto-approve
                        </span>
                      </Show>
                    </div>
                  </Show>
                </div>
                <div class="flex gap-1 ml-2">
                  <button
                    onClick={() => startEdit(hook)}
                    class="p-1.5 text-gray-400 hover:text-white hover:bg-gray-700 rounded transition-colors"
                    title="Edit"
                  >
                    <EditIcon class="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => handleDelete(hook.id)}
                    class="p-1.5 text-gray-400 hover:text-red-400 hover:bg-red-500/10 rounded transition-colors"
                    title="Delete"
                  >
                    <TrashIcon class="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>
          )}
        </For>
      </div>
    </div>
  );
}
