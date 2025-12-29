/**
 * @deprecated This component is DEPRECATED and no longer maintained.
 *
 * The TaskChat component was built for an older chat-based API that no longer exists.
 * The current task interaction model uses executors via TaskDetailsPanel.
 *
 * DO NOT USE THIS COMPONENT - it is kept for reference only and will be removed
 * in a future version. Use TaskDetailsPanel for task interactions instead.
 *
 * Issues with this component:
 * 1. Uses `messages`, `streamingContent`, `sendMessage` - these don't exist in current useTaskChat
 * 2. Uses `getDisplayMessages` - this function is not exported from useTaskChat
 * 3. References `ChatMessage` type from socket.ts - this type doesn't exist
 *
 * @see TaskDetailsPanel for the current task interaction implementation
 */

import {
  createEffect,
  createMemo,
  createSignal,
  For,
  onMount,
  Show,
} from "solid-js";
import { type AgentStatusType, useTaskChat } from "../lib/useTaskChat";

// Placeholder type for backward compatibility - this type is not used anymore
interface LegacyChatMessage {
  role: "user" | "assistant" | "system";
  content: string;
  status?: "pending" | "processing" | "completed" | "failed";
  inserted_at?: string;
}

interface TaskChatProps {
  taskId: string;
}

/**
 * @deprecated Use TaskDetailsPanel instead. This component uses a deprecated API.
 */
export default function TaskChat(props: TaskChatProps) {
  // NOTE: This component is broken - the useTaskChat hook no longer provides
  // the methods this component expects. This is left as a stub.
  const {
    isConnected,
    isLoading,
    error,
    agentStatus,
    agentStatusMessage,
    reconnect,
  } = useTaskChat(() => props.taskId);

  // These would need to be reimplemented if this component were to be used
  const messages = () => [] as LegacyChatMessage[];
  const streamingContent = () => "";
  const sendMessage = async (_content: string) => {
    console.warn(
      "TaskChat.sendMessage is deprecated - use TaskDetailsPanel instead",
    );
  };

  const [input, setInput] = createSignal("");
  const [isSending, setIsSending] = createSignal(false);

  let messagesEndRef: HTMLDivElement | undefined;
  let inputRef: HTMLInputElement | undefined;

  // Display messages (deprecated - always returns empty array)
  const displayMessages = createMemo(() => {
    const msgs = messages();
    const streaming = streamingContent();
    // In the old implementation, this would merge messages with streaming content
    // Now it just returns the messages as-is
    if (streaming && msgs.length > 0) {
      const lastMsg = msgs[msgs.length - 1];
      if (lastMsg.role === "assistant" && lastMsg.status === "processing") {
        return [
          ...msgs.slice(0, -1),
          { ...lastMsg, content: streaming || lastMsg.content },
        ];
      }
    }
    return msgs;
  });

  // Auto-scroll to bottom when new messages arrive
  const scrollToBottom = () => {
    if (messagesEndRef) {
      messagesEndRef.scrollIntoView({ behavior: "smooth" });
    }
  };

  // Scroll on new messages - use createEffect for side effects, not createMemo
  createEffect(() => {
    const msgs = displayMessages();
    if (msgs.length > 0) {
      setTimeout(scrollToBottom, 100);
    }
  });

  onMount(() => {
    // Focus input on mount
    inputRef?.focus();
  });

  const handleSubmit = async (e: Event) => {
    e.preventDefault();
    const content = input().trim();
    if (!content || isSending() || !isConnected()) return;

    setIsSending(true);
    setInput("");

    try {
      await sendMessage(content);
    } catch (err) {
      console.error("Failed to send message:", err);
    } finally {
      setIsSending(false);
      inputRef?.focus();
    }
  };

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e);
    }
  };

  const formatTime = (dateStr?: string) => {
    if (!dateStr) return "";
    const date = new Date(dateStr);
    return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  };

  const getStatusColor = (status: AgentStatusType): string => {
    switch (status) {
      case "thinking":
        return "text-blue-400";
      case "executing":
        return "text-green-400";
      case "waiting_for_user":
        return "text-yellow-400";
      case "error":
        return "text-red-400";
      case "idle":
      default:
        return "text-gray-400";
    }
  };

  const getStatusIcon = (status: AgentStatusType) => {
    switch (status) {
      case "thinking":
        return (
          <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
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
        );
      case "executing":
        return (
          <svg
            class="w-4 h-4 animate-pulse"
            fill="currentColor"
            viewBox="0 0 24 24"
          >
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
          </svg>
        );
      case "error":
        return (
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z" />
          </svg>
        );
      case "idle":
      case "waiting_for_user":
      default:
        return (
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
            <circle cx="12" cy="12" r="3" />
          </svg>
        );
    }
  };

  // agentStatus is already properly typed as AgentStatusType from useTaskChat

  return (
    <div class="flex flex-col h-full bg-gray-900 rounded-lg border border-gray-800">
      {/* Header with connection status */}
      <div class="flex items-center justify-between px-4 py-2 border-b border-gray-800">
        <div class="flex items-center gap-2">
          <span
            class={`flex items-center gap-1.5 text-xs ${
              isConnected() ? "text-green-400" : "text-red-400"
            }`}
          >
            <span
              class={`w-2 h-2 rounded-full ${
                isConnected() ? "bg-green-500" : "bg-red-500"
              }`}
            />
            {isConnected() ? "Connected" : "Disconnected"}
          </span>
        </div>

        {/* Agent Status */}
        <Show when={agentStatus() !== "idle"}>
          <div
            class={`flex items-center gap-2 text-xs ${getStatusColor(agentStatus())}`}
          >
            {getStatusIcon(agentStatus())}
            <span class="capitalize">{agentStatus().replace("_", " ")}</span>
            <Show when={agentStatusMessage()}>
              <span class="text-gray-500">- {agentStatusMessage()}</span>
            </Show>
          </div>
        </Show>

        <Show when={!isConnected()}>
          <button
            onClick={() => reconnect()}
            class="text-xs text-brand-400 hover:text-brand-300"
          >
            Reconnect
          </button>
        </Show>
      </div>

      {/* Error Banner */}
      <Show when={error()}>
        <div class="px-4 py-2 bg-red-500/10 border-b border-red-500/30 text-red-400 text-sm">
          {error()}
        </div>
      </Show>

      {/* Loading State */}
      <Show when={isLoading()}>
        <div class="flex-1 flex items-center justify-center">
          <div class="flex items-center gap-2 text-gray-400">
            <svg class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
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

      {/* Messages */}
      <Show when={!isLoading()}>
        <div class="flex-1 overflow-y-auto p-4 space-y-4">
          <Show
            when={displayMessages().length > 0}
            fallback={
              <div class="h-full flex items-center justify-center text-gray-500 text-sm">
                Start a conversation with the AI agent
              </div>
            }
          >
            <For each={displayMessages()}>
              {(message) => (
                <MessageBubble message={message} formatTime={formatTime} />
              )}
            </For>
          </Show>
          <div ref={messagesEndRef} />
        </div>
      </Show>

      {/* Input */}
      <form onSubmit={handleSubmit} class="p-4 border-t border-gray-800">
        <div class="flex gap-2">
          <input
            ref={inputRef}
            type="text"
            value={input()}
            onInput={(e) => setInput(e.currentTarget.value)}
            onKeyDown={handleKeyDown}
            placeholder={isConnected() ? "Type a message..." : "Connecting..."}
            disabled={!isConnected() || isSending()}
            class="flex-1 px-4 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent disabled:opacity-50 disabled:cursor-not-allowed"
          />
          <button
            type="submit"
            disabled={!isConnected() || isSending() || !input().trim()}
            class="px-4 py-2 bg-brand-600 hover:bg-brand-700 disabled:bg-brand-800 disabled:cursor-not-allowed text-white rounded-lg transition-colors flex items-center gap-2"
          >
            <Show when={isSending()} fallback="Send">
              <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
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
        </div>
      </form>
    </div>
  );
}

