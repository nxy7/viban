import { useNavigate } from "@solidjs/router";
import { useLiveQuery, useQuery } from "@tanstack/solid-db";
import { marked } from "marked";
import {
  createEffect,
  createMemo,
  createResource,
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

const HIDE_DETAILS_KEY = "viban:hideDetails";
const FULLSCREEN_KEY = "viban:fullscreen";

function getStoredBoolean(key: string, defaultValue: boolean): boolean {
  if (typeof window === "undefined") return defaultValue;
  const stored = localStorage.getItem(key);
  if (stored === null) return defaultValue;
  return stored === "true";
}

function setStoredBoolean(key: string, value: boolean): void {
  if (typeof window === "undefined") return;
  localStorage.setItem(key, String(value));
}
import * as sdk from "~/lib/generated/ash";
import { getErrorMessage } from "~/lib/errorUtils";
import { CHAT_PROSE_CLASSES, renderMarkdown } from "~/lib/markdown";
import { useSystem } from "~/lib/SystemContext";
import { getPRBadgeHoverClasses } from "~/lib/taskStyles";
import {
  columnsCollection,
  type Task,
  toDecimal,
  unwrap,
} from "~/lib/useKanban";
import { type OutputLine, useTaskChat } from "~/lib/useTaskChat";
import { AgentStatusBadge, type AgentStatusType } from "./AgentStatus";
import CreatePRModal from "./CreatePRModal";
import CreateTaskModal from "./CreateTaskModal";
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
  status:
    | "pending"
    | "running"
    | "completed"
    | "failed"
    | "cancelled"
    | "skipped";
  skip_reason?:
    | "error"
    | "disabled"
    | "column_change"
    | "server_restart"
    | "user_cancelled"
    | null;
  error_message?: string | null;
  queued_at: string | null;
  started_at?: string | null;
  completed_at?: string | null;
};

type GroupedHooksActivity = {
  type: "grouped_hooks";
  hooks: HookExecutionActivity[];
};

type ActivityItem =
  | TaskCreatedActivity
  | OutputActivity
  | HookExecutionActivity
  | GroupedHooksActivity;

interface ImageAttachment {
  id: string;
  file: File;
  dataUrl: string;
  name: string;
}

function fileToDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

const shouldShowOutput = (
  line: OutputLine,
  hideDetails: boolean = false,
): boolean => {
  if (line.type === "user" || line.role === "user") return true;
  if (line.role === "tool") return true;

  if (line.type === "parsed" || line.role === "assistant") {
    const content = typeof line.content === "string" ? line.content : "";
    if (
      content.includes('"type" => "tool_use"') ||
      content.includes('"type": "tool_use"')
    ) {
      return false;
    }
    if (
      content.includes('"type" => "tool_result"') ||
      content.includes('"type": "tool_result"')
    ) {
      return false;
    }
    return true;
  }

  if (line.type === "system" || line.role === "system") {
    const content = typeof line.content === "string" ? line.content : "";
    if (content.startsWith("Using tool:")) return false;
    return true;
  }

  if (line.type === "raw") {
    const content = typeof line.content === "string" ? line.content : "";
    if (content.trim().length === 0) return false;

    // In hide details mode, filter out system/init JSON messages
    if (hideDetails) {
      const trimmed = content.trim();
      // Filter out JSON that looks like system init messages
      if (
        trimmed.startsWith('{"type":"system"') ||
        trimmed.startsWith('{\"type\":\"system\"')
      ) {
        return false;
      }
      // Filter partial JSON fragments that are part of init messages
      if (trimmed.includes('"mcp_servers"') || trimmed.includes('"tools":[')) {
        return false;
      }
    }

    return true;
  }

  return true;
};

