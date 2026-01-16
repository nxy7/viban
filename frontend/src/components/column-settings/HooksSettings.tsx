import {
  closestCenter,
  createSortable,
  DragDropProvider,
  DragDropSensors,
  DragOverlay,
  SortableProvider,
} from "@thisbeyond/solid-dnd";
import { createMemo, createResource, createSignal, For, Show } from "solid-js";
import { Button, Chip, Select } from "~/components/design-system";
import { useHookReordering } from "~/hooks/useHookReordering";
import {
  type Column,
  type ColumnHook,
  type CombinedHook,
  fetchAllHooks,
  unwrap,
  useColumnHooks,
} from "~/hooks/useKanban";
import * as sdk from "~/lib/generated/ash";
import { createLogger } from "~/lib/logger";
import { getDefaultSound, type SoundType } from "~/lib/sounds";
import HookSoundSettings from "../HookSoundSettings";
import {
  CloseIcon,
  DragHandleIcon,
  SpeakerIcon,
  TerminalIcon,
} from "../ui/Icons";
import Toggle from "../ui/Toggle";

const log = createLogger("HooksSettings");

interface HooksSettingsProps {
  column: Column;
  boardId: string;
}

export default function HooksSettings(props: HooksSettingsProps) {
  const [allHooks] = createResource(() => props.boardId, fetchAllHooks);
  const { columnHooks, isLoading: isColumnHooksLoading } = useColumnHooks(
    () => props.column.id,
  );

  const isLoading = () => allHooks.loading || isColumnHooksLoading();
  const [hooksEnabled, setHooksEnabled] = createSignal(
    props.column.settings?.hooks_enabled !== false,
  );
  const [isSaving, setIsSaving] = createSignal(false);

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

interface HookSectionProps {
  title: string;
  description: string;
  hooks: ColumnHook[];
  columnId: string;
  availableHooks: CombinedHook[];
}

function HookSection(props: HookSectionProps) {
  const [showPicker, setShowPicker] = createSignal(false);
  const [isAdding, setIsAdding] = createSignal(false);

  const unassignedHooks = createMemo(() => {
    const assignedIds = new Set(props.hooks.map((h) => h.hook_id));
    return props.availableHooks.filter((h) => !assignedIds.has(h.id));
  });

  const sortedHooks = createMemo(() =>
    [...props.hooks].sort((a, b) => Number(a.position) - Number(b.position)),
  );

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
      log.error("Failed to add hook", { error: err });
    } finally {
      setIsAdding(false);
    }
  };

  const handleRemoveHook = async (columnHookId: string) => {
    try {
      await sdk.destroy_column_hook({ identity: columnHookId }).then(unwrap);
    } catch (err) {
      log.error("Failed to remove hook", { error: err });
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

interface SortableHookItemProps {
  columnHook: () => ColumnHook;
  hookDetails: () => CombinedHook | undefined;
  onRemove: (id: string) => void;
  onToggleExecuteOnce: () => void;
  onToggleTransparent: () => void;
}

const isPlaySoundHook = (hookId: string) => hookId === "system:play-sound";
const isMoveTaskHook = (hookId: string) => hookId === "system:move-task";

function SortableHookItem(props: SortableHookItemProps) {
  const columnHook = () => props.columnHook();
  const hookDetails = () => props.hookDetails();

  const sortable = createSortable(columnHook().id);

  const isRemovable = () => columnHook().removable !== false;

  const currentSound = () =>
    (columnHook().hook_settings?.sound as SoundType) || getDefaultSound();

  const targetColumn = () =>
    (columnHook().hook_settings?.target_column as string) || "next";

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
      log.error("Failed to update hook settings", { error: err });
    }
  };

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
      <div class="flex items-center gap-2">
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

      <Show when={isPlaySoundHook(columnHook().hook_id)}>
        <HookSoundSettings
          currentSound={currentSound}
          onChange={handleSoundChange}
        />
      </Show>

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
      log.error("Failed to update target column", { error: err });
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
