import { createMemo, Show } from "solid-js";

/** Agent status type - matches backend agent_status field */
export type AgentStatusType =
  | "idle"
  | "thinking"
  | "executing"
  | "waiting_for_user"
  | "error";

/** Configuration for rendering a status indicator */
interface StatusConfig {
  label: string;
  color: string;
  bgColor: string;
  animate?: boolean;
}

interface AgentStatusProps {
  status: AgentStatusType;
  message?: string | null;
  compact?: boolean;
}

/** Default status used when an unknown status is provided */
const DEFAULT_STATUS: AgentStatusType = "idle";

/** Status display configurations */
const STATUS_CONFIG: Record<AgentStatusType, StatusConfig> = {
  idle: {
    label: "Idle",
    color: "text-gray-400",
    bgColor: "bg-gray-500",
  },
  thinking: {
    label: "Thinking",
    color: "text-blue-400",
    bgColor: "bg-blue-500",
    animate: true,
  },
  executing: {
    label: "Executing",
    color: "text-green-400",
    bgColor: "bg-green-500",
    animate: true,
  },
  waiting_for_user: {
    label: "Waiting",
    color: "text-yellow-400",
    bgColor: "bg-yellow-500",
  },
  error: {
    label: "Error",
    color: "text-red-400",
    bgColor: "bg-red-500",
  },
};

/** Background colors with opacity for badge styling */
const STATUS_BG_COLORS: Record<AgentStatusType, string> = {
  idle: "rgba(107, 114, 128, 0.2)",
  thinking: "rgba(59, 130, 246, 0.2)",
  executing: "rgba(34, 197, 94, 0.2)",
  waiting_for_user: "rgba(234, 179, 8, 0.2)",
  error: "rgba(239, 68, 68, 0.2)",
};

/**
 * Agent status indicator component.
 * Shows the current state of the AI agent with appropriate styling.
 */
export default function AgentStatus(props: AgentStatusProps) {
  const config = createMemo(
    () => STATUS_CONFIG[props.status] ?? STATUS_CONFIG[DEFAULT_STATUS],
  );

  // Use Show instead of early return for proper SolidJS reactivity
  return (
    <Show
      when={!props.compact}
      fallback={
        <div class={`flex items-center gap-1.5 ${config().color}`}>
          <span
            class={`w-2 h-2 rounded-full ${config().bgColor} ${
              config().animate ? "animate-pulse" : ""
            }`}
          />
          <span class="text-xs font-medium">{config().label}</span>
        </div>
      }
    >
      <div class="flex items-center gap-2">
        <span
          class={`w-2.5 h-2.5 rounded-full ${config().bgColor} ${
            config().animate ? "animate-pulse" : ""
          }`}
        />
        <span class={`text-sm font-medium ${config().color}`}>
          {config().label}
        </span>
        <Show when={props.message}>
          <span class="text-sm text-gray-500">- {props.message}</span>
        </Show>
      </div>
    </Show>
  );
}

interface AgentStatusBadgeProps {
  status: AgentStatusType;
}

/**
 * Compact inline status badge for use in tight spaces like task cards.
 * Only displays when status is not idle.
 */
export function AgentStatusBadge(props: AgentStatusBadgeProps) {
  const config = createMemo(
    () => STATUS_CONFIG[props.status] ?? STATUS_CONFIG[DEFAULT_STATUS],
  );
  const bgColor = createMemo(
    () => STATUS_BG_COLORS[props.status] ?? STATUS_BG_COLORS[DEFAULT_STATUS],
  );

  // Only show non-idle status - use Show for proper reactivity
  return (
    <Show when={props.status !== "idle"}>
      <span
        class={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium ${config().color}`}
        style={{ "background-color": bgColor() }}
      >
        <span
          class={`w-1.5 h-1.5 rounded-full ${config().bgColor} ${
            config().animate ? "animate-pulse" : ""
          }`}
        />
        {config().label}
      </span>
    </Show>
  );
}
