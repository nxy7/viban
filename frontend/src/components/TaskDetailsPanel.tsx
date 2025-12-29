import { useLiveQuery } from "@tanstack/solid-db";
import { marked } from "marked";
import {
  createEffect,
  createMemo,
  createSignal,
  For,
  onMount,
  Show,
} from "solid-js";
import {
  CodeEditorIcon,
  DuplicateIcon,
  FolderIcon,
  LightningIcon,
  LoadingSpinner,
  PRIcon,
  TrashIcon,
} from "~/components/ui/Icons";

// LocalStorage keys for preferences
const HIDE_DETAILS_KEY = "viban:hideDetails";
const FULLSCREEN_KEY = "viban:fullscreen";

// Helper to get localStorage value with default
function getStoredBoolean(key: string, defaultValue: boolean): boolean {
  if (typeof window === "undefined") return defaultValue;
  const stored = localStorage.getItem(key);
  if (stored === null) return defaultValue;
  return stored === "true";
}

// Helper to set localStorage value
function setStoredBoolean(key: string, value: boolean): void {
  if (typeof window === "undefined") return;
  localStorage.setItem(key, String(value));
}
import { CHAT_PROSE_CLASSES, renderMarkdown } from "~/lib/markdown";
import { getPRBadgeHoverClasses } from "~/lib/taskStyles";
import {
  columnsCollection,
  deleteTask,
  refineTask,
  type Task,
  type UpdateTaskInput,
  updateTask,
} from "~/lib/useKanban";
import { type OutputLine, useTaskChat } from "~/lib/useTaskChat";
import { AgentStatusBadge, type AgentStatusType } from "./AgentStatus";
import CreateTaskModal from "./CreateTaskModal";
import HookQueueDisplay from "./HookQueueDisplay";
import ImageTextarea, {
  type InlineImage,
  parseDescriptionImages,
  prepareImagesForApi,
  renderDescriptionWithImages,
} from "./ImageTextarea";
import LLMTodoList from "./LLMTodoList";
import SubtaskList from "./SubtaskList";
import ErrorBanner from "./ui/ErrorBanner";
import SidePanel from "./ui/SidePanel";

interface TaskDetailsPanelProps {
  isOpen: boolean;
  onClose: () => void;
  task: Task | null;
  columnName?: string;
}

// Activity item types for the unified view
type TaskCreatedActivity = {
  type: "task_created";
  timestamp: string;
  description: string | null;
};

type OutputActivity = {
  type: "output";
  line: OutputLine;
};

type HookExecutionActivity = {
  type: "hook_execution";
  id: string;
  name: string;
  status: "pending" | "running" | "completed" | "failed" | "cancelled" | "skipped";
  skip_reason?: "error" | "disabled";
  error_message?: string;
  inserted_at: string;
  executed_at?: string;
};

// Grouped hooks activity - for collapsing consecutive hooks
type GroupedHooksActivity = {
  type: "grouped_hooks";
  hooks: HookExecutionActivity[];
  firstTimestamp: string;
  lastTimestamp: string;
};

type ActivityItem =
  | TaskCreatedActivity
  | OutputActivity
  | HookExecutionActivity
  | GroupedHooksActivity;

/** Image attachment for chat input - holds the file and its data URL for preview */
interface ImageAttachment {
  /** Unique identifier for the attachment (e.g., "img-1") */
  id: string;
  /** Original file object */
  file: File;
  /** Base64 data URL for preview and transmission */
  dataUrl: string;
  /** Display name for the image */
  name: string;
}

/** Converts a File to a base64 data URL */
function fileToDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

// Filter function to determine which output lines to show
const shouldShowOutput = (line: OutputLine): boolean => {
  // Always show user messages
  if (line.type === "user" || line.role === "user") return true;

  // Show tool usage events (role === "tool")
  if (line.role === "tool") return true;

  // Show assistant messages, but filter out tool_use noise in string format
  if (line.type === "parsed" || line.role === "assistant") {
    const content = typeof line.content === "string" ? line.content : "";
    // Filter out tool_use events that leaked through (they show as %{...} Elixir maps)
    if (
      content.includes('"type" => "tool_use"') ||
      content.includes('"type": "tool_use"')
    ) {
      return false;
    }
    // Filter out tool_result events
    if (
      content.includes('"type" => "tool_result"') ||
      content.includes('"type": "tool_result"')
    ) {
      return false;
    }
    return true;
  }

  // Show system messages only for important events (started, completed, errors)
  if (line.type === "system" || line.role === "system") {
    const content = typeof line.content === "string" ? line.content : "";
    // Hide "Using tool:" messages as they're now shown via tool role
    if (content.startsWith("Using tool:")) return false;
    return (
      content.includes("Completed") ||
      content.includes("Failed") ||
      content.includes("Error") ||
      content.includes("Started")
    );
  }

  // Hide raw output by default (noise from executor)
  return false;
};

