import {
  type Accessor,
  createContext,
  createEffect,
  createSignal,
  type JSX,
  on,
  onCleanup,
  onMount,
  useContext,
} from "solid-js";

export interface ShortcutDefinition {
  keys: string[];
  description: string;
}

interface ShortcutContextValue {
  shortcuts: Accessor<ShortcutDefinition[]>;
  register: (shortcut: ShortcutDefinition) => () => void;
}

const ShortcutContext = createContext<ShortcutContextValue>();

export function ShortcutProvider(props: { children: JSX.Element }) {
  const [shortcuts, setShortcuts] = createSignal<ShortcutDefinition[]>([]);

  const register = (shortcut: ShortcutDefinition): (() => void) => {
    setShortcuts((prev) => [...prev, shortcut]);
    return () => {
      setShortcuts((prev) =>
        prev.filter(
          (s) =>
            s.keys.join("+") !== shortcut.keys.join("+") ||
            s.description !== shortcut.description,
        ),
      );
    };
  };

  return (
    <ShortcutContext.Provider value={{ shortcuts, register }}>
      {props.children}
    </ShortcutContext.Provider>
  );
}

export function useShortcutRegistry(): Accessor<ShortcutDefinition[]> {
  const context = useContext(ShortcutContext);
  if (!context) {
    return () => [];
  }
  return context.shortcuts;
}

function isEditableElement(event: KeyboardEvent): boolean {
  const target = event.target as Element | null;
  if (!target) return false;
  const tag = target.tagName.toLowerCase();
  if (tag === "input" || tag === "textarea" || tag === "select") return true;
  if ((target as HTMLElement).isContentEditable) return true;
  return false;
}

function formatKeys(keys: string[]): string {
  return keys
    .map((k) => {
      if (k === "Shift") return "Shift +";
      if (k === "Control") return "Ctrl +";
      if (k === "Meta") return "Cmd +";
      if (k === "Alt") return "Alt +";
      return k;
    })
    .join(" ");
}

function normalizeKey(key: string): string {
  return key.toLowerCase();
}

function matchesShortcut(e: KeyboardEvent, keys: string[]): boolean {
  const pressedKeys = new Set<string>();

  if (e.shiftKey) pressedKeys.add("shift");
  if (e.ctrlKey) pressedKeys.add("control");
  if (e.metaKey) pressedKeys.add("meta");
  if (e.altKey) pressedKeys.add("alt");

  const mainKey = normalizeKey(e.key);
  if (!["shift", "control", "meta", "alt"].includes(mainKey)) {
    pressedKeys.add(mainKey);
  }

  const expectedKeys = new Set(keys.map(normalizeKey));

  if (pressedKeys.size !== expectedKeys.size) return false;
  for (const key of pressedKeys) {
    if (!expectedKeys.has(key)) return false;
  }
  return true;
}

export function useShortcut(
  keys: string[],
  callback: () => void,
  options?: {
    allowInInput?: boolean;
    description?: string;
    enabled?: Accessor<boolean>;
  },
): void {
  const context = useContext(ShortcutContext);
  const isEnabled = options?.enabled ?? (() => true);

  if (context && options?.description) {
    let unregister: (() => void) | null = null;

    createEffect(
      on(isEnabled, (enabled) => {
        if (enabled && !unregister) {
          unregister = context.register({
            keys,
            description: options.description!,
          });
        } else if (!enabled && unregister) {
          unregister();
          unregister = null;
        }
      }),
    );

    onCleanup(() => {
      if (unregister) unregister();
    });
  }

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.repeat) return;
    if (!isEnabled()) return;
    if (!options?.allowInInput && isEditableElement(e)) return;

    if (matchesShortcut(e, keys)) {
      e.preventDefault();
      callback();
    }
  };

  onMount(() => {
    document.addEventListener("keydown", handleKeyDown);
  });

  onCleanup(() => {
    document.removeEventListener("keydown", handleKeyDown);
  });
}

export { formatKeys };
