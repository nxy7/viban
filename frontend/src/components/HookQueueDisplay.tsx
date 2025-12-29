import { For, Show } from "solid-js";
import { CheckIcon } from "./ui/Icons";

export type HookStatus =
  | "pending"
  | "running"
  | "completed"
  | "cancelled"
  | "failed"
  | "skipped";

export interface HookQueueItem {
  id: string;
  name: string;
  status: HookStatus;
  /** Reason why hook was skipped (only present when status is "skipped") */
  skip_reason?: "error" | "disabled";
}

interface HookQueueDisplayProps {
  hooks: HookQueueItem[];
}

/** Returns the appropriate icon and color for a hook status */
function getStatusDisplay(status: HookStatus) {
  switch (status) {
    case "completed":
      return {
        icon: <CheckIcon class="w-3.5 h-3.5 text-green-500" />,
        textClass: "text-green-400",
        label: "Completed",
      };
    case "running":
      return {
        icon: (
          <div class="w-3.5 h-3.5 border-2 border-blue-400 border-t-transparent rounded-full animate-spin" />
        ),
        textClass: "text-blue-400",
        label: "Running",
      };
    case "pending":
      return {
        icon: <div class="w-3.5 h-3.5 border border-gray-500 rounded-full" />,
        textClass: "text-gray-400",
        label: "Pending",
      };
    case "cancelled":
      return {
        icon: (
          <svg
            class="w-3.5 h-3.5 text-yellow-500"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M18 12H6"
            />
          </svg>
        ),
        textClass: "text-yellow-500",
        label: "Cancelled",
      };
    case "failed":
      return {
        icon: (
          <svg
            class="w-3.5 h-3.5 text-red-500"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M6 18L18 6M6 6l12 12"
            />
          </svg>
        ),
        textClass: "text-red-400",
        label: "Failed",
      };
    case "skipped":
      return {
        icon: (
          <svg
            class="w-3.5 h-3.5 text-gray-500"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M13 5l7 7-7 7M5 5l7 7-7 7"
            />
          </svg>
        ),
        textClass: "text-gray-500",
        label: "Skipped",
      };
  }
}

export default function HookQueueDisplay(props: HookQueueDisplayProps) {
  const hasHooks = () => props.hooks.length > 0;

  return (
    <Show when={hasHooks()}>
      <div class="mt-3 bg-gray-800/30 border border-gray-700/50 rounded-lg p-2">
        <div class="flex items-center justify-between mb-2">
          <span class="text-xs font-medium text-gray-500 uppercase tracking-wide">
            Hook Execution
          </span>
        </div>
        <div class="space-y-1">
          <For each={props.hooks}>
            {(hook) => {
              const display = getStatusDisplay(hook.status);
              return (
                <div class="flex items-center gap-2 text-xs">
                  <div class="flex-shrink-0">{display.icon}</div>
                  <span class={`flex-1 truncate ${display.textClass}`}>
                    {hook.name}
                  </span>
                  <Show when={hook.status === "cancelled"}>
                    <span class="text-yellow-600 text-[10px]">cancelled</span>
                  </Show>
                  <Show when={hook.status === "skipped"}>
                    <span class="text-gray-500 text-[10px]">
                      {hook.skip_reason === "disabled"
                        ? "skipped (disabled)"
                        : "skipped (error)"}
                    </span>
                  </Show>
                </div>
              );
            }}
          </For>
        </div>
      </div>
    </Show>
  );
}
