import { createResource, createSignal, For, Show } from "solid-js";
import * as sdk from "~/lib/generated/ash";
import { type Subtask, type Task, unwrap } from "~/lib/useKanban";
import { Button } from "~/components/design-system";
import ErrorBanner from "./ui/ErrorBanner";
import {
  ChevronRightIcon,
  ClipboardListIcon,
  LoadingSpinner,
  SparklesIcon,
} from "./ui/Icons";
import ProgressBar from "./ui/ProgressBar";

/**
 * Polling intervals for refetching subtasks after generation starts.
 * Uses increasing intervals to balance responsiveness with performance.
 */
const SUBTASK_POLL_INTERVALS_MS = [2000, 5000, 10000] as const;

/** Percentage multiplier for progress calculation */
const PERCENTAGE_MULTIPLIER = 100;

interface SubtaskListProps {
  task: Task;
  onSubtaskClick?: (subtaskId: string) => void;
}

type SubtaskAgentStatus = Subtask["agent_status"];

/** Get status indicator color based on agent status */
function getStatusColor(agentStatus: SubtaskAgentStatus): string {
  switch (agentStatus) {
    case "thinking":
    case "executing":
      return "bg-blue-500";
    case "error":
      return "bg-red-500";
    default:
      return "bg-gray-600";
  }
}

type SubtaskPriority = Subtask["priority"];

/** Get priority badge styles */
function getPriorityStyles(priority: SubtaskPriority): string {
  switch (priority) {
    case "high":
      return "bg-red-500/20 text-red-400";
    case "low":
      return "bg-gray-500/20 text-gray-400";
    default:
      return "bg-blue-500/20 text-blue-400";
  }
}