export default function TaskDetailsPanel(props: TaskDetailsPanelProps) {
  const [title, setTitle] = createSignal("");
  const [description, setDescription] = createSignal("");
  const [descriptionImages, setDescriptionImages] = createSignal<InlineImage[]>(
    [],
  );
  const [isEditingTitle, setIsEditingTitle] = createSignal(false);
  const [isEditingDescription, setIsEditingDescription] = createSignal(false);
  const [isSaving, setIsSaving] = createSignal(false);
  const [isDeleting, setIsDeleting] = createSignal(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = createSignal(false);
  const [error, setError] = createSignal<string | null>(null);
  const [input, setInput] = createSignal("");
  const [isSending, setIsSending] = createSignal(false);
  const [isRefining, setIsRefining] = createSignal(false);
  const [showDuplicateModal, setShowDuplicateModal] = createSignal(false);

  // Image attachments for chat input
  const [attachedImages, setAttachedImages] = createSignal<ImageAttachment[]>(
    [],
  );

  // Stopping executor state
  const [isStopping, setIsStopping] = createSignal(false);

  // Hide details preference (persisted to localStorage)
  // Hides: hooks, system messages (started/completed), timestamps
  const [hideDetails, setHideDetails] = createSignal(
    getStoredBoolean(HIDE_DETAILS_KEY, false)
  );

  // Toggle hide details and persist to localStorage
  const toggleHideDetails = () => {
    const newValue = !hideDetails();
    setHideDetails(newValue);
    setStoredBoolean(HIDE_DETAILS_KEY, newValue);
  };

  // Fullscreen preference (persisted to localStorage)
  const [isFullscreen, setIsFullscreen] = createSignal(
    getStoredBoolean(FULLSCREEN_KEY, false)
  );

  // Toggle fullscreen and persist to localStorage
  const toggleFullscreen = () => {
    const newValue = !isFullscreen();
    setIsFullscreen(newValue);
    setStoredBoolean(FULLSCREEN_KEY, newValue);
  };

  // Type for the column query result
  interface ColumnQueryResult {
    id: string;
    name: string;
    board_id: string;
  }

  // Query to get the TODO column for duplicating tasks
  const columnsQuery = useLiveQuery((q) =>
    q.from({ columns: columnsCollection }).select(({ columns }) => ({
      id: columns.id,
      name: columns.name,
      board_id: columns.board_id,
    })),
  );

  // Find the TODO column
  const todoColumn = (): ColumnQueryResult | undefined => {
    const cols = (columnsQuery.data ?? []) as ColumnQueryResult[];
    return cols.find((c) => c.name.toUpperCase() === "TODO");
  };

  // Check if task is in TODO column
  const isTodoTask = () => props.columnName?.toUpperCase() === "TODO";

  let messagesEndRef: HTMLDivElement | undefined;
  let inputRef: HTMLTextAreaElement | undefined;

  // Get task ID accessor
  const taskId = () => props.task?.id;

  // Executor integration (replaces old chat)
  const {
    output,
    isConnected,
    isLoading: isExecutorLoading,
    isRunning,
    error: executorError,
    agentStatus,
    agentStatusMessage,
    executors,
    todos,
    startExecutor,
    stopExecutor,
    reconnect,
  } = useTaskChat(taskId);

  // Helper to get timestamp from activity item for sorting
  const getActivityTimestamp = (item: ActivityItem): number => {
    switch (item.type) {
      case "task_created":
        return new Date(item.timestamp).getTime();
      case "hook_execution":
        // Use inserted_at for stable sorting (when hook was queued)
        return new Date(item.inserted_at).getTime();
      case "grouped_hooks":
        return new Date(item.firstTimestamp).getTime();
      case "output":
        return item.line.timestamp
          ? new Date(item.line.timestamp).getTime()
          : 0;
    }
  };

  // Group all hook activities together (always collapsed, even if just 1)
  const groupConsecutiveHooks = (items: ActivityItem[]): ActivityItem[] => {
    const result: ActivityItem[] = [];
    let currentHookGroup: HookExecutionActivity[] = [];

    const flushHookGroup = () => {
      if (currentHookGroup.length > 0) {
        // Always create a grouped hooks entry (even for 1 hook)
        result.push({
          type: "grouped_hooks",
          hooks: [...currentHookGroup],
          firstTimestamp: currentHookGroup[0].inserted_at,
          lastTimestamp: currentHookGroup[currentHookGroup.length - 1].inserted_at,
        });
      }
      currentHookGroup = [];
    };

    for (const item of items) {
      if (item.type === "hook_execution") {
        currentHookGroup.push(item);
      } else {
        // Flush any accumulated hooks before adding non-hook item
        if (currentHookGroup.length > 0) {
          flushHookGroup();
        }
        result.push(item);
      }
    }

    // Flush any remaining hooks at the end
    if (currentHookGroup.length > 0) {
      flushHookGroup();
    }

    return result;
  };

  // Combine task creation, hook history, and output into unified activity list
  const activityItems = createMemo((): ActivityItem[] => {
    const items: ActivityItem[] = [];

    // For TODO tasks, we don't show the description in the activity feed
    // (it's shown in the header instead as editable content)
    if (props.task && !isTodoTask()) {
      items.push({
        type: "task_created",
        timestamp: props.task.inserted_at,
        description: props.task.description,
      });
    }

    // Add hooks (unless details are hidden)
    if (!hideDetails()) {
      // Add currently running hooks from hook_queue (pending/running state)
      const hookQueue = props.task?.hook_queue;
      if (hookQueue && hookQueue.length > 0) {
        for (const entry of hookQueue) {
          // Only show pending/running hooks - completed ones are in history
          if (entry.status === "pending" || entry.status === "running") {
            items.push({
              type: "hook_execution",
              id: entry.id,
              name: entry.name,
              status: entry.status,
              skip_reason: entry.skip_reason,
              error_message: undefined,
              inserted_at: entry.inserted_at,
            });
          }
        }
      }

      // Add hook execution history (completed hooks)
      const hookHistory = props.task?.hook_history;
      if (hookHistory && hookHistory.length > 0) {
        for (const entry of hookHistory) {
          items.push({
            type: "hook_execution",
            id: entry.id,
            name: entry.name,
            status: entry.status,
            skip_reason: entry.skip_reason,
            error_message: entry.error_message,
            inserted_at: entry.inserted_at,
            executed_at: entry.executed_at,
          });
        }
      }
    }

    // Add filtered output lines
    for (const line of output()) {
      if (shouldShowOutput(line)) {
        // When hideDetails is on, also filter out system messages (started/completed/etc)
        if (hideDetails() && (line.type === "system" || line.role === "system")) {
          continue;
        }
        items.push({ type: "output", line });
      }
    }

    // Sort by timestamp to interleave activities correctly
    items.sort((a, b) => getActivityTimestamp(a) - getActivityTimestamp(b));

    // Group consecutive hooks together
    return groupConsecutiveHooks(items);
  });

  // Get agent status from task if available
  const taskAgentStatus = () => {
    const task = props.task;
    if (!task) return "idle" as AgentStatusType;
    return (task.agent_status || "idle") as AgentStatusType;
  };

  // Reset form when task changes
  createEffect(() => {
    if (props.task) {
      setTitle(props.task.title);
      setDescription(props.task.description || "");
      setDescriptionImages(
        parseDescriptionImages(props.task.description_images),
      );
      setIsEditingTitle(false);
      setIsEditingDescription(false);
      setError(null);
      setShowDeleteConfirm(false);
      setShowDuplicateModal(false);
    }
  });

  const handleDuplicate = () => {
    setShowDuplicateModal(true);
  };

  const handleDuplicateClose = () => {
    setShowDuplicateModal(false);
  };

  // Auto-scroll to bottom when new output arrives
  const scrollToBottom = () => {
    if (messagesEndRef) {
      messagesEndRef.scrollIntoView({ behavior: "smooth" });
    }
  };

  // Scroll on new output - use createEffect for side effects, not createMemo
  createEffect(() => {
    const items = activityItems();
    if (items.length > 0) {
      setTimeout(scrollToBottom, 100);
    }
  });

  onMount(() => {
    // Focus input on mount
    inputRef?.focus();
  });

  const handleSaveTitle = async () => {
    if (!props.task) return;
    if (!title().trim()) {
      setError("Title is required");
      return;
    }

    setIsSaving(true);
    setError(null);

    try {
      const input: UpdateTaskInput = {
        title: title().trim(),
      };

      await updateTask(props.task.id, input);
      setIsEditingTitle(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to update task");
    } finally {
      setIsSaving(false);
    }
  };

  const handleSaveDescription = async () => {
    if (!props.task) return;

    setIsSaving(true);
    setError(null);

    try {
      const images = descriptionImages();
      const input: UpdateTaskInput = {
        description: description().trim() || undefined,
        description_images:
          images.length > 0 ? prepareImagesForApi(images) : undefined,
      };

      await updateTask(props.task.id, input);
      setIsEditingDescription(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to update task");
    } finally {
      setIsSaving(false);
    }
  };

  const handleCancelDescriptionEdit = () => {
    if (props.task) {
      setDescription(props.task.description || "");
      setDescriptionImages(
        parseDescriptionImages(props.task.description_images),
      );
    }
    setIsEditingDescription(false);
    setError(null);
  };

  const handleDelete = async () => {
    if (!props.task) return;

    setIsDeleting(true);
    setError(null);

    try {
      await deleteTask(props.task.id);
      props.onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to delete task");
    } finally {
      setIsDeleting(false);
      setShowDeleteConfirm(false);
    }
  };

  const handleCancelEdit = () => {
    if (props.task) {
      setTitle(props.task.title);
    }
    setIsEditingTitle(false);
    setError(null);
  };

  const handleRefine = async () => {
    if (!props.task) return;

    setIsRefining(true);
    setError(null);

    try {
      await refineTask(props.task.id);
      // The task will be updated via Electric sync, so we don't need to manually update
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to refine task");
    } finally {
      setIsRefining(false);
    }
  };

  // Get the next available image ID for chat
  const getNextChatImageId = (): string => {
    const images = attachedImages();
    const existingNums = images
      .map((img) => {
        const match = img.id.match(/^img-(\d+)$/);
        return match ? parseInt(match[1], 10) : 0;
      })
      .filter((n) => n > 0);

    const maxNum = existingNums.length > 0 ? Math.max(...existingNums) : 0;
    return `img-${maxNum + 1}`;
  };

  // Handle paste event to capture images from clipboard
  const handlePaste = async (e: ClipboardEvent) => {
    const items = e.clipboardData?.items;
    if (!items) return;

    const imageItems: DataTransferItem[] = [];
    for (let i = 0; i < items.length; i++) {
      if (items[i].type.startsWith("image/")) {
        imageItems.push(items[i]);
      }
    }

    if (imageItems.length === 0) return;

    // Don't prevent default for text paste
    e.preventDefault();

    for (const item of imageItems) {
      const file = item.getAsFile();
      if (!file) continue;

      try {
        const dataUrl = await fileToDataUrl(file);
        const imageId = getNextChatImageId();
        const attachment: ImageAttachment = {
          id: imageId,
          file,
          dataUrl,
          name: file.name || `screenshot-${Date.now()}.png`,
        };
        setAttachedImages((prev) => [...prev, attachment]);

        // Insert placeholder at cursor position
        const textarea = inputRef;
        if (textarea) {
          const start = textarea.selectionStart;
          const end = textarea.selectionEnd;
          const text = input();
          const placeholder = `![${imageId}]()`;

          const newText =
            text.substring(0, start) + placeholder + text.substring(end);
          setInput(newText);

          // Update cursor position after the placeholder
          requestAnimationFrame(() => {
            const newPos = start + placeholder.length;
            textarea.selectionStart = newPos;
            textarea.selectionEnd = newPos;
            textarea.focus();
          });
        }
      } catch (err) {
        console.error("Failed to process pasted image:", err);
      }
    }
  };

  // Remove an attached image and its placeholder from text
  const removeImage = (id: string) => {
    setAttachedImages((prev) => prev.filter((img) => img.id !== id));
    // Also remove the placeholder from the input text
    const placeholder = `![${id}]()`;
    setInput((prev) => prev.replaceAll(placeholder, ""));
  };

  const handleStartExecutor = async (e: Event) => {
    e.preventDefault();
    const prompt = input().trim();
    const images = attachedImages();

    // Allow sending with just images (no text required if images present)
    if (
      (!prompt && images.length === 0) ||
      isSending() ||
      !isConnected() ||
      isRunning()
    )
      return;

    setIsSending(true);
    setInput("");
    setAttachedImages([]);

    try {
      const task = props.task;
      if (!task) {
        throw new Error("No task selected");
      }

      // Start the executor with the user's prompt
      // Note: Backend handles moving task to "In Progress" if needed
      // This will also create the user message in the database
      const imageData = images.map((img) => ({
        name: img.name,
        data: img.dataUrl,
        mimeType: img.file.type,
      }));
      await startExecutor(prompt, "claude_code", imageData);
    } catch (err) {
      console.error("Failed to start work:", err);
      setError(err instanceof Error ? err.message : "Failed to start work");
    } finally {
      setIsSending(false);
      inputRef?.focus();
    }
  };

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleStartExecutor(e);
    }
  };

  const handleStopExecutor = async () => {
    if (isStopping() || !isRunning()) return;

    setIsStopping(true);
    try {
      await stopExecutor();
    } catch (err) {
      console.error("Failed to stop executor:", err);
      setError(err instanceof Error ? err.message : "Failed to stop executor");
    } finally {
      setIsStopping(false);
    }
  };

  const formatTime = (dateStr?: string) => {
    if (!dateStr) return "";
    const date = new Date(dateStr);
    return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  };

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr);
    return date.toLocaleDateString([], {
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  const openInEditor = async (path: string) => {
    try {
      const response = await fetch("/api/editor/open", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ path }),
      });
      if (!response.ok) {
        const data = await response.json();
        setError(data.error || "Failed to open editor");
      }
    } catch (err) {
      setError("Failed to open editor");
      console.error("Failed to open editor:", err);
    }
  };

  const openFolder = async (path: string) => {
    try {
      const response = await fetch("/api/folder/open", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ path }),
      });
      if (!response.ok) {
        const data = await response.json();
        setError(data.error || "Failed to open folder");
      }
    } catch (err) {
      setError("Failed to open folder");
      console.error("Failed to open folder:", err);
    }
  };

  // Check if Claude Code is available
  const hasClaudeCode = () =>
    executors().some((e) => e.type === "claude_code" && e.available);

  return (
    <SidePanel
      isOpen={props.isOpen}
      onClose={props.onClose}
      title=""
      subtitle={props.columnName}
      width={isFullscreen() ? "full" : "lg"}
    >
      <Show when={props.task}>
        {(task) => (
          <div class="flex flex-col h-full">
            {/* Header with Title and Actions */}
            <div class="flex-shrink-0 px-6 py-4 border-b border-gray-800">
              <div class="flex items-start justify-between gap-4">
                <div class="flex-1">
                  <Show
                    when={isEditingTitle()}
                    fallback={
                      <h2
                        class="text-lg font-semibold text-white cursor-pointer hover:text-brand-400 transition-colors"
                        onClick={() => setIsEditingTitle(true)}
                        title="Click to edit"
                      >
                        {task().title}
                      </h2>
                    }
                  >
                    <div class="flex gap-2">
                      <input
                        type="text"
                        value={title()}
                        onInput={(e) => setTitle(e.currentTarget.value)}
                        class="flex-1 px-3 py-1 bg-gray-800 border border-gray-700 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-brand-500 text-lg font-semibold"
                        autofocus
                        onKeyDown={(e) => {
                          if (e.key === "Enter") handleSaveTitle();
                          if (e.key === "Escape") handleCancelEdit();
                        }}
                      />
                      <button
                        onClick={handleSaveTitle}
                        disabled={isSaving()}
                        class="px-3 py-1 bg-brand-600 hover:bg-brand-700 disabled:bg-brand-800 text-white rounded-lg text-sm"
                      >
                        Save
                      </button>
                      <button
                        onClick={handleCancelEdit}
                        class="px-3 py-1 bg-gray-700 hover:bg-gray-600 text-white rounded-lg text-sm"
                      >
                        Cancel
                      </button>
                    </div>
                  </Show>
                  {/* Branch name - shown as small text below title */}
                  <Show
                    when={task().worktree_branch || task().custom_branch_name}
                  >
                    <p class="text-xs text-gray-500 font-mono mt-1">
                      {task().worktree_branch || task().custom_branch_name}
                    </p>
                  </Show>
                </div>

                {/* Status and Actions */}
                <div class="flex items-center gap-2">
                  <AgentStatusBadge status={taskAgentStatus()} />
                  <Show when={task().worktree_path}>
                    {/* Open Folder button */}
                    <button
                      onClick={() => openFolder(task().worktree_path!)}
                      class="p-1.5 text-gray-400 hover:text-brand-400 hover:bg-brand-500/10 rounded-lg transition-colors"
                      title="Open Folder"
                    >
                      <FolderIcon class="w-4 h-4" />
                    </button>
                    {/* Open in Code Editor button */}
                    <button
                      onClick={() => openInEditor(task().worktree_path!)}
                      class="p-1.5 text-gray-400 hover:text-brand-400 hover:bg-brand-500/10 rounded-lg transition-colors"
                      title="Open in Code Editor"
                    >
                      <CodeEditorIcon class="w-4 h-4" />
                    </button>
                  </Show>
                  {/* PR Link - show when task has a PR */}
                  <Show when={task().pr_url && task().pr_status}>
                    <a
                      href={task().pr_url!}
                      target="_blank"
                      rel="noopener noreferrer"
                      class={`flex items-center gap-1 px-2 py-1 text-xs rounded-lg transition-colors ${getPRBadgeHoverClasses(task().pr_status!)}`}
                      title="View Pull Request"
                    >
                      <PRIcon status={task().pr_status!} class="w-3.5 h-3.5" />
                      <span>#{task().pr_number}</span>
                    </a>
                  </Show>
                  {/* Refine button - uses LLM to improve task description (only in TODO) */}
                  <Show when={isTodoTask()}>
                    <button
                      onClick={handleRefine}
                      disabled={isRefining()}
                      class="p-1.5 text-gray-400 hover:text-brand-400 hover:bg-brand-500/10 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                      title="Refine task with AI"
                    >
                      <Show
                        when={isRefining()}
                        fallback={<LightningIcon class="w-4 h-4" />}
                      >
                        <LoadingSpinner class="w-4 h-4" />
                      </Show>
                    </button>
                  </Show>
                  {/* Duplicate button */}
                  <Show when={todoColumn()}>
                    <button
                      onClick={handleDuplicate}
                      class="p-1.5 text-gray-400 hover:text-brand-400 hover:bg-brand-500/10 rounded-lg transition-colors"
                      title="Duplicate task"
                    >
                      <DuplicateIcon class="w-4 h-4" />
                    </button>
                  </Show>
                  {/* Hide/Show details toggle */}
                  <button
                    onClick={toggleHideDetails}
                    class={`p-1.5 rounded-lg transition-colors ${
                      hideDetails()
                        ? "text-brand-400 bg-brand-500/10"
                        : "text-gray-400 hover:text-brand-400 hover:bg-brand-500/10"
                    }`}
                    title={hideDetails() ? "Show details" : "Hide details"}
                  >
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <Show
                        when={hideDetails()}
                        fallback={
                          <path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                        }
                      >
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                        <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                      </Show>
                    </svg>
                  </button>
                  {/* Fullscreen toggle */}
                  <button
                    onClick={toggleFullscreen}
                    class={`p-1.5 rounded-lg transition-colors ${
                      isFullscreen()
                        ? "text-brand-400 bg-brand-500/10"
                        : "text-gray-400 hover:text-brand-400 hover:bg-brand-500/10"
                    }`}
                    title={isFullscreen() ? "Exit fullscreen" : "Fullscreen"}
                  >
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <Show
                        when={isFullscreen()}
                        fallback={
                          <path stroke-linecap="round" stroke-linejoin="round" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
                        }
                      >
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 9V4.5M9 9H4.5M9 9L3.75 3.75M9 15v4.5M9 15H4.5M9 15l-5.25 5.25M15 9h4.5M15 9V4.5M15 9l5.25-5.25M15 15h4.5M15 15v4.5m0-4.5l5.25 5.25" />
                      </Show>
                    </svg>
                  </button>
                  <button
                    onClick={() => setShowDeleteConfirm(true)}
                    class="p-1.5 text-gray-400 hover:text-red-400 hover:bg-red-500/10 rounded-lg transition-colors"
                    title="Delete task"
                  >
                    <TrashIcon class="w-4 h-4" />
                  </button>
                </div>
              </div>

              {/* Connection Status */}
              <div class="flex items-center gap-3 mt-2">
                <span
                  class={`flex items-center gap-1.5 text-xs ${
                    isConnected() ? "text-green-400" : "text-red-400"
                  }`}
                >
                  <span
                    class={`w-1.5 h-1.5 rounded-full ${
                      isConnected() ? "bg-green-500" : "bg-red-500"
                    }`}
                  />
                  {isConnected() ? "Connected" : "Disconnected"}
                </span>
                <Show when={!isConnected()}>
                  <button
                    onClick={() => reconnect()}
                    class="text-xs text-brand-400 hover:text-brand-300"
                  >
                    Reconnect
                  </button>
                </Show>
                <Show when={isRunning()}>
                  <span class="flex items-center gap-1.5 text-xs text-amber-400">
                    <span class="w-1.5 h-1.5 bg-amber-500 rounded-full animate-pulse" />
                    Executor running
                  </span>
                </Show>
                <Show when={agentStatus() !== "idle"}>
                  <span class="text-xs text-gray-400">
                    {agentStatus().replace("_", " ")}
                    <Show when={agentStatusMessage()}>
                      {" - "}
                      {agentStatusMessage()}
                    </Show>
                  </span>
                </Show>
              </div>

              {/* LLM Todo List - shows agent's progress during execution */}
              <LLMTodoList todos={todos()} isRunning={isRunning()} />

              {/* Hook Queue - shows pending/running/completed/cancelled hooks */}
              <Show when={task().hook_queue && task().hook_queue!.length > 0}>
                <HookQueueDisplay hooks={task().hook_queue!} />
              </Show>

              {/* Subtasks Section - for parent tasks or tasks that can have subtasks */}
              <Show when={isTodoTask()}>
                <div class="mt-4 pt-4 border-t border-gray-700">
                  <SubtaskList
                    task={task()}
                    onSubtaskClick={(subtaskId) => {
                      // TODO: Navigate to subtask details
                      console.log("Subtask clicked:", subtaskId);
                    }}
                  />
                </div>
              </Show>

              {/* Executor availability notice */}
              <Show
                when={
                  isConnected() && !hasClaudeCode() && executors().length > 0
                }
              >
                <div class="mt-2 p-2 bg-amber-500/10 border border-amber-500/30 rounded-lg text-amber-400 text-sm">
                  Claude Code is not available. Make sure it's installed and in
                  PATH.
                </div>
              </Show>

              {/* Error Display */}
              <div class="mt-2">
                <ErrorBanner message={error() || executorError()} size="sm" />
              </div>

              {/* Delete Confirmation */}
              <Show when={showDeleteConfirm()}>
                <div class="mt-3 p-3 bg-red-500/10 border border-red-500/30 rounded-lg space-y-2">
                  <p class="text-red-400 text-sm">
                    Delete this task? This cannot be undone.
                  </p>
                  <div class="flex gap-2">
                    <button
                      onClick={() => setShowDeleteConfirm(false)}
                      class="flex-1 py-1.5 px-3 bg-gray-800 hover:bg-gray-700 text-gray-300 rounded-lg text-sm transition-colors"
                    >
                      Cancel
                    </button>
                    <button
                      onClick={handleDelete}
                      disabled={isDeleting()}
                      class="flex-1 py-1.5 px-3 bg-red-600 hover:bg-red-700 disabled:bg-red-800 disabled:cursor-not-allowed text-white rounded-lg text-sm transition-colors flex items-center justify-center gap-2"
                    >
                      <Show when={isDeleting()} fallback="Delete">
                        <div class="animate-spin rounded-full h-3 w-3 border-b-2 border-white" />
                      </Show>
                    </button>
                  </div>
                </div>
              </Show>
            </div>

            {/* TODO Task: Editable Description Section */}
            <Show when={isTodoTask()}>
              <div class="flex-shrink-0 max-h-[40vh] overflow-y-auto px-6 py-4 border-b border-gray-800 bg-gray-900/30">
                <div class="flex items-center justify-between mb-2">
                  <h3 class="text-sm font-medium text-gray-400">Description</h3>
                  <Show when={!isEditingDescription()}>
                    <button
                      onClick={() => setIsEditingDescription(true)}
                      class="text-xs text-brand-400 hover:text-brand-300"
                    >
                      Edit
                    </button>
                  </Show>
                </div>
                <Show
                  when={isEditingDescription()}
                  fallback={
                    <Show
                      when={task().description}
                      fallback={
                        <p
                          class="text-sm text-gray-500 italic cursor-pointer hover:text-gray-400"
                          onClick={() => setIsEditingDescription(true)}
                        >
                          Click to add a description...
                        </p>
                      }
                    >
                      <div
                        class="text-sm text-gray-300 prose prose-sm prose-invert max-w-none prose-p:my-1 prose-ul:my-1 prose-li:my-0 prose-headings:my-2 prose-headings:text-gray-200 cursor-pointer hover:bg-gray-800/50 rounded-lg p-2 -m-2 transition-colors"
                        innerHTML={
                          marked.parse(
                            renderDescriptionWithImages(
                              task().description || "",
                              parseDescriptionImages(task().description_images),
                              task().id,
                            ),
                          ) as string
                        }
                        onClick={() => setIsEditingDescription(true)}
                        title="Click to edit"
                      />
                    </Show>
                  }
                >
                  <div class="space-y-2">
                    <ImageTextarea
                      value={description()}
                      onChange={setDescription}
                      images={descriptionImages()}
                      onImagesChange={setDescriptionImages}
                      placeholder="Add a description (Markdown supported, paste images with Ctrl+V)..."
                      rows={6}
                      autofocus
                    />
                    <div class="flex gap-2 justify-end">
                      <button
                        onClick={handleCancelDescriptionEdit}
                        class="px-3 py-1.5 bg-gray-700 hover:bg-gray-600 text-white rounded-lg text-sm"
                      >
                        Cancel
                      </button>
                      <button
                        onClick={handleSaveDescription}
                        disabled={isSaving()}
                        class="px-3 py-1.5 bg-brand-600 hover:bg-brand-700 disabled:bg-brand-800 text-white rounded-lg text-sm"
                      >
                        {isSaving() ? "Saving..." : "Save"}
                      </button>
                    </div>
                  </div>
                </Show>
              </div>
            </Show>

            {/* Activity Feed - Scrollable */}
            <div class="flex-1 overflow-y-auto px-6 py-4">
              <Show when={isExecutorLoading()}>
                <div class="flex items-center justify-center py-8">
                  <div class="flex items-center gap-2 text-gray-400">
                    <svg
                      class="w-5 h-5 animate-spin"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <circle
                        class="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        stroke-width="4"
                      />
                      <path
                        class="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      />
                    </svg>
                    <span>Connecting...</span>
                  </div>
                </div>
              </Show>

              <Show when={!isExecutorLoading()}>
                <div class="space-y-4">
                  <For each={activityItems()}>
                    {(item) => (
                      <Show
                        when={item.type === "task_created" ? item : null}
                        fallback={
                          <Show
                            when={item.type === "hook_execution" ? item : null}
                            fallback={
                              <Show
                                when={item.type === "grouped_hooks" ? item : null}
                                fallback={
                                  <Show when={item.type === "output" ? item : null}>
                                    {(outputItem) => (
                                      <OutputBubble
                                        line={outputItem().line}
                                        formatTime={formatTime}
                                        hideDetails={hideDetails()}
                                      />
                                    )}
                                  </Show>
                                }
                              >
                                {(groupedItem) => (
                                  <GroupedHooksActivityComponent
                                    hooks={groupedItem().hooks}
                                    formatDate={formatDate}
                                  />
                                )}
                              </Show>
                            }
                          >
                            {(hookItem) => (
                              <HookExecutionActivityComponent
                                name={hookItem().name}
                                status={hookItem().status}
                                skip_reason={hookItem().skip_reason}
                                error_message={hookItem().error_message}
                                inserted_at={hookItem().inserted_at}
                                formatDate={formatDate}
                              />
                            )}
                          </Show>
                        }
                      >
                        {(createdItem) => (
                          <TaskCreatedActivityComponent
                            timestamp={createdItem().timestamp}
                            description={createdItem().description}
                            formatDate={formatDate}
                          />
                        )}
                      </Show>
                    )}
                  </For>
                  <div ref={messagesEndRef} />
                </div>
              </Show>
            </div>

            {/* Executor Input - Fixed at bottom */}
            <div class="flex-shrink-0 px-6 py-4 border-t border-gray-800 bg-gray-900">
              {/* Image thumbnails with IDs */}
              <Show when={attachedImages().length > 0}>
                <div class="flex flex-wrap gap-2 mb-3 p-2 bg-gray-800/50 border border-gray-700 rounded-lg">
                  <For each={attachedImages()}>
                    {(img) => {
                      const isInText = () => input().includes(`![${img.id}]()`);
                      return (
                        <div
                          class={`relative group flex items-center gap-2 px-2 py-1 rounded border ${
                            isInText()
                              ? "bg-gray-700/50 border-gray-600"
                              : "bg-yellow-500/10 border-yellow-500/30"
                          }`}
                        >
                          <img
                            src={img.dataUrl}
                            alt={img.name}
                            class="w-10 h-10 object-cover rounded"
                          />
                          <span
                            class={`text-xs font-mono ${isInText() ? "text-gray-400" : "text-yellow-400"}`}
                          >
                            {img.id}
                          </span>
                          <Show when={!isInText()}>
                            <span
                              class="text-xs text-yellow-500"
                              title="Not in text"
                            >
                              !
                            </span>
                          </Show>
                          <button
                            type="button"
                            onClick={() => removeImage(img.id)}
                            class="ml-1 text-gray-500 hover:text-red-400 transition-colors"
                            title="Remove image"
                          >
                            <svg
                              class="w-4 h-4"
                              viewBox="0 0 24 24"
                              fill="none"
                              stroke="currentColor"
                              stroke-width="2"
                            >
                              <path d="M18 6L6 18M6 6l12 12" />
                            </svg>
                          </button>
                        </div>
                      );
                    }}
                  </For>
                </div>
              </Show>
              <form onSubmit={handleStartExecutor} class="flex gap-2">
                <textarea
                  ref={inputRef}
                  value={input()}
                  onInput={(e) => setInput(e.currentTarget.value)}
                  onKeyDown={handleKeyDown}
                  onPaste={handlePaste}
                  placeholder={
                    !isConnected()
                      ? "Connecting..."
                      : isRunning()
                        ? "Executor is running..."
                        : hasClaudeCode()
                          ? "Enter a prompt or paste an image (Ctrl+V)..."
                          : "Claude Code not available"
                  }
                  disabled={
                    !isConnected() ||
                    isSending() ||
                    isRunning() ||
                    !hasClaudeCode()
                  }
                  rows={1}
                  class="flex-1 px-4 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent disabled:opacity-50 disabled:cursor-not-allowed resize-none"
                />
                <Show
                  when={isRunning()}
                  fallback={
                    <button
                      type="submit"
                      disabled={
                        !isConnected() ||
                        isSending() ||
                        (!input().trim() && attachedImages().length === 0) ||
                        !hasClaudeCode()
                      }
                      class="px-4 py-2 bg-brand-600 hover:bg-brand-700 disabled:bg-brand-800 disabled:cursor-not-allowed text-white rounded-lg transition-colors flex items-center gap-2"
                      title="Start Claude Code"
                    >
                      <Show
                        when={isSending()}
                        fallback={
                          <svg
                            class="w-4 h-4"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke="currentColor"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"
                            />
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                            />
                          </svg>
                        }
                      >
                        <svg
                          class="w-4 h-4 animate-spin"
                          fill="none"
                          viewBox="0 0 24 24"
                        >
                          <circle
                            class="opacity-25"
                            cx="12"
                            cy="12"
                            r="10"
                            stroke="currentColor"
                            stroke-width="4"
                          />
                          <path
                            class="opacity-75"
                            fill="currentColor"
                            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                          />
                        </svg>
                      </Show>
                    </button>
                  }
                >
                  <button
                    type="button"
                    onClick={handleStopExecutor}
                    disabled={isStopping()}
                    class="px-4 py-2 bg-red-600 hover:bg-red-700 disabled:bg-red-800 disabled:cursor-not-allowed text-white rounded-lg transition-colors flex items-center gap-2"
                    title="Stop Executor"
                  >
                    <Show
                      when={isStopping()}
                      fallback={
                        <svg
                          class="w-4 h-4"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                        >
                          <rect
                            x="6"
                            y="6"
                            width="12"
                            height="12"
                            rx="1"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            fill="currentColor"
                          />
                        </svg>
                      }
                    >
                      <svg
                        class="w-4 h-4 animate-spin"
                        fill="none"
                        viewBox="0 0 24 24"
                      >
                        <circle
                          class="opacity-25"
                          cx="12"
                          cy="12"
                          r="10"
                          stroke="currentColor"
                          stroke-width="4"
                        />
                        <path
                          class="opacity-75"
                          fill="currentColor"
                          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                        />
                      </svg>
                    </Show>
                  </button>
                </Show>
              </form>
            </div>
          </div>
        )}
      </Show>

      {/* Duplicate Task Modal */}
      <Show when={props.task}>
        {(getTask) => {
          const col = todoColumn();
          // Only render if we have a TODO column for the duplicate
          if (!col) return null;
          return (
            <CreateTaskModal
              isOpen={showDuplicateModal()}
              onClose={handleDuplicateClose}
              columnId={col.id}
              columnName={col.name}
              initialValues={{
                title: `${getTask().title} (copy)`,
                description: getTask().description || undefined,
              }}
            />
          );
        }}
      </Show>
    </SidePanel>
  );
}

