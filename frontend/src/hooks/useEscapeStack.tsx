import {
  createContext,
  createEffect,
  type JSX,
  onCleanup,
  useContext,
} from "solid-js";

type EscapeHandler = () => void;

interface EscapeStackContextValue {
  push: (handler: EscapeHandler) => void;
  pop: (handler: EscapeHandler) => void;
}

const EscapeStackContext = createContext<EscapeStackContextValue>();

export function EscapeStackProvider(props: { children: JSX.Element }) {
  const handlers: EscapeHandler[] = [];

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key !== "Escape") return;
    if (handlers.length === 0) return;

    const target = e.target as Element | null;
    if (target) {
      const tag = target.tagName.toLowerCase();
      if (tag === "input" || tag === "textarea" || tag === "select") {
        (target as HTMLElement).blur();
        e.preventDefault();
        return;
      }
      if ((target as HTMLElement).isContentEditable) {
        (target as HTMLElement).blur();
        e.preventDefault();
        return;
      }
    }

    const topHandler = handlers[handlers.length - 1];
    topHandler();
    e.preventDefault();
  };

  document.addEventListener("keydown", handleKeyDown);
  onCleanup(() => {
    document.removeEventListener("keydown", handleKeyDown);
  });

  const push = (handler: EscapeHandler) => {
    handlers.push(handler);
  };

  const pop = (handler: EscapeHandler) => {
    const index = handlers.indexOf(handler);
    if (index !== -1) {
      handlers.splice(index, 1);
    }
  };

  return (
    <EscapeStackContext.Provider value={{ push, pop }}>
      {props.children}
    </EscapeStackContext.Provider>
  );
}

export function useEscapeLayer(
  isActive: () => boolean,
  onEscape: () => void,
): void {
  const context = useContext(EscapeStackContext);
  if (!context) return;

  createEffect(() => {
    if (!isActive()) return;

    context.push(onEscape);

    onCleanup(() => {
      context.pop(onEscape);
    });
  });
}
