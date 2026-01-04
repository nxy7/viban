import { type Channel, Socket } from "phoenix";
import { showError } from "./notifications";

// ============================================================================
// Configuration Constants
// ============================================================================

/** Base reconnection delay in milliseconds */
const RECONNECT_BASE_MS = 1000;

/** Maximum reconnection delay in milliseconds */
const RECONNECT_MAX_MS = 30000;

/** Socket connection timeout in milliseconds */
const SOCKET_TIMEOUT_MS = 10000;

/** Default WebSocket URL for SSR/server context */
const DEFAULT_SOCKET_URL = "ws://localhost:8000/socket";

// ============================================================================
// URL Utilities
// ============================================================================

/**
 * Constructs the WebSocket URL based on current location.
 * Uses window.location in browser (through Caddy proxy).
 */
const getSocketUrl = (): string => {
  if (typeof window === "undefined") return DEFAULT_SOCKET_URL;
  const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  return `${protocol}//${window.location.host}/socket`;
};

// ============================================================================
// Type Guards & Response Types
// ============================================================================

/** Error response structure from channel operations */
interface ErrorResponse {
  reason?: string;
  details?: string;
}

/**
 * Type guard to check if a response is an error response.
 */
function isErrorResponse(resp: unknown): resp is ErrorResponse {
  return (
    typeof resp === "object" &&
    resp !== null &&
    ("reason" in resp || "details" in resp)
  );
}

// ============================================================================
// Channel Utilities
// ============================================================================

interface ChannelPushOptions {
  showErrorNotification?: boolean;
  errorTitle?: string;
}

/**
 * Generic promise wrapper for channel push operations.
 * Handles ok/error/timeout responses consistently.
 * Shows error notifications by default for failed operations.
 *
 * Note: The type cast to T is necessary because Phoenix channels
 * return untyped responses. The caller is responsible for ensuring
 * the response matches type T based on the channel protocol.
 */
function channelPush<T>(
  channel: Channel,
  event: string,
  payload: Record<string, unknown> = {},
  timeoutMessage = "Request timeout",
  options: ChannelPushOptions = {},
): Promise<T> {
  const { showErrorNotification = true, errorTitle } = options;

  return new Promise((resolve, reject) => {
    channel
      .push(event, payload)
      .receive("ok", (resp: unknown) => {
        // Type assertion is safe here as the channel protocol defines
        // what response type is expected for each event
        resolve(resp as T);
      })
      .receive("error", (resp: unknown) => {
        let errorMessage: string;
        if (isErrorResponse(resp)) {
          errorMessage = resp.reason || resp.details || `Failed: ${event}`;
        } else {
          errorMessage = `Failed: ${event}`;
        }

        if (showErrorNotification) {
          showError(errorTitle || "Operation Failed", errorMessage);
        }

        reject(new Error(errorMessage));
      })
      .receive("timeout", () => {
        if (showErrorNotification) {
          showError(errorTitle || "Request Timeout", timeoutMessage);
        }
        reject(new Error(timeoutMessage));
      });
  });
}

// ============================================================================
// Executor Types
// ============================================================================

export interface ExecutorInfo {
  name: string;
  type: string;
  available: boolean;
  capabilities: string[];
}

export interface ExecutorSession {
  id: string;
  executor_type: string;
  prompt: string;
  status: "pending" | "running" | "completed" | "failed" | "stopped";
  exit_code: number | null;
  error_message: string | null;
  working_directory: string | null;
  started_at: string | null;
  completed_at: string | null;
  inserted_at: string;
}

export interface LLMTodoItem {
  content: string;
  activeForm: string;
  status: "pending" | "in_progress" | "completed";
}

// Image attachment for executor
export interface ImageAttachment {
  name: string;
  data: string; // base64 data URL
  mimeType: string;
}

export interface TaskStatus {
  agent_status: string;
  agent_status_message: string | null;
  worktree_path: string | null;
  worktree_branch: string | null;
  in_progress: boolean;
  error_message: string | null;
  sessions: ExecutorSession[];
}

export type TaskChannelHandlers = Record<string, never>;

// ============================================================================
// Board Channel Types
// ============================================================================

/** Client action types that can be triggered by hooks */
export type ClientActionType = "play-sound";

/** Payload for play-sound client action */
export interface PlaySoundActionPayload {
  type: "play-sound";
  sound: string;
}

/** Union type for all client action payloads */
export type ClientActionPayload = PlaySoundActionPayload;

/** Handlers for board channel events */
export interface BoardChannelHandlers {
  onClientAction?: (data: ClientActionPayload) => void;
}

