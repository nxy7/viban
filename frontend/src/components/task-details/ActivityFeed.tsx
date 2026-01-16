import { createSignal, For, Show } from "solid-js";
import type { OutputLine } from "~/hooks/useTaskChat";
import { CHAT_PROSE_CLASSES, renderMarkdown } from "~/lib/markdown";

// ============================================================================
// Types
// ============================================================================

export type HookExecutionStatus =
  | "pending"
  | "running"
  | "completed"
  | "failed"
  | "cancelled"
  | "skipped";

export type SkipReason =
  | "error"
  | "disabled"
  | "column_change"
  | "server_restart"
  | "user_cancelled"
  | null;

export interface HookExecutionActivity {
  type: "hook_execution";
  id: string;
  name: string;
  status: HookExecutionStatus;
  skip_reason?: SkipReason;
  error_message?: string | null;
  queued_at: string | null;
  started_at?: string | null;
  completed_at?: string | null;
  inserted_at: string;
}

// ============================================================================
// Helper Functions
// ============================================================================

function formatDuration(
  startedAt: string | null | undefined,
  completedAt: string | null | undefined,
): string | null {
  if (!startedAt || !completedAt) return null;
  const start = new Date(startedAt).getTime();
  const end = new Date(completedAt).getTime();
  const durationMs = end - start;

  if (durationMs < 1000) {
    return `${durationMs}ms`;
  } else if (durationMs < 60000) {
    const seconds = (durationMs / 1000).toFixed(1);
    return `${seconds}s`;
  } else {
    const minutes = Math.floor(durationMs / 60000);
    const seconds = Math.floor((durationMs % 60000) / 1000);
    return `${minutes}m ${seconds}s`;
  }
}

const TASK_CREATED_PROSE_CLASSES =
  "prose prose-sm prose-invert max-w-none prose-p:my-1 prose-ul:my-1 prose-li:my-0 prose-headings:my-2 prose-headings:text-gray-200";

// ============================================================================
// TaskCreatedActivity Component
// ============================================================================

interface TaskCreatedActivityProps {
  timestamp: string;
  description: string | null;
  formatDate: (dateStr: string) => string;
}

export function TaskCreatedActivity(props: TaskCreatedActivityProps) {
  return (
    <div class="flex items-start gap-3 group">
      <div class="flex-shrink-0 w-8 h-8 rounded-full bg-brand-500/20 border border-brand-500/30 flex items-center justify-center">
        <svg
          class="w-4 h-4 text-brand-400"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 6v6m0 0v6m0-6h6m-6 0H6"
          />
        </svg>
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-baseline gap-2">
          <span class="text-sm font-medium text-gray-300">Task Created</span>
          <span class="text-xs text-gray-500">
            {props.formatDate(props.timestamp)}
          </span>
        </div>
        <Show when={props.description}>
          <div
            class={`mt-2 text-sm text-gray-300 ${TASK_CREATED_PROSE_CLASSES}`}
            innerHTML={renderMarkdown(props.description || "")}
          />
        </Show>
      </div>
    </div>
  );
}

// ============================================================================
// HookExecutionActivity Component
// ============================================================================

interface HookExecutionActivityProps {
  name: string;
  status: HookExecutionStatus;
  skip_reason?: SkipReason;
  error_message?: string | null;
  queued_at: string | null;
  started_at?: string | null;
  completed_at?: string | null;
  formatDate: (dateStr: string) => string;
}

export function HookExecutionActivityComponent(
  props: HookExecutionActivityProps,
) {
  const getSkipLabel = () => {
    switch (props.skip_reason) {
      case "disabled":
        return "Hook skipped (disabled)";
      case "error":
        return "Hook skipped (error)";
      case "column_change":
        return "Hook skipped (column change)";
      case "server_restart":
        return "Hook skipped (server restart)";
      case "user_cancelled":
        return "Hook cancelled (by user)";
      default:
        return "Hook skipped";
    }
  };

  const duration = () => formatDuration(props.started_at, props.completed_at);

  const statusConfig = () => {
    const dur = duration();
    switch (props.status) {
      case "pending":
        return {
          label: "Pending",
          textClass: "text-gray-400",
        };
      case "running":
        return {
          label: "Running...",
          textClass: "text-blue-400",
        };
      case "completed":
        return {
          label: dur ? `Completed in ${dur}` : "Completed",
          textClass: "text-green-400",
        };
      case "failed":
        return {
          label: dur ? `Failed after ${dur}` : "Failed",
          textClass: "text-red-400",
        };
      case "cancelled":
        return {
          label: getSkipLabel(),
          textClass: "text-yellow-400",
        };
      case "skipped":
        return {
          label: getSkipLabel(),
          textClass: "text-gray-400",
        };
    }
  };

  const config = statusConfig();

  return (
    <div
      class="flex items-center gap-2 text-xs py-0.5"
      title={props.error_message || undefined}
    >
      <span class={`font-medium ${config.textClass}`}>{props.name}</span>
      <span class="text-gray-500">{config.label}</span>
      <Show when={props.queued_at}>
        <span class="text-gray-600 ml-auto">
          {props.formatDate(props.queued_at!)}
        </span>
      </Show>
      <Show when={props.error_message}>
        <span
          class="text-red-400 truncate max-w-[150px]"
          title={props.error_message ?? undefined}
        >
          {props.error_message}
        </span>
      </Show>
    </div>
  );
}

