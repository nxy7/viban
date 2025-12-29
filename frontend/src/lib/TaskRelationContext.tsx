/**
 * TaskRelationContext - Provides parent-child task relationship highlighting.
 *
 * When hovering over a task, related parent/child tasks are highlighted
 * to visualize the subtask hierarchy.
 */

import { createContext, createSignal, type JSX, useContext } from "solid-js";
import type { GlowState } from "./taskStyles";
import type { Task } from "./useKanban";

/** Extended glow state including "none" for no relationship */
type TaskGlowState = GlowState | "none";

/** Context value interface for task relation state */
interface TaskRelationContextValue {
  /** The currently hovered task ID */
  hoveredTaskId: () => string | null;
  /** Set which task is being hovered */
  setHoveredTask: (taskId: string | null) => void;
  /** All tasks (needed to find relationships) */
  allTasks: () => Task[];
  /** Check if a task should glow based on current hover */
  getGlowState: (taskId: string) => TaskGlowState;
}

const TaskRelationContext = createContext<TaskRelationContextValue>();

/** Props for TaskRelationProvider component */
interface TaskRelationProviderProps {
  children: JSX.Element;
  tasks: () => Task[];
}

/**
 * Provider component that tracks task hover state and computes
 * relationship glow states for the task hierarchy.
 */
export function TaskRelationProvider(props: TaskRelationProviderProps) {
  const [hoveredTaskId, setHoveredTaskId] = createSignal<string | null>(null);

  /**
   * Determines the glow state for a task based on its relationship
   * to the currently hovered task.
   */
  const getGlowState = (taskId: string): TaskGlowState => {
    const hovered = hoveredTaskId();
    if (!hovered) return "none";

    const tasks = props.tasks();
    const hoveredTask = tasks.find((t) => t.id === hovered);
    const thisTask = tasks.find((t) => t.id === taskId);

    if (!hoveredTask || !thisTask) return "none";

    // Case 1: Hovering a parent task
    if (hoveredTask.is_parent) {
      if (taskId === hovered) {
        // This is the hovered parent
        return "parent";
      }
      if (thisTask.parent_task_id === hovered) {
        // This is a child of the hovered parent
        return "child";
      }
    }

    // Case 2: Hovering a child task (subtask)
    if (hoveredTask.parent_task_id) {
      if (taskId === hovered) {
        // This is the hovered child
        return "child";
      }
      if (taskId === hoveredTask.parent_task_id) {
        // This is the parent of the hovered child
        return "parent";
      }
    }

    return "none";
  };

  const value: TaskRelationContextValue = {
    hoveredTaskId,
    setHoveredTask: setHoveredTaskId,
    allTasks: props.tasks,
    getGlowState,
  };

  return (
    <TaskRelationContext.Provider value={value}>
      {props.children}
    </TaskRelationContext.Provider>
  );
}

/**
 * Hook to access task relation context.
 * Returns a default no-op implementation if used outside provider.
 */
export function useTaskRelation(): TaskRelationContextValue {
  const context = useContext(TaskRelationContext);
  if (!context) {
    // Return a default implementation if used outside provider
    return {
      hoveredTaskId: () => null,
      setHoveredTask: () => {},
      allTasks: () => [],
      getGlowState: () => "none",
    };
  }
  return context;
}
