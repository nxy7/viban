import {
  createEffect,
  createMemo,
  createSignal,
  For,
  onCleanup,
  Show,
} from "solid-js";
import {
  Button,
  CronInput,
  Input,
  Select,
  Textarea,
} from "~/components/design-system";
import type { AgentExecutor } from "~/hooks/useKanban";
import ErrorBanner from "./ui/ErrorBanner";
import {
  CalendarIcon,
  ClockIcon,
  EditIcon,
  PauseIcon,
  PlayIcon,
  TrashIcon,
} from "./ui/Icons";

const AGENT_EXECUTOR_LABELS: Record<AgentExecutor, string> = {
  claude_code: "Claude Code",
  gemini_cli: "Gemini CLI",
  codex: "Codex",
  opencode: "OpenCode",
  cursor_agent: "Cursor Agent",
};

interface PeriodicalTask {
  id: string;
  title: string;
  description: string | null;
  schedule: string;
  executor: AgentExecutor;
  execution_count: number;
  last_executed_at: string | null;
  next_execution_at: string | null;
  enabled: boolean;
  board_id: string;
}

interface PeriodicalTasksConfigProps {
  boardId: string;
  periodicalTasks: PeriodicalTask[];
  onRefetch?: () => void;
  onCreate?: (task: {
    title: string;
    description: string;
    schedule: string;
    executor: AgentExecutor;
  }) => Promise<void>;
  onUpdate?: (
    id: string,
    updates: Partial<{
      title: string;
      description: string;
      schedule: string;
      executor: AgentExecutor;
      enabled: boolean;
    }>,
  ) => Promise<void>;
  onDelete?: (id: string) => Promise<void>;
}

function formatTimeRemaining(targetDate: Date): string {
  const now = new Date();
  const diffMs = targetDate.getTime() - now.getTime();

  if (diffMs <= 0) return "Running...";

  const diffSeconds = Math.floor(diffMs / 1000);
  const diffMinutes = Math.floor(diffSeconds / 60);
  const diffHours = Math.floor(diffMinutes / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffDays > 0) {
    return `${diffDays}d ${diffHours % 24}h`;
  } else if (diffHours > 0) {
    return `${diffHours}h ${diffMinutes % 60}m`;
  } else if (diffMinutes > 0) {
    return `${diffMinutes}m ${diffSeconds % 60}s`;
  } else {
    return `${diffSeconds}s`;
  }
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return "Never";
  const date = new Date(dateStr);
  return date.toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
}

