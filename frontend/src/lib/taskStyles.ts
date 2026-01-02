/**
 * Shared task styling utilities - Extracted to eliminate DRY violations
 *
 * This module contains:
 * - Task status styling (glow effects, border colors)
 * - Relationship glow states
 * - PR status badge styling
 */

import type { JSX } from "solid-js";

// Type for relationship glow state
export type GlowState = "parent" | "child" | null;

// Type for agent status
export type AgentStatus = "idle" | "thinking" | "executing" | "error";

// Type for PR status
export type PRStatusType = "open" | "merged" | "closed" | "draft";

/**
 * Computes the glow style (box-shadow) for a task card based on its state
 */
export function computeGlowStyle(options: {
  glowState: GlowState;
  isError: boolean;
  isInProgress: boolean;
  isQueued: boolean;
}): JSX.CSSProperties {
  const { glowState, isError, isInProgress, isQueued } = options;

  // Parent-child relationship glow takes precedence for visual feedback
  if (glowState === "parent") {
    return {
      "box-shadow":
        "0 0 25px rgba(147, 51, 234, 0.6), 0 0 50px rgba(147, 51, 234, 0.3), 0 0 75px rgba(147, 51, 234, 0.15)",
    };
  }
  if (glowState === "child") {
    return {
      "box-shadow":
        "0 0 15px rgba(147, 51, 234, 0.4), 0 0 30px rgba(147, 51, 234, 0.2)",
    };
  }

  // Status-based glow
  if (isError) {
    return {
      "box-shadow":
        "0 0 20px rgba(239, 68, 68, 0.5), 0 0 40px rgba(239, 68, 68, 0.2)",
    };
  }
  if (isInProgress) {
    return {
      "box-shadow":
        "0 0 20px rgba(139, 92, 246, 0.5), 0 0 40px rgba(139, 92, 246, 0.2)",
    };
  }
  if (isQueued) {
    return {
      "box-shadow":
        "0 0 15px rgba(234, 179, 8, 0.3), 0 0 30px rgba(234, 179, 8, 0.1)",
    };
  }

  return {};
}

/**
 * Computes the overlay style for a dragged task card
 */
export function computeOverlayStyle(options: {
  tilt: number;
  isError: boolean;
  isInProgress: boolean;
}): JSX.CSSProperties {
  const { tilt, isError, isInProgress } = options;
  const base: JSX.CSSProperties = { transform: `rotate(${tilt}deg)` };

  if (isError) {
    return {
      ...base,
      "box-shadow":
        "0 0 20px rgba(239, 68, 68, 0.5), 0 0 40px rgba(239, 68, 68, 0.2)",
    };
  }
  if (isInProgress) {
    return {
      ...base,
      "box-shadow":
        "0 0 20px rgba(139, 92, 246, 0.5), 0 0 40px rgba(139, 92, 246, 0.2)",
    };
  }

  return base;
}

/**
 * Returns the CSS classes for task card border and background based on state
 */
export function getTaskBorderClass(options: {
  glowState: GlowState;
  isError: boolean;
  isInProgress: boolean;
  isQueued: boolean;
}): string {
  const { glowState, isError, isInProgress, isQueued } = options;

  if (glowState === "parent") {
    return "border-purple-500/70 bg-purple-900/20";
  }
  if (glowState === "child") {
    return "border-purple-500/50 bg-purple-900/10";
  }
  if (isError) {
    return "border-red-500/50 bg-gray-800/50";
  }
  if (isInProgress) {
    return "border-brand-500/50 bg-gray-800/50";
  }
  if (isQueued) {
    return "border-yellow-500/50 bg-gray-800/50 opacity-75";
  }

  return "border-gray-700 bg-gray-800/50";
}

/**
 * Returns the CSS classes for PR status badge
 */
export function getPRBadgeClasses(status: PRStatusType): string {
  switch (status) {
    case "open":
      return "bg-green-500/20 text-green-400 border border-green-500/30";
    case "merged":
      return "bg-purple-500/20 text-purple-400 border border-purple-500/30";
    case "draft":
      return "bg-gray-500/20 text-gray-400 border border-gray-500/30";
    case "closed":
      return "bg-red-500/20 text-red-400 border border-red-500/30";
  }
}

/**
 * Returns hover classes for PR badges (used in TaskDetailsPanel)
 */
export function getPRBadgeHoverClasses(status: PRStatusType): string {
  switch (status) {
    case "open":
      return "bg-green-500/20 text-green-400 hover:bg-green-500/30";
    case "merged":
      return "bg-purple-500/20 text-purple-400 hover:bg-purple-500/30";
    case "draft":
      return "bg-gray-500/20 text-gray-400 hover:bg-gray-500/30";
    case "closed":
      return "bg-red-500/20 text-red-400 hover:bg-red-500/30";
  }
}
