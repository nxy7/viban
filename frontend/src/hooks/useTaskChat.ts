import { type Accessor, createEffect, createMemo, createSignal, onCleanup } from "solid-js";
import { getErrorMessage } from "~/lib/errorUtils";
import {
  type ExecutorInfo,
  type LLMTodoItem,
  socketManager,
} from "~/lib/socket";
import { useTaskEvents, useExecutorSessions, type TaskEvent } from "~/hooks/useKanban";

export type AgentStatusType = "idle" | "thinking" | "executing" | "error";

type OutputType = "raw" | "parsed" | "system" | "user";

type MessageRole = "user" | "assistant" | "system" | "tool";

export interface OutputLine {
  id: string;
  type: OutputType;
  content: string | Record<string, unknown>;
  timestamp: string;
  role?: MessageRole;
  metadata?: Record<string, unknown>;
}

export interface UseTaskChatOptions {
  autoConnect?: boolean;
}

export interface ImageData {
  name: string;
  data: string;
  mimeType: string;
}

export interface UseTaskChatReturn {
  output: Accessor<OutputLine[]>;
  isConnected: Accessor<boolean>;
  isLoading: Accessor<boolean>;
  isRunning: Accessor<boolean>;
  isThinking: Accessor<boolean>;
  error: Accessor<string | null>;
  agentStatus: Accessor<AgentStatusType>;
  agentStatusMessage: Accessor<string | null>;
  executors: Accessor<ExecutorInfo[]>;
  todos: Accessor<LLMTodoItem[]>;
  queueMessage: (
    prompt: string,
    executorType?: string,
    images?: ImageData[],
  ) => Promise<void>;
  stopExecutor: () => Promise<void>;
  reconnect: () => Promise<void>;
  createWorktree: () => Promise<{
    worktree_path: string;
    worktree_branch: string;
  }>;
}

// ============================================================================
// Convert TaskEvent to OutputLine
// ============================================================================

function taskEventToOutputLine(event: TaskEvent): OutputLine | null {
  if (event.type === "message" || event.type === "executor_output") {
    const role = event.role as MessageRole | null;
    let content: string | Record<string, unknown> = event.content || "";
    let outputType: OutputType;

    if (role === "user") {
      outputType = "user";
    } else if (role === "assistant" || role === "tool") {
      outputType = "parsed";
      if (role === "tool" && typeof content === "string") {
        try {
          content = JSON.parse(content);
        } catch {
          // Keep as string
        }
      }
    } else {
      outputType = "system";
    }

    // Parse metadata for todos
    let metadata: Record<string, unknown> | undefined;
    if (event.metadata) {
      try {
        metadata = typeof event.metadata === "string"
          ? JSON.parse(event.metadata)
          : event.metadata as Record<string, unknown>;
      } catch {
        // Ignore parsing errors
      }
    }

    return {
      id: event.id,
      type: outputType,
      content,
      timestamp: event.inserted_at,
      role: role || undefined,
      metadata,
    };
  }

  return null;
}