// Message Bubble Component
interface MessageBubbleProps {
  message: LegacyChatMessage;
  formatTime: (dateStr?: string) => string;
}

function MessageBubble(props: MessageBubbleProps) {
  const isUser = () => props.message.role === "user";
  const isProcessing = () => props.message.status === "processing";
  const isFailed = () => props.message.status === "failed";

  return (
    <div class={`flex ${isUser() ? "justify-end" : "justify-start"}`}>
      <div
        class={`max-w-[85%] rounded-lg px-4 py-2 ${
          isUser() ? "bg-brand-600 text-white" : "bg-gray-800 text-gray-100"
        }`}
      >
        {/* Message Content */}
        <div class="whitespace-pre-wrap break-words">
          {props.message.content ||
            (isProcessing() && (
              <span class="inline-flex items-center gap-1 text-gray-400">
                <span class="w-2 h-2 bg-current rounded-full animate-pulse" />
                <span
                  class="w-2 h-2 bg-current rounded-full animate-pulse"
                  style={{ "animation-delay": "0.2s" }}
                />
                <span
                  class="w-2 h-2 bg-current rounded-full animate-pulse"
                  style={{ "animation-delay": "0.4s" }}
                />
              </span>
            ))}
        </div>

        {/* Streaming indicator */}
        <Show when={isProcessing() && props.message.content}>
          <span class="inline-block w-1.5 h-4 bg-current animate-pulse ml-0.5" />
        </Show>

        {/* Failed indicator */}
        <Show when={isFailed()}>
          <div class="mt-1 text-xs text-red-400 flex items-center gap-1">
            <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z" />
            </svg>
            Failed to send
          </div>
        </Show>

        {/* Timestamp */}
        <Show when={props.message.inserted_at}>
          <div
            class={`mt-1 text-xs ${
              isUser() ? "text-brand-200" : "text-gray-500"
            }`}
          >
            {props.formatTime(props.message.inserted_at)}
          </div>
        </Show>
      </div>
    </div>
  );
}
