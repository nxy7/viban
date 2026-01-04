import {
  closestCenter,
  createSortable,
  DragDropProvider,
  DragDropSensors,
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
import * as sdk from "~/lib/generated/ash";
import { useHookReordering } from "~/hooks/useHookReordering";
import {
  type Column,
  type ColumnHook,
  type CombinedHook,
  fetchAllHooks,
  unwrap,
  useColumnHooks,
} from "~/hooks/useKanban";
import { getDefaultSound, type SoundType } from "~/lib/sounds";
import {
  Button,
  Chip,
  Input,
  Select,
  Textarea,
} from "~/components/design-system";
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
        console.log(
          "[ColumnSettingsPopup] Closing due to click outside",
          e.target,
        );
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
          <Button onClick={props.onClose} variant="icon">
            <CloseIcon class="w-4 h-4" />
          </Button>
        </div>

        {/* Tabs */}
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
  const [showDeleteConfirm, setShowDeleteConfirm] = createSignal(false);
  const [isDeleting, setIsDeleting] = createSignal(false);

  const isSystemColumn = (SYSTEM_COLUMNS as readonly string[]).includes(
    props.column.name,
  );

  const handleDeleteAllTasks = async () => {
    setIsDeleting(true);
    setError(null);

    const result = await sdk
      .delete_all_column_tasks({ input: { column_id: props.column.id } })
      .then(unwrap);

    setIsDeleting(false);
    if (result !== null) {
      setShowDeleteConfirm(false);
      props.onClose();
    }
  };

  const handleSave = async () => {
    setIsSaving(true);
    setError(null);

    const result = await sdk
      .update_column({
        identity: props.column.id,
        input: {
          name: isSystemColumn ? undefined : name(),
          color: color(),
          settings: {
            ...props.column.settings,
            description: description() || null,
          },
        },
      })
      .then(unwrap);

    setIsSaving(false);
    if (result) {
      props.onClose();
    }
  };

  return (
    <div class="space-y-4">
      <ErrorBanner message={error()} size="sm" />

      {/* Name */}
      <div>
        <label class="block text-sm font-medium text-gray-300 mb-1">Name</label>
        <Input
          type="text"
          value={name()}
          onInput={(e) => setName(e.currentTarget.value)}
          disabled={isSystemColumn}
          variant="dark"
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
              <Button
                onClick={() => setColor(c)}
                variant="ghost"
                style={{
                  "background-color": c,
                  width: "1.5rem",
                  height: "1.5rem",
                  padding: 0,
                  "border-radius": "9999px",
                  transform: color() === c ? "scale(1.1)" : undefined,
                  "box-shadow":
                    color() === c
                      ? "0 0 0 2px #1f2937, 0 0 0 4px white"
                      : undefined,
                }}
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
        <Textarea
          value={description()}
          onInput={(e) => setDescription(e.currentTarget.value)}
          placeholder="What should tasks in this column be doing?"
          rows={2}
          variant="dark"
          resizable={false}
        />
      </div>

      {/* Save button */}
      <Button
        onClick={handleSave}
        disabled={isSaving()}
        loading={isSaving()}
        fullWidth
        buttonSize="sm"
      >
        <Show when={!isSaving()}>Save Changes</Show>
      </Button>

      {/* Danger Zone */}
      <div class="pt-4 mt-4 border-t border-gray-700">
        <h4 class="text-sm font-medium text-red-400 mb-2">Danger Zone</h4>
        <Show
          when={showDeleteConfirm()}
          fallback={
            <Button
              onClick={() => setShowDeleteConfirm(true)}
              variant="danger"
              buttonSize="sm"
              fullWidth
            >
              Delete All Tasks
            </Button>
          }
        >
          <div class="p-3 bg-red-900/20 border border-red-500/30 rounded-md space-y-2">
            <p class="text-sm text-red-400">
              Delete all tasks in this column? This cannot be undone.
            </p>
            <Show when={error()}>
              <p class="text-sm text-red-300 bg-red-900/50 p-2 rounded">
                {error()}
              </p>
            </Show>
            <div class="flex gap-2">
              <Button
                onClick={() => {
                  setShowDeleteConfirm(false);
                  setError(null);
                }}
                variant="secondary"
                buttonSize="sm"
                fullWidth
              >
                Cancel
              </Button>
              <Button
                onClick={handleDeleteAllTasks}
                disabled={isDeleting()}
                loading={isDeleting()}
                variant="danger"
                buttonSize="sm"
                fullWidth
              >
                <Show when={!isDeleting()}>Delete All</Show>
              </Button>
            </div>
          </div>
        </Show>
      </div>
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
      await sdk
        .update_column_settings({
          identity: props.column.id,
          input: { settings: { hooks_enabled: enabled } },
        })
        .then(unwrap);
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
        await sdk
          .update_column_settings({
            identity: props.column.id,
            input: { settings: { max_concurrent_tasks: null } },
          })
          .then(unwrap);
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
      await sdk
        .update_column_settings({
          identity: props.column.id,
          input: {
            settings: { max_concurrent_tasks: enabled() ? limit() : null },
          },
        })
        .then(unwrap);
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
              <Input
                type="number"
                min={1}
                max={100}
                value={limit()}
                onInput={(e) => {
                  const val = parseInt(e.currentTarget.value, 10);
                  if (!Number.isNaN(val) && val >= 1) setLimit(val);
                }}
                variant="dark"
                inputSize="sm"
                fullWidth={false}
                style={{ width: "5rem", "text-align": "center" }}
              />
              <span class="text-sm text-gray-400">tasks at once</span>
            </div>
          </div>

          {/* Save button */}
          <Button
            onClick={handleSave}
            disabled={isSaving()}
            loading={isSaving()}
            fullWidth
            buttonSize="sm"
          >
            <Show when={!isSaving()}>
              {saveSuccess() ? "Saved!" : "Save Limit"}
            </Show>
          </Button>
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
      await sdk
        .create_column_hook({
          input: {
            column_id: props.columnId,
            hook_id: hookId,
            position: props.hooks.length,
          },
        })
        .then(unwrap);
      setShowPicker(false);
    } catch (err) {
      console.error("Failed to add hook:", err);
    } finally {
      setIsAdding(false);
    }
  };

  const handleRemoveHook = async (columnHookId: string) => {
    try {
      await sdk.destroy_column_hook({ identity: columnHookId }).then(unwrap);
    } catch (err) {
      console.error("Failed to remove hook:", err);
    }
  };

  const { handleDragEnd } = useHookReordering(sortedHooks);

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
          <Button
            onClick={() => setShowPicker(!showPicker())}
            variant="ghost"
            buttonSize="sm"
          >
            + Add
          </Button>
        </Show>
      </div>

      {/* Hook picker dropdown */}
      <Show when={showPicker()}>
        <div class="bg-gray-900 border border-gray-700 rounded-md p-2 space-y-1">
          <For each={unassignedHooks()}>
            {(hook) => (
              <Button
                onClick={() => handleAddHook(hook.id)}
                disabled={isAdding()}
                variant="ghost"
                buttonSize="sm"
                fullWidth
              >
                <span class="truncate">{hook.name}</span>
                <Show when={hook.is_system}>
                  <Chip variant="purple">System</Chip>
                </Show>
              </Button>
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
                  {(columnHook) => {
                    const getHook = () =>
                      sortedHooks().find((h) => h.id === columnHook.id) ??
                      columnHook;
                    return (
                      <SortableHookItem
                        columnHook={getHook}
                        hookDetails={() => getHookDetails(getHook().hook_id)}
                        onRemove={handleRemoveHook}
                        onToggleExecuteOnce={() =>
                          sdk
                            .update_column_hook({
                              identity: getHook().id,
                              input: { execute_once: !getHook().execute_once },
                            })
                            .then(unwrap)
                        }
                        onToggleTransparent={() =>
                          sdk
                            .update_column_hook({
                              identity: getHook().id,
                              input: { transparent: !getHook().transparent },
                            })
                            .then(unwrap)
                        }
                      />
                    );
                  }}
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
  columnHook: () => ColumnHook;
  hookDetails: () => CombinedHook | undefined;
  onRemove: (id: string) => void;
  onToggleExecuteOnce: () => void;
  onToggleTransparent: () => void;
}

// Check if hook is the play-sound hook
const isPlaySoundHook = (hookId: string) => hookId === "system:play-sound";

// Check if hook is the move-task hook
const isMoveTaskHook = (hookId: string) => hookId === "system:move-task";

function SortableHookItem(props: SortableHookItemProps) {
  const columnHook = () => props.columnHook();
  const hookDetails = () => props.hookDetails();

  const sortable = createSortable(columnHook().id);

  const isRemovable = () => columnHook().removable !== false;

  // Get current sound setting, defaulting to "ding"
  const currentSound = () =>
    (columnHook().hook_settings?.sound as SoundType) || getDefaultSound();

  // Get current target column for move-task hook
  const targetColumn = () =>
    (columnHook().hook_settings?.target_column as string) || "next";

  // Handle sound setting change
  const handleSoundChange = async (sound: SoundType) => {
    try {
      await sdk
        .update_column_hook({
          identity: columnHook().id,
          input: {
            hook_settings: { ...columnHook().hook_settings, sound },
          },
        })
        .then(unwrap);
    } catch (err) {
      console.error("Failed to update hook settings:", err);
    }
  };

  // Choose icon based on hook type
  const HookIcon = () =>
    isPlaySoundHook(columnHook().hook_id) ? (
      <SpeakerIcon class="w-3.5 h-3.5 text-gray-400 flex-shrink-0" />
    ) : (
      <TerminalIcon class="w-3.5 h-3.5 text-gray-400 flex-shrink-0" />
    );

  const showMetaRow = () => hookDetails()?.is_system || !isRemovable();

  return (
    <div
      ref={sortable.ref}
      class={`p-2 bg-gray-900 rounded-md group ${
        sortable.isActiveDraggable ? "opacity-50" : ""
      }`}
      classList={{ "cursor-grabbing": sortable.isActiveDraggable }}
    >
      {/* Row 1: Drag handle, icon, title, settings */}
      <div class="flex items-center gap-2">
        {/* Drag handle - disabled for non-removable hooks */}
        <div
          {...(isRemovable() ? sortable.dragActivators : {})}
          class={`flex-shrink-0 p-0.5 ${
            isRemovable()
              ? "cursor-grab hover:text-gray-300 text-gray-500"
              : "text-gray-600 cursor-not-allowed"
          }`}
        >
          <DragHandleIcon class="w-3.5 h-3.5" />
        </div>
        <HookIcon />
        <span class="text-sm text-white truncate flex-1 min-w-0">
          {hookDetails()?.name || "Unknown Hook"}
        </span>
        <div class="flex items-center gap-0.5 flex-shrink-0">
          {/* Execute once toggle */}
          <Button
            onClick={(e) => {
              e.stopPropagation();
              props.onToggleExecuteOnce();
            }}
            variant="badge"
            title={
              columnHook().execute_once
                ? "Runs only once per task (click to disable)"
                : "Runs every time (click to enable execute-once)"
            }
            class={
              columnHook().execute_once
                ? "bg-yellow-500/20 text-yellow-400 border-yellow-500/30 hover:bg-yellow-500/30"
                : "bg-gray-700/50 text-gray-500 border-gray-600/30 hover:bg-gray-700"
            }
          >
            {columnHook().execute_once ? "1x" : "∞"}
          </Button>
          {/* Transparent toggle */}
          <Button
            onClick={(e) => {
              e.stopPropagation();
              props.onToggleTransparent();
            }}
            variant="badge"
            title={
              columnHook().transparent
                ? "Transparent: runs even on error, doesn't change status (click to disable)"
                : "Normal: skipped on error, changes status on failure (click to make transparent)"
            }
            class={
              columnHook().transparent
                ? "bg-blue-500/20 text-blue-400 border-blue-500/30 hover:bg-blue-500/30"
                : "bg-gray-700/50 text-gray-500 border-gray-600/30 hover:bg-gray-700"
            }
          >
            {columnHook().transparent ? "T" : "N"}
          </Button>
          {/* Remove button - only show if removable */}
          <Show when={isRemovable()}>
            <Button
              onClick={() => props.onRemove(columnHook().id)}
              variant="icon"
              title="Remove hook"
            >
              <CloseIcon class="w-3.5 h-3.5" />
            </Button>
          </Show>
        </div>
      </div>

      {/* Row 2: System badge and Required status (only if applicable) */}
      <Show when={showMetaRow()}>
        <div class="flex items-center gap-2 mt-1.5">
          <Show when={hookDetails()?.is_system}>
            <Chip variant="purple">System</Chip>
          </Show>
          <Show when={!isRemovable()}>
            <Chip variant="gray">Required</Chip>
          </Show>
        </div>
      </Show>

      {/* Sound settings for play-sound hook */}
      <Show when={isPlaySoundHook(columnHook().hook_id)}>
        <HookSoundSettings
          currentSound={currentSound}
          onChange={handleSoundChange}
        />
      </Show>

      {/* Target column settings for move-task hook */}
      <Show when={isMoveTaskHook(columnHook().hook_id)}>
        <MoveTaskSettings
          columnHook={columnHook()}
          targetColumn={targetColumn()}
          disabled={!isRemovable()}
        />
      </Show>
    </div>
  );
}

// Move Task hook settings component
interface MoveTaskSettingsProps {
  columnHook: ColumnHook;
  targetColumn: string;
  disabled: boolean;
}

const TARGET_COLUMN_OPTIONS = [
  { value: "next", label: "Next column" },
  { value: "TODO", label: "TODO" },
  { value: "In Progress", label: "In Progress" },
  { value: "To Review", label: "To Review" },
  { value: "Done", label: "Done" },
  { value: "Cancelled", label: "Cancelled" },
] as const;

function MoveTaskSettings(props: MoveTaskSettingsProps) {
  const handleTargetChange = async (target: string) => {
    if (props.disabled) return;
    try {
      await sdk
        .update_column_hook({
          identity: props.columnHook.id,
          input: {
            hook_settings: {
              ...props.columnHook.hook_settings,
              target_column: target,
            },
          },
        })
        .then(unwrap);
    } catch (err) {
      console.error("Failed to update target column:", err);
    }
  };

  return (
    <div class="mt-2 pt-2 border-t border-gray-800">
      <div class="flex items-center gap-2 text-xs">
        <span class="text-gray-500">Target:</span>
        <Show
          when={!props.disabled}
          fallback={
            <span class="text-gray-300 px-2 py-0.5 bg-gray-800 rounded">
              {props.targetColumn === "next"
                ? "Next column"
                : props.targetColumn}
            </span>
          }
        >
          <Select
            value={props.targetColumn}
            onChange={(e) => handleTargetChange(e.currentTarget.value)}
            variant="dark"
            selectSize="sm"
          >
            <For each={TARGET_COLUMN_OPTIONS}>
              {(option) => <option value={option.value}>{option.label}</option>}
            </For>
          </Select>
        </Show>
      </div>
    </div>
  );
}