// ============================================================================
// GroupedHooksActivity Component
// ============================================================================

interface GroupedHooksActivityProps {
  hooks: HookExecutionActivity[];
  formatDate: (dateStr: string) => string;
}

export function GroupedHooksActivity(props: GroupedHooksActivityProps) {
  const [isExpanded, setIsExpanded] = createSignal(false);

  const statusCounts = () => {
    const counts = {
      pending: 0,
      running: 0,
      completed: 0,
      failed: 0,
      cancelled: 0,
      skipped: 0,
    };
    for (const hook of props.hooks) {
      counts[hook.status]++;
    }
    return counts;
  };

  const summaryText = () => {
    const counts = statusCounts();
    const parts: string[] = [];
    if (counts.running > 0) parts.push(`${counts.running} running`);
    if (counts.pending > 0) parts.push(`${counts.pending} pending`);
    if (counts.completed > 0) parts.push(`${counts.completed} successful`);
    if (counts.failed > 0) parts.push(`${counts.failed} failed`);
    if (counts.cancelled > 0) parts.push(`${counts.cancelled} cancelled`);
    if (counts.skipped > 0) parts.push(`${counts.skipped} skipped`);
    return parts.join(", ");
  };

  const overallStatus = () => {
    const counts = statusCounts();
    if (counts.running > 0) return "running";
    if (counts.pending > 0) return "pending";
    if (counts.failed > 0) return "failed";
    if (counts.cancelled > 0) return "cancelled";
    if (counts.skipped > 0) return "skipped";
    return "completed";
  };

  const statusColors = () => {
    const status = overallStatus();
    switch (status) {
      case "running":
        return { textClass: "text-blue-400" };
      case "pending":
        return { textClass: "text-gray-400" };
      case "completed":
        return { textClass: "text-green-400" };
      case "failed":
        return { textClass: "text-red-400" };
      case "cancelled":
        return { textClass: "text-yellow-400" };
      case "skipped":
        return { textClass: "text-gray-400" };
      default:
        return { textClass: "text-gray-400" };
    }
  };

  const colors = statusColors();

  return (
    <div class="py-1 px-2">
      <button
        onClick={() => setIsExpanded(!isExpanded())}
        class={`flex items-center gap-2 text-sm font-medium ${colors.textClass} hover:underline cursor-pointer`}
      >
        <span>
          {props.hooks.length} {props.hooks.length === 1 ? "hook" : "hooks"}
        </span>
        <span class="text-gray-500 font-normal">({summaryText()})</span>
        <svg
          class={`w-4 h-4 transition-transform ${isExpanded() ? "rotate-180" : ""}`}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M19 9l-7 7-7-7"
          />
        </svg>
      </button>

      <Show when={isExpanded()}>
        <div class="mt-2 space-y-1 pl-4 border-l-2 border-gray-700">
          <For each={props.hooks}>
            {(hook) => (
              <HookExecutionActivityComponent
                name={hook.name}
                status={hook.status}
                skip_reason={hook.skip_reason}
                error_message={hook.error_message}
                queued_at={hook.queued_at}
                started_at={hook.started_at}
                completed_at={hook.completed_at}
                formatDate={props.formatDate}
              />
            )}
          </For>
        </div>
      </Show>
    </div>
  );
}

// ============================================================================
// OutputBubble Component
// ============================================================================

interface OutputBubbleProps {
  line: OutputLine;
  formatTime: (dateStr?: string) => string;
  hideDetails?: boolean;
}

