import { createEffect, createSignal, on, Show } from "solid-js";
import { Button, Checkbox, Input } from "~/components/design-system";
import { type Column, toDecimal, unwrap } from "~/hooks/useKanban";
import * as sdk from "~/lib/generated/ash";
import ImageTextarea, {
  type InlineImage,
  prepareImagesForApi,
} from "./ImageTextarea";
import ErrorBanner from "./ui/ErrorBanner";
import { LightningIcon, PlayIcon } from "./ui/Icons";
import Modal from "./ui/Modal";

const MAX_BRANCH_NAME_LENGTH = 200;
const AUTO_BRANCH_NAME_LENGTH = 25;
const BRANCH_NAME_PREFIX = "viban-";
const STORAGE_KEY_TITLE = "create-task-draft-title";
const STORAGE_KEY_DESCRIPTION = "create-task-draft-description";

interface CreateTaskModalProps {
  isOpen: boolean;
  onClose: () => void;
  columnId: string;
  columnName: string;
  /** All columns for autostart feature */
  columns?: Column[];
  /** Optional initial values for pre-populating the form (e.g., when duplicating) */
  initialValues?: {
    title?: string;
    description?: string;
  };
}

function generateDefaultBranchName(taskTitle: string): string {
  const sanitized = taskTitle
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, "")
    .trim()
    .replace(/\s+/g, "-");

  return (BRANCH_NAME_PREFIX + sanitized).slice(0, AUTO_BRANCH_NAME_LENGTH);
}

