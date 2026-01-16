import { createEffect, createSignal, onCleanup, Show } from "solid-js";
import { Portal } from "solid-js/web";
import { Button } from "~/components/design-system";
import type { Column } from "~/hooks/useKanban";
import { createLogger } from "~/lib/logger";
import {
  ConcurrencySettings,
  GeneralSettings,
  HooksSettings,
} from "./column-settings";
import { CloseIcon } from "./ui/Icons";

const log = createLogger("ColumnSettings");

type SettingsTab = "general" | "hooks" | "concurrency";

const POPUP_WIDTH = 320;
const POPUP_HEIGHT = 400;
const VIEWPORT_PADDING = 8;
const POPUP_ANCHOR_GAP = 8;

interface ColumnSettingsPopupProps {
  column: Column;
  boardId: string;
  anchor: HTMLElement | undefined;
  onClose: () => void;
}

export default function ColumnSettingsPopup(props: ColumnSettingsPopupProps) {
  const [activeTab, setActiveTab] = createSignal<SettingsTab>("general");

  const isInProgressColumn = () =>
    props.column.name.toLowerCase() === "in progress";

  let popupRef: HTMLDivElement | undefined;

  const [position, setPosition] = createSignal({ top: 0, left: 0 });

  createEffect(() => {
    if (props.anchor) {
      const rect = props.anchor.getBoundingClientRect();

      let left = rect.right - POPUP_WIDTH;
      let top = rect.bottom + POPUP_ANCHOR_GAP;

      if (left < VIEWPORT_PADDING) {
        left = VIEWPORT_PADDING;
      }
      if (left + POPUP_WIDTH > window.innerWidth - VIEWPORT_PADDING) {
        left = window.innerWidth - POPUP_WIDTH - VIEWPORT_PADDING;
      }
      if (top + POPUP_HEIGHT > window.innerHeight - VIEWPORT_PADDING) {
        top = rect.top - POPUP_HEIGHT - POPUP_ANCHOR_GAP;
      }

      setPosition({ top, left });
    }
  });

  createEffect(() => {
    const handleClickOutside = (e: PointerEvent) => {
      if (e.button !== 0) return;

      if (popupRef && !popupRef.contains(e.target as Node)) {
        log.debug("Closing due to click outside");
        props.onClose();
      }
    };

    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        props.onClose();
      }
    };

    setTimeout(() => {
      document.addEventListener("pointerdown", handleClickOutside);
      document.addEventListener("keydown", handleEscape);
    }, 0);

    onCleanup(() => {
      document.removeEventListener("pointerdown", handleClickOutside);
      document.removeEventListener("keydown", handleEscape);
    });
  });

  return (
    <Portal>
      <div class="fixed inset-0 z-40" />

      <div
        ref={popupRef}
        class="fixed z-50 w-80 bg-gray-800 border border-gray-700 rounded-lg shadow-xl"
        style={{
          top: `${position().top}px`,
          left: `${position().left}px`,
        }}
      >
        <div class="flex items-center justify-between px-4 py-3 border-b border-gray-700">
          <h3 class="font-semibold text-white">{props.column.name} Settings</h3>
          <Button onClick={props.onClose} variant="icon">
            <CloseIcon class="w-4 h-4" />
          </Button>
        </div>

        <div class="flex border-b border-gray-700">
          <Button
            onClick={() => setActiveTab("general")}
            variant="ghost"
            buttonSize="sm"
            fullWidth
          >
            <span
              class={
                activeTab() === "general"
                  ? "text-white border-b-2 border-brand-500 pb-1"
                  : "text-gray-400"
              }
            >
              General
            </span>
          </Button>
          <Button
            onClick={() => setActiveTab("hooks")}
            variant="ghost"
            buttonSize="sm"
            fullWidth
          >
            <span
              class={
                activeTab() === "hooks"
                  ? "text-white border-b-2 border-brand-500 pb-1"
                  : "text-gray-400"
              }
            >
              Hooks
            </span>
          </Button>
          <Show when={isInProgressColumn()}>
            <Button
              onClick={() => setActiveTab("concurrency")}
              variant="ghost"
              buttonSize="sm"
              fullWidth
            >
              <span
                class={
                  activeTab() === "concurrency"
                    ? "text-white border-b-2 border-brand-500 pb-1"
                    : "text-gray-400"
                }
              >
                Limits
              </span>
            </Button>
          </Show>
        </div>

        <div class="p-4 max-h-80 overflow-y-auto">
          <Show when={activeTab() === "general"}>
            <GeneralSettings column={props.column} onClose={props.onClose} />
          </Show>

          <Show when={activeTab() === "hooks"}>
            <HooksSettings column={props.column} boardId={props.boardId} />
          </Show>

          <Show when={activeTab() === "concurrency"}>
            <ConcurrencySettings column={props.column} />
          </Show>
        </div>
      </div>
    </Portal>
  );
}
