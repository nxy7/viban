import { createSignal, For, Show } from "solid-js";
import { Button, Input, Textarea } from "~/components/design-system";
import type { Column } from "~/hooks/useKanban";
import { unwrap } from "~/hooks/useKanban";
import * as sdk from "~/lib/generated/ash";
import ErrorBanner from "../ui/ErrorBanner";

const SYSTEM_COLUMNS = [
  "TODO",
  "In Progress",
  "To Review",
  "Done",
  "Cancelled",
] as const;

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

interface GeneralSettingsProps {
  column: Column;
  onClose: () => void;
}

export default function GeneralSettings(props: GeneralSettingsProps) {
  const [name, setName] = createSignal(props.column.name);
  const [color, setColor] = createSignal(props.column.color);
  const [description, setDescription] = createSignal(
    props.column.settings?.description ?? "",
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

      <Button
        onClick={handleSave}
        disabled={isSaving()}
        loading={isSaving()}
        fullWidth
        buttonSize="sm"
      >
        <Show when={!isSaving()}>Save Changes</Show>
      </Button>

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