// Task Created Activity Component
interface TaskCreatedActivityComponentProps {
  timestamp: string;
  description: string | null;
  formatDate: (dateStr: string) => string;
}

/** CSS classes for task created activity description styling */
const TASK_CREATED_PROSE_CLASSES =
  "prose prose-sm prose-invert max-w-none prose-p:my-1 prose-ul:my-1 prose-li:my-0 prose-headings:my-2 prose-headings:text-gray-200";

function TaskCreatedActivityComponent(
  props: TaskCreatedActivityComponentProps,
) {
  return (
    <div class="flex items-start gap-3 group">
      <div class="flex-shrink-0 w-8 h-8 rounded-full bg-brand-500/20 border border-brand-500/30 flex items-center justify-center">
        <svg
          class="w-4 h-4 text-brand-400"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 6v6m0 0v6m0-6h6m-6 0H6"
          />
        </svg>
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-baseline gap-2">
          <span class="text-sm font-medium text-gray-300">Task Created</span>
          <span class="text-xs text-gray-500">
            {props.formatDate(props.timestamp)}
          </span>
        </div>
        <Show when={props.description}>
          <div
            class={`mt-2 text-sm text-gray-300 ${TASK_CREATED_PROSE_CLASSES}`}
            innerHTML={renderMarkdown(props.description || "")}
          />
        </Show>
      </div>
    </div>
  );
}

