import { useLocation } from "@solidjs/router";
import { eq } from "@tanstack/db";
import { useLiveQuery } from "@tanstack/solid-db";
import {
  type CollisionDetector,
  DragDropProvider,
  DragDropSensors,
  type DragEvent,
  type Draggable,
  DragOverlay,
  type Droppable,
} from "@thisbeyond/solid-dnd";
import {
  type Accessor,
  createMemo,
  createSignal,
  For,
  onCleanup,
  onMount,
  Show,
} from "solid-js";
import { Button, Input } from "~/components/design-system";
import {
  BackArrowIcon,
  CloseIcon,
  HelpIcon,
  PlusIcon,
  SearchIcon,
  SettingsIcon,
} from "~/components/ui/Icons";
import {
  type Column,
  type Task,
  tasksCollection,
  toDecimal,
  unwrap,
  useBoard,
  useColumns,
} from "~/hooks/useKanban";
import { useShortcut } from "~/hooks/useKeyboardShortcuts";
import { fuzzyMatch } from "~/lib/fuzzySearch";
import * as sdk from "~/lib/generated/ash";
import { syncTaskTemplatesCollection } from "~/lib/generated/sync/collections";
import { TaskRelationProvider } from "~/lib/TaskRelationContext";
import BoardSettings from "./BoardSettings";
import ColumnSettingsPopup from "./ColumnSettingsPopup";
import CreateTaskModal, { type TaskTemplate } from "./CreateTaskModal";
import KanbanColumn from "./KanbanColumn";
import KeyboardShortcutsHelp from "./KeyboardShortcutsHelp";
import { TaskCardOverlay } from "./TaskCard";

/** Valid settings tabs */
type SettingsTab =
  | "general"
  | "templates"
  | "hooks"
  | "columns"
  | "scheduled"
  | "system";

/** Represents where a task will be dropped */
export interface DropTarget {
  /** Column ID where task will be dropped */
  columnId: string;
  /** Task ID to insert before, or null to append at end */
  beforeTaskId: string | null;
}

/** Global pointer position tracker for accurate drag positioning */
let globalPointerY = 0;

/**
 * Custom collision detector for kanban boards.
 * Prioritizes task droppables over column droppables and calculates
 * the correct insertion point based on the pointer's Y position.
 *
 * Uses global pointer position for accurate collision detection since
 * draggable.transformed.center doesn't track properly with DragOverlay.
 */
