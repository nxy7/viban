/**
 * SidePanel - A slide-in panel from the right side of the screen.
 *
 * Features:
 * - ESC key to close
 * - Click outside to close
 * - Body scroll lock when open
 * - Slide-in animation
 * - Configurable width
 */

import { type JSX, Show } from "solid-js";
import { Portal } from "solid-js/web";
import { CloseIcon } from "./Icons";
import { createBackdropClickHandler, useOverlay } from "./useOverlay";

/** Available panel width options */
type PanelWidth = "sm" | "md" | "lg" | "xl" | "2xl" | "full";

/** Props for the SidePanel component */
interface SidePanelProps {
  /** Whether the panel is visible */
  isOpen: boolean;
  /** Callback when panel is closed */
  onClose: () => void;
  /** Optional title shown in the header */
  title?: string;
  /** Optional subtitle/badge shown next to close button */
  subtitle?: string;
  /** Panel content */
  children: JSX.Element;
  /** Panel width (default: "md") */
  width?: PanelWidth;
}

/** Tailwind classes for each width option */
const WIDTH_CLASSES: Record<PanelWidth, string> = {
  sm: "max-w-sm",
  md: "max-w-md",
  lg: "max-w-lg",
  xl: "max-w-xl",
  "2xl": "max-w-2xl",
  full: "max-w-full",
};

/**
 * Slide-in panel from the right side.
 */
export default function SidePanel(props: SidePanelProps) {
  // Use shared overlay behavior (ESC key, body scroll lock)
  useOverlay(
    () => props.isOpen,
    () => props.onClose(),
  );

  const handleBackdropClick = createBackdropClickHandler(() => props.onClose());

  const widthClass = () => WIDTH_CLASSES[props.width ?? "md"];

  return (
    <Show when={props.isOpen}>
      <Portal>
        <div
          class="fixed inset-0 z-50 flex justify-end bg-black/50 backdrop-blur-sm"
          onClick={handleBackdropClick}
        >
          <div
            class={`bg-gray-900 border-l border-gray-800 w-full ${widthClass()} h-full shadow-2xl animate-in slide-in-from-right duration-200 flex flex-col`}
            role="dialog"
            aria-modal="true"
            aria-labelledby={props.title ? "panel-title" : undefined}
          >
            <div class="flex-shrink-0 bg-gray-900 border-b border-gray-800 px-6 py-4 flex items-center justify-between">
              <div class="flex items-center gap-3">
                <Show when={props.subtitle}>
                  <span class="px-2 py-0.5 text-xs font-medium rounded bg-gray-700 text-gray-300">
                    {props.subtitle}
                  </span>
                </Show>
                <Show when={props.title}>
                  <h2 id="panel-title" class="text-lg font-semibold text-white">
                    {props.title}
                  </h2>
                </Show>
              </div>
              <button
                onClick={props.onClose}
                class="p-1 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
                aria-label="Close panel"
              >
                <CloseIcon class="w-5 h-5" />
              </button>
            </div>
            <div class="flex-1 min-h-0 flex flex-col overflow-y-auto px-6 py-4">
              {props.children}
            </div>
          </div>
        </div>
      </Portal>
    </Show>
  );
}
