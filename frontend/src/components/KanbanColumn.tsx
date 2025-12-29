import { createDroppable, SortableProvider } from "@thisbeyond/solid-dnd";
import { createMemo, For, Show } from "solid-js";
import { CheckIcon, PlusIcon, SettingsIcon } from "~/components/ui/Icons";
import type { Column, Task } from "~/lib/useKanban";
import type { DropTarget } from "./KanbanBoard";
import TaskCard from "./TaskCard";

/** Visual indicator for where a task will be dropped */
function DropGapIndicator() {
  return (
    <div class="h-1 bg-brand-500 rounded-full my-1 animate-pulse shadow-[0_0_8px_rgba(139,92,246,0.5)]" />
  );
}

interface KanbanColumnProps {
  column: Column;
  boardId: string;
  tasks: Task[];
  onAddTask: () => void;
  onTaskClick: (task: Task) => void;
  showAddButton?: boolean;
  /** Callback to open settings for this column, passing the settings button element as anchor */
  onOpenSettings?: (anchor: HTMLButtonElement | undefined) => void;
  /** Current drop target for visual feedback */
  dropTarget?: DropTarget | null;
  /** ID of the task currently being dragged */
  draggedTaskId?: string | null;
}

export default function KanbanColumn(props: KanbanColumnProps) {
  // Note: createDroppable needs a stable ID. Accessing props.column.id here is safe
  // because the column ID doesn't change during the component's lifetime.
  // If the column ID changes, the entire component would be re-created.
  const droppable = createDroppable(props.column.id);

  let settingsButtonRef: HTMLButtonElement | undefined;

  // Check if this column is the drop target
  const isDropTarget = createMemo(
    () => props.dropTarget?.columnId === props.column.id,
  );

  // Get the task ID before which to show the gap (null = end of column)
  const gapBeforeTaskId = createMemo(() =>
    isDropTarget() ? props.dropTarget?.beforeTaskId : undefined,
  );

  // Sort tasks and optionally filter out the dragged task if it's from this column
  const sortedTasks = createMemo(() => {
    const tasks = [...props.tasks].sort(
      (a, b) => Number(a.position) - Number(b.position),
    );
    // Don't filter out dragged task - let solid-dnd handle the opacity
    return tasks;
  });

  const taskIds = createMemo(() => sortedTasks().map((t) => t.id));

  // Count of tasks that are currently executing (in_progress)
  const inProgressCount = createMemo(
    () => props.tasks.filter((t) => t.in_progress).length,
  );

  return (
    <div
      class={`
        flex flex-col bg-gray-900/50 border border-gray-800 rounded-xl min-w-[280px] max-w-[320px]
        ${droppable.isActiveDroppable ? "ring-2 ring-brand-500/50" : ""}
      `}
    >
      {/* Column Header */}
      <div
        class="p-3 border-b border-gray-800 flex items-center justify-between"
        style={{ "border-left": `3px solid ${props.column.color}` }}
      >
        <div class="flex items-center gap-2">
          <h3 class="font-semibold text-white text-sm">{props.column.name}</h3>
          <span class="text-xs text-gray-500 bg-gray-800 px-2 py-0.5 rounded-full">
            {props.tasks.length}
          </span>

          {/* Show in-progress indicator for columns with running tasks */}
          <Show when={inProgressCount() > 0}>
            <span class="text-xs text-blue-400 bg-blue-500/20 px-1.5 py-0.5 rounded flex items-center gap-1">
              <CheckIcon class="w-3 h-3 animate-pulse" />
              {inProgressCount()} running
            </span>
          </Show>
        </div>

        {/* Settings button */}
        <button
          ref={settingsButtonRef}
          onClick={() => props.onOpenSettings?.(settingsButtonRef)}
          class="p-1.5 text-gray-500 hover:text-gray-300 hover:bg-gray-800 rounded-md transition-colors"
          title="Column settings"
        >
          <SettingsIcon class="w-4 h-4" />
        </button>
      </div>

      {/* Tasks List - droppable ref on the scrollable container for cross-column drops */}
      <div
        ref={droppable.ref}
        class="flex-1 p-3 min-h-[100px] max-h-[calc(100vh-200px)] overflow-y-auto"
      >
        <SortableProvider ids={taskIds()}>
          <div class="flex flex-col gap-2">
            <For each={sortedTasks()}>
              {(task) => (
                <>
                  {/* Show gap before this task if it's the drop target */}
                  <Show
                    when={
                      isDropTarget() &&
                      gapBeforeTaskId() === task.id &&
                      props.draggedTaskId !== task.id
                    }
                  >
                    <DropGapIndicator />
                  </Show>
                  <TaskCard task={task} onClick={() => props.onTaskClick(task)} />
                </>
              )}
            </For>
            {/* Show gap at end if dropping at end of column */}
            <Show
              when={
                isDropTarget() &&
                gapBeforeTaskId() === null &&
                sortedTasks().length > 0
              }
            >
              <DropGapIndicator />
            </Show>
          </div>
        </SortableProvider>

        {/* Empty column with drop target */}
        <Show when={props.tasks.length === 0}>
          <Show
            when={isDropTarget()}
            fallback={
              <div class="text-center text-gray-500 text-sm py-8">
                No tasks yet
              </div>
            }
          >
            <div class="py-4">
              <DropGapIndicator />
            </div>
          </Show>
        </Show>
      </div>

      {/* Add Task Button (bottom) - only shown for TODO column */}
      <Show when={props.showAddButton}>
        <div class="p-2 border-t border-gray-800">
          <button
            onClick={props.onAddTask}
            class="w-full py-2 text-sm text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors flex items-center justify-center gap-2"
          >
            <PlusIcon class="w-4 h-4" />
            Add a card
          </button>
        </div>
      </Show>

    </div>
  );
}