export function useTaskChat(
  taskId: Accessor<string | undefined>,
  options: UseTaskChatOptions = {},
): UseTaskChatReturn {
  const { autoConnect = true } = options;

  const [isConnected, setIsConnected] = createSignal(false);
  const [isLoading, setIsLoading] = createSignal(false);
  const [error, setError] = createSignal<string | null>(null);
  const [executors, setExecutors] = createSignal<ExecutorInfo[]>([]);

  const [currentTaskId, setCurrentTaskId] = createSignal<string | undefined>(
    undefined,
  );

  // Electric SQL sync for task events (messages, output)
  const { events: electricEvents, isLoading: electricLoading } = useTaskEvents(taskId);

  // Electric SQL sync for executor sessions (to determine running state)
  const { sessions } = useExecutorSessions(taskId);

  // Convert events to output lines
  const output = createMemo((): OutputLine[] => {
    const events = electricEvents();
    const lines: OutputLine[] = [];

    for (const event of events) {
      const line = taskEventToOutputLine(event);
      if (line) {
        lines.push(line);
      }
    }

    return lines;
  });

  // Derive running state from sessions
  const isRunning = createMemo(() => {
    const sessionList = sessions();
    return sessionList.some(s => s.status === "running" || s.status === "pending");
  });

  // Derive agent status from task or session state
  const agentStatus = createMemo((): AgentStatusType => {
    if (isRunning()) {
      return "executing";
    }
    const sessionList = sessions();
    const lastSession = sessionList[sessionList.length - 1];
    if (lastSession?.status === "failed") {
      return "error";
    }
    return "idle";
  });

  const agentStatusMessage = createMemo((): string | null => {
    const sessionList = sessions();
    const lastSession = sessionList[sessionList.length - 1];
    if (!lastSession) return null;

    if (lastSession.status === "running") {
      return `${lastSession.executor_type} is running...`;
    }
    if (lastSession.status === "failed") {
      return lastSession.error_message || `Failed with exit code ${lastSession.exit_code}`;
    }
    if (lastSession.status === "completed") {
      return "Completed successfully";
    }
    if (lastSession.status === "stopped") {
      return "Stopped by user";
    }
    return null;
  });

  // Extract todos from task events with metadata
  const todos = createMemo((): LLMTodoItem[] => {
    const events = electricEvents();
    // Find the most recent todo update event
    for (let i = events.length - 1; i >= 0; i--) {
      const event = events[i];
      if (event.content === "todos" && event.metadata) {
        try {
          const meta = typeof event.metadata === "string"
            ? JSON.parse(event.metadata)
            : event.metadata;
          if (meta?.todos && Array.isArray(meta.todos)) {
            return meta.todos as LLMTodoItem[];
          }
        } catch {
          // Ignore parsing errors
        }
      }
    }
    return [];
  });

  const isThinking = createMemo(() => {
    // Consider thinking if running but no output yet
    if (!isRunning()) return false;
    const lines = output();
    const sessionList = sessions();
    const runningSession = sessionList.find(s => s.status === "running");
    if (!runningSession) return false;

    // Check if we have any output from this session
    const hasSessionOutput = lines.some(line => {
      // Session output would be after session start
      return new Date(line.timestamp) >= new Date(runningSession.started_at || runningSession.inserted_at);
    });
    return !hasSessionOutput;
  });

  const connect = async (id: string) => {
    setIsLoading(true);
    setError(null);

    try {
      // Join channel for commands only (send message, stop executor)
      await socketManager.joinTaskChannel(id, {});
      setIsConnected(true);

      try {
        const { executors: availableExecutors } =
          await socketManager.listExecutors(id);
        setExecutors(availableExecutors);
        console.log("[useTaskChat] Available executors:", availableExecutors);
      } catch (err) {
        console.error("[useTaskChat] Failed to list executors:", err);
      }

    } catch (err) {
      console.error("[useTaskChat] Connection error:", err);
      setError(getErrorMessage(err, "Failed to connect"));
      setIsConnected(false);
    } finally {
      setIsLoading(false);
    }
  };

  const disconnect = (id: string) => {
    socketManager.leaveTaskChannel(id);
    setIsConnected(false);
    setError(null);
  };

  createEffect(() => {
    const id = taskId();
    const prevTaskId = currentTaskId();

    if (prevTaskId && prevTaskId !== id) {
      disconnect(prevTaskId);
    }

    setCurrentTaskId(id);

    if (id && autoConnect) {
      connect(id);
    }
  });

  onCleanup(() => {
    const id = currentTaskId();
    if (id) {
      disconnect(id);
    }
  });

  const queueMessage = async (
    prompt: string,
    executorType: string = "claude_code",
    images?: ImageData[],
  ): Promise<void> => {
    const id = taskId();
    if (!id) {
      throw new Error("No task ID");
    }

    if (!isConnected()) {
      throw new Error("Not connected");
    }

    setError(null);

    try {
      await socketManager.queueMessage(
        id,
        prompt,
        executorType,
        undefined,
        images,
      );
      console.log("[useTaskChat] Message queued successfully");
    } catch (err) {
      console.error("[useTaskChat] Send message error:", err);
      setError(getErrorMessage(err, "Failed to send message"));
      throw err;
    }
  };

  const stopExecutor = async (): Promise<void> => {
    const id = taskId();
    if (!id) {
      throw new Error("No task ID");
    }

    if (!isConnected()) {
      throw new Error("Not connected");
    }

    try {
      await socketManager.stopExecutor(id);
    } catch (err) {
      console.error("[useTaskChat] Stop executor error:", err);
      setError(getErrorMessage(err, "Failed to stop executor"));
      throw err;
    }
  };

  const reconnect = async (): Promise<void> => {
    const id = taskId();
    if (!id) return;

    disconnect(id);
    await connect(id);
  };

  const createWorktree = async (): Promise<{
    worktree_path: string;
    worktree_branch: string;
  }> => {
    const id = taskId();
    if (!id) {
      throw new Error("No task ID");
    }

    if (!isConnected()) {
      throw new Error("Not connected");
    }

    return socketManager.createWorktree(id);
  };

  const isLoadingCombined = createMemo(() => isLoading() || electricLoading());

  return {
    output,
    isConnected,
    isLoading: isLoadingCombined,
    isRunning,
    isThinking,
    error,
    agentStatus,
    agentStatusMessage,
    executors,
    todos,
    queueMessage,
    stopExecutor,
    reconnect,
    createWorktree,
  };
}

export function formatOutput(lines: OutputLine[]): string {
  return lines
    .map((line) => {
      if (typeof line.content === "string") {
        return line.content;
      }
      return JSON.stringify(line.content, null, 2);
    })
    .join("\n");
}