export default function CreateTaskModal(props: CreateTaskModalProps) {
  const [title, setTitle] = createSignal("");
  const [description, setDescription] = createSignal("");
  const [descriptionImages, setDescriptionImages] = createSignal<InlineImage[]>(
    [],
  );
  const [customBranchName, setCustomBranchName] = createSignal("");
  const [isSubmitting, setIsSubmitting] = createSignal(false);
  const [isRefining, setIsRefining] = createSignal(false);
  const [autostart, setAutostart] = createSignal(false);
  const [error, setError] = createSignal<string | null>(null);

  // Auto-update branch name when title changes (if not manually edited)
  const [branchNameManuallyEdited, setBranchNameManuallyEdited] =
    createSignal(false);

  /**
   * Find the "In Progress" column for autostart feature.
   * Returns undefined if columns not provided or no matching column found.
   */
  const inProgressColumn = (): Column | undefined =>
    props.columns?.find((c) => c.name.toLowerCase() === "in progress");

  // Auto-update branch name when title changes (if not manually edited)
  createEffect(
    on(title, (titleValue) => {
      if (!branchNameManuallyEdited() && titleValue) {
        setCustomBranchName(generateDefaultBranchName(titleValue));
      }
    }),
  );

  let titleInputRef: HTMLInputElement | undefined;

  createEffect(
    on(
      () => props.isOpen,
      (isOpen) => {
        if (isOpen) {
          if (props.initialValues) {
            if (props.initialValues.title) {
              setTitle(props.initialValues.title);
            }
            if (props.initialValues.description) {
              setDescription(props.initialValues.description);
            }
          } else {
            const savedTitle = localStorage.getItem(STORAGE_KEY_TITLE);
            const savedDescription = localStorage.getItem(
              STORAGE_KEY_DESCRIPTION,
            );
            if (savedTitle) setTitle(savedTitle);
            if (savedDescription) setDescription(savedDescription);
          }
          setTimeout(() => titleInputRef?.focus(), 0);
        }
      },
    ),
  );

  createEffect(
    on(title, (value) => {
      if (!props.isOpen) return;
      if (value) {
        localStorage.setItem(STORAGE_KEY_TITLE, value);
      }
    }),
  );

  createEffect(
    on(description, (value) => {
      if (!props.isOpen) return;
      if (value) {
        localStorage.setItem(STORAGE_KEY_DESCRIPTION, value);
      }
    }),
  );

  const resetForm = (clearStorage = false) => {
    setTitle("");
    setDescription("");
    setDescriptionImages([]);
    setCustomBranchName("");
    setBranchNameManuallyEdited(false);
    setAutostart(false);
    setError(null);
    if (clearStorage) {
      localStorage.removeItem(STORAGE_KEY_TITLE);
      localStorage.removeItem(STORAGE_KEY_DESCRIPTION);
    }
  };

  // Handle refine button click
  const handleRefine = async () => {
    if (!title().trim()) {
      setError("Title is required for refinement");
      return;
    }

    setIsRefining(true);
    setError(null);

    const result = await sdk
      .refine_preview({
        input: {
          title: title().trim(),
          description: description().trim() || undefined,
        },
      })
      .then(unwrap);

    setIsRefining(false);
    if (result) {
      setDescription(result.refined_description);
    }
  };

  const handleClose = () => {
    resetForm();
    props.onClose();
  };

  const handleSubmit = async (e: Event) => {
    e.preventDefault();

    if (!title().trim()) {
      setError("Title is required");
      return;
    }

    setIsSubmitting(true);

    const images = descriptionImages();
    const task = await sdk
      .create_task({
        input: {
          title: title().trim(),
          description: description().trim() || undefined,
          column_id: props.columnId,
          position: toDecimal(Date.now()),
          custom_branch_name: customBranchName().trim() || undefined,
          description_images:
            images.length > 0 ? prepareImagesForApi(images) : undefined,
        },
        fields: ["id"],
      })
      .then(unwrap);

    if (!task) {
      setIsSubmitting(false);
      return;
    }

    // If autostart is enabled and we have an "In Progress" column, move the task there
    const targetColumn = inProgressColumn();
    if (autostart() && targetColumn) {
      await sdk
        .move_task({
          identity: task.id,
          input: {
            column_id: targetColumn.id,
            position: toDecimal(Date.now()),
          },
        })
        .then(unwrap);
    }

    setIsSubmitting(false);
    resetForm(true);
    props.onClose();
  };

  return (
    <Modal
      isOpen={props.isOpen}
      onClose={handleClose}
      title={`Add task to ${props.columnName}`}
    >
      <form onSubmit={handleSubmit} class="space-y-4">
        <div>
          <label
            for="title"
            class="block text-sm font-medium text-gray-300 mb-1"
          >
            Title *
          </label>
          <Input
            ref={titleInputRef}
            id="title"
            type="text"
            value={title()}
            onInput={(e) => setTitle(e.currentTarget.value)}
            placeholder="Enter task title..."
          />
        </div>

        <div>
          <div class="flex items-center justify-between mb-1">
            <label
              for="description"
              class="block text-sm font-medium text-gray-300"
            >
              Description
            </label>
            <Button
              type="button"
              onClick={handleRefine}
              disabled={isRefining() || !title().trim()}
              loading={isRefining()}
              variant="ghost"
              buttonSize="sm"
              title="Refine description with AI"
            >
              <Show when={!isRefining()}>
                <LightningIcon class="w-3.5 h-3.5" />
                Refine with AI
              </Show>
              <Show when={isRefining()}>Refining...</Show>
            </Button>
          </div>
          <ImageTextarea
            id="description"
            value={description()}
            onChange={setDescription}
            images={descriptionImages()}
            onImagesChange={setDescriptionImages}
            placeholder="Enter task description... (paste images with Ctrl+V)"
            rows={3}
          />
        </div>

        <div>
          <label
            for="branchName"
            class="block text-sm font-medium text-gray-300 mb-1"
          >
            Worktree Name
          </label>
          <Input
            id="branchName"
            type="text"
            value={customBranchName()}
            onInput={(e) => {
              const value = e.currentTarget.value;
              setCustomBranchName(value);
              setBranchNameManuallyEdited(value.length > 0);
            }}
            maxLength={MAX_BRANCH_NAME_LENGTH}
            placeholder="Auto-generated from title..."
            variant="mono"
          />
          <p class="text-xs text-gray-500 mt-1">
            Git branch and worktree folder name. Auto-generated from title if
            left empty.
          </p>
        </div>

        {/* Autostart toggle - only show if we have an In Progress column */}
        <Show when={inProgressColumn()}>
          <div class="flex items-center gap-3 p-3 bg-gray-800/50 border border-gray-700 rounded-lg">
            <Checkbox
              id="autostart"
              checked={autostart()}
              onChange={(e) => setAutostart(e.currentTarget.checked)}
            />
            <div class="flex-1">
              <label
                for="autostart"
                class="text-sm font-medium text-gray-300 cursor-pointer"
              >
                Start immediately
              </label>
              <p class="text-xs text-gray-500">
                Move to "In Progress" after creation
              </p>
            </div>
            <PlayIcon class="w-5 h-5 text-brand-400" />
          </div>
        </Show>

        <ErrorBanner message={error()} />

        <div class="flex gap-3 pt-2">
          <Button
            type="button"
            onClick={handleClose}
            variant="secondary"
            fullWidth
          >
            Cancel
          </Button>
          <Button
            type="submit"
            disabled={isSubmitting()}
            loading={isSubmitting()}
            fullWidth
          >
            <Show when={!isSubmitting()}>Create Task</Show>
            <Show when={isSubmitting()}>Creating...</Show>
          </Button>
        </div>
      </form>
    </Modal>
  );
}