// Response types for channel operations
export interface StartExecutorResponse {
  status: string;
  pid: string;
  task_id: string;
  executor_type: string;
}

export interface ListExecutorsResponse {
  executors: ExecutorInfo[];
}

export interface GetHistoryResponse {
  sessions: ExecutorSession[];
}

export interface StopExecutorResponse {
  status: string;
}

export interface CreateWorktreeResponse {
  worktree_path: string;
  worktree_branch: string;
}

// ============================================================================
// Socket Manager
// ============================================================================

/**
 * Manages WebSocket connections and Phoenix channels for real-time communication.
 * Implements singleton pattern for global socket state management.
 */
class SocketManager {
  private socket: Socket | null = null;
  private channels: Map<string, Channel> = new Map();
  private connectionPromise: Promise<Socket> | null = null;

  /**
   * Helper to get channel or throw with consistent error message.
   */
  private getChannelOrThrow(taskId: string): Channel {
    const channel = this.channels.get(`task:${taskId}`);
    if (!channel) {
      throw new Error(`Not connected to task ${taskId}`);
    }
    return channel;
  }

  /**
   * Calculates exponential backoff delay for reconnection attempts.
   */
  private calculateReconnectDelay(tries: number): number {
    return Math.min(RECONNECT_BASE_MS * 2 ** (tries - 1), RECONNECT_MAX_MS);
  }

  /**
   * Establishes WebSocket connection to the backend.
   * Returns existing connection if already connected, or waits for pending connection.
   */
  connect(): Promise<Socket> {
    if (this.socket?.isConnected()) {
      return Promise.resolve(this.socket);
    }

    if (this.connectionPromise) {
      return this.connectionPromise;
    }

    this.connectionPromise = new Promise((resolve, reject) => {
      const socketUrl = getSocketUrl();
      console.log(`[Socket] Connecting to ${socketUrl}`);

      this.socket = new Socket(socketUrl, {
        params: {},
        reconnectAfterMs: (tries: number) =>
          this.calculateReconnectDelay(tries),
      });

      // Capture socket reference for callbacks to avoid null assertion
      const socketRef = this.socket;

      socketRef.onOpen(() => {
        console.log("[Socket] Connected");
        this.connectionPromise = null;
        resolve(socketRef);
      });

      socketRef.onError((error: unknown) => {
        console.error("[Socket] Error:", error);
      });

      socketRef.onClose(() => {
        console.log("[Socket] Closed");
      });

      socketRef.connect();

      setTimeout(() => {
        if (!this.socket?.isConnected()) {
          this.connectionPromise = null;
          reject(new Error("Socket connection timeout"));
        }
      }, SOCKET_TIMEOUT_MS);
    });

    return this.connectionPromise;
  }

  /**
   * Joins a task-specific Phoenix channel for sending commands.
   * Data sync is handled via Electric SQL, this channel is only for RPC-style commands.
   */
  async joinTaskChannel(
    taskId: string,
    _handlers: TaskChannelHandlers,
  ): Promise<Channel> {
    const topic = `task:${taskId}`;

    // Return existing channel if already joined
    const existing = this.channels.get(topic);
    if (existing?.state === "joined") {
      return existing;
    }

    const socket = await this.connect();
    const channel = socket.channel(topic, {});

    return new Promise((resolve, reject) => {
      channel
        .join()
        .receive("ok", (resp: unknown) => {
          console.log(`[Channel] Joined ${topic}`, resp);
          this.channels.set(topic, channel);
          resolve(channel);
        })
        .receive("error", (resp: unknown) => {
          console.error(`[Channel] Failed to join ${topic}`, resp);
          const errorResp = resp as { reason?: string };
          reject(new Error(errorResp.reason || "Failed to join channel"));
        })
        .receive("timeout", () => {
          console.error(`[Channel] Timeout joining ${topic}`);
          reject(new Error("Channel join timeout"));
        });
    });
  }

  /**
   * Leaves a task channel and cleans up handlers.
   */
  leaveTaskChannel(taskId: string): void {
    const topic = `task:${taskId}`;
    const channel = this.channels.get(topic);
    if (channel) {
      channel.leave();
      this.channels.delete(topic);
      console.log(`[Channel] Left ${topic}`);
    }
  }

