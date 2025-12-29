import type { JSX } from "solid-js";
import { Show } from "solid-js";

interface ErrorBannerProps {
  message: string | null;
  /** Size variant for the banner */
  size?: "sm" | "md";
}

/**
 * Error banner component - extracted from multiple components
 * where duplicated error display patterns were found.
 *
 * Usage:
 *   <ErrorBanner message={error()} />
 */
export default function ErrorBanner(props: ErrorBannerProps): JSX.Element {
  const size = () => props.size ?? "md";

  const sizeClasses = () => {
    if (size() === "sm") {
      return "p-2 text-xs";
    }
    return "p-3 text-sm";
  };

  return (
    <Show when={props.message}>
      <div
        class={`bg-red-500/10 border border-red-500/30 rounded-lg text-red-400 ${sizeClasses()}`}
        role="alert"
      >
        {props.message}
      </div>
    </Show>
  );
}

interface InfoBannerProps {
  children: JSX.Element;
}

/**
 * Info banner component - for informational messages
 */
export function InfoBanner(props: InfoBannerProps): JSX.Element {
  return (
    <div class="bg-blue-500/10 border border-blue-500/20 rounded-lg p-3">
      <p class="text-xs text-blue-300">{props.children}</p>
    </div>
  );
}