export default function PeriodicalTasksConfig(
  props: PeriodicalTasksConfigProps,
) {
  const [isCreating, setIsCreating] = createSignal(false);
  const [editingTask, setEditingTask] = createSignal<PeriodicalTask | null>(
    null,
  );
  const [error, setError] = createSignal<string | null>(null);
  const [isSaving, setIsSaving] = createSignal(false);

  const [title, setTitle] = createSignal("");
  const [description, setDescription] = createSignal("");
  const [schedule, setSchedule] = createSignal("");
  const [executor, setExecutor] = createSignal<AgentExecutor>("claude_code");

  const [, setNow] = createSignal(new Date());
  let timerInterval: ReturnType<typeof setInterval> | undefined;

  createEffect(() => {
    timerInterval = setInterval(() => {
      setNow(new Date());
    }, 1000);

    onCleanup(() => {
      if (timerInterval) clearInterval(timerInterval);
    });
  });

  const resetForm = () => {
    setTitle("");
    setDescription("");
    setSchedule("0 0 * * 6");
    setExecutor("claude_code");
    setError(null);
  };

  const startCreate = () => {
    resetForm();
    setIsCreating(true);
    setEditingTask(null);
  };

  const startEdit = (task: PeriodicalTask) => {
    setTitle(task.title);
    setDescription(task.description || "");
    setSchedule(task.schedule);
    setExecutor(task.executor);
    setEditingTask(task);
    setIsCreating(false);
    setError(null);
  };

  const cancelEdit = () => {
    resetForm();
    setIsCreating(false);
    setEditingTask(null);
  };

  const handleSave = async () => {
    if (!title().trim()) {
      setError("Title is required");
      return;
    }

    if (!schedule().trim()) {
      setError("Schedule is required");
      return;
    }

    setIsSaving(true);
    setError(null);

    try {
      if (isCreating()) {
        await props.onCreate?.({
          title: title().trim(),
          description: description().trim(),
          schedule: schedule().trim(),
          executor: executor(),
        });
      } else {
        const task = editingTask();
        if (task) {
          await props.onUpdate?.(task.id, {
            title: title().trim(),
            description: description().trim(),
            schedule: schedule().trim(),
            executor: executor(),
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
    if (!confirm("Are you sure you want to delete this scheduled task?"))
      return;

    try {
      await props.onDelete?.(id);
      props.onRefetch?.();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to delete");
    }
  };

  const handleToggleEnabled = async (task: PeriodicalTask) => {
    try {
      await props.onUpdate?.(task.id, { enabled: !task.enabled });
      props.onRefetch?.();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to toggle");
    }
  };

  const sortedTasks = createMemo(() =>
    [...props.periodicalTasks].sort((a, b) => {
      if (a.enabled !== b.enabled) return a.enabled ? -1 : 1;
      return a.title.localeCompare(b.title);
    }),
  );

  return (
    <div class="space-y-4">
      <div class="flex justify-between items-center">
        <h3 class="text-lg font-semibold text-white">Scheduled Tasks</h3>
        <Show when={!isCreating() && !editingTask()}>
          <Button onClick={startCreate} buttonSize="sm">
            Add Scheduled Task
          </Button>
        </Show>
      </div>

      <p class="text-sm text-gray-400">
        Configure tasks that run automatically on a schedule. Each execution
        creates a new task with a unique number.
      </p>

      <ErrorBanner message={error()} />

      <Show when={isCreating() || editingTask()}>
        <div class="p-4 bg-gray-800 border border-gray-700 rounded-lg space-y-4">
          <h4 class="text-sm font-medium text-gray-300">
            {isCreating() ? "Create Scheduled Task" : "Edit Scheduled Task"}
          </h4>

          <div>
            <label class="block text-sm text-gray-400 mb-1">Title</label>
            <Input
              type="text"
              value={title()}
              onInput={(e) => setTitle(e.currentTarget.value)}
              placeholder="e.g., Daily Code Review"
              variant="dark"
            />
            <p class="text-xs text-gray-500 mt-1">
              Tasks will be created as "#1 {title()}", "#2 {title()}", etc.
            </p>
          </div>

          <div>
            <label class="block text-sm text-gray-400 mb-1">Description</label>
            <Textarea
              value={description()}
              onInput={(e) => setDescription(e.currentTarget.value)}
              placeholder="Describe what this scheduled task should do..."
              rows={4}
              variant="dark"
              resizable={false}
            />
          </div>

          <div>
            <label class="block text-sm text-gray-400 mb-1">Schedule</label>
            <CronInput value={schedule()} onChange={setSchedule} />
            <p class="text-xs text-gray-500 mt-1">
              Use cron syntax: minute hour day-of-month month day-of-week
            </p>
          </div>

          <div>
            <label class="block text-sm text-gray-400 mb-1">Executor</label>
            <Select
              value={executor()}
              onChange={(e) =>
                setExecutor(e.currentTarget.value as AgentExecutor)
              }
              variant="dark"
              fullWidth
            >
              <option value="claude_code">Claude Code</option>
              <option value="gemini_cli">Gemini CLI</option>
              <option value="codex">Codex</option>
              <option value="opencode">OpenCode</option>
              <option value="cursor_agent">Cursor Agent</option>
            </Select>
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

      <Show when={sortedTasks().length === 0 && !isCreating()}>
        <div class="text-gray-500 text-sm text-center py-8">
          No scheduled tasks configured. Click "Add Scheduled Task" to create
          one.
        </div>
      </Show>

      <div class="space-y-2">
        <For each={sortedTasks()}>
          {(task) => (
            <div
              class={`p-4 bg-gray-800 border rounded-lg ${
                editingTask()?.id === task.id
                  ? "border-brand-500"
                  : task.enabled
                    ? "border-gray-700"
                    : "border-gray-700/50 opacity-60"
              }`}
            >
              <div class="flex justify-between items-start">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2">
                    <CalendarIcon class="w-4 h-4 text-brand-400" />
                    <span class="font-medium text-white">{task.title}</span>
                    <span
                      class={`px-1.5 py-0.5 text-xs rounded ${
                        task.enabled
                          ? "bg-green-600/20 text-green-400"
                          : "bg-gray-700 text-gray-400"
                      }`}
                    >
                      {task.enabled ? "Active" : "Paused"}
                    </span>
                    <span class="px-1.5 py-0.5 text-xs bg-gray-700 text-gray-400 rounded">
                      #{task.execution_count} runs
                    </span>
                  </div>

                  <Show when={task.description}>
                    <div class="text-xs text-gray-400 mt-1 line-clamp-2">
                      {task.description}
                    </div>
                  </Show>

                  <div class="flex flex-wrap gap-x-4 gap-y-1 mt-2 text-xs text-gray-500">
                    <div class="flex items-center gap-1">
                      <ClockIcon class="w-3 h-3" />
                      <span class="font-mono">{task.schedule}</span>
                    </div>
                    <div>
                      <span class="text-gray-600">Executor:</span>{" "}
                      {AGENT_EXECUTOR_LABELS[task.executor]}
                    </div>
                    <Show when={task.last_executed_at}>
                      <div>
                        <span class="text-gray-600">Last run:</span>{" "}
                        {formatDate(task.last_executed_at)}
                      </div>
                    </Show>
                  </div>

                  <Show when={task.enabled && task.next_execution_at}>
                    <div class="mt-2 flex items-center gap-2">
                      <span class="text-xs text-gray-500">Next run in:</span>
                      <span class="text-sm font-medium text-brand-400">
                        {formatTimeRemaining(new Date(task.next_execution_at!))}
                      </span>
                    </div>
                  </Show>
                </div>

                <div class="flex gap-1 ml-2">
                  <Button
                    onClick={() => handleToggleEnabled(task)}
                    variant="icon"
                    title={task.enabled ? "Pause" : "Resume"}
                  >
                    <Show
                      when={task.enabled}
                      fallback={<PlayIcon class="w-4 h-4" />}
                    >
                      <PauseIcon class="w-4 h-4" />
                    </Show>
                  </Button>
                  <Button
                    onClick={() => startEdit(task)}
                    variant="icon"
                    title="Edit"
                  >
                    <EditIcon class="w-4 h-4" />
                  </Button>
                  <Button
                    onClick={() => handleDelete(task.id)}
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