// Hook Execution Activity Component
interface HookExecutionActivityComponentProps {
  name: string;
  status: "pending" | "running" | "completed" | "failed" | "cancelled" | "skipped";
  skip_reason?: "error" | "disabled";
  error_message?: string;
  inserted_at: string;
  formatDate: (dateStr: string) => string;
}

function HookExecutionActivityComponent(
  props: HookExecutionActivityComponentProps,
) {
  const statusConfig = () => {
    switch (props.status) {
      case "pending":
        return {
          label: "Pending",
          textClass: "text-gray-400",
        };
      case "running":
        return {
          label: "Running...",
          textClass: "text-blue-400",
        };
      case "completed":
        return {
          label: "Hook completed",
          textClass: "text-green-400",
        };
      case "failed":
        return {
          label: "Hook failed",
          textClass: "text-red-400",
        };
      case "cancelled":
        return {
          label: "Hook cancelled",
          textClass: "text-yellow-400",
        };
      case "skipped":
        return {
          label:
            props.skip_reason === "disabled"
              ? "Hook skipped (disabled)"
              : "Hook skipped (error)",
          textClass: "text-gray-400",
        };
    }
  };

  const config = statusConfig();

  return (
    <div
      class="flex items-center gap-2 text-xs py-0.5"
      title={props.error_message || undefined}
    >
      <span class={`font-medium ${config.textClass}`}>
        {props.name}
      </span>
      <span class="text-gray-500">{config.label}</span>
      <span class="text-gray-600 ml-auto">
        {props.formatDate(props.inserted_at)}
      </span>
      <Show when={props.error_message}>
        <span class="text-red-400 truncate max-w-[150px]" title={props.error_message}>
          {props.error_message}
        </span>
      </Show>
    </div>
  );
}

