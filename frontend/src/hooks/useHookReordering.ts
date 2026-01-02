import type { DragEvent } from "@thisbeyond/solid-dnd";
import * as sdk from "~/lib/generated/ash";
import { type ColumnHook, unwrap } from "~/lib/useKanban";

export function useHookReordering(getSortedHooks: () => ColumnHook[]) {
  const handleDragEnd = async ({ draggable, droppable }: DragEvent) => {
    if (!droppable) return;

    const draggedId = String(draggable.id);
    const droppedId = String(droppable.id);

    if (draggedId === droppedId) return;

    const hooks = getSortedHooks();
    const draggedIndex = hooks.findIndex((h) => h.id === draggedId);
    const droppedIndex = hooks.findIndex((h) => h.id === droppedId);

    if (draggedIndex === -1 || droppedIndex === -1) return;

    const reorderedHooks = [...hooks];
    const [removed] = reorderedHooks.splice(draggedIndex, 1);
    reorderedHooks.splice(droppedIndex, 0, removed);

    await Promise.all(
      reorderedHooks.map((hook, index) => {
        if (hook.position !== index) {
          return sdk
            .update_column_hook({
              identity: hook.id,
              input: { position: index },
            })
            .then(unwrap);
        }
        return Promise.resolve();
      }),
    );
  };

  return { handleDragEnd };
}
