import {
  createDraggable,
  createDroppable,
  useDragDropContext,
} from "@thisbeyond/solid-dnd";
import { createEffect, createMemo, createSignal, on, Show } from "solid-js";
import {
  ChatBubbleIcon,
  LoadingSpinner,
  ParentTaskIcon,
  PRIcon,
  QueuedIcon,
  SubtaskIcon,
} from "~/components/ui/Icons";
import type { Task } from "~/hooks/useKanban";
import { renderMarkdown, TASK_CARD_PROSE_CLASSES } from "~/lib/markdown";
import { useTaskRelation } from "~/lib/TaskRelationContext";
import {
  computeGlowStyle,
  computeOverlayStyle,
  type GlowState,
  getPRBadgeClasses,
  getTaskBorderClass,
} from "~/lib/taskStyles";

// Delay before click is allowed after drag ends (ms)
const POST_DRAG_CLICK_DELAY = 50;

interface TaskCardProps {
  task: Task;
  onClick: () => void;
}

interface TaskCardOverlayProps {
  task: Task;
  tilt?: number; // rotation in degrees, positive = tilt right
}

export default function TaskCard(props: TaskCardProps) {
  const draggable = createDraggable(props.task.id);
  const droppable = createDroppable(props.task.id);
  const taskRelation = useTaskRelation();

  // useDragDropContext returns [state, actions] tuple or null if not in context.
  // We cache the context once on component creation since it won't change.
  const dragDropContext = useDragDropContext();

  const isBeingDragged = () => draggable.isActiveDraggable;

  /**
   * Check if any drag operation is currently active.
   * Uses the drag drop context state to determine if there's an active draggable.
   */
  const isAnyDragging = () => {
    if (!dragDropContext) {
      // If context is null, we're outside a DragDropProvider - assume no dragging
      return false;
    }
    const [state] = dragDropContext;
    return state.active.draggable !== null;
  };

  // Track if we just finished dragging to prevent click after drag
  const [wasDragging, setWasDragging] = createSignal(false);

  // When drag ends, set wasDragging flag briefly to block the click event
  createEffect(
    on(isBeingDragged, (isDragging, wasDraggingPrev) => {
      if (wasDraggingPrev && !isDragging) {
        // Just finished dragging - block clicks temporarily
        setWasDragging(true);
        setTimeout(() => setWasDragging(false), POST_DRAG_CLICK_DELAY);
      }
    }),
  );

  const handleClick = () => {
    if (!isAnyDragging() && !wasDragging()) {
      props.onClick();
    }
  };

  // Check if this task has parent-child relationships
  const hasRelationship = () =>
    props.task.is_parent || props.task.parent_task_id != null;

  // Handle mouse enter/leave for relationship highlighting
  const handleMouseEnter = () => {
    if (hasRelationship()) {
      taskRelation.setHoveredTask(props.task.id);
    }
  };

  const handleMouseLeave = () => {
    if (hasRelationship()) {
      taskRelation.setHoveredTask(null);
    }
  };

  // Get glow state from context
  // The context returns "parent" | "child" | "none", but GlowState expects "parent" | "child" | null
  const glowState = createMemo((): GlowState => {
    const state = taskRelation.getGlowState(props.task.id);
    return state === "none" ? null : state;
  });

  const isError = () => props.task.agent_status === "error";
  const isInProgress = () => !!props.task.in_progress;
  const isQueued = () => props.task.queued_at != null;
  const isWaitingForUser = () => props.task.agent_status === "thinking";

  // Use shared utility for glow style computation
  const glowStyle = () =>
    computeGlowStyle({
      glowState: glowState(),
      isError: isError(),
      isInProgress: isInProgress(),
      isQueued: isQueued(),
    });

  // Use shared utility for border class computation
  const borderClass = () =>
    getTaskBorderClass({
      glowState: glowState(),
      isError: isError(),
      isInProgress: isInProgress(),
      isQueued: isQueued(),
    });

  const combinedStyle = () => glowStyle();

  const setRefs = (el: HTMLDivElement) => {
    draggable.ref(el);
    droppable.ref(el);
  };

  return (
    <div
      ref={setRefs}
      class={`
        relative border rounded-lg p-3 cursor-pointer
        transition-transform duration-150
        hover:border-gray-600 hover:bg-gray-800
        ${isBeingDragged() ? "hidden" : ""}
        ${isAnyDragging() && !isBeingDragged() ? "pointer-events-none" : ""}
        ${borderClass()}
      `}
      style={combinedStyle()}
      onClick={handleClick}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
      {...draggable.dragActivators}
    >
      <div class="flex flex-col gap-2 min-w-0">
        <div class="flex items-start justify-between gap-2 min-w-0">
          <h4 class="text-sm font-medium text-white line-clamp-2 flex-1 min-w-0">
            {props.task.title}
          </h4>
          <Show when={isInProgress() && !isQueued()}>
            <LoadingSpinner />
          </Show>
          <Show when={isWaitingForUser()}>
            <span class="text-blue-400" title="Waiting for user input">
              <ChatBubbleIcon class="w-4 h-4" />
            </span>
          </Show>
          <Show when={isQueued()}>
            <QueuedIcon />
          </Show>
        </div>

        <Show when={props.task.description}>
          <div
            class={`text-xs text-gray-400 line-clamp-6 ${TASK_CARD_PROSE_CLASSES}`}
            innerHTML={renderMarkdown(props.task.description || "")}
          />
        </Show>

        <Show when={isQueued()}>
          <span class="text-xs px-2 py-0.5 rounded-full bg-yellow-500/20 text-yellow-400 border border-yellow-500/30 self-start">
            Queued
          </span>
        </Show>

        <Show when={isInProgress() && !isQueued()}>
          <span class="text-xs px-2 py-0.5 rounded-full bg-brand-500/20 text-brand-400 border border-brand-500/30 self-start truncate max-w-full">
            {props.task.agent_status_message || "Working..."}
          </span>
        </Show>

        <Show when={isWaitingForUser()}>
          <span class="text-xs px-2 py-0.5 rounded-full bg-blue-500/20 text-blue-400 border border-blue-500/30 self-start truncate max-w-full">
            {props.task.agent_status_message || "Waiting for input"}
          </span>
        </Show>

        <Show when={isError()}>
          <span
            class="text-xs px-2 py-0.5 rounded-full bg-red-500/20 text-red-400 border border-red-500/30 self-start truncate max-w-full"
            title={props.task.error_message || "Error"}
          >
            {props.task.error_message?.slice(0, 40) || "Error"}
            {(props.task.error_message?.length || 0) > 40 ? "..." : ""}
          </span>
        </Show>

        <Show when={props.task.pr_url && props.task.pr_status}>
          <a
            href={props.task.pr_url!}
            target="_blank"
            rel="noopener noreferrer"
            onClick={(e) => e.stopPropagation()}
            class={`text-xs px-2 py-0.5 rounded-full self-start flex items-center gap-1 hover:opacity-80 transition-opacity ${getPRBadgeClasses(props.task.pr_status!)}`}
          >
            <PRIcon status={props.task.pr_status!} />
            <span>{props.task.pr_number}</span>
          </a>
        </Show>

        {/* Parent/Subtask relationship indicator */}
        <Show when={props.task.is_parent}>
          <span class="text-xs px-2 py-0.5 rounded-full bg-purple-500/20 text-purple-400 border border-purple-500/30 self-start flex items-center gap-1">
            <ParentTaskIcon class="w-3 h-3" />
            Parent
          </span>
        </Show>
        <Show when={props.task.parent_task_id}>
          <span class="text-xs px-2 py-0.5 rounded-full bg-purple-500/10 text-purple-300 border border-purple-500/20 self-start flex items-center gap-1">
            <SubtaskIcon class="w-3 h-3" />
            Subtask
          </span>
        </Show>
      </div>
    </div>
  );
}