  /**
   * Joins a board-specific Phoenix channel for real-time board events.
   * Used for client actions triggered by hooks (e.g., play-sound).
   */
  async joinBoardChannel(
    boardId: string,
    handlers: BoardChannelHandlers,
  ): Promise<Channel> {
    const topic = `board:${boardId}`;

    // Return existing channel if already joined
    const existing = this.channels.get(topic);
    if (existing?.state === "joined") {
      return existing;
    }

    const socket = await this.connect();
    const channel = socket.channel(topic, {});

    // Set up client_action event handler
    const onClientAction = handlers.onClientAction;
    if (onClientAction) {
      channel.on("client_action", (data: unknown) => {
        console.log(`[BoardChannel] Received client_action:`, data);
        onClientAction(data as ClientActionPayload);
      });
    }

    return new Promise((resolve, reject) => {
      channel
        .join()
        .receive("ok", (resp: unknown) => {
          console.log(`[Channel] Joined ${topic}`, resp);
          this.channels.set(topic, channel);
          resolve(channel);
        })
        .receive("error", (resp: unknown) => {
          console.error(`[Channel] Failed to join ${topic}`, resp);
          const errorResp = resp as { reason?: string };
          reject(new Error(errorResp.reason || "Failed to join channel"));
        })
        .receive("timeout", () => {
          console.error(`[Channel] Timeout joining ${topic}`);
          reject(new Error("Channel join timeout"));
        });
    });
  }

  /**
   * Leaves a board channel and cleans up handlers.
   */
  leaveBoardChannel(boardId: string): void {
    const topic = `board:${boardId}`;
    const channel = this.channels.get(topic);
    if (channel) {
      channel.leave();
      this.channels.delete(topic);
      console.log(`[Channel] Left ${topic}`);
    }
  }

  /**
   * Queues a message for AI processing on a task.
   * The message is added to the task's message queue and processed by the Execute AI hook.
   * @param taskId - The task to queue the message for
   * @param prompt - The prompt/instructions for the executor
   * @param executorType - Type of executor to use (default: "claude_code")
   * @param workingDirectory - Optional working directory override
   * @param images - Optional image attachments for vision capabilities
   */
  async queueMessage(
    taskId: string,
    prompt: string,
    executorType = "claude_code",
    workingDirectory?: string,
    images?: ImageAttachment[],
  ): Promise<StartExecutorResponse> {
    const channel = this.getChannelOrThrow(taskId);

    return channelPush<StartExecutorResponse>(
      channel,
      "send_message",
      {
        prompt,
        executor_type: executorType,
        working_directory: workingDirectory,
        images: images ?? [],
      },
      "Send message timeout",
      { errorTitle: "Failed to Send Message" },
    );
  }

  /** Lists available executors for a task. */
  async listExecutors(taskId: string): Promise<ListExecutorsResponse> {
    const channel = this.getChannelOrThrow(taskId);
    return channelPush<ListExecutorsResponse>(
      channel,
      "list_executors",
      {},
      "List executors timeout",
      { showErrorNotification: false },
    );
  }

  /** Stops the currently running executor for a task. */
  async stopExecutor(taskId: string): Promise<StopExecutorResponse> {
    const channel = this.getChannelOrThrow(taskId);
    return channelPush<StopExecutorResponse>(
      channel,
      "stop_executor",
      {},
      "Stop executor timeout",
      { errorTitle: "Failed to Stop Executor" },
    );
  }

  /** Gets current status of a task including agent state. */
  async getStatus(taskId: string): Promise<TaskStatus> {
    const channel = this.getChannelOrThrow(taskId);
    return channelPush<TaskStatus>(
      channel,
      "get_status",
      {},
      "Get status timeout",
      { showErrorNotification: false },
    );
  }

  /** Gets executor session history for a task. */
  async getHistory(taskId: string): Promise<GetHistoryResponse> {
    const channel = this.getChannelOrThrow(taskId);
    return channelPush<GetHistoryResponse>(
      channel,
      "get_history",
      {},
      "Get history timeout",
      { showErrorNotification: false },
    );
  }

  /** Creates a git worktree for a task. */
  async createWorktree(taskId: string): Promise<CreateWorktreeResponse> {
    const channel = this.getChannelOrThrow(taskId);
    return channelPush<CreateWorktreeResponse>(
      channel,
      "create_worktree",
      {},
      "Create worktree timeout",
      { errorTitle: "Failed to Create Worktree" },
    );
  }

  /** Checks if the socket is currently connected. */
  isConnected(): boolean {
    return this.socket?.isConnected() ?? false;
  }

  /** Disconnects the socket and leaves all channels. */
  disconnect(): void {
    // Leave all channels
    for (const [topic, channel] of this.channels) {
      channel.leave();
      console.log(`[Channel] Left ${topic}`);
    }
    this.channels.clear();

    // Disconnect socket
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
    this.connectionPromise = null;
  }
}

// Singleton instance
export const socketManager = new SocketManager();