const createKanbanCollisionDetector = (
  columnIds: Set<string>,
  getTaskColumnId: (taskId: string) => string | undefined,
): CollisionDetector => {
  return (
    draggable: Draggable,
    droppables: Droppable[],
    _context: { activeDroppableId: string | number | null },
  ): Droppable | null => {
    // Use actual pointer position for Y, but draggable center for X (column detection)
    const draggableCenter = {
      x: draggable.transformed.center.x,
      y: globalPointerY || draggable.transformed.center.y,
    };

    // Separate column droppables from task droppables
    const columnDroppables: Droppable[] = [];
    const taskDroppables: Droppable[] = [];

    for (const droppable of droppables) {
      if (columnIds.has(String(droppable.id))) {
        columnDroppables.push(droppable);
      } else {
        taskDroppables.push(droppable);
      }
    }

    // First, find which column the pointer is in
    let targetColumn: Droppable | null = null;
    for (const col of columnDroppables) {
      const layout = col.layout;
      if (
        draggableCenter.x >= layout.left &&
        draggableCenter.x <= layout.right
      ) {
        targetColumn = col;
        break;
      }
    }

    if (!targetColumn) {
      // Find closest column by horizontal distance
      let minDistance = Infinity;
      for (const col of columnDroppables) {
        const distance = Math.abs(draggableCenter.x - col.layout.center.x);
        if (distance < minDistance) {
          minDistance = distance;
          targetColumn = col;
        }
      }
    }

    if (!targetColumn) return null;

    // Get tasks in the target column
    const tasksInColumn = taskDroppables.filter(
      (t) => getTaskColumnId(String(t.id)) === String(targetColumn!.id),
    );

    if (tasksInColumn.length === 0) {
      // Empty column - return the column itself
      return targetColumn;
    }

    // Sort tasks by their vertical position
    tasksInColumn.sort((a, b) => a.layout.top - b.layout.top);

    // Find which task the pointer is closest to, considering Y position
    let bestMatch: Droppable | null = null;
    let minYDistance = Infinity;

    for (const task of tasksInColumn) {
      // Skip the dragged item itself
      if (task.id === draggable.id) continue;

      const taskLayout = task.layout;
      const taskCenterY = taskLayout.center.y;
      const yDistance = Math.abs(draggableCenter.y - taskCenterY);

      // Check if pointer is within the task's vertical bounds (with some tolerance)
      const isWithinTask =
        draggableCenter.y >= taskLayout.top - 10 &&
        draggableCenter.y <= taskLayout.bottom + 10;

      if (isWithinTask && yDistance < minYDistance) {
        minYDistance = yDistance;
        bestMatch = task;
      }
    }

    // If no task matched, check if we're above the first or below the last
    if (!bestMatch) {
      // Exclude the dragged item from consideration
      const nonDraggedTasks = tasksInColumn.filter(
        (t) => t.id !== draggable.id,
      );
      if (nonDraggedTasks.length === 0) {
        return targetColumn;
      }

      const effectiveFirst = nonDraggedTasks[0];
      const effectiveLast = nonDraggedTasks[nonDraggedTasks.length - 1];

      // Use top edge for first task - if above the midpoint of first task, select it
      // This ensures dragging to the very top of a column works
      const firstMidpoint =
        (effectiveFirst.layout.top + effectiveFirst.layout.bottom) / 2;
      if (draggableCenter.y < firstMidpoint) {
        bestMatch = effectiveFirst;
      } else if (draggableCenter.y > effectiveLast.layout.bottom) {
        // Below the bottom of the last task
        bestMatch = effectiveLast;
      } else {
        // Find the two tasks the pointer is between
        for (let i = 0; i < nonDraggedTasks.length - 1; i++) {
          const current = nonDraggedTasks[i];
          const next = nonDraggedTasks[i + 1];
          const currentMidpoint =
            (current.layout.top + current.layout.bottom) / 2;
          const nextMidpoint = (next.layout.top + next.layout.bottom) / 2;

          if (
            draggableCenter.y >= currentMidpoint &&
            draggableCenter.y <= nextMidpoint
          ) {
            // Return the task we're closer to
            const distToCurrent = Math.abs(draggableCenter.y - currentMidpoint);
            const distToNext = Math.abs(draggableCenter.y - nextMidpoint);
            bestMatch = distToCurrent < distToNext ? current : next;
            break;
          }
        }

        // If still no match, pick the closest task
        if (!bestMatch) {
          let minDist = Infinity;
          for (const task of nonDraggedTasks) {
            const midpoint = (task.layout.top + task.layout.bottom) / 2;
            const dist = Math.abs(draggableCenter.y - midpoint);
            if (dist < minDist) {
              minDist = dist;
              bestMatch = task;
            }
          }
        }
      }
    }

    return bestMatch || targetColumn;
  };
};

interface KanbanBoardProps {
  boardId: string;
  onTaskClick?: (task: Task) => void;
  /** Current settings tab from URL (null means settings not open) */
  settingsTab?: SettingsTab | null;
  /** Called when settings button is clicked */
  onOpenSettings?: (tab?: SettingsTab) => void;
  /** Called when settings panel is closed */
  onCloseSettings?: () => void;
  /** Called when settings tab is changed */
  onChangeSettingsTab?: (tab: SettingsTab) => void;
  /** Currently selected task ID (for arrow key navigation) */
  selectedTaskId?: string | null;
  /** Called to navigate to a different task */
  onNavigateToTask?: (task: Task) => void;
}

/** Skeleton placeholder for loading state - shows 3 column placeholders */
function BoardLoadingSkeleton() {
  return (
    <div class="flex gap-4">
      <For each={[1, 2, 3]}>
        {() => (
          <div class="flex flex-col bg-gray-900/50 border border-gray-800 rounded-xl min-w-[280px] h-[400px] animate-pulse">
            <div class="p-3 border-b border-gray-800">
              <div class="h-5 w-24 bg-gray-800 rounded" />
            </div>
            <div class="flex-1 p-2 space-y-2">
              <div class="h-20 bg-gray-800/50 rounded-lg" />
              <div class="h-20 bg-gray-800/50 rounded-lg" />
            </div>
          </div>
        )}
      </For>
    </div>
  );
}

// Constants for drag tilt effect
const TILT_MAX_DEGREES = 3;
const TILT_VELOCITY_SCALE = 8;
const TILT_SMOOTHING_FACTOR = 0.3;

