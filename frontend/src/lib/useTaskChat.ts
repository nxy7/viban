import { type Accessor, createEffect, createSignal, onCleanup } from "solid-js";
import { getErrorMessage } from "./errorUtils";
import {
  type ExecutorCompletedPayload,
  type ExecutorErrorPayload,
  type ExecutorInfo,
  type ExecutorOutputPayload,
  type ExecutorStartedPayload,
  type ExecutorStoppedPayload,
  type ExecutorTodosPayload,
  type LLMTodoItem,
  type StoredMessage,
  socketManager,
} from "./socket";

export type AgentStatusType = "idle" | "thinking" | "executing" | "error";

const DEFAULT_AGENT_STATUS: AgentStatusType = "idle";

const VALID_AGENT_STATUSES: readonly AgentStatusType[] = [
  "idle",
  "thinking",
  "executing",
  "error",
];

const HASH_CONTENT_PREFIX_LENGTH = 200;

function isValidAgentStatus(status: unknown): status is AgentStatusType {
  return (
    typeof status === "string" &&
    VALID_AGENT_STATUSES.includes(status as AgentStatusType)
  );
}

function toAgentStatus(status: unknown): AgentStatusType {
  return isValidAgentStatus(status) ? status : DEFAULT_AGENT_STATUS;
}

type OutputType = "raw" | "parsed" | "system" | "user";

type MessageRole = "user" | "assistant" | "system" | "tool";