// Grouped Hooks Activity Component - collapsible group of hooks
interface GroupedHooksActivityComponentProps {
  hooks: HookExecutionActivity[];
  formatDate: (dateStr: string) => string;
}

function GroupedHooksActivityComponent(
  props: GroupedHooksActivityComponentProps,
) {
  const [isExpanded, setIsExpanded] = createSignal(false);

  // Count hooks by status
  const statusCounts = () => {
    const counts = { pending: 0, running: 0, completed: 0, failed: 0, cancelled: 0, skipped: 0 };
    for (const hook of props.hooks) {
      counts[hook.status]++;
    }
    return counts;
  };

  // Build summary text like "7 successful, 3 failed, 2 skipped"
  const summaryText = () => {
    const counts = statusCounts();
    const parts: string[] = [];
    if (counts.running > 0) parts.push(`${counts.running} running`);
    if (counts.pending > 0) parts.push(`${counts.pending} pending`);
    if (counts.completed > 0) parts.push(`${counts.completed} successful`);
    if (counts.failed > 0) parts.push(`${counts.failed} failed`);
    if (counts.cancelled > 0) parts.push(`${counts.cancelled} cancelled`);
    if (counts.skipped > 0) parts.push(`${counts.skipped} skipped`);
    return parts.join(", ");
  };

  // Determine overall status color based on worst status
  const overallStatus = () => {
    const counts = statusCounts();
    if (counts.running > 0) return "running";
    if (counts.pending > 0) return "pending";
    if (counts.failed > 0) return "failed";
    if (counts.cancelled > 0) return "cancelled";
    if (counts.skipped > 0) return "skipped";
    return "completed";
  };

  const statusColors = () => {
    const status = overallStatus();
    switch (status) {
      case "running":
        return { textClass: "text-blue-400" };
      case "pending":
        return { textClass: "text-gray-400" };
      case "completed":
        return { textClass: "text-green-400" };
      case "failed":
        return { textClass: "text-red-400" };
      case "cancelled":
        return { textClass: "text-yellow-400" };
      case "skipped":
        return { textClass: "text-gray-400" };
      default:
        return { textClass: "text-gray-400" };
    }
  };

  const colors = statusColors();

  return (
    <div class="py-1 px-2">
      <button
        onClick={() => setIsExpanded(!isExpanded())}
        class={`flex items-center gap-2 text-sm font-medium ${colors.textClass} hover:underline cursor-pointer`}
      >
        <span>{props.hooks.length} {props.hooks.length === 1 ? "hook" : "hooks"}</span>
        <span class="text-gray-500 font-normal">({summaryText()})</span>
        <svg
          class={`w-4 h-4 transition-transform ${isExpanded() ? "rotate-180" : ""}`}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M19 9l-7 7-7-7"
          />
        </svg>
      </button>

      <Show when={isExpanded()}>
        <div class="mt-2 space-y-1 pl-4 border-l-2 border-gray-700">
          <For each={props.hooks}>
            {(hook) => (
              <HookExecutionActivityComponent
                name={hook.name}
                status={hook.status}
                skip_reason={hook.skip_reason}
                error_message={hook.error_message}
                inserted_at={hook.inserted_at}
                formatDate={props.formatDate}
              />
            )}
          </For>
        </div>
      </Show>
    </div>
  );
}

