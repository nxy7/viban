import { For, Show } from "solid-js";
import { formatKeys, useShortcutRegistry } from "~/hooks/useKeyboardShortcuts";
import Modal from "./ui/Modal";

interface KeyboardShortcutsHelpProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function KeyboardShortcutsHelp(
  props: KeyboardShortcutsHelpProps,
) {
  const shortcuts = useShortcutRegistry();

  return (
    <Modal
      isOpen={props.isOpen}
      onClose={props.onClose}
      title="Keyboard Shortcuts"
    >
      <Show
        when={shortcuts().length > 0}
        fallback={<p class="text-gray-500 text-sm">No shortcuts available</p>}
      >
        <div class="space-y-2">
          <For each={shortcuts()}>
            {(shortcut) => (
              <div class="flex items-center justify-between py-2 border-b border-gray-800 last:border-0">
                <span class="text-gray-300">{shortcut.description}</span>
                <kbd class="px-2 py-1 text-sm font-mono bg-gray-800 border border-gray-700 rounded text-gray-200">
                  {formatKeys(shortcut.keys)}
                </kbd>
              </div>
            )}
          </For>
        </div>
      </Show>
    </Modal>
  );
}
