import {
  closestCenter,
  createSortable,
  DragDropProvider,
  DragDropSensors,
  DragOverlay,
  SortableProvider,
} from "@thisbeyond/solid-dnd";
import { createMemo, createResource, createSignal, For, Show } from "solid-js";
import * as sdk from "~/lib/generated/ash";
import { useHookReordering } from "~/hooks/useHookReordering";
import {
  type ColumnHook,
  type CombinedHook,
  fetchAllHooks,
  unwrap,
  useColumnHooks,
} from "~/hooks/useKanban";
import { Button, Checkbox, Select } from "~/components/design-system";
import ErrorBanner from "./ui/ErrorBanner";
import { CloseIcon, DragHandleIcon, SystemIcon } from "./ui/Icons";

interface ColumnHookConfigProps {
  boardId: string;
  columnId: string;
  columnName: string;
}

export default function ColumnHookConfig(props: ColumnHookConfigProps) {
  const [allHooks] = createResource(() => props.boardId, fetchAllHooks);
  const { columnHooks, isLoading } = useColumnHooks(() => props.columnId);
  const [isAdding, setIsAdding] = createSignal(false);
  const [selectedHookId, setSelectedHookId] = createSignal("");
  const [executeOnce, setExecuteOnce] = createSignal(false);
  const [transparent, setTransparent] = createSignal(false);
  const [error, setError] = createSignal<string | null>(null);
  const [isSaving, setIsSaving] = createSignal(false);

  const assignedHookIds = createMemo(() => {
    return new Set(columnHooks().map((ch) => ch.hook_id));
  });

  const availableHooks = createMemo(() => {
    const hooks = allHooks() || [];
    return hooks.filter((h) => !assignedHookIds().has(h.id));
  });

  const availableSystemHooks = createMemo(() =>
    availableHooks().filter((h) => h.is_system),
  );
  const availableCustomHooks = createMemo(() =>
    availableHooks().filter((h) => !h.is_system),
  );

  const getHookDetails = (hookId: string): CombinedHook | undefined => {
    return (allHooks() || []).find((h) => h.id === hookId);
  };

  const sortedColumnHooks = createMemo(() => {
    return [...columnHooks()].sort(
      (a, b) => Number(a.position) - Number(b.position),
    );
  });

  const hookIds = createMemo(() => sortedColumnHooks().map((h) => h.id));

  const handleAdd = async () => {
    if (!selectedHookId()) {
      setError("Please select a hook");
      return;
    }

    setIsSaving(true);
    setError(null);

    const result = await sdk
      .create_column_hook({
        input: {
          column_id: props.columnId,
          hook_id: selectedHookId(),
          position: columnHooks().length,
          execute_once: executeOnce(),
          transparent: transparent(),
        },
      })
      .then(unwrap);

    setIsSaving(false);
    if (result) {
      setIsAdding(false);
      setSelectedHookId("");
      setExecuteOnce(false);
      setTransparent(false);
    }
  };

  const handleRemove = async (columnHookId: string) => {
    await sdk.destroy_column_hook({ identity: columnHookId }).then(unwrap);
  };

  const { handleDragEnd } = useHookReordering(sortedColumnHooks);

  return (
    <div class="space-y-3">
      <div class="flex justify-between items-center">
        <h4 class="text-sm font-medium text-gray-300">{props.columnName}</h4>
        <Show when={!isAdding() && availableHooks().length > 0}>
          <Button
            onClick={() => setIsAdding(true)}
            variant="ghost"
            buttonSize="sm"
          >
            + Add Hook
          </Button>
        </Show>
      </div>

      <ErrorBanner message={error()} size="sm" />

      {/* Add Hook Form */}
      <Show when={isAdding()}>
        <div class="p-3 bg-gray-800 border border-gray-700 rounded-lg space-y-3">
          <div>
            <label class="block text-xs text-gray-400 mb-1">Hook</label>
            <Select
              value={selectedHookId()}
              onChange={(e) => {
                const hookId = e.currentTarget.value;
                setSelectedHookId(hookId);
                const selectedHook = (allHooks() || []).find(
                  (h) => h.id === hookId,
                );
                if (selectedHook) {
                  setExecuteOnce(selectedHook.default_execute_once ?? false);
                  setTransparent(selectedHook.default_transparent ?? false);
                }
              }}
              variant="dark"
              selectSize="sm"
              fullWidth
            >
              <option value="">Select a hook...</option>
              <Show when={availableSystemHooks().length > 0}>
                <optgroup label="System Hooks">
                  <For each={availableSystemHooks()}>
                    {(hook) => <option value={hook.id}>{hook.name}</option>}
                  </For>
                </optgroup>
              </Show>
              <Show when={availableCustomHooks().length > 0}>
                <optgroup label="Custom Hooks">
                  <For each={availableCustomHooks()}>
                    {(hook) => <option value={hook.id}>{hook.name}</option>}
                  </For>
                </optgroup>
              </Show>
            </Select>
          </div>

          {/* Execute once checkbox */}
          <div class="flex items-center gap-2 p-2 bg-gray-900/50 rounded border border-gray-700">
            <Checkbox
              id="executeOnce"
              checked={executeOnce()}
              onChange={(e) => setExecuteOnce(e.currentTarget.checked)}
            />
            <label
              for="executeOnce"
              class="text-xs text-gray-300 cursor-pointer"
            >
              Execute only once per task
            </label>
          </div>

          {/* Transparent checkbox */}
          <div class="flex items-center gap-2 p-2 bg-gray-900/50 rounded border border-gray-700">
            <Checkbox
              id="transparent"
              checked={transparent()}
              onChange={(e) => setTransparent(e.currentTarget.checked)}
            />
            <label
              for="transparent"
              class="text-xs text-gray-300 cursor-pointer"
            >
              Transparent (runs even on error, doesn't change status)
            </label>
          </div>

          <div class="flex gap-2">
            <Button
              onClick={() => {
                setIsAdding(false);
                setSelectedHookId("");
                setError(null);
              }}
              variant="secondary"
              buttonSize="sm"
              fullWidth
            >
              Cancel
            </Button>
            <Button
              onClick={handleAdd}
              disabled={isSaving() || !selectedHookId()}
              loading={isSaving()}
              buttonSize="sm"
              fullWidth
            >
              <Show when={!isSaving()}>Add</Show>
            </Button>
          </div>
        </div>
      </Show>

      {/* Column Hooks List */}
      <Show when={isLoading()}>
        <div class="text-gray-500 text-xs">Loading...</div>
      </Show>

      <Show when={!isLoading() && columnHooks().length === 0 && !isAdding()}>
        <div class="text-gray-500 text-xs text-center py-2">
          No hooks assigned
        </div>
      </Show>

      <Show when={sortedColumnHooks().length > 0}>
        <DragDropProvider
          onDragEnd={handleDragEnd}
          collisionDetector={closestCenter}
        >
          <DragDropSensors />
          <SortableProvider ids={hookIds()}>
            <div class="space-y-1.5">
              <For each={sortedColumnHooks()}>
                {(columnHook) => (
                  <SortableHookItem
                    columnHook={columnHook}
                    hookDetails={getHookDetails(columnHook.hook_id)}
                    onRemove={handleRemove}
                    onToggleExecuteOnce={async () => {
                      try {
                        await sdk
                          .update_column_hook({
                            identity: columnHook.id,
                            input: { execute_once: !columnHook.execute_once },
                          })
                          .then(unwrap);
                      } catch (err) {
                        setError(
                          err instanceof Error
                            ? err.message
                            : "Failed to update hook",
                        );
                      }
                    }}
                    onToggleTransparent={async () => {
                      try {
                        await sdk
                          .update_column_hook({
                            identity: columnHook.id,
                            input: { transparent: !columnHook.transparent },
                          })
                          .then(unwrap);
                      } catch (err) {
                        setError(
                          err instanceof Error
                            ? err.message
                            : "Failed to update hook",
                        );
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
              const hook = sortedColumnHooks().find(
                (h) => h.id === String(draggable.id),
              );
              if (!hook) return null;
              const details = getHookDetails(hook.hook_id);
              return (
                <HookItemOverlay hookName={details?.name || hook.hook_id} />
              );
            }}
          </DragOverlay>
        </DragDropProvider>
      </Show>
    </div>
  );
}

interface SortableHookItemProps {
  columnHook: ColumnHook;
  hookDetails: CombinedHook | undefined;
  onRemove: (id: string) => void;
  onToggleExecuteOnce: () => void;
  onToggleTransparent: () => void;
}

function SortableHookItem(props: SortableHookItemProps) {
  const sortable = createSortable(props.columnHook.id);
  const isSystem =
    props.hookDetails?.is_system ||
    props.columnHook.hook_id.startsWith("system:");

  return (
    <div
      ref={sortable.ref}
      class={`flex items-center justify-between p-2 bg-gray-800/50 border rounded group ${
        isSystem ? "border-purple-500/30" : "border-gray-700/50"
      } ${sortable.isActiveDraggable ? "opacity-50" : ""}`}
      classList={{ "cursor-grabbing": sortable.isActiveDraggable }}
    >
      <div class="flex items-center gap-2 min-w-0 flex-1">
        {/* Drag handle */}
        <div
          {...sortable.dragActivators}
          class="cursor-grab hover:text-gray-300 text-gray-500 p-0.5"
        >
          <DragHandleIcon class="w-3.5 h-3.5" />
        </div>
        <Show when={isSystem}>
          <SystemIcon class="w-3.5 h-3.5 text-purple-400" />
        </Show>
        <span class="text-sm text-white truncate">
          {props.hookDetails?.name || props.columnHook.hook_id}
        </span>
        {/* Execute once indicator */}
        <Button
          onClick={(e) => {
            e.stopPropagation();
            props.onToggleExecuteOnce();
          }}
          variant="ghost"
          buttonSize="sm"
          title={
            props.columnHook.execute_once
              ? "Runs only once per task (click to disable)"
              : "Runs every time (click to enable execute-once)"
          }
        >
          <span
            class={`text-xs px-1.5 py-0.5 rounded border transition-colors ${
              props.columnHook.execute_once
                ? "bg-yellow-500/20 text-yellow-400 border-yellow-500/30"
                : "bg-gray-700/50 text-gray-500 border-gray-600/30"
            }`}
          >
            {props.columnHook.execute_once ? "1x" : "∞"}
          </span>
        </Button>
        {/* Transparent indicator */}
        <Button
          onClick={(e) => {
            e.stopPropagation();
            props.onToggleTransparent();
          }}
          variant="ghost"
          buttonSize="sm"
          title={
            props.columnHook.transparent
              ? "Transparent: runs even on error, doesn't change status (click to disable)"
              : "Normal: skipped on error, changes status on failure (click to make transparent)"
          }
        >
          <span
            class={`text-xs px-1.5 py-0.5 rounded border transition-colors ${
              props.columnHook.transparent
                ? "bg-blue-500/20 text-blue-400 border-blue-500/30"
                : "bg-gray-700/50 text-gray-500 border-gray-600/30"
            }`}
          >
            {props.columnHook.transparent ? "T" : "N"}
          </span>
        </Button>
      </div>
      <Show when={props.columnHook.removable !== false}>
        <Button
          onClick={() => props.onRemove(props.columnHook.id)}
          variant="icon"
          title="Remove hook"
        >
          <CloseIcon class="w-3.5 h-3.5" />
        </Button>
      </Show>
      <Show when={props.columnHook.removable === false}>
        <span
          class="p-1 text-gray-600 text-xs"
          title="This hook cannot be removed"
        >
          Required
        </span>
      </Show>
    </div>
  );
}

function HookItemOverlay(props: { hookName: string }) {
  return (
    <div class="flex items-center gap-2 p-2 bg-gray-800 border border-brand-500 rounded shadow-lg">
      <DragHandleIcon class="w-3.5 h-3.5 text-gray-400" />
      <span class="text-sm text-white">{props.hookName}</span>
    </div>
  );
}