interface TiltingDragOverlayProps {
  task: Task;
}

/**
 * Component to render drag overlay with tilt effect based on pointer velocity.
 * Extracted as a separate component to isolate pointer tracking logic.
 */
function TiltingDragOverlay(props: TiltingDragOverlayProps) {
  const [tilt, setTilt] = createSignal(0);
  let lastX: number | null = null;
  let lastTime: number | null = null;

  const handlePointerMove = (e: PointerEvent) => {
    const currentX = e.clientX;
    const currentTime = performance.now();

    if (lastX !== null && lastTime !== null) {
      const deltaX = currentX - lastX;
      const deltaTime = currentTime - lastTime;

      if (deltaTime > 0) {
        // Calculate velocity (pixels per ms) and convert to tilt
        const velocity = deltaX / deltaTime;
        // Scale velocity to tilt: max +/-3 degrees, with smoothing
        const targetTilt = Math.max(
          -TILT_MAX_DEGREES,
          Math.min(TILT_MAX_DEGREES, velocity * TILT_VELOCITY_SCALE),
        );
        // Smooth transition to target tilt
        setTilt((prev) => prev + (targetTilt - prev) * TILT_SMOOTHING_FACTOR);
      }
    }

    lastX = currentX;
    lastTime = currentTime;
  };

  onMount(() => {
    window.addEventListener("pointermove", handlePointerMove);
  });

  onCleanup(() => {
    window.removeEventListener("pointermove", handlePointerMove);
  });

  return <TaskCardOverlay task={props.task} tilt={tilt()} />;
}

