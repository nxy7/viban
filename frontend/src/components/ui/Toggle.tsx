/**
 * Toggle - A switch/toggle component for boolean settings.
 *
 * Features:
 * - Two size variants (sm, md)
 * - Disabled state support
 * - Accessible with proper ARIA attributes
 */

import type { JSX } from "solid-js";

/** Props for the Toggle component */
interface ToggleProps {
  /** Current toggle state */
  checked: boolean;
  /** Callback when toggle state changes */
  onChange: (checked: boolean) => void;
  /** Whether the toggle is disabled */
  disabled?: boolean;
  /** Size variant (default: "md") */
  size?: "sm" | "md";
}

/**
 * Toggle switch component for boolean settings.
 */
export default function Toggle(props: ToggleProps): JSX.Element {
  const size = () => props.size ?? "md";

  const dimensions = () => {
    if (size() === "sm") {
      return {
        track: "h-5 w-9",
        thumb: "h-3 w-3",
        translateOn: "translate-x-5",
        translateOff: "translate-x-1",
      };
    }
    return {
      track: "h-6 w-11",
      thumb: "h-4 w-4",
      translateOn: "translate-x-6",
      translateOff: "translate-x-1",
    };
  };

  return (
    <button
      type="button"
      role="switch"
      aria-checked={props.checked}
      on:click={(e) => {
        e.stopPropagation();
        if (!props.disabled) {
          props.onChange(!props.checked);
        }
      }}
      on:pointerdown={(e) => {
        e.stopPropagation();
      }}
      disabled={props.disabled}
      class={`relative inline-flex items-center rounded-full transition-colors ${dimensions().track} ${
        props.checked ? "bg-brand-600" : "bg-gray-600"
      } ${props.disabled ? "opacity-50 cursor-not-allowed" : "cursor-pointer"}`}
    >
      <span
        class={`inline-block transform rounded-full bg-white transition-transform ${dimensions().thumb} ${
          props.checked ? dimensions().translateOn : dimensions().translateOff
        }`}
      />
    </button>
  );
}
