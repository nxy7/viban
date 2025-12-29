import { type Accessor, createMemo, For, Show } from "solid-js";
import type { LLMTodoItem } from "~/lib/socket";
import { CheckIcon } from "./ui/Icons";
import ProgressBar from "./ui/ProgressBar";

interface LLMTodoListProps {
  todos: LLMTodoItem[];
  isRunning: boolean;
}

/** Shared computed values for todo progress - eliminates DRY violation */
interface TodoProgress {
  completedCount: Accessor<number>;
  totalCount: Accessor<number>;
  currentTask: Accessor<LLMTodoItem | undefined>;
  progressPercentage: Accessor<number>;
}

function useTodoProgress(todos: () => LLMTodoItem[]): TodoProgress {
  const completedCount = createMemo(
    () => todos().filter((t) => t.status === "completed").length,
  );
  const totalCount = createMemo(() => todos().length);
  const currentTask = createMemo(() =>
    todos().find((t) => t.status === "in_progress"),
  );
  const progressPercentage = createMemo(() => {
    if (totalCount() === 0) return 0;
    return (completedCount() / totalCount()) * 100;
  });

  return { completedCount, totalCount, currentTask, progressPercentage };
}

export default function LLMTodoList(props: LLMTodoListProps) {
  const { completedCount, totalCount, currentTask, progressPercentage } =
    useTodoProgress(() => props.todos);

  return (
    <Show when={props.todos.length > 0}>
      <div class="bg-gray-800/50 border border-gray-700 rounded-lg p-3 space-y-3">
        {/* Header with progress */}
        <div class="flex items-center justify-between">
          <span class="text-xs font-medium text-gray-400 uppercase tracking-wide">
            Agent Progress
          </span>
          <span class="text-xs text-gray-500">
            {completedCount()}/{totalCount()}
          </span>
        </div>

        {/* Progress bar */}
        <ProgressBar percentage={progressPercentage()} gradient />

        {/* Current task indicator */}
        <Show when={props.isRunning ? currentTask() : undefined}>
          {(task) => (
            <div class="flex items-center gap-2 text-sm text-blue-400">
              <div class="w-2 h-2 bg-blue-400 rounded-full animate-pulse" />
              <span class="truncate">{task().activeForm}</span>
            </div>
          )}
        </Show>

        {/* Todo list */}
        <div class="space-y-1 max-h-48 overflow-y-auto">
          <For each={props.todos}>
            {(todo) => (
              <div
                class={`flex items-start gap-2 text-sm py-1 ${
                  todo.status === "completed"
                    ? "text-gray-500"
                    : todo.status === "in_progress"
                      ? "text-blue-300"
                      : "text-gray-300"
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
                    <div class="w-4 h-4 border border-gray-600 rounded" />
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

/** Compact version for the task card */
interface LLMTodoProgressProps {
  todos: LLMTodoItem[];
  isRunning: boolean;
}

export function LLMTodoProgress(props: LLMTodoProgressProps) {
  const { completedCount, totalCount, currentTask, progressPercentage } =
    useTodoProgress(() => props.todos);

  return (
    <Show when={props.isRunning && props.todos.length > 0}>
      <div class="mt-2 space-y-1">
        {/* Mini progress bar */}
        <div class="flex items-center gap-2">
          <div class="flex-1">
            <ProgressBar percentage={progressPercentage()} size="sm" />
          </div>
          <span class="text-xs text-gray-500 flex-shrink-0">
            {completedCount()}/{totalCount()}
          </span>
        </div>
        {/* Current task hint */}
        <Show when={currentTask()}>
          {(task) => (
            <p class="text-xs text-gray-500 truncate">{task().activeForm}</p>
          )}
        </Show>
      </div>
    </Show>
  );
}
