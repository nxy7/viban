import { createMemo, createSignal, For, Show } from "solid-js";
import { Button, Input, Textarea } from "~/components/design-system";
import ErrorBanner from "./ui/ErrorBanner";
import { EditIcon, TrashIcon } from "./ui/Icons";

interface TaskTemplate {
  id: string;
  name: string;
  description_template: string | null;
  position: number;
  board_id: string;
}

interface TaskTemplatesConfigProps {
  boardId: string;
  templates: TaskTemplate[];
  onRefetch?: () => void;
  onCreate?: (template: {
    name: string;
    description_template: string;
  }) => Promise<void>;
  onUpdate?: (
    id: string,
    updates: Partial<{
      name: string;
      description_template: string;
      position: number;
    }>,
  ) => Promise<void>;
  onDelete?: (id: string) => Promise<void>;
}

export default function TaskTemplatesConfig(props: TaskTemplatesConfigProps) {
  const [isCreating, setIsCreating] = createSignal(false);
  const [editingTemplate, setEditingTemplate] =
    createSignal<TaskTemplate | null>(null);
  const [error, setError] = createSignal<string | null>(null);
  const [isSaving, setIsSaving] = createSignal(false);

  const [name, setName] = createSignal("");
  const [descriptionTemplate, setDescriptionTemplate] = createSignal("");

  const resetForm = () => {
    setName("");
    setDescriptionTemplate("");
    setError(null);
  };

  const startCreate = () => {
    resetForm();
    setIsCreating(true);
    setEditingTemplate(null);
  };

  const startEdit = (template: TaskTemplate) => {
    setName(template.name);
    setDescriptionTemplate(template.description_template || "");
    setEditingTemplate(template);
    setIsCreating(false);
    setError(null);
  };

  const cancelEdit = () => {
    resetForm();
    setIsCreating(false);
    setEditingTemplate(null);
  };

  const handleSave = async () => {
    if (!name().trim()) {
      setError("Name is required");
      return;
    }

    setIsSaving(true);
    setError(null);

    try {
      if (isCreating()) {
        await props.onCreate?.({
          name: name().trim(),
          description_template: descriptionTemplate().trim(),
        });
      } else {
        const template = editingTemplate();
        if (template) {
          await props.onUpdate?.(template.id, {
            name: name().trim(),
            description_template: descriptionTemplate().trim(),
          });
        }
      }
      cancelEdit();
      props.onRefetch?.();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to save");
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm("Are you sure you want to delete this template?")) return;

    try {
      await props.onDelete?.(id);
      props.onRefetch?.();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to delete");
    }
  };

  const sortedTemplates = createMemo(() =>
    [...props.templates].sort((a, b) => a.position - b.position),
  );

  return (
    <div class="space-y-4">
      <div class="flex justify-between items-center">
        <h3 class="text-lg font-semibold text-white">Task Templates</h3>
        <Show when={!isCreating() && !editingTemplate()}>
          <Button onClick={startCreate} buttonSize="sm">
            Add Template
          </Button>
        </Show>
      </div>

      <p class="text-sm text-gray-400">
        Define templates for common task types. When creating a new task, you
        can select a template to pre-fill the description.
      </p>

      <ErrorBanner message={error()} />

      <Show when={isCreating() || editingTemplate()}>
        <div class="p-4 bg-gray-800 border border-gray-700 rounded-lg space-y-4">
          <h4 class="text-sm font-medium text-gray-300">
            {isCreating() ? "Create Template" : "Edit Template"}
          </h4>

          <div>
            <label class="block text-sm text-gray-400 mb-1">Name</label>
            <Input
              type="text"
              value={name()}
              onInput={(e) => setName(e.currentTarget.value)}
              placeholder="e.g., Feature, Bugfix, Refactor"
              variant="dark"
            />
          </div>

          <div>
            <label class="block text-sm text-gray-400 mb-1">
              Description Template
            </label>
            <Textarea
              value={descriptionTemplate()}
              onInput={(e) => setDescriptionTemplate(e.currentTarget.value)}
              placeholder="Enter a template for the task description. You can use markdown."
              rows={8}
              variant="dark"
              resizable
            />
            <p class="text-xs text-gray-500 mt-1">
              This will be pre-filled when selecting this template during task
              creation.
            </p>
          </div>

          <div class="flex gap-2 pt-2">
            <Button
              onClick={cancelEdit}
              variant="secondary"
              buttonSize="sm"
              fullWidth
            >
              Cancel
            </Button>
            <Button
              onClick={handleSave}
              disabled={isSaving()}
              loading={isSaving()}
              buttonSize="sm"
              fullWidth
            >
              <Show when={!isSaving()}>
                {isCreating() ? "Create" : "Save Changes"}
              </Show>
            </Button>
          </div>
        </div>
      </Show>

      <Show when={sortedTemplates().length === 0 && !isCreating()}>
        <div class="text-gray-500 text-sm text-center py-8">
          No templates configured. Click "Add Template" to create one.
        </div>
      </Show>

      <div class="space-y-2">
        <For each={sortedTemplates()}>
          {(template) => (
            <div
              class={`p-4 bg-gray-800 border rounded-lg ${
                editingTemplate()?.id === template.id
                  ? "border-brand-500"
                  : "border-gray-700"
              }`}
            >
              <div class="flex justify-between items-start">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2">
                    <span class="font-medium text-white">{template.name}</span>
                  </div>

                  <Show when={template.description_template}>
                    <div class="text-xs text-gray-400 mt-2 line-clamp-3 whitespace-pre-wrap font-mono bg-gray-900 p-2 rounded">
                      {template.description_template}
                    </div>
                  </Show>
                </div>

                <div class="flex gap-1 ml-2">
                  <Button
                    onClick={() => startEdit(template)}
                    variant="icon"
                    title="Edit"
                  >
                    <EditIcon class="w-4 h-4" />
                  </Button>
                  <Button
                    onClick={() => handleDelete(template.id)}
                    variant="icon"
                    title="Delete"
                  >
                    <TrashIcon class="w-4 h-4" />
                  </Button>
                </div>
              </div>
            </div>
          )}
        </For>
      </div>
    </div>
  );
}