export default function TaskDetailsPanel(props: TaskDetailsPanelProps) {
  const navigate = useNavigate();
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
  const [showCreatePRModal, setShowCreatePRModal] = createSignal(false);

  const [attachedImages, setAttachedImages] = createSignal<ImageAttachment[]>(
    [],
  );
  const [isStopping, setIsStopping] = createSignal(false);
  const [isCreatingWorktree, setIsCreatingWorktree] = createSignal(false);
  const [hideDetails, setHideDetails] = createSignal(
    getStoredBoolean(HIDE_DETAILS_KEY, false),
  );

  const toggleHideDetails = () => {
    const newValue = !hideDetails();
    setHideDetails(newValue);
    setStoredBoolean(HIDE_DETAILS_KEY, newValue);
  };

  const [isFullscreen, setIsFullscreen] = createSignal(
    getStoredBoolean(FULLSCREEN_KEY, false),
  );

  const toggleFullscreen = () => {
    const newValue = !isFullscreen();
    setIsFullscreen(newValue);
    setStoredBoolean(FULLSCREEN_KEY, newValue);
  };

  interface ColumnQueryResult {
    id: string;
    name: string;
    board_id: string;
  }

  const columnsQuery = useLiveQuery((q) =>
    q.from({ columns: columnsCollection }).select(({ columns }) => ({
      id: columns.id,
      name: columns.name,
      board_id: columns.board_id,
    })),
  );

  const todoColumn = (): ColumnQueryResult | undefined => {
    const cols = (columnsQuery.data ?? []) as ColumnQueryResult[];
    return cols.find((c) => c.name.toUpperCase() === "TODO");
  };

  const currentBoardId = (): string | undefined => {
    const task = props.task;
    if (!task) return undefined;
    const cols = (columnsQuery.data ?? []) as ColumnQueryResult[];
    const col = cols.find((c) => c.id === task.column_id);
    return col?.board_id;
  };

  const navigateToSubtask = (subtaskId: string) => {
    const boardId = currentBoardId();
    if (boardId) {
      navigate(`/board/${boardId}/card/${subtaskId}`);
    }
  };

  const isTodoTask = () => props.columnName?.toUpperCase() === "TODO";

  let messagesEndRef: HTMLDivElement | undefined;
  let inputRef: HTMLTextAreaElement | undefined;

  const taskId = () => props.task?.id;

  const { executors, selectedExecutor, setSelectedExecutor, hasClaudeCode } =
    useSystem();

  const {
    output,
    isConnected,
    isLoading: isExecutorLoading,
    isRunning,
    isThinking,
    error: executorError,
    agentStatus,
    agentStatusMessage,
    todos,
    queueMessage,
    stopExecutor,
    reconnect,
    createWorktree,
  } = useTaskChat(taskId);

  const [hookExecutions, { refetch: refetchHookExecutions }] = createResource(
    taskId,
    async (id) => {
      if (!id) return [];
      const result = await sdk.hook_executions_for_task({
        input: { task_id: id },
        fields: [
          "id",
          "hook_name",
          "status",
          "skip_reason",
          "error_message",
          "queued_at",
          "started_at",
          "completed_at",
        ],
      });
      if (result.success) {
        return result.data;
      }
      return [];
    },
  );

  createEffect(() => {
    props.task?.agent_status;
    refetchHookExecutions();
  });

  const getActivityTimestamp = (item: ActivityItem): number => {
    switch (item.type) {
      case "task_created":
        return new Date(item.timestamp).getTime();
      case "hook_execution":
        return item.queued_at ? new Date(item.queued_at).getTime() : 0;
      case "grouped_hooks":
        return item.hooks[0]?.queued_at
          ? new Date(item.hooks[0].queued_at).getTime()
          : 0;
      case "output":
        return item.line.timestamp
          ? new Date(item.line.timestamp).getTime()
          : 0;
    }
  };

  const groupConsecutiveHooks = (items: ActivityItem[]): ActivityItem[] => {
    const result: ActivityItem[] = [];
    let currentHookGroup: HookExecutionActivity[] = [];

    const flushHookGroup = () => {
      if (currentHookGroup.length > 0) {
        result.push({
          type: "grouped_hooks",
          hooks: [...currentHookGroup],
        });
      }
      currentHookGroup = [];
    };

    for (const item of items) {
      if (item.type === "hook_execution") {
        currentHookGroup.push(item);
      } else {
        if (currentHookGroup.length > 0) {
          flushHookGroup();
        }
        result.push(item);
      }
    }

    if (currentHookGroup.length > 0) {
      flushHookGroup();
    }

    return result;
  };

  const activityItems = createMemo((): ActivityItem[] => {
    const items: ActivityItem[] = [];

    if (props.task && !isTodoTask()) {
      items.push({
        type: "task_created",
        timestamp: props.task.inserted_at,
        description: props.task.description,
      });
    }

    const executions = hookExecutions() ?? [];
    for (const exec of executions) {
      items.push({
        type: "hook_execution",
        id: exec.id,
        name: exec.hook_name,
        status: exec.status,
        skip_reason: exec.skip_reason,
        error_message: exec.error_message,
        queued_at: exec.queued_at,
        started_at: exec.started_at,
        completed_at: exec.completed_at,
      });
    }

    for (const line of output()) {
      if (shouldShowOutput(line, hideDetails())) {
        items.push({ type: "output", line });
      }
    }

    items.sort((a, b) => getActivityTimestamp(a) - getActivityTimestamp(b));

    return groupConsecutiveHooks(items);
  });

  const taskAgentStatus = () => {
    const task = props.task;
    if (!task) return "idle" as AgentStatusType;
    return (task.agent_status || "idle") as AgentStatusType;
  };

  const isTaskWorking = () => {
    const status = taskAgentStatus();
    return isRunning() || status === "executing" || status === "thinking";
  };

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

  const scrollToBottom = () => {
    if (messagesEndRef) {
      messagesEndRef.scrollIntoView({ behavior: "smooth" });
    }
  };

  createEffect(() => {
    const items = activityItems();
    const thinking = isThinking();
    if (items.length > 0 || thinking) {
      setTimeout(scrollToBottom, 100);
    }
  });

  onMount(() => {
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

    const result = await sdk
      .update_task({
        identity: props.task.id,
        input: { title: title().trim() },
      })
      .then(unwrap);

    setIsSaving(false);
    if (result) {
      setIsEditingTitle(false);
    }
  };

  const handleSaveDescription = async () => {
    if (!props.task) return;

    setIsSaving(true);
    setError(null);

    const images = descriptionImages();
    const result = await sdk
      .update_task({
        identity: props.task.id,
        input: {
          description: description().trim() || undefined,
          description_images:
            images.length > 0 ? prepareImagesForApi(images) : undefined,
        },
      })
      .then(unwrap);

    setIsSaving(false);
    if (result) {
      setIsEditingDescription(false);
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

    const result = await sdk
      .destroy_task({ identity: props.task.id })
      .then(unwrap);

    setIsDeleting(false);
    setShowDeleteConfirm(false);
    if (result !== null) {
      props.onClose();
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

    await sdk.refine_task({ input: { task_id: props.task.id } }).then(unwrap);

    setIsRefining(false);
  };

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

  const removeImage = (id: string) => {
    setAttachedImages((prev) => prev.filter((img) => img.id !== id));
    const placeholder = `![${id}]()`;
    setInput((prev) => prev.replaceAll(placeholder, ""));
  };

  const handleStartExecutor = async (e: Event) => {
    e.preventDefault();
    const prompt = input().trim();
    const images = attachedImages();
    const executor = selectedExecutor();

    if (
      (!prompt && images.length === 0) ||
      isSending() ||
      !isConnected() ||
      !executor
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

      const imageData = images.map((img) => ({
        name: img.name,
        data: img.dataUrl,
        mimeType: img.file.type,
      }));

      await queueMessage(prompt, executor, imageData);
    } catch (err) {
      console.error("Failed to start work:", err);
      setError(getErrorMessage(err, "Failed to start work"));
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
    if (isStopping() || !isTaskWorking()) return;

    setIsStopping(true);
    try {
      await stopExecutor();
    } catch (err) {
      console.error("Failed to stop executor:", err);
      setError(getErrorMessage(err, "Failed to stop executor"));
    } finally {
      setIsStopping(false);
    }
  };

  const handleCreateWorktree = async () => {
    if (isCreatingWorktree() || !isConnected()) return;

    setIsCreatingWorktree(true);
    setError(null);
    try {
      await createWorktree();
    } catch (err) {
      console.error("Failed to create worktree:", err);
      setError(getErrorMessage(err, "Failed to create worktree"));
    } finally {
      setIsCreatingWorktree(false);
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
      await sdk.open_in_editor({ input: { path } });
    } catch (err) {
      setError(getErrorMessage(err, "Failed to open editor"));
      console.error("Failed to open editor:", err);
    }
  };

  const openFolder = async (path: string) => {
    try {
      await sdk.open_folder({ input: { path } });
    } catch (err) {
      setError(getErrorMessage(err, "Failed to open folder"));
      console.error("Failed to open folder:", err);
    }
  };

  const handleDismissError = async () => {
    const t = props.task;
    if (!t) return;

    try {
      await sdk.clear_task_error({ identity: t.id });
    } catch (err) {
      console.error("Failed to clear error:", err);
      setError(getErrorMessage(err, "Failed to clear error"));
    }
  };

  const availableExecutors = () => executors().filter((e) => e.available);
  const hasAvailableExecutor = () => availableExecutors().length > 0;

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
              <div class="flex flex-wrap-reverse items-end justify-between gap-x-4 gap-y-2">
                <div class="flex-1 basis-[250px]">
                  <Show
                    when={isEditingTitle()}
                    fallback={
                      <h2
                        class="text-lg font-semibold text-white cursor-pointer hover:text-brand-400 transition-colors break-words"
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
                <div class="flex items-center gap-2 flex-shrink-0 self-end">
                  <AgentStatusBadge
                    status={taskAgentStatus()}
                    onDismiss={handleDismissError}
                  />
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
                  {/* Create Worktree button - show when task doesn't have a worktree */}
                  <Show when={!task().worktree_path && isConnected()}>
                    <button
                      onClick={handleCreateWorktree}
                      disabled={isCreatingWorktree()}
                      class="p-1.5 text-gray-400 hover:text-amber-400 hover:bg-amber-500/10 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                      title="Create Worktree"
                    >
                      <Show
                        when={isCreatingWorktree()}
                        fallback={
                          <svg
                            class="w-4 h-4"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke="currentColor"
                            stroke-width="2"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"
                            />
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="M12 11v6m-3-3h6"
                            />
                          </svg>
                        }
                      >
                        <LoadingSpinner class="w-4 h-4" />
                      </Show>
                    </button>
                  </Show>
                  {/* PR Link - show when task has an active PR */}
                  <Show
                    when={
                      task().pr_url &&
                      task().pr_status &&
                      task().pr_status !== "closed"
                    }
                  >
                    <a
                      href={task().pr_url!}
                      target="_blank"
                      rel="noopener noreferrer"
                      class={`flex items-center gap-1 px-2 py-1 text-xs rounded-lg transition-colors ${getPRBadgeHoverClasses(task().pr_status!)}`}
                      title="View Pull Request"
                    >
                      <PRIcon status={task().pr_status!} class="w-3.5 h-3.5" />
                      <span>{task().pr_number}</span>
                    </a>
                  </Show>
                  {/* Create PR button - show when task has branch but no active PR */}
                  <Show
                    when={
                      task().worktree_branch &&
                      (!task().pr_url || task().pr_status === "closed")
                    }
                  >
                    <button
                      onClick={() => setShowCreatePRModal(true)}
                      class="flex items-center p-1.5 text-xs rounded-full bg-gray-500/20 text-gray-400 border border-gray-500/30 hover:bg-gray-500/30 transition-colors"
                      title="Create Pull Request"
                    >
                      <PRIcon status="draft" class="w-3.5 h-3.5" />
                    </button>
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
                    <svg
                      class="w-4 h-4"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <Show
                        when={hideDetails()}
                        fallback={
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"
                          />
                        }
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                        />
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
                        />
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
                    <svg
                      class="w-4 h-4"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <Show
                        when={isFullscreen()}
                        fallback={
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"
                          />
                        }
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M9 9V4.5M9 9H4.5M9 9L3.75 3.75M9 15v4.5M9 15H4.5M9 15l-5.25 5.25M15 9h4.5M15 9V4.5M15 9l5.25-5.25M15 15h4.5M15 15v4.5m0-4.5l5.25 5.25"
                        />
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
                <Show when={isTaskWorking()}>
                  <span class="flex items-center gap-1.5 text-xs text-amber-400">
                    <span class="w-1.5 h-1.5 bg-amber-500 rounded-full animate-pulse" />
                    {isRunning() ? "Executor running" : "Processing..."}
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

              {/* Hook execution history moved to hook_executions table */}

              {/* Parent Task Link - for subtasks */}
              <Show when={task().parent_task_id}>
                <div class="mt-4 pt-4 border-t border-gray-700">
                  <button
                    type="button"
                    onClick={() => navigateToSubtask(task().parent_task_id!)}
                    class="flex items-center gap-2 text-sm text-gray-400 hover:text-white transition-colors"
                  >
                    <svg
                      class="w-4 h-4"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M10 19l-7-7m0 0l7-7m-7 7h18"
                      />
                    </svg>
                    Parent Task
                  </button>
                </div>
              </Show>

              {/* Subtasks Section - only for tasks without a parent (top-level tasks) */}
              <Show when={isTodoTask() && !task().parent_task_id}>
                <div class="mt-4 pt-4 border-t border-gray-700">
                  <SubtaskList
                    task={task()}
                    onSubtaskClick={navigateToSubtask}
                  />
                </div>
              </Show>

              {/* Executor availability notice */}
              <Show
                when={
                  isConnected() &&
                  !hasAvailableExecutor() &&
                  executors().length > 0
                }
              >
                <div class="mt-2 p-2 bg-amber-500/10 border border-amber-500/30 rounded-lg text-amber-400 text-sm">
                  No AI executors available. Make sure at least one (Claude
                  Code, Codex, Aider, etc.) is installed and in PATH.
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
                                when={
                                  item.type === "grouped_hooks" ? item : null
                                }
                                fallback={
                                  <Show
                                    when={item.type === "output" ? item : null}
                                  >
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
                                queued_at={hookItem().queued_at}
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
                  <Show when={isThinking()}>
                    <div class="flex items-start gap-3 px-4 py-3 animate-pulse">
                      <div class="w-8 h-8 rounded-full bg-blue-500/20 flex items-center justify-center">
                        <div class="w-4 h-4 border-2 border-blue-400 border-t-transparent rounded-full animate-spin" />
                      </div>
                      <div class="flex-1">
                        <div class="flex items-center gap-2">
                          <span class="text-sm font-medium text-blue-400">
                            Agent is thinking
                          </span>
                          <span class="flex gap-1">
                            <span
                              class="w-1.5 h-1.5 bg-blue-400 rounded-full animate-bounce"
                              style={{ "animation-delay": "0ms" }}
                            />
                            <span
                              class="w-1.5 h-1.5 bg-blue-400 rounded-full animate-bounce"
                              style={{ "animation-delay": "150ms" }}
                            />
                            <span
                              class="w-1.5 h-1.5 bg-blue-400 rounded-full animate-bounce"
                              style={{ "animation-delay": "300ms" }}
                            />
                          </span>
                        </div>
                        <p class="text-xs text-gray-500 mt-1">
                          Processing your request...
                        </p>
                      </div>
                    </div>
                  </Show>
                  <Show when={!isThinking() && isRunning()}>
                    <div class="flex items-center gap-2 px-4 py-2">
                      <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
                      <span class="text-xs text-gray-400">
                        {agentStatusMessage() || "Agent is working..."}
                      </span>
                    </div>
                  </Show>
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
              <Show when={(task().message_queue?.length ?? 0) > 0}>
                <div class="flex items-center gap-2 px-3 py-1.5 bg-amber-900/30 border border-amber-700/50 rounded-lg">
                  <svg
                    class="w-4 h-4 text-amber-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
                    />
                  </svg>
                  <span class="text-sm text-amber-200">
                    {task().message_queue?.length ?? 0} message
                    {(task().message_queue?.length ?? 0) > 1 ? "s" : ""} queued
                  </span>
                </div>
              </Show>
              <form onSubmit={handleStartExecutor} class="flex flex-col gap-1">
                {/* Subtle executor indicator */}
                <Show when={hasAvailableExecutor()}>
                  <div class="flex items-center px-1">
                    <Show
                      when={availableExecutors().length > 1}
                      fallback={
                        <span class="text-xs text-gray-500">
                          {executors().find(
                            (e) => e.type === selectedExecutor(),
                          )?.name ?? "AI"}
                        </span>
                      }
                    >
                      <div class="relative inline-block">
                        <select
                          value={selectedExecutor() ?? ""}
                          onChange={(e) =>
                            setSelectedExecutor(e.currentTarget.value)
                          }
                          disabled={!isConnected() || isSending()}
                          class="appearance-none bg-transparent text-xs text-gray-400 hover:text-gray-300 pr-4 cursor-pointer focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
                          title="Select AI executor"
                        >
                          <For each={availableExecutors()}>
                            {(exec) => (
                              <option
                                value={exec.type}
                                class="bg-gray-800 text-white"
                              >
                                {exec.name}
                              </option>
                            )}
                          </For>
                        </select>
                        <svg
                          class="absolute right-0 top-1/2 -translate-y-1/2 w-3 h-3 text-gray-500 pointer-events-none"
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
                      </div>
                    </Show>
                  </div>
                </Show>
                <div class="flex gap-2">
                  <textarea
                    ref={inputRef}
                    value={input()}
                    onInput={(e) => setInput(e.currentTarget.value)}
                    onKeyDown={handleKeyDown}
                    onPaste={handlePaste}
                    placeholder={
                      !isConnected()
                        ? "Connecting..."
                        : hasAvailableExecutor()
                          ? "Enter a prompt or paste an image (Ctrl+V)..."
                          : "No AI executors available"
                    }
                    disabled={
                      !isConnected() || isSending() || !hasAvailableExecutor()
                    }
                    rows={1}
                    class="flex-1 px-4 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent disabled:opacity-50 disabled:cursor-not-allowed resize-none"
                  />
                  <button
                    type="submit"
                    disabled={
                      !isConnected() ||
                      isSending() ||
                      (!input().trim() && attachedImages().length === 0) ||
                      !hasAvailableExecutor()
                    }
                    class="px-4 py-2 bg-brand-600 hover:bg-brand-700 disabled:bg-brand-800 disabled:cursor-not-allowed text-white rounded-lg transition-colors flex items-center gap-2"
                    title="Send message"
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
                            d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"
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
                    <Show when={(task().message_queue?.length ?? 0) > 0}>
                      <span class="text-xs bg-white/20 px-1.5 py-0.5 rounded">
                        {task().message_queue?.length ?? 0}
                      </span>
                    </Show>
                  </button>
                  <Show when={isTaskWorking()}>
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
                </div>
              </form>
            </div>
          </div>
        )}
      </Show>

      {/* Duplicate Task Modal */}
      <Show when={props.task}>
        {(getTask) => {
          const col = todoColumn();
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

      <Show when={props.task}>
        {(getTask) => (
          <CreatePRModal
            isOpen={showCreatePRModal()}
            onClose={() => setShowCreatePRModal(false)}
            task={getTask()}
            onSuccess={(url) => {
              window.open(url, "_blank");
            }}
          />
        )}
      </Show>
    </SidePanel>
  );
}

interface TaskCreatedActivityComponentProps {
  timestamp: string;
  description: string | null;
  formatDate: (dateStr: string) => string;
}

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

interface HookExecutionActivityComponentProps {
  name: string;
  status:
    | "pending"
    | "running"
    | "completed"
    | "failed"
    | "cancelled"
    | "skipped";
  skip_reason?:
    | "error"
    | "disabled"
    | "column_change"
    | "server_restart"
    | "user_cancelled"
    | null;
  error_message?: string | null;
  queued_at: string | null;
  formatDate: (dateStr: string) => string;
}

function HookExecutionActivityComponent(
  props: HookExecutionActivityComponentProps,
) {
  const getSkipLabel = () => {
    switch (props.skip_reason) {
      case "disabled":
        return "Hook skipped (disabled)";
      case "error":
        return "Hook skipped (error)";
      case "column_change":
        return "Hook skipped (column change)";
      case "server_restart":
        return "Hook skipped (server restart)";
      case "user_cancelled":
        return "Hook cancelled (by user)";
      default:
        return "Hook skipped";
    }
  };

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
          label: "Completed",
          textClass: "text-green-400",
        };
      case "failed":
        return {
          label: "Failed",
          textClass: "text-red-400",
        };
      case "cancelled":
        return {
          label: getSkipLabel(),
          textClass: "text-yellow-400",
        };
      case "skipped":
        return {
          label: getSkipLabel(),
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
      <span class={`font-medium ${config.textClass}`}>{props.name}</span>
      <span class="text-gray-500">{config.label}</span>
      <Show when={props.queued_at}>
        <span class="text-gray-600 ml-auto">
          {props.formatDate(props.queued_at!)}
        </span>
      </Show>
      <Show when={props.error_message}>
        <span
          class="text-red-400 truncate max-w-[150px]"
          title={props.error_message ?? undefined}
        >
          {props.error_message}
        </span>
      </Show>
    </div>
  );
}

interface GroupedHooksActivityComponentProps {
  hooks: HookExecutionActivity[];
  formatDate: (dateStr: string) => string;
}

function GroupedHooksActivityComponent(
  props: GroupedHooksActivityComponentProps,
) {
  const [isExpanded, setIsExpanded] = createSignal(false);

  const statusCounts = () => {
    const counts = {
      pending: 0,
      running: 0,
      completed: 0,
      failed: 0,
      cancelled: 0,
      skipped: 0,
    };
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
        <span>
          {props.hooks.length} {props.hooks.length === 1 ? "hook" : "hooks"}
        </span>
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
                queued_at={hook.queued_at}
                formatDate={props.formatDate}
              />
            )}
          </For>
        </div>
      </Show>
    </div>
  );
}

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

  const getToolInfo = (): {
    tool: string;
    input?: Record<string, unknown>;
  } | null => {
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

  const formatToolInput = (
    input: Record<string, unknown> | undefined,
  ): string => {
    if (!input) return "";

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

    for (const value of Object.values(input)) {
      if (typeof value === "string" && value.length > 0) {
        return value.length > 50 ? value.slice(0, 50) + "..." : value;
      }
    }
    return "";
  };

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

  if (isSystem()) {
    const content = getTextContent();
    const isError =
      content.toLowerCase().includes("error") ||
      content.toLowerCase().includes("failed");
    const isSuccess =
      content.toLowerCase().includes("completed") ||
      content.toLowerCase().includes("success");
    const colorClass = isError
      ? "text-red-400"
      : isSuccess
        ? "text-green-400"
        : "text-amber-400";

    return (
      <div class="flex items-center gap-2 py-1.5 px-3 text-xs bg-gray-900/50 rounded-lg border border-gray-800">
        <svg
          class={`w-4 h-4 flex-shrink-0 ${colorClass}`}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          stroke-width="2"
        >
          <Show
            when={isError}
            fallback={
              <Show
                when={isSuccess}
                fallback={
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                }
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </Show>
            }
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
            />
          </Show>
        </svg>
        <span class={colorClass}>{content}</span>
        <Show when={!props.hideDetails}>
          <span class="text-gray-600 ml-auto">
            {props.formatTime(props.line.timestamp)}
          </span>
        </Show>
      </div>
    );
  }

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
