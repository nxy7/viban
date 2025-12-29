import { createEffect, onCleanup } from "solid-js";

/**
 * Hook for shared overlay behavior (modals, panels, dialogs).
 * Handles:
 * - ESC key to close
 * - Body scroll lock when open
 * - Cleanup on unmount
 */
export function useOverlay(isOpen: () => boolean, onClose: () => void): void {
  createEffect(() => {
    if (!isOpen()) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        onClose();
      }
    };

    document.addEventListener("keydown", handleKeyDown);
    document.body.style.overflow = "hidden";

    onCleanup(() => {
      document.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = "";
    });
  });
}

/**
 * Creates a backdrop click handler that only triggers
 * when clicking directly on the backdrop (not its children).
 */
export function createBackdropClickHandler(
  onClose: () => void,
): (e: MouseEvent) => void {
  return (e: MouseEvent) => {
    if (e.target === e.currentTarget) {
      onClose();
    }
  };
}