export function TaskCardOverlay(props: TaskCardOverlayProps) {
  const isError = () => props.task.agent_status === "error";
  const isInProgress = () => !!props.task.in_progress;

  // Use shared utility for overlay style computation
  const overlayStyle = () =>
    computeOverlayStyle({
      tilt: props.tilt ?? 0,
      isError: isError(),
      isInProgress: isInProgress(),
    });

  // Compute border class for overlay
  const borderClass = () => {
    if (isError()) return "border-red-500/50";
    if (isInProgress()) return "border-brand-500/50";
    return "border-gray-700";
  };

  return (
    <div
      class={`
        border rounded-lg p-3 shadow-xl ring-2 ring-brand-500
        w-64 max-w-64 transition-transform duration-75
        bg-gray-800 ${borderClass()}
      `}
      style={overlayStyle()}
    >
      <div class="flex flex-col gap-2 min-w-0">
        <div class="flex items-start justify-between gap-2 min-w-0">
          <h4 class="text-sm font-medium text-white line-clamp-2 flex-1 min-w-0">
            {props.task.title}
          </h4>
          <Show when={props.task.in_progress}>
            <LoadingSpinner />
          </Show>
        </div>

        <Show when={props.task.description}>
          <div
            class={`text-xs text-gray-400 line-clamp-6 ${TASK_CARD_PROSE_CLASSES}`}
            innerHTML={renderMarkdown(props.task.description || "")}
          />
        </Show>

        <Show when={props.task.in_progress}>
          <span class="text-xs px-2 py-0.5 rounded-full bg-brand-500/20 text-brand-400 border border-brand-500/30 self-start truncate max-w-full">
            {props.task.agent_status_message || "Working..."}
          </span>
        </Show>

        <Show when={isError()}>
          <span
            class="text-xs px-2 py-0.5 rounded-full bg-red-500/20 text-red-400 border border-red-500/30 self-start truncate max-w-full"
            title={props.task.error_message || "Error"}
          >
            {props.task.error_message?.slice(0, 40) || "Error"}
            {(props.task.error_message?.length || 0) > 40 ? "..." : ""}
          </span>
        </Show>
      </div>
    </div>
  );
}
