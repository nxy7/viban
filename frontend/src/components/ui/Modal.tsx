/**
 * Modal - A centered overlay dialog component.
 *
 * Features:
 * - ESC key to close
 * - Click outside to close
 * - Body scroll lock when open
 * - Fade-in animation
 */

import { type JSX, Show } from "solid-js";
import { Portal } from "solid-js/web";
import { CloseIcon } from "./Icons";
import { createBackdropClickHandler, useOverlay } from "./useOverlay";

/** Props for the Modal component */
interface ModalProps {
  /** Whether the modal is visible */
  isOpen: boolean;
  /** Callback when modal is closed */
  onClose: () => void;
  /** Optional title shown in the header */
  title?: string;
  /** Modal content */
  children: JSX.Element;
}

/**
 * Centered modal dialog with backdrop.
 */
export default function Modal(props: ModalProps) {
  // Use shared overlay behavior (ESC key, body scroll lock)
  useOverlay(
    () => props.isOpen,
    () => props.onClose(),
  );

  const handleBackdropClick = createBackdropClickHandler(() => props.onClose());

  return (
    <Show when={props.isOpen}>
      <Portal>
        <div
          class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm"
          onClick={handleBackdropClick}
        >
          <div
            class="bg-gray-900 border border-gray-800 rounded-md shadow-2xl w-full max-w-md mx-4 animate-in fade-in zoom-in-95 duration-200"
            role="dialog"
            aria-modal="true"
            aria-labelledby={props.title ? "modal-title" : undefined}
          >
            <Show when={props.title}>
              <div class="flex items-center justify-between px-6 py-4 border-b border-gray-800">
                <h2 id="modal-title" class="text-lg font-semibold text-white">
                  {props.title}
                </h2>
                <button
                  onClick={props.onClose}
                  class="p-1 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
                  aria-label="Close modal"
                >
                  <CloseIcon class="w-5 h-5" />
                </button>
              </div>
            </Show>
            <div class="p-6">{props.children}</div>
          </div>
        </div>
      </Portal>
    </Show>
  );
}