export function OutputBubble(props: OutputBubbleProps) {
  const isSystem = () =>
    props.line.type === "system" || props.line.role === "system";
  const isUser = () => props.line.type === "user" || props.line.role === "user";
  const isTool = () => props.line.role === "tool";
  const isAssistant = () =>
    props.line.type === "parsed" || props.line.role === "assistant";

  const getTextContent = (): string => {
    if (typeof props.line.content === "string") {
      return props.line.content;
    }
    return JSON.stringify(props.line.content, null, 2);
  };

  const getToolInfo = (): {
    tool: string;
    input?: Record<string, unknown>;
  } | null => {
    const content = props.line.content;
    if (typeof content === "object" && content !== null) {
      const parsed = content as Record<string, unknown>;
      if (parsed.type === "tool_use" && typeof parsed.tool === "string") {
        return {
          tool: parsed.tool,
          input: parsed.input as Record<string, unknown> | undefined,
        };
      }
    }
    return null;
  };

  const formatToolInput = (
    input: Record<string, unknown> | undefined,
  ): string => {
    if (!input) return "";

    if (typeof input.file_path === "string") {
      return input.file_path;
    }
    if (typeof input.pattern === "string") {
      return input.pattern;
    }
    if (typeof input.command === "string") {
      const cmd = input.command as string;
      return cmd.length > 60 ? `${cmd.slice(0, 60)}...` : cmd;
    }
    if (typeof input.url === "string") {
      return input.url;
    }
    if (typeof input.query === "string") {
      return input.query;
    }

    for (const value of Object.values(input)) {
      if (typeof value === "string" && value.length > 0) {
        return value.length > 50 ? `${value.slice(0, 50)}...` : value;
      }
    }
    return "";
  };

  if (isUser()) {
    return (
      <div class="flex justify-end">
        <div class="max-w-[85%] rounded-lg px-4 py-2 bg-brand-600 text-white">
          <div class="whitespace-pre-wrap break-words">{getTextContent()}</div>
          <Show when={!props.hideDetails}>
            <div class="mt-1 text-xs text-brand-200">
              {props.formatTime(props.line.timestamp)}
            </div>
          </Show>
        </div>
      </div>
    );
  }

  if (isTool()) {
    const toolInfo = getToolInfo();
    if (toolInfo) {
      const detail = formatToolInput(toolInfo.input);
      return (
        <div class="flex items-center gap-2 py-1 px-2 text-xs">
          <div class="flex items-center gap-1.5 text-cyan-400">
            <svg
              class="w-3.5 h-3.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M11.42 15.17L17.25 21A2.652 2.652 0 0021 17.25l-5.877-5.877M11.42 15.17l2.496-3.03c.317-.384.74-.626 1.208-.766M11.42 15.17l-4.655 5.653a2.548 2.548 0 11-3.586-3.586l6.837-5.63m5.108-.233c.55-.164 1.163-.188 1.743-.14a4.5 4.5 0 004.486-6.336l-3.276 3.277a3.004 3.004 0 01-2.25-2.25l3.276-3.276a4.5 4.5 0 00-6.336 4.486c.091 1.076-.071 2.264-.904 2.95l-.102.085m-1.745 1.437L5.909 7.5H4.5L2.25 3.75l1.5-1.5L7.5 4.5v1.409l4.26 4.26m-1.745 1.437l1.745-1.437m6.615 8.206L15.75 15.75M4.867 19.125h.008v.008h-.008v-.008z"
              />
            </svg>
            <span class="font-medium">{toolInfo.tool}</span>
          </div>
          <Show when={detail}>
            <span class="text-gray-500 truncate max-w-[300px]" title={detail}>
              {detail}
            </span>
          </Show>
          <Show when={!props.hideDetails}>
            <span class="text-gray-600 ml-auto">
              {props.formatTime(props.line.timestamp)}
            </span>
          </Show>
        </div>
      );
    }
  }

  if (isSystem()) {
    const content = getTextContent();
    const isError =
      content.toLowerCase().includes("error") ||
      content.toLowerCase().includes("failed");
    const isSuccess =
      content.toLowerCase().includes("completed") ||
      content.toLowerCase().includes("success");
    const colorClass = isError
      ? "text-red-400"
      : isSuccess
        ? "text-green-400"
        : "text-amber-400";

    return (
      <div class="flex items-center gap-2 py-1.5 px-3 text-xs bg-gray-900/50 rounded-lg border border-gray-800">
        <svg
          class={`w-4 h-4 flex-shrink-0 ${colorClass}`}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          stroke-width="2"
        >
          <Show
            when={isError}
            fallback={
              <Show
                when={isSuccess}
                fallback={
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                }
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </Show>
            }
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
            />
          </Show>
        </svg>
        <span class={colorClass}>{content}</span>
        <Show when={!props.hideDetails}>
          <span class="text-gray-600 ml-auto">
            {props.formatTime(props.line.timestamp)}
          </span>
        </Show>
      </div>
    );
  }

  if (isAssistant()) {
    return (
      <div class="flex justify-start">
        <div class="max-w-[85%] rounded-lg px-4 py-2 bg-gray-800 text-gray-100">
          <div
            class={CHAT_PROSE_CLASSES}
            innerHTML={renderMarkdown(getTextContent())}
          />
          <Show when={!props.hideDetails}>
            <div class="mt-1 text-xs text-gray-500">
              {props.formatTime(props.line.timestamp)}
            </div>
          </Show>
        </div>
      </div>
    );
  }

  return (
    <div class="flex justify-start">
      <div class="max-w-[95%] rounded-lg px-4 py-2 bg-gray-900 border border-gray-700 text-gray-300 font-mono text-sm">
        <pre class="whitespace-pre-wrap break-words overflow-x-auto">
          {getTextContent()}
        </pre>
        <Show when={!props.hideDetails}>
          <div class="mt-1 text-xs text-gray-600">
            {props.formatTime(props.line.timestamp)}
          </div>
        </Show>
      </div>
    </div>
  );
}