export default function SubtaskList(props: SubtaskListProps) {
  const [isGenerating, setIsGenerating] = createSignal(false);
  const [error, setError] = createSignal<string | null>(null);

  // Fetch subtasks
  const [subtasks, { refetch }] = createResource(
    () => props.task.id,
    async (taskId: string): Promise<Subtask[]> => {
      const result = await sdk
        .list_subtasks({
          input: { parent_task_id: taskId },
          fields: [
            "id",
            "title",
            "description",
            "agent_status",
            "priority",
            "position",
          ],
        })
        .then(unwrap);
      return result as unknown as Subtask[];
    },
  );

  // Check if generation is in progress (from task status or local state)
  const isGenLoading = () =>
    isGenerating() || props.task.subtask_generation_status === "generating";

  /**
   * Calculate progress percentage based on idle subtasks.
   * Assumes idle status means the subtask is complete.
   */
  const progress = () => {
    const subs = subtasks();
    if (!subs || subs.length === 0) return 0;
    const completedCount = subs.filter((s) => s.agent_status === "idle").length;
    return Math.round((completedCount / subs.length) * PERCENTAGE_MULTIPLIER);
  };

  const handleGenerate = async () => {
    if (isGenLoading()) return;

    setIsGenerating(true);
    setError(null);

    await sdk
      .generate_subtasks({ input: { task_id: props.task.id } })
      .then(unwrap);

    setIsGenerating(false);
    // Poll for completion - the task status will update via Electric sync
    // but we can refetch subtasks after a delay using increasing intervals
    for (const delay of SUBTASK_POLL_INTERVALS_MS) {
      setTimeout(() => refetch(), delay);
    }
  };

  return (
    <div class="space-y-3">
      {/* Header */}
      <div class="flex items-center justify-between">
        <h4 class="text-sm font-medium text-gray-400 flex items-center gap-2">
          <ClipboardListIcon class="w-4 h-4" />
          Subtasks
          <Show when={subtasks()?.length}>
            <span class="text-xs text-gray-500">({subtasks()?.length})</span>
          </Show>
        </h4>

        <Show when={subtasks()?.length}>
          <div class="flex items-center gap-2 text-xs text-gray-500">
            <span>{progress()}%</span>
            <div class="w-16">
              <ProgressBar percentage={progress()} size="sm" gradient />
            </div>
          </div>
        </Show>
      </div>

      <ErrorBanner message={error()} size="sm" />

      {/* Loading state */}
      <Show when={subtasks.loading && !subtasks()}>
        <div class="text-gray-500 text-sm text-center py-4">
          Loading subtasks...
        </div>
      </Show>

      {/* Subtask list */}
      <Show when={subtasks()?.length}>
        <div class="space-y-2">
          <For each={subtasks()}>
            {(subtask) => (
              <Button
                type="button"
                onClick={() => props.onSubtaskClick?.(subtask.id)}
                variant="secondary"
                fullWidth
              >
                <div class="w-full flex items-center gap-3 text-left">
                  {/* Status indicator */}
                  <div
                    class={`w-2 h-2 rounded-full flex-shrink-0 ${getStatusColor(subtask.agent_status)}`}
                  />

                  {/* Content */}
                  <div class="flex-1 min-w-0">
                    <div class="font-medium text-white truncate text-sm">
                      {subtask.title}
                    </div>
                    <Show when={subtask.description}>
                      <div class="text-xs text-gray-500 truncate mt-0.5">
                        {subtask.description}
                      </div>
                    </Show>
                  </div>

                  {/* Priority badge */}
                  <span
                    class={`text-xs px-1.5 py-0.5 rounded ${getPriorityStyles(subtask.priority)}`}
                  >
                    {subtask.priority}
                  </span>

                  {/* Status indicator for active states */}
                  <Show
                    when={
                      subtask.agent_status === "thinking" ||
                      subtask.agent_status === "executing"
                    }
                  >
                    <LoadingSpinner class="w-3 h-3 text-blue-400" />
                  </Show>
                  {/* Chevron */}
                  <ChevronRightIcon class="w-4 h-4 text-gray-500" />
                </div>
              </Button>
            )}
          </For>
        </div>
      </Show>

      {/* Empty state with generate button */}
      <Show
        when={!subtasks.loading && (!subtasks() || subtasks()?.length === 0)}
      >
        <div class="text-center py-6 space-y-3">
          <p class="text-sm text-gray-500">No subtasks yet</p>
          <Button
            type="button"
            onClick={handleGenerate}
            disabled={isGenLoading()}
            loading={isGenLoading()}
          >
            <Show when={!isGenLoading()}>
              <SparklesIcon class="w-4 h-4" />
            </Show>
            {isGenLoading() ? "Generating..." : "Generate Subtasks with AI"}
          </Button>
          <p class="text-xs text-gray-600">
            AI will analyze the task and break it into smaller steps
          </p>
        </div>
      </Show>

      {/* Add subtask button when list has items */}
      <Show when={subtasks()?.length && !isGenLoading()}>
        <div class="flex gap-2">
          <Button
            type="button"
            onClick={handleGenerate}
            variant="secondary"
            buttonSize="sm"
            fullWidth
          >
            <SparklesIcon class="w-4 h-4" />
            Generate More
          </Button>
        </div>
      </Show>

      {/* Generation in progress indicator */}
      <Show when={isGenLoading()}>
        <div class="flex items-center gap-2 p-3 bg-purple-500/10 border border-purple-500/30 rounded-lg">
          <LoadingSpinner class="w-4 h-4 text-purple-400" />
          <span class="text-sm text-purple-400">
            AI is breaking down your task into subtasks...
          </span>
        </div>
      </Show>

      {/* Generation failed indicator */}
      <Show when={props.task.subtask_generation_status === "failed"}>
        <div class="flex items-center gap-2 p-3 bg-red-500/10 border border-red-500/30 rounded-lg">
          <span class="text-sm text-red-400">
            Failed to generate subtasks.
            <Show when={props.task.agent_status_message}>
              {" "}
              {props.task.agent_status_message}
            </Show>
          </span>
          <Button
            type="button"
            onClick={handleGenerate}
            variant="danger"
            buttonSize="sm"
          >
            Retry
          </Button>
        </div>
      </Show>
    </div>
  );
}