export interface OutputLine {
  id: string;
  type: OutputType;
  content: string | Record<string, unknown>;
  timestamp: string;
  role?: MessageRole;
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

export function useTaskChat(
  taskId: Accessor<string | undefined>,
  options: UseTaskChatOptions = {},
): UseTaskChatReturn {
  const { autoConnect = true } = options;

  const [output, setOutput] = createSignal<OutputLine[]>([]);
  const [isConnected, setIsConnected] = createSignal(false);
  const [isLoading, setIsLoading] = createSignal(false);
  const [isRunning, setIsRunning] = createSignal(false);
  const [isThinking, setIsThinking] = createSignal(false);
  const [error, setError] = createSignal<string | null>(null);
  const [agentStatus, setAgentStatus] = createSignal<AgentStatusType>("idle");
  const [agentStatusMessage, setAgentStatusMessage] = createSignal<
    string | null
  >(null);
  const [executors, setExecutors] = createSignal<ExecutorInfo[]>([]);
  const [todos, setTodos] = createSignal<LLMTodoItem[]>([]);

  const [currentTaskId, setCurrentTaskId] = createSignal<string | undefined>(
    undefined,
  );
  const [outputIdCounter, setOutputIdCounter] = createSignal(0);

  const seenMessagesRef = { current: new Set<string>() };

  const getContentHash = (
    content: string | Record<string, unknown>,
  ): string => {
    const text =
      typeof content === "string" ? content : JSON.stringify(content);
    return `${text.slice(0, HASH_CONTENT_PREFIX_LENGTH)}_${text.length}`;
  };

  const addOutput = (
    type: OutputType,
    content: string | Record<string, unknown>,
    role?: MessageRole,
  ) => {
    const hash = getContentHash(content);
    if (seenMessagesRef.current.has(hash)) {
      return;
    }
    seenMessagesRef.current.add(hash);

    const newId = outputIdCounter() + 1;
    setOutputIdCounter(newId);

    const line: OutputLine = {
      id: `output-${newId}`,
      type,
      content,
      timestamp: new Date().toISOString(),
      role,
    };
    setOutput((prev) => [...prev, line]);
  };

  const loadStoredMessages = (messages: StoredMessage[]) => {
    const lines: OutputLine[] = messages.map((msg, index) => {
      const hash = getContentHash(msg.content);
      seenMessagesRef.current.add(hash);

      let content: string | Record<string, unknown> = msg.content;

      if (msg.role === "tool" && typeof msg.content === "string") {
        try {
          content = JSON.parse(msg.content);
        } catch {
          content = msg.content;
        }
      }

      return {
        id: `stored-${msg.id || index}`,
        type:
          msg.role === "user"
            ? "user"
            : msg.role === "assistant" || msg.role === "tool"
              ? "parsed"
              : "system",
        content,
        timestamp: msg.timestamp,
        role: msg.role,
      };
    });
    setOutput(lines);
  };

  const connect = async (id: string) => {
    setIsLoading(true);
    setError(null);

    try {
      await socketManager.joinTaskChannel(id, {
        onExecutorStarted: (data: ExecutorStartedPayload) => {
          console.log("[useTaskChat] Executor started:", data);
          setIsRunning(true);
          setIsThinking(true);
          setAgentStatus("thinking");
          setAgentStatusMessage(`${data.executor_type} is thinking...`);
          setTodos([]);
        },
        onExecutorOutput: (data: ExecutorOutputPayload) => {
          if (data.type === "parsed" && typeof data.content === "object") {
            const parsed = data.content as Record<string, unknown>;
            if (parsed.type === "assistant_message" && parsed.content) {
              setIsThinking(false);
              setAgentStatus("executing");
              setAgentStatusMessage("Agent is responding...");
              addOutput("parsed", parsed.content as string, "assistant");
            } else if (parsed.type === "result") {
              setIsThinking(false);
              setAgentStatus("idle");
              setAgentStatusMessage("Agent completed");
              const resultContent = parsed.content as string | undefined;
              if (resultContent) {
                addOutput("parsed", resultContent, "assistant");
              }
            } else if (parsed.type === "tool_use") {
              setIsThinking(false);
              setAgentStatus("executing");
              const toolName = parsed.tool as string | undefined;
              setAgentStatusMessage(
                toolName ? `Using ${toolName}...` : "Using tools...",
              );
              addOutput("parsed", parsed, "tool");
            } else if (parsed.type === "tool_result") {
              const toolContent = parsed.content as string | undefined;
              if (toolContent && toolContent.trim()) {
                addOutput("parsed", parsed, "tool");
              }
            } else if (parsed.type === "error") {
              setIsThinking(false);
              setAgentStatus("error");
              const errorMsg = parsed.message as string | undefined;
              setAgentStatusMessage(errorMsg || "An error occurred");
              addOutput(
                "system",
                `Error: ${errorMsg || "Unknown error"}`,
                "system",
              );
            } else if (parsed.type === "unknown") {
              console.log("[useTaskChat] Unknown event type:", parsed);
            }
          } else {
            const text =
              typeof data.content === "string"
                ? data.content
                : JSON.stringify(data.content);
            if (text.trim()) {
              setIsThinking(false);
              addOutput("raw", text);
            }
          }
        },
        onExecutorCompleted: (data: ExecutorCompletedPayload) => {
          console.log("[useTaskChat] Executor completed:", data);
          setIsRunning(false);
          setIsThinking(false);

          if (data.status === "completed") {
            setAgentStatus("idle");
            setAgentStatusMessage("Completed successfully");
            addOutput(
              "system",
              `Completed with exit code ${data.exit_code ?? 0}`,
            );
          } else if (data.status === "failed") {
            setAgentStatus("error");
            setAgentStatusMessage(`Failed with exit code ${data.exit_code}`);
            addOutput("system", `Failed with exit code ${data.exit_code}`);
          } else {
            setAgentStatus("idle");
            setAgentStatusMessage("Stopped");
            addOutput("system", "Stopped by user");
          }
        },
        onExecutorError: (data: ExecutorErrorPayload) => {
          console.error("[useTaskChat] Executor error:", data);
          setIsRunning(false);
          setIsThinking(false);
          setAgentStatus("error");
          setAgentStatusMessage(data.error);
          setError(data.error);
          addOutput("system", `Error: ${data.error}`);
        },
        onExecutorStopped: (data: ExecutorStoppedPayload) => {
          console.log("[useTaskChat] Executor stopped:", data);
          setIsRunning(false);
          setIsThinking(false);
          setAgentStatus("idle");
          setAgentStatusMessage(data.reason);
          addOutput("system", `Stopped: ${data.reason}`);
          setTodos([]);
        },
        onExecutorTodos: (data: ExecutorTodosPayload) => {
          console.log("[useTaskChat] Received todos:", data.todos);
          setTodos(data.todos);
        },
      });

      setIsConnected(true);

      try {
        const status = await socketManager.getStatus(id);
        setAgentStatus(toAgentStatus(status.agent_status));
        setAgentStatusMessage(status.agent_status_message);
      } catch {}

      try {
        const { executors: availableExecutors } =
          await socketManager.listExecutors(id);
        setExecutors(availableExecutors);
        console.log("[useTaskChat] Available executors:", availableExecutors);
      } catch (err) {
        console.error("[useTaskChat] Failed to list executors:", err);
      }

      try {
        const { messages } = await socketManager.getMessages(id);
        if (messages && messages.length > 0) {
          console.log(
            "[useTaskChat] Loaded",
            messages.length,
            "previous messages",
          );
          loadStoredMessages(messages);
        }
      } catch (err) {
        console.error("[useTaskChat] Failed to load messages:", err);
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
    setOutput([]);
    setError(null);
    setAgentStatus("idle");
    setAgentStatusMessage(null);
    setIsRunning(false);
    setIsThinking(false);
    setTodos([]);
    seenMessagesRef.current.clear();
    setOutputIdCounter(0);
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

    const imageCount = images?.length || 0;
    const displayContent =
      imageCount > 0
        ? `${prompt}${prompt ? "\n\n" : ""}[${imageCount} image${imageCount > 1 ? "s" : ""} attached]`
        : prompt;

    addOutput("user", displayContent, "user");

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

  return {
    output,
    isConnected,
    isLoading,
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
