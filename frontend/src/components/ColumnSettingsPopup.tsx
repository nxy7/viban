import {
  closestCenter,
  createSortable,
  DragDropProvider,
  DragDropSensors,
  type DragEvent,
  DragOverlay,
  SortableProvider,
} from "@thisbeyond/solid-dnd";
import {
  createEffect,
  createMemo,
  createResource,
  createSignal,
  For,
  onCleanup,
  Show,
} from "solid-js";
import { Portal } from "solid-js/web";
import {
  type Column,
  type ColumnHook,
  type CombinedHook,
  createColumnHook,
  deleteColumnHook,
  fetchAllHooks,
  updateColumn,
  updateColumnHook,
  updateColumnSettings,
  useColumnHooks,
} from "~/lib/useKanban";
import { getDefaultSound, type SoundType } from "~/lib/sounds";
import HookSoundSettings from "./HookSoundSettings";
import ErrorBanner, { InfoBanner } from "./ui/ErrorBanner";
import {
  CloseIcon,
  DragHandleIcon,
  InfoIcon,
  SpeakerIcon,
  TerminalIcon,
} from "./ui/Icons";
import Toggle from "./ui/Toggle";

/** Tab types for the settings popup */
type SettingsTab = "general" | "hooks" | "concurrency";

/** Popup layout constants */
const POPUP_WIDTH = 320;
const POPUP_HEIGHT = 400;
const VIEWPORT_PADDING = 8;
const POPUP_ANCHOR_GAP = 8;

/** Success feedback duration in milliseconds */
const SUCCESS_FEEDBACK_DURATION_MS = 2000;

/** Column names that cannot be renamed (system columns) */
const SYSTEM_COLUMNS = [
  "TODO",
  "In Progress",
  "To Review",
  "Done",
  "Cancelled",
] as const;

/** Available column colors for customization */
const COLUMN_COLORS = [
  "#6366f1", // Indigo
  "#8b5cf6", // Purple
  "#ec4899", // Pink
  "#ef4444", // Red
  "#f97316", // Orange
  "#eab308", // Yellow
  "#22c55e", // Green
  "#06b6d4", // Cyan
  "#3b82f6", // Blue
  "#64748b", // Slate
] as const;

interface ColumnSettingsPopupProps {
  column: Column;
  boardId: string;
  anchor: HTMLElement | undefined;
  onClose: () => void;
}

