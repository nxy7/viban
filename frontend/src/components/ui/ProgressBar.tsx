/**
 * ProgressBar - A horizontal progress indicator component.
 *
 * Features:
 * - Two size variants (sm, md)
 * - Optional gradient styling
 * - Smooth transition animations
 * - Clamped percentage (0-100)
 */

import type { JSX } from "solid-js";

/** Props for the ProgressBar component */
interface ProgressBarProps {
  /** Progress percentage (0-100, clamped) */
  percentage: number;
  /** Size variant (default: "md") */
  size?: "sm" | "md";
  /** Whether to use gradient styling (default: false) */
  gradient?: boolean;
}

/**
 * Horizontal progress bar with optional gradient.
 */
export default function ProgressBar(props: ProgressBarProps): JSX.Element {
  const size = () => props.size ?? "md";
  const useGradient = () => props.gradient ?? false;

  const heightClass = () => (size() === "sm" ? "h-1" : "h-1.5");

  const fillClass = () =>
    useGradient()
      ? "bg-gradient-to-r from-brand-500 to-blue-500"
      : "bg-blue-500";

  return (
    <div class={`${heightClass()} bg-gray-700 rounded-full overflow-hidden`}>
      <div
        class={`h-full ${fillClass()} transition-all duration-300 ease-out`}
        style={{ width: `${Math.min(100, Math.max(0, props.percentage))}%` }}
      />
    </div>
  );
}
