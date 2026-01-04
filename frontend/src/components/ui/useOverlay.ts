import { createEffect, onCleanup } from "solid-js";
import { useEscapeLayer } from "~/lib/useEscapeStack";

export function useOverlay(isOpen: () => boolean, onClose: () => void): void {
  useEscapeLayer(isOpen, onClose);

  createEffect(() => {
    if (!isOpen()) return;

    document.body.style.overflow = "hidden";

    onCleanup(() => {
      document.body.style.overflow = "";
    });
  });
}

export function createBackdropClickHandler(
  onClose: () => void,
): (e: MouseEvent) => void {
  return (e: MouseEvent) => {
    if (e.target === e.currentTarget) {
      onClose();
    }
  };
}