export default function ColumnSettingsPopup(props: ColumnSettingsPopupProps) {
  const [activeTab, setActiveTab] = createSignal<SettingsTab>("general");

  // Check if this is the "In Progress" column (only column with concurrency settings)
  const isInProgressColumn = () =>
    props.column.name.toLowerCase() === "in progress";

  let popupRef: HTMLDivElement | undefined;

  // Position the popup
  const [position, setPosition] = createSignal({ top: 0, left: 0 });

  createEffect(() => {
    if (props.anchor) {
      const rect = props.anchor.getBoundingClientRect();

      // Position below the anchor, aligned to the right
      let left = rect.right - POPUP_WIDTH;
      let top = rect.bottom + POPUP_ANCHOR_GAP;

      // Keep within viewport bounds
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

  // Handle click outside - use pointerdown with capture to ensure we see all clicks
  createEffect(() => {
    const handleClickOutside = (e: PointerEvent) => {
      // Only handle primary button (left click)
      if (e.button !== 0) return;

      // Check if click is outside popup
      if (popupRef && !popupRef.contains(e.target as Node)) {
        console.log("[ColumnSettingsPopup] Closing due to click outside", e.target);
        props.onClose();
      }
    };

    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        props.onClose();
      }
    };

    // Delay adding listeners to avoid immediate close from the click that opened it
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
      {/* Semi-transparent backdrop */}
      <div class="fixed inset-0 z-40" />

      {/* Popup */}
      <div
        ref={popupRef}
        class="fixed z-50 w-80 bg-gray-800 border border-gray-700 rounded-lg shadow-xl"
        style={{
          top: `${position().top}px`,
          left: `${position().left}px`,
        }}
      >
        {/* Header */}
        <div class="flex items-center justify-between px-4 py-3 border-b border-gray-700">
          <h3 class="font-semibold text-white">{props.column.name} Settings</h3>
          <button
            onClick={props.onClose}
            class="text-gray-400 hover:text-white p-1 hover:bg-gray-700 rounded transition-colors"
          >
            <CloseIcon class="w-4 h-4" />
          </button>
        </div>

        {/* Tabs */}
        <div class="flex border-b border-gray-700">
          <button
            onClick={() => setActiveTab("general")}
            class={`flex-1 px-4 py-2 text-sm font-medium transition-colors ${
              activeTab() === "general"
                ? "text-white border-b-2 border-brand-500"
                : "text-gray-400 hover:text-white"
            }`}
          >
            General
          </button>
          <button
            onClick={() => setActiveTab("hooks")}
            class={`flex-1 px-4 py-2 text-sm font-medium transition-colors ${
              activeTab() === "hooks"
                ? "text-white border-b-2 border-brand-500"
                : "text-gray-400 hover:text-white"
            }`}
          >
            Hooks
          </button>
          <Show when={isInProgressColumn()}>
            <button
              onClick={() => setActiveTab("concurrency")}
              class={`flex-1 px-4 py-2 text-sm font-medium transition-colors ${
                activeTab() === "concurrency"
                  ? "text-white border-b-2 border-brand-500"
                  : "text-gray-400 hover:text-white"
              }`}
            >
              Limits
            </button>
          </Show>
        </div>

        {/* Content */}
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

// General Settings Tab
interface GeneralSettingsProps {
  column: Column;
  onClose: () => void;
}

function GeneralSettings(props: GeneralSettingsProps) {
  const [name, setName] = createSignal(props.column.name);
  const [color, setColor] = createSignal(props.column.color);
  const [description, setDescription] = createSignal(
    props.column.settings?.description || "",
  );
  const [isSaving, setIsSaving] = createSignal(false);
  const [error, setError] = createSignal<string | null>(null);

  const isSystemColumn = (SYSTEM_COLUMNS as readonly string[]).includes(
    props.column.name,
  );

  const handleSave = async () => {
    setIsSaving(true);
    setError(null);

    try {
      await updateColumn(props.column.id, {
        name: isSystemColumn ? undefined : name(),
        color: color(),
        settings: {
          ...props.column.settings,
          description: description() || null,
        },
      });
      props.onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to save");
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div class="space-y-4">
      <ErrorBanner message={error()} size="sm" />

      {/* Name */}
      <div>
        <label class="block text-sm font-medium text-gray-300 mb-1">Name</label>
        <input
          type="text"
          value={name()}
          onInput={(e) => setName(e.currentTarget.value)}
          disabled={isSystemColumn}
          class="w-full px-3 py-2 bg-gray-900 border border-gray-700 rounded-md text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 disabled:opacity-50 disabled:cursor-not-allowed"
        />
        <Show when={isSystemColumn}>
          <p class="text-xs text-gray-500 mt-1">
            System columns cannot be renamed
          </p>
        </Show>
      </div>

      {/* Color */}
      <div>
        <label class="block text-sm font-medium text-gray-300 mb-2">
          Color
        </label>
        <div class="flex flex-wrap gap-2">
          <For each={COLUMN_COLORS}>
            {(c) => (
              <button
                onClick={() => setColor(c)}
                class={`w-6 h-6 rounded-full transition-transform ${
                  color() === c
                    ? "ring-2 ring-white ring-offset-2 ring-offset-gray-800 scale-110"
                    : "hover:scale-110"
                }`}
                style={{ "background-color": c }}
              />
            )}
          </For>
        </div>
      </div>

      {/* Description */}
      <div>
        <label class="block text-sm font-medium text-gray-300 mb-1">
          Description (optional)
        </label>
        <textarea
          value={description()}
          onInput={(e) => setDescription(e.currentTarget.value)}
          placeholder="What should tasks in this column be doing?"
          rows={2}
          class="w-full px-3 py-2 bg-gray-900 border border-gray-700 rounded-md text-white text-sm resize-none focus:outline-none focus:ring-2 focus:ring-brand-500"
        />
      </div>

      {/* Save button */}
      <button
        onClick={handleSave}
        disabled={isSaving()}
        class="w-full py-2 text-sm bg-brand-600 hover:bg-brand-700 disabled:opacity-50 rounded-md font-medium text-white transition-colors"
      >
        {isSaving() ? "Saving..." : "Save Changes"}
      </button>
    </div>
  );
}

// Hooks Settings Tab
interface HooksSettingsProps {
  column: Column;
  boardId: string;
}

function HooksSettings(props: HooksSettingsProps) {
  // Use fetchAllHooks to get both system hooks and custom hooks
  const [allHooks, { refetch }] = createResource(
    () => props.boardId,
    fetchAllHooks,
  );
  const { columnHooks, isLoading: isColumnHooksLoading } = useColumnHooks(
    () => props.column.id,
  );

  // Wait for both hooks and column hooks to load
  const isLoading = () => allHooks.loading || isColumnHooksLoading();
  const [hooksEnabled, setHooksEnabled] = createSignal(
    props.column.settings?.hooks_enabled !== false,
  );
  const [isSaving, setIsSaving] = createSignal(false);

  // Get on_entry hooks (the only type we support now)
  const onEntryHooks = createMemo(() =>
    columnHooks().filter((h) => h.hook_type === "on_entry"),
  );

  const handleToggleHooks = async (enabled: boolean) => {
    setHooksEnabled(enabled);
    setIsSaving(true);
    try {
      await updateColumnSettings(props.column.id, { hooks_enabled: enabled });
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div class="space-y-4">
      {/* Hooks enabled toggle */}
      <div class="flex items-center justify-between">
        <span class="text-sm text-gray-300">Hooks enabled</span>
        <Toggle
          checked={hooksEnabled()}
          onChange={handleToggleHooks}
          disabled={isSaving()}
        />
      </div>

      <Show when={isLoading()}>
        <div class="text-gray-500 text-xs text-center py-4">
          Loading hooks...
        </div>
      </Show>

      <Show when={!isLoading()}>
        {/* On Entry Hooks */}
        <HookSection
          title="On Entry"
          description="Run when task enters this column"
          hooks={onEntryHooks()}
          columnId={props.column.id}
          availableHooks={allHooks() ?? []}
        />
      </Show>
    </div>
  );
}

// Hook Section Component
interface HookSectionProps {
  title: string;
  description: string;
  hooks: ColumnHook[];
  columnId: string;
  availableHooks: CombinedHook[];
}

// Concurrency Settings Tab
interface ConcurrencySettingsProps {
  column: Column;
}

function ConcurrencySettings(props: ConcurrencySettingsProps) {
  const [enabled, setEnabled] = createSignal(
    props.column.settings?.max_concurrent_tasks != null,
  );
  const [limit, setLimit] = createSignal(
    props.column.settings?.max_concurrent_tasks || 3,
  );
  const [isSaving, setIsSaving] = createSignal(false);
  const [saveSuccess, setSaveSuccess] = createSignal(false);

  const handleToggle = async (newEnabled: boolean) => {
    setEnabled(newEnabled);
    if (!newEnabled) {
      // Immediately save when disabling
      setIsSaving(true);
      try {
        await updateColumnSettings(props.column.id, {
          max_concurrent_tasks: null,
        });
        setSaveSuccess(true);
        setTimeout(() => setSaveSuccess(false), SUCCESS_FEEDBACK_DURATION_MS);
      } finally {
        setIsSaving(false);
      }
    }
  };

  const handleSave = async () => {
    setIsSaving(true);
    try {
      await updateColumnSettings(props.column.id, {
        max_concurrent_tasks: enabled() ? limit() : null,
      });
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), SUCCESS_FEEDBACK_DURATION_MS);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div class="space-y-4">
      {/* Enable/Disable Toggle */}
      <div class="flex items-center justify-between">
        <div>
          <h4 class="text-sm font-medium text-gray-200">
            Limit Concurrent Tasks
          </h4>
          <p class="text-xs text-gray-500 mt-0.5">
            Control how many tasks can run at once
          </p>
        </div>
        <Toggle
          checked={enabled()}
          onChange={handleToggle}
          disabled={isSaving()}
        />
      </div>

      {/* Limit Configuration */}
      <Show when={enabled()}>
        <div class="space-y-4 pl-3 border-l-2 border-brand-500/30">
          <div>
            <label class="block text-sm font-medium text-gray-300 mb-2">
              Maximum Concurrent Tasks
            </label>
            <div class="flex items-center gap-3">
              <input
                type="number"
                min={1}
                max={100}
                value={limit()}
                onInput={(e) => {
                  const val = parseInt(e.currentTarget.value, 10);
                  if (!Number.isNaN(val) && val >= 1) setLimit(val);
                }}
                class="w-20 px-3 py-2 bg-gray-900 border border-gray-700 rounded-md text-white text-sm text-center focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
              <span class="text-sm text-gray-400">tasks at once</span>
            </div>
          </div>

          {/* Save button */}
          <button
            onClick={handleSave}
            disabled={isSaving()}
            class={`w-full py-2 text-sm rounded-md font-medium transition-colors ${
              saveSuccess()
                ? "bg-green-600 text-white"
                : "bg-brand-600 hover:bg-brand-700 disabled:opacity-50 text-white"
            }`}
          >
            {isSaving() ? "Saving..." : saveSuccess() ? "Saved!" : "Save Limit"}
          </button>
        </div>
      </Show>

      {/* Info box */}
      <InfoBanner>
        <InfoIcon class="w-4 h-4 inline mr-1" />
        When the limit is reached, new tasks will queue and start automatically
        when a slot becomes available.
      </InfoBanner>
    </div>
  );
}

function HookSection(props: HookSectionProps) {
  const [showPicker, setShowPicker] = createSignal(false);
  const [isAdding, setIsAdding] = createSignal(false);

  // Get hooks that are not already assigned to this column for this type
  const unassignedHooks = createMemo(() => {
    const assignedIds = new Set(props.hooks.map((h) => h.hook_id));
    return props.availableHooks.filter((h) => !assignedIds.has(h.id));
  });

  // Sort hooks by position
  const sortedHooks = createMemo(() =>
    [...props.hooks].sort((a, b) => Number(a.position) - Number(b.position)),
  );

  // IDs for sortable provider
  const hookIds = createMemo(() => sortedHooks().map((h) => h.id));

  const getHookDetails = (hookId: string): CombinedHook | undefined => {
    return props.availableHooks.find((h) => h.id === hookId);
  };

  const handleAddHook = async (hookId: string) => {
    setIsAdding(true);
    try {
      await createColumnHook({
        column_id: props.columnId,
        hook_id: hookId,
        position: props.hooks.length,
      });
      setShowPicker(false);
    } catch (err) {
      console.error("Failed to add hook:", err);
    } finally {
      setIsAdding(false);
    }
  };

  const handleRemoveHook = async (columnHookId: string) => {
    try {
      await deleteColumnHook(columnHookId);
    } catch (err) {
      console.error("Failed to remove hook:", err);
    }
  };

  // Handle drag end for reordering
  const handleDragEnd = async ({ draggable, droppable }: DragEvent) => {
    if (!droppable) return;

    const draggedId = String(draggable.id);
    const droppedId = String(droppable.id);

    if (draggedId === droppedId) return;

    const hooks = sortedHooks();
    const draggedIndex = hooks.findIndex((h) => h.id === draggedId);
    const droppedIndex = hooks.findIndex((h) => h.id === droppedId);

    if (draggedIndex === -1 || droppedIndex === -1) return;

    // Calculate new positions
    const reorderedHooks = [...hooks];
    const [removed] = reorderedHooks.splice(draggedIndex, 1);
    reorderedHooks.splice(droppedIndex, 0, removed);

    // Update positions for all affected hooks
    try {
      await Promise.all(
        reorderedHooks.map((hook, index) => {
          if (hook.position !== index) {
            return updateColumnHook(hook.id, { position: index });
          }
          return Promise.resolve();
        }),
      );
    } catch (err) {
      console.error("Failed to reorder hooks:", err);
    }
  };

  return (
    <div class="space-y-2">
      <div class="flex items-center justify-between">
        <div>
          <h4 class="text-sm font-medium text-gray-200">{props.title}</h4>
          <p class="text-xs text-gray-500">{props.description}</p>
        </div>
        <Show
          when={unassignedHooks().length > 0}
          fallback={
            <Show
              when={props.hooks.length > 0 && props.availableHooks.length > 0}
            >
              <span class="text-xs text-gray-500 italic">
                All hooks assigned
              </span>
            </Show>
          }
        >
          <button
            onClick={() => setShowPicker(!showPicker())}
            class="text-xs text-brand-400 hover:text-brand-300"
          >
            + Add
          </button>
        </Show>
      </div>

      {/* Hook picker dropdown */}
      <Show when={showPicker()}>
        <div class="bg-gray-900 border border-gray-700 rounded-md p-2 space-y-1">
          <For each={unassignedHooks()}>
            {(hook) => (
              <button
                onClick={() => handleAddHook(hook.id)}
                disabled={isAdding()}
                class="w-full text-left p-2 text-sm text-gray-300 hover:bg-gray-800 rounded transition-colors disabled:opacity-50 flex items-center gap-2"
              >
                <span class="truncate">{hook.name}</span>
                <Show when={hook.is_system}>
                  <span class="text-xs px-1.5 py-0.5 bg-purple-500/20 text-purple-400 rounded flex-shrink-0">
                    System
                  </span>
                </Show>
              </button>
            )}
          </For>
        </div>
      </Show>

      {/* Assigned hooks with drag-and-drop */}
      <div class="space-y-1">
        <Show
          when={props.hooks.length > 0}
          fallback={
            <p class="text-xs text-gray-600 italic py-1">No hooks assigned</p>
          }
        >
          <DragDropProvider
            onDragEnd={handleDragEnd}
            collisionDetector={closestCenter}
          >
            <DragDropSensors />
            <SortableProvider ids={hookIds()}>
              <div class="space-y-1">
                <For each={sortedHooks()}>
                  {(columnHook) => (
                    <SortableHookItem
                      columnHook={columnHook}
                      hookDetails={getHookDetails(columnHook.hook_id)}
                      onRemove={handleRemoveHook}
                      onToggleExecuteOnce={async () => {
                        try {
                          await updateColumnHook(columnHook.id, {
                            execute_once: !columnHook.execute_once,
                          });
                        } catch (err) {
                          console.error("Failed to toggle execute_once:", err);
                        }
                      }}
                      onToggleTransparent={async () => {
                        try {
                          await updateColumnHook(columnHook.id, {
                            transparent: !columnHook.transparent,
                          });
                        } catch (err) {
                          console.error("Failed to toggle transparent:", err);
                        }
                      }}
                    />
                  )}
                </For>
              </div>
            </SortableProvider>
            <DragOverlay>
              {(draggable) => {
                if (!draggable) return null;
                const hook = sortedHooks().find(
                  (h) => h.id === String(draggable.id),
                );
                if (!hook) return null;
                const details = getHookDetails(hook.hook_id);
                return (
                  <div class="flex items-center gap-2 p-2 bg-gray-800 border border-brand-500 rounded-md shadow-lg">
                    <DragHandleIcon class="w-3.5 h-3.5 text-gray-400" />
                    <span class="text-sm text-white">
                      {details?.name || hook.hook_id}
                    </span>
                  </div>
                );
              }}
            </DragOverlay>
          </DragDropProvider>
        </Show>
      </div>
    </div>
  );
}

// Sortable hook item component
interface SortableHookItemProps {
  columnHook: ColumnHook;
  hookDetails: CombinedHook | undefined;
  onRemove: (id: string) => void;
  onToggleExecuteOnce: () => void;
  onToggleTransparent: () => void;
}

// Check if hook is the play-sound hook
const isPlaySoundHook = (hookId: string) => hookId === "system:play-sound";

function SortableHookItem(props: SortableHookItemProps) {
  const sortable = createSortable(props.columnHook.id);

  // Get current sound setting, defaulting to "ding"
  const currentSound = () =>
    (props.columnHook.hook_settings?.sound as SoundType) || getDefaultSound();

  // Handle sound setting change
  const handleSoundChange = async (sound: SoundType) => {
    try {
      await updateColumnHook(props.columnHook.id, {
        hook_settings: { ...props.columnHook.hook_settings, sound },
      });
    } catch (err) {
      console.error("Failed to update hook settings:", err);
    }
  };

  // Choose icon based on hook type
  const HookIcon = () =>
    isPlaySoundHook(props.columnHook.hook_id) ? (
      <SpeakerIcon class="w-3.5 h-3.5 text-gray-400 flex-shrink-0" />
    ) : (
      <TerminalIcon class="w-3.5 h-3.5 text-gray-400 flex-shrink-0" />
    );

  return (
    <div
      ref={sortable.ref}
      class={`p-2 bg-gray-900 rounded-md group ${
        sortable.isActiveDraggable ? "opacity-50" : ""
      }`}
      classList={{ "cursor-grabbing": sortable.isActiveDraggable }}
    >
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2 min-w-0">
          {/* Drag handle */}
          <div
            {...sortable.dragActivators}
            class="cursor-grab hover:text-gray-300 text-gray-500 p-0.5"
          >
            <DragHandleIcon class="w-3.5 h-3.5" />
          </div>
          <HookIcon />
          <span class="text-sm text-white truncate">
            {props.hookDetails?.name || "Unknown Hook"}
          </span>
          <Show when={props.hookDetails?.is_system}>
            <span class="text-xs px-1.5 py-0.5 bg-purple-500/20 text-purple-400 rounded flex-shrink-0">
              System
            </span>
          </Show>
        </div>
        <div class="flex items-center gap-1">
          {/* Execute once toggle */}
          <button
            onClick={(e) => {
              e.stopPropagation();
              props.onToggleExecuteOnce();
            }}
            class={`text-xs px-1.5 py-0.5 rounded border transition-colors ${
              props.columnHook.execute_once
                ? "bg-yellow-500/20 text-yellow-400 border-yellow-500/30 hover:bg-yellow-500/30"
                : "bg-gray-700/50 text-gray-500 border-gray-600/30 hover:bg-gray-700 hover:text-gray-400"
            }`}
            title={
              props.columnHook.execute_once
                ? "Runs only once per task (click to disable)"
                : "Runs every time (click to enable execute-once)"
            }
          >
            {props.columnHook.execute_once ? "1x" : "∞"}
          </button>
          {/* Transparent toggle */}
          <button
            onClick={(e) => {
              e.stopPropagation();
              props.onToggleTransparent();
            }}
            class={`text-xs px-1.5 py-0.5 rounded border transition-colors ${
              props.columnHook.transparent
                ? "bg-blue-500/20 text-blue-400 border-blue-500/30 hover:bg-blue-500/30"
                : "bg-gray-700/50 text-gray-500 border-gray-600/30 hover:bg-gray-700 hover:text-gray-400"
            }`}
            title={
              props.columnHook.transparent
                ? "Transparent: runs even on error, doesn't change status (click to disable)"
                : "Normal: skipped on error, changes status on failure (click to make transparent)"
            }
          >
            {props.columnHook.transparent ? "T" : "N"}
          </button>
          {/* Remove button */}
          <button
            onClick={() => props.onRemove(props.columnHook.id)}
            class="p-1 text-gray-500 hover:text-red-400 opacity-0 group-hover:opacity-100 transition-all"
            title="Remove hook"
          >
            <CloseIcon class="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {/* Sound settings for play-sound hook */}
      <Show when={isPlaySoundHook(props.columnHook.hook_id)}>
        <HookSoundSettings
          currentSound={currentSound()}
          onChange={handleSoundChange}
        />
      </Show>
    </div>
  );
}