export default function KanbanBoard(props: KanbanBoardProps) {
  const { board, isLoading: isBoardLoading } = useBoard(() => props.boardId);
  const { columns, isLoading: isColumnsLoading } = useColumns(
    () => props.boardId,
  );

  // Load all tasks for the board - selecting all fields to ensure type safety
  // Note: useLiveQuery returns a generic type, but since we're selecting all Task fields
  // in the exact schema shape, the runtime data will match the Task interface.
  const tasksQuery = useLiveQuery((q) =>
    q
      .from({ tasks: tasksCollection })
      .orderBy(({ tasks }) => tasks.position, "asc")
      .select(({ tasks }) => ({
        id: tasks.id,
        column_id: tasks.column_id,
        title: tasks.title,
        description: tasks.description,
        position: tasks.position,
        worktree_path: tasks.worktree_path,
        worktree_branch: tasks.worktree_branch,
        custom_branch_name: tasks.custom_branch_name,
        agent_status: tasks.agent_status,
        agent_status_message: tasks.agent_status_message,
        in_progress: tasks.in_progress,
        error_message: tasks.error_message,
        queued_at: tasks.queued_at,
        queue_priority: tasks.queue_priority,
        pr_url: tasks.pr_url,
        pr_number: tasks.pr_number,
        pr_status: tasks.pr_status,
        parent_task_id: tasks.parent_task_id,
        is_parent: tasks.is_parent,
        subtask_position: tasks.subtask_position,
        subtask_generation_status: tasks.subtask_generation_status,
        description_images: tasks.description_images,
        inserted_at: tasks.inserted_at,
        updated_at: tasks.updated_at,
      })),
  );

  /**
   * Returns all tasks from the query.
   * Type assertion is necessary here because useLiveQuery's type inference
   * returns a generic object type. We've selected all Task fields above
   * with matching types, so this cast is structurally safe.
   */
  const allTasks: Accessor<Task[]> = () => (tasksQuery.data ?? []) as Task[];

  const taskTemplatesQuery = useLiveQuery((q) =>
    q
      .from({ templates: syncTaskTemplatesCollection })
      .where(({ templates }) => eq(templates.board_id, props.boardId))
      .orderBy(({ templates }) => templates.position, "asc")
      .select(({ templates }) => ({
        id: templates.id,
        name: templates.name,
        description_template: templates.description_template,
      })),
  );

  const taskTemplates = (): TaskTemplate[] =>
    (taskTemplatesQuery.data ?? []) as TaskTemplate[];

  const [isCreateModalOpen, setIsCreateModalOpen] = createSignal(false);
  const [selectedColumnId, setSelectedColumnId] = createSignal<string | null>(
    null,
  );
  const [selectedColumnName, setSelectedColumnName] = createSignal("");

  const [activeTaskId, setActiveTaskId] = createSignal<string | null>(null);

  const [dropTarget, setDropTarget] = createSignal<DropTarget | null>(null);

  // Track the current droppable during drag for continuous position updates
  const [currentDroppable, setCurrentDroppable] =
    createSignal<Droppable | null>(null);

  // State is lifted to survive re-renders from Electric sync updates
  const [openColumnSettingsId, setOpenColumnSettingsId] = createSignal<
    string | null
  >(null);
  const [columnSettingsAnchor, setColumnSettingsAnchor] = createSignal<
    HTMLButtonElement | undefined
  >(undefined);

  const openSettingsColumn = createMemo(() => {
    const columnId = openColumnSettingsId();
    if (!columnId) return null;
    return columns().find((c) => c.id === columnId) ?? null;
  });

  const [filterText, setFilterText] = createSignal("");
  const [showShortcutsHelp, setShowShortcutsHelp] = createSignal(false);
  let searchInputRef: HTMLInputElement | undefined;

  const location = useLocation();
  const isTaskPanelOpen = () => !!props.selectedTaskId;
  const isSettingsOpen = () => props.settingsTab != null;
  const isBoardView = () => /^\/board\/[^/]+$/.test(location.pathname);

  useShortcut(["Shift", "?"], () => setShowShortcutsHelp(true), {
    description: "Show keyboard shortcuts",
  });
  useShortcut(["n"], () => openCreateModal(), {
    description: "Create new task",
    enabled: isBoardView,
  });
  useShortcut(["/"], () => searchInputRef?.focus(), {
    description: "Focus search",
    enabled: isBoardView,
  });
  useShortcut([","], () => props.onOpenSettings?.(), {
    description: "Open settings",
    enabled: isBoardView,
  });

  const filteredTasks = createMemo(() => {
    const query = filterText().trim();
    if (!query) return allTasks();
    return allTasks().filter((task) => {
      const titleMatch = fuzzyMatch(task.title, query);
      const descriptionMatch = task.description
        ? fuzzyMatch(task.description, query)
        : false;
      return titleMatch || descriptionMatch;
    });
  });

  const orderedFilteredTasks = createMemo(() => {
    const cols = columns();
    const tasks = filteredTasks();
    const result: Task[] = [];
    for (const col of cols) {
      const colTasks = tasks
        .filter((t) => t.column_id === col.id)
        .sort((a, b) => Number(a.position) - Number(b.position));
      result.push(...colTasks);
    }
    return result;
  });

  const navigateTask = (direction: "prev" | "next") => {
    if (!props.selectedTaskId || !props.onNavigateToTask) return;
    const tasks = orderedFilteredTasks();
    const currentIndex = tasks.findIndex((t) => t.id === props.selectedTaskId);
    if (currentIndex === -1) return;

    const newIndex =
      direction === "next"
        ? (currentIndex + 1) % tasks.length
        : (currentIndex - 1 + tasks.length) % tasks.length;
    props.onNavigateToTask(tasks[newIndex]);
  };

  useShortcut(["ArrowRight"], () => navigateTask("next"), {
    description: "Next task",
    enabled: isTaskPanelOpen,
  });
  useShortcut(["ArrowLeft"], () => navigateTask("prev"), {
    description: "Previous task",
    enabled: isTaskPanelOpen,
  });

  const todoColumn = () =>
    columns().find((c) => c.name.toUpperCase() === "TODO");

  const openCreateModal = (column?: Column) => {
    const col = column || todoColumn();
    if (!col) return;
    setSelectedColumnId(col.id);
    setSelectedColumnName(col.name);
    setIsCreateModalOpen(true);
  };

  const closeCreateModal = () => {
    setIsCreateModalOpen(false);
    setSelectedColumnId(null);
    setSelectedColumnName("");
  };

  const handleTaskClick = (task: Task) => {
    if (props.onTaskClick) {
      props.onTaskClick(task);
    }
  };

  /**
   * Memoized map of tasks grouped by column ID.
   * Uses filteredTasks so search filter is applied.
   * This provides O(1) lookup when rendering columns instead of
   * filtering the entire task list for each column.
   */
  const tasksByColumn = createMemo(() => {
    const map = new Map<string, Task[]>();
    for (const task of filteredTasks()) {
      const existing = map.get(task.column_id);
      if (existing) {
        existing.push(task);
      } else {
        map.set(task.column_id, [task]);
      }
    }
    return map;
  });

  const getTasksForColumn = (columnId: string): Task[] => {
    return tasksByColumn().get(columnId) ?? [];
  };

  const taskColumnMap = createMemo(() => {
    const map = new Map<string, string>();
    for (const task of allTasks()) {
      map.set(task.id, task.column_id);
    }
    return map;
  });

  const columnIdSet = createMemo(() => new Set(columns().map((c) => c.id)));

  const collisionDetector = createMemo(() =>
    createKanbanCollisionDetector(columnIdSet(), (taskId) =>
      taskColumnMap().get(taskId),
    ),
  );

  const activeTask = createMemo(() => {
    const id = activeTaskId();
    if (!id) return null;
    return allTasks().find((t) => t.id === id) || null;
  });

  // Function to calculate drop target based on droppable and pointer position
  const calculateDropTarget = (
    droppable: Droppable,
    draggedTaskId: string,
    currentPointerY: number,
  ): DropTarget | null => {
    const droppableId = droppable.id as string;

    // Ignore if we're hovering over the dragged task itself
    if (droppableId === draggedTaskId) {
      return null;
    }

    // Check if we're over a column
    if (columnIdSet().has(droppableId)) {
      return {
        columnId: droppableId,
        beforeTaskId: null,
      };
    }

    // We're over a task
    const targetTask = allTasks().find((t) => t.id === droppableId);
    if (!targetTask) return null;

    const columnTasks = getTasksForColumn(targetTask.column_id)
      .filter((t) => t.id !== draggedTaskId)
      .sort((a, b) => {
        const posA = Number(a.position) || 0;
        const posB = Number(b.position) || 0;
        if (posA !== posB) return posA - posB;
        return a.id.localeCompare(b.id);
      });

    const targetIndex = columnTasks.findIndex((t) => t.id === targetTask.id);
    const targetMidpoint = (droppable.layout.top + droppable.layout.bottom) / 2;
    const insertBefore = currentPointerY < targetMidpoint;

    if (insertBefore) {
      return {
        columnId: targetTask.column_id,
        beforeTaskId: targetTask.id,
      };
    } else {
      const nextTask = columnTasks[targetIndex + 1];
      return {
        columnId: targetTask.column_id,
        beforeTaskId: nextTask?.id ?? null,
      };
    }
  };

  const onDragStart = ({ draggable }: DragEvent) => {
    setActiveTaskId(draggable.id as string);
  };

  // Track pointer position during drag for continuous drop target updates
  onMount(() => {
    const handlePointerMove = (e: PointerEvent) => {
      globalPointerY = e.clientY;

      // Update drop target reactively during drag
      const droppable = currentDroppable();
      const draggedId = activeTaskId();
      if (droppable && draggedId) {
        const newTarget = calculateDropTarget(droppable, draggedId, e.clientY);
        if (newTarget) {
          setDropTarget(newTarget);
        }
      }
    };

    window.addEventListener("pointermove", handlePointerMove);
    onCleanup(() => {
      window.removeEventListener("pointermove", handlePointerMove);
    });
  });

  const onDragOver = ({ draggable, droppable }: DragEvent) => {
    if (!draggable || !droppable) {
      setDropTarget(null);
      setCurrentDroppable(null);
      return;
    }

    const draggedTaskId = draggable.id as string;

    // Store current droppable for continuous position updates
    setCurrentDroppable(droppable);

    // Calculate initial drop target
    const newTarget = calculateDropTarget(
      droppable,
      draggedTaskId,
      globalPointerY,
    );
    if (newTarget) {
      setDropTarget(newTarget);
    }
  };

  // Handle drag end
  const onDragEnd = async ({ draggable, droppable }: DragEvent) => {
    setActiveTaskId(null);
    setDropTarget(null);
    setCurrentDroppable(null);

    if (!draggable || !droppable) return;

    const taskId = draggable.id as string;
    const task = allTasks().find((t) => t.id === taskId);
    if (!task) return;

    const droppableId = droppable.id as string;

    // Recalculate the exact drop position using current pointer position
    // This is more accurate than using cached dropTarget since onDragOver
    // only fires when droppable changes, not when pointer moves within same droppable
    let columnId: string;
    let beforeTaskId: string | null;

    if (columnIdSet().has(droppableId)) {
      // Dropped on a column - insert at end
      columnId = droppableId;
      beforeTaskId = null;
    } else {
      // Dropped on a task - calculate insertion point using pointer position
      const targetTask = allTasks().find((t) => t.id === droppableId);
      if (!targetTask) return;

      columnId = targetTask.column_id;
      const columnTasks = getTasksForColumn(columnId)
        .filter((t) => t.id !== task.id)
        .sort((a, b) => {
          const posA = Number(a.position) || 0;
          const posB = Number(b.position) || 0;
          if (posA !== posB) return posA - posB;
          return a.id.localeCompare(b.id);
        });

      const targetIndex = columnTasks.findIndex((t) => t.id === targetTask.id);
      const pointerY = globalPointerY;
      const targetMidpoint =
        (droppable.layout.top + droppable.layout.bottom) / 2;
      const insertBefore = pointerY < targetMidpoint;

      if (insertBefore) {
        beforeTaskId = targetTask.id;
      } else {
        const nextTask = columnTasks[targetIndex + 1];
        beforeTaskId = nextTask?.id ?? null;
      }
    }

    const isSameColumn = task.column_id === columnId;

    // Get tasks in target column (excluding the dragged task)
    const columnTasks = getTasksForColumn(columnId)
      .filter((t) => t.id !== task.id)
      .sort((a, b) => {
        const posA = Number(a.position) || 0;
        const posB = Number(b.position) || 0;
        if (posA !== posB) return posA - posB;
        return a.id.localeCompare(b.id);
      });

    let newPosition: number;
    const positions = columnTasks.map((t) => Number(t.position) || 0);

    if (beforeTaskId === null) {
      // Insert at end of column
      if (columnTasks.length === 0) {
        newPosition = 1000;
      } else {
        const maxPos = Math.max(...positions);
        newPosition = maxPos + 1000;
      }
    } else {
      // Insert before the specified task
      const beforeTaskIndex = columnTasks.findIndex(
        (t) => t.id === beforeTaskId,
      );

      if (beforeTaskIndex === -1) {
        // Task not found, insert at end
        newPosition =
          columnTasks.length > 0 ? Math.max(...positions) + 1000 : 1000;
      } else if (beforeTaskIndex === 0) {
        // Insert at the very beginning - use negative position
        const firstPos = positions[0];
        newPosition = firstPos - 1000;
      } else {
        // Insert between two tasks
        const prevPos = positions[beforeTaskIndex - 1];
        const beforePos = positions[beforeTaskIndex];
        const gap = beforePos - prevPos;

        if (gap > 0.001) {
          newPosition = (prevPos + beforePos) / 2;
        } else {
          newPosition = beforePos - 0.001;
        }
      }
    }

    // Ensure position is valid
    if (!Number.isFinite(newPosition)) {
      newPosition = 0;
    }

    // Skip if no actual change
    if (isSameColumn) {
      const currentPos = Number(task.position) || 0;
      if (Math.abs(currentPos - newPosition) < 0.001) {
        return;
      }
    }

    // Execute the move
    if (isSameColumn) {
      await sdk
        .move_task({
          identity: taskId,
          input: { position: toDecimal(newPosition) },
        })
        .then(unwrap);
    } else {
      await sdk
        .move_task({
          identity: taskId,
          input: { column_id: columnId, position: toDecimal(newPosition) },
        })
        .then(unwrap);
    }
  };

  const isLoading = () => isBoardLoading() || isColumnsLoading();

  return (
    <div class="h-screen flex flex-col bg-gray-950 text-white overflow-hidden">
      {/* Header */}
      <header class="flex-shrink-0 bg-gray-900/50 border-b border-gray-800 px-6 py-4">
        <Show
          when={!isLoading() && board()}
          fallback={<div class="h-8 w-48 bg-gray-800 animate-pulse rounded" />}
        >
          <div class="flex items-center justify-between w-full gap-4">
            <div class="flex items-center gap-4">
              <a
                href="/"
                class="text-brand-500 hover:text-brand-400 transition-colors"
              >
                <BackArrowIcon class="w-5 h-5" />
              </a>
              <div>
                <h1 class="text-xl font-bold text-white">{board()?.name}</h1>
                <Show when={board()?.description}>
                  <p class="text-sm text-gray-400">{board()?.description}</p>
                </Show>
              </div>
            </div>

            {/* Filter input */}
            <div class="flex-1 max-w-md">
              <div class="relative">
                <SearchIcon class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                <Input
                  ref={searchInputRef}
                  type="text"
                  placeholder="Filter tasks..."
                  value={filterText()}
                  onInput={(e) => setFilterText(e.currentTarget.value)}
                  variant="search"
                  inputSize="sm"
                  hasIcon
                />
                <Show when={filterText()}>
                  <Button
                    onClick={() => setFilterText("")}
                    variant="icon"
                    title="Clear filter"
                  >
                    <CloseIcon class="w-4 h-4" />
                  </Button>
                </Show>
              </div>
            </div>

            <div class="flex items-center gap-2">
              <Show when={todoColumn()}>
                <Button
                  onClick={() => openCreateModal()}
                  buttonSize="sm"
                  title="Add new task"
                >
                  <PlusIcon class="w-4 h-4" />
                  New Task
                </Button>
              </Show>
              <Button
                onClick={() => props.onOpenSettings?.()}
                variant="secondary"
                buttonSize="sm"
              >
                <SettingsIcon class="w-4 h-4" />
                Settings
              </Button>
              <Button
                onClick={() => setShowShortcutsHelp(true)}
                variant="icon"
                title="Keyboard shortcuts (Shift+?)"
              >
                <HelpIcon class="w-4 h-4" />
              </Button>
            </div>
          </div>
        </Show>
      </header>

      {/* Board Content */}
      <main class="flex-1 p-6 overflow-hidden">
        <Show when={!isLoading()} fallback={<BoardLoadingSkeleton />}>
          <TaskRelationProvider tasks={allTasks}>
            <DragDropProvider
              onDragStart={onDragStart}
              onDragOver={onDragOver}
              onDragEnd={onDragEnd}
              collisionDetector={collisionDetector()}
            >
              <DragDropSensors />
              <div class="flex gap-4 h-full overflow-x-auto pb-4">
                <For each={columns()}>
                  {(column) => (
                    <KanbanColumn
                      column={column}
                      boardId={props.boardId}
                      tasks={getTasksForColumn(column.id)}
                      onAddTask={() => openCreateModal(column)}
                      onTaskClick={handleTaskClick}
                      showAddButton={column.name.toUpperCase() === "TODO"}
                      onOpenSettings={(anchor) => {
                        setOpenColumnSettingsId(column.id);
                        setColumnSettingsAnchor(anchor);
                      }}
                      dropTarget={dropTarget()}
                      draggedTaskId={activeTaskId()}
                    />
                  )}
                </For>

                <Show when={columns().length === 0}>
                  <div class="flex items-center justify-center min-w-[280px] h-[200px] bg-gray-900/50 border border-gray-800 border-dashed rounded-xl text-gray-500">
                    No columns yet
                  </div>
                </Show>
              </div>

              {/* Drag Overlay */}
              <DragOverlay>
                <Show when={activeTask()}>
                  {(task) => <TiltingDragOverlay task={task()} />}
                </Show>
              </DragOverlay>
            </DragDropProvider>
          </TaskRelationProvider>
        </Show>
      </main>

      {/* Create Task Modal */}
      <Show when={selectedColumnId()}>
        <CreateTaskModal
          isOpen={isCreateModalOpen()}
          onClose={closeCreateModal}
          columnId={selectedColumnId()!}
          columnName={selectedColumnName()}
          columns={columns()}
          templates={taskTemplates()}
        />
      </Show>

      {/* Board Settings Panel */}
      <Show when={board()}>
        <BoardSettings
          isOpen={isSettingsOpen()}
          onClose={() => props.onCloseSettings?.()}
          boardId={props.boardId}
          boardName={board()?.name || ""}
          activeTab={props.settingsTab ?? "general"}
          onTabChange={(tab) => props.onChangeSettingsTab?.(tab)}
        />
      </Show>

      {/* Column Settings Popup - rendered at board level to survive column re-renders */}
      <Show when={openSettingsColumn()}>
        {(column) => (
          <ColumnSettingsPopup
            column={column()}
            boardId={props.boardId}
            anchor={columnSettingsAnchor()}
            onClose={() => {
              setOpenColumnSettingsId(null);
              setColumnSettingsAnchor(undefined);
            }}
          />
        )}
      </Show>

      {/* Keyboard Shortcuts Help Modal */}
      <KeyboardShortcutsHelp
        isOpen={showShortcutsHelp()}
        onClose={() => setShowShortcutsHelp(false)}
      />
    </div>
  );
}