// Output Bubble Component - displays executor output
interface OutputBubbleProps {
  line: OutputLine;
  formatTime: (dateStr?: string) => string;
  hideDetails?: boolean;
}

function OutputBubble(props: OutputBubbleProps) {
  const isSystem = () =>
    props.line.type === "system" || props.line.role === "system";
  const isUser = () => props.line.type === "user" || props.line.role === "user";
  const isTool = () => props.line.role === "tool";
  const isAssistant = () =>
    props.line.type === "parsed" || props.line.role === "assistant";

  const getTextContent = (): string => {
    if (typeof props.line.content === "string") {
      return props.line.content;
    }
    return JSON.stringify(props.line.content, null, 2);
  };

  // Get tool info from parsed content
  const getToolInfo = (): { tool: string; input?: Record<string, unknown> } | null => {
    const content = props.line.content;
    if (typeof content === "object" && content !== null) {
      const parsed = content as Record<string, unknown>;
      if (parsed.type === "tool_use" && typeof parsed.tool === "string") {
        return {
          tool: parsed.tool,
          input: parsed.input as Record<string, unknown> | undefined,
        };
      }
    }
    return null;
  };

  // Format tool input for display (extract key details)
  const formatToolInput = (input: Record<string, unknown> | undefined): string => {
    if (!input) return "";

    // For common tools, show relevant info
    if (typeof input.file_path === "string") {
      return input.file_path;
    }
    if (typeof input.pattern === "string") {
      return input.pattern;
    }
    if (typeof input.command === "string") {
      const cmd = input.command as string;
      return cmd.length > 60 ? cmd.slice(0, 60) + "..." : cmd;
    }
    if (typeof input.url === "string") {
      return input.url;
    }
    if (typeof input.query === "string") {
      return input.query;
    }

    // Fallback: show first string value
    for (const value of Object.values(input)) {
      if (typeof value === "string" && value.length > 0) {
        return value.length > 50 ? value.slice(0, 50) + "..." : value;
      }
    }
    return "";
  };

  // User messages display on the right with brand color
  if (isUser()) {
    return (
      <div class="flex justify-end">
        <div class="max-w-[85%] rounded-lg px-4 py-2 bg-brand-600 text-white">
          <div class="whitespace-pre-wrap break-words">{getTextContent()}</div>
          <Show when={!props.hideDetails}>
            <div class="mt-1 text-xs text-brand-200">
              {props.formatTime(props.line.timestamp)}
            </div>
          </Show>
        </div>
      </div>
    );
  }

  // Tool usage messages display as compact inline items
  if (isTool()) {
    const toolInfo = getToolInfo();
    if (toolInfo) {
      const detail = formatToolInput(toolInfo.input);
      return (
        <div class="flex items-center gap-2 py-1 px-2 text-xs">
          <div class="flex items-center gap-1.5 text-cyan-400">
            <svg
              class="w-3.5 h-3.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M11.42 15.17L17.25 21A2.652 2.652 0 0021 17.25l-5.877-5.877M11.42 15.17l2.496-3.03c.317-.384.74-.626 1.208-.766M11.42 15.17l-4.655 5.653a2.548 2.548 0 11-3.586-3.586l6.837-5.63m5.108-.233c.55-.164 1.163-.188 1.743-.14a4.5 4.5 0 004.486-6.336l-3.276 3.277a3.004 3.004 0 01-2.25-2.25l3.276-3.276a4.5 4.5 0 00-6.336 4.486c.091 1.076-.071 2.264-.904 2.95l-.102.085m-1.745 1.437L5.909 7.5H4.5L2.25 3.75l1.5-1.5L7.5 4.5v1.409l4.26 4.26m-1.745 1.437l1.745-1.437m6.615 8.206L15.75 15.75M4.867 19.125h.008v.008h-.008v-.008z"
              />
            </svg>
            <span class="font-medium">{toolInfo.tool}</span>
          </div>
          <Show when={detail}>
            <span class="text-gray-500 truncate max-w-[300px]" title={detail}>
              {detail}
            </span>
          </Show>
          <Show when={!props.hideDetails}>
            <span class="text-gray-600 ml-auto">
              {props.formatTime(props.line.timestamp)}
            </span>
          </Show>
        </div>
      );
    }
  }

  // System messages display as compact inline text
  if (isSystem()) {
    return (
      <div class="flex items-center gap-2 py-1 px-2 text-xs">
        <span class="text-amber-400">{getTextContent()}</span>
        <Show when={!props.hideDetails}>
          <span class="text-gray-600 ml-auto">
            {props.formatTime(props.line.timestamp)}
          </span>
        </Show>
      </div>
    );
  }

  // Assistant messages (from Claude) display with markdown rendering
  if (isAssistant()) {
    return (
      <div class="flex justify-start">
        <div class="max-w-[85%] rounded-lg px-4 py-2 bg-gray-800 text-gray-100">
          <div
            class={CHAT_PROSE_CLASSES}
            innerHTML={renderMarkdown(getTextContent())}
          />
          <Show when={!props.hideDetails}>
            <div class="mt-1 text-xs text-gray-500">
              {props.formatTime(props.line.timestamp)}
            </div>
          </Show>
        </div>
      </div>
    );
  }

  // Fallback for raw output (should be filtered out, but just in case)
  return (
    <div class="flex justify-start">
      <div class="max-w-[95%] rounded-lg px-4 py-2 bg-gray-900 border border-gray-700 text-gray-300 font-mono text-sm">
        <pre class="whitespace-pre-wrap break-words overflow-x-auto">
          {getTextContent()}
        </pre>
        <Show when={!props.hideDetails}>
          <div class="mt-1 text-xs text-gray-600">
            {props.formatTime(props.line.timestamp)}
          </div>
        </Show>
      </div>
    </div>
  );
}
