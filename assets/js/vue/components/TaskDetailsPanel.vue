<template>
    <div class="fixed inset-0 z-50 flex justify-end">
        <!-- Backdrop -->
        <div
            v-if="!fullscreen"
            class="fixed inset-0 bg-black/50 backdrop-blur-sm"
            @click="$emit('close')"
        />

        <!-- Panel -->
        <div
            ref="panelRef"
            class="relative bg-gray-900 border-l border-gray-800 shadow-xl h-full overflow-hidden flex flex-col animate-in slide-in-from-right duration-200"
            :class="fullscreen ? 'w-full' : 'w-[32rem]'"
        >
            <!-- Header -->
            <div class="flex-shrink-0 border-b border-gray-800">
                <div class="flex items-center justify-between px-4 py-3">
                    <div class="flex items-center gap-2 min-w-0">
                        <AgentStatusBadge
                            v-if="task.agent_status"
                            :status="task.agent_status"
                            @clearError="
                                $emit('clearError', { taskId: task.id })
                            "
                        />
                        <h2 class="text-lg font-semibold text-white truncate">
                            {{ task.title }}
                        </h2>
                    </div>

                    <div class="flex items-center gap-1 flex-shrink-0">
                        <!-- Open folder button -->
                        <button
                            v-if="task.worktree_path"
                            class="p-1.5 text-gray-400 hover:text-white hover:bg-gray-800 rounded transition-colors"
                            title="Open folder"
                            @click="$emit('openFolder', { taskId: task.id })"
                        >
                            <FolderIcon class="w-4 h-4" />
                        </button>

                        <!-- Open in editor button -->
                        <button
                            v-if="task.worktree_path"
                            class="p-1.5 text-gray-400 hover:text-white hover:bg-gray-800 rounded transition-colors"
                            title="Open in editor"
                            @click="$emit('openInEditor', { taskId: task.id })"
                        >
                            <CodeIcon class="w-4 h-4" />
                        </button>

                        <!-- View PR link -->
                        <a
                            v-if="task.pr_url"
                            :href="task.pr_url"
                            target="_blank"
                            class="p-1.5 text-gray-400 hover:text-white hover:bg-gray-800 rounded transition-colors"
                            title="View PR"
                        >
                            <PrIcon class="w-4 h-4" />
                        </a>

                        <!-- Create PR button -->
                        <button
                            v-else-if="task.worktree_branch"
                            class="p-1.5 text-gray-400 hover:text-brand-400 hover:bg-gray-800 rounded transition-colors"
                            title="Create Pull Request"
                            @click="
                                $emit('showCreatePrModal', { taskId: task.id })
                            "
                        >
                            <PrIcon class="w-4 h-4" />
                        </button>

                        <!-- Hide details toggle -->
                        <button
                            class="p-1.5 hover:bg-gray-800 rounded transition-colors"
                            :class="
                                hideDetails
                                    ? 'text-brand-400'
                                    : 'text-gray-400 hover:text-white'
                            "
                            :title="
                                hideDetails ? 'Show details' : 'Hide details'
                            "
                            @click="$emit('toggleHideDetails')"
                        >
                            <EyeIcon v-if="hideDetails" class="w-4 h-4" />
                            <EyeOffIcon v-else class="w-4 h-4" />
                        </button>

                        <!-- Fullscreen toggle -->
                        <button
                            class="p-1.5 hover:bg-gray-800 rounded transition-colors"
                            :class="
                                fullscreen
                                    ? 'text-brand-400'
                                    : 'text-gray-400 hover:text-white'
                            "
                            :title="
                                fullscreen ? 'Exit fullscreen' : 'Fullscreen'
                            "
                            @click="$emit('toggleFullscreen')"
                        >
                            <MinimizeIcon v-if="fullscreen" class="w-4 h-4" />
                            <MaximizeIcon v-else class="w-4 h-4" />
                        </button>

                        <!-- Close button -->
                        <button
                            class="p-1.5 text-gray-400 hover:text-white hover:bg-gray-800 rounded transition-colors"
                            title="Close"
                            @click="$emit('close')"
                        >
                            <CloseIcon class="w-5 h-5" />
                        </button>
                    </div>
                </div>

                <!-- Branch info -->
                <div
                    v-if="task.worktree_branch"
                    class="px-4 pb-2 flex items-center gap-2"
                >
                    <span class="text-xs text-gray-500 font-mono truncate">{{
                        task.worktree_branch
                    }}</span>
                    <a
                        v-if="task.pr_url"
                        :href="task.pr_url"
                        target="_blank"
                        class="inline-flex items-center gap-1 px-2 py-0.5 text-xs rounded-full"
                        :class="prStatusClass"
                    >
                        PR #{{ task.pr_number }}
                    </a>
                </div>

                <!-- No worktree warning -->
                <div
                    v-if="!task.worktree_path"
                    class="mx-4 mb-2 p-2 bg-amber-900/30 border border-amber-700/50 rounded-lg flex items-center justify-between gap-2"
                >
                    <div class="flex items-center gap-2 text-amber-400 text-sm">
                        <svg
                            class="w-4 h-4 flex-shrink-0"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                        >
                            <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                            />
                        </svg>
                        <span>No worktree</span>
                    </div>
                    <button
                        class="px-2 py-1 text-xs bg-amber-600 hover:bg-amber-700 text-white rounded transition-colors"
                        @click="$emit('createWorktree', { taskId: task.id })"
                    >
                        Create
                    </button>
                </div>

                <!-- Agent status message -->
                <div v-if="task.agent_status_message" class="px-4 pb-2">
                    <div class="flex items-center gap-2 text-sm text-gray-400">
                        <span class="animate-pulse">●</span>
                        <span class="truncate">{{
                            task.agent_status_message
                        }}</span>
                    </div>
                </div>
            </div>

            <!-- Activity Feed - Scrollable -->
            <div ref="activityRef" class="flex-1 overflow-y-auto px-4 py-4">
                <div class="space-y-4">
                    <!-- Task created message -->
                    <div v-if="!hideDetails" class="flex items-start gap-3">
                        <div
                            class="w-8 h-8 rounded-full bg-gray-800 flex items-center justify-center flex-shrink-0"
                        >
                            <PlusIcon class="w-4 h-4 text-gray-400" />
                        </div>
                        <div class="flex-1 min-w-0">
                            <p class="text-sm text-gray-300">Task created</p>
                            <p
                                v-if="task.description"
                                class="text-sm text-gray-500 mt-1 whitespace-pre-wrap"
                            >
                                {{ task.description }}
                            </p>
                            <p class="text-xs text-gray-600 mt-1">
                                {{ formatActivityTime(task.inserted_at) }}
                            </p>
                        </div>
                    </div>

                    <!-- Activity items -->
                    <template v-for="item in processedActivity" :key="item.id">
                        <!-- Collapsed hook group -->
                        <div
                            v-if="item.type === 'hook_group' && !hideDetails"
                            class="relative flex items-center gap-2 py-1 px-2 text-xs text-gray-500 group/hooks cursor-default"
                        >
                            <span
                                class="w-1.5 h-1.5 rounded-full flex-shrink-0"
                                :class="hookStatusDot(item.status)"
                            />
                            <span>{{ item.count }} hooks</span>
                            <span :class="hookStatusTextColor(item.status)">{{
                                hookStatusText(item.status)
                            }}</span>
                            <span
                                v-if="item.total_duration_ms"
                                class="text-gray-600"
                                >in
                                {{
                                    formatDuration(item.total_duration_ms)
                                }}</span
                            >
                            <span class="text-gray-600 ml-auto flex-shrink-0">{{
                                formatActivityTime(item.timestamp)
                            }}</span>

                            <!-- Hover popup with delay -->
                            <div
                                class="absolute left-0 bottom-full mb-1 opacity-0 invisible group-hover/hooks:opacity-100 group-hover/hooks:visible transition-all duration-150 delay-[250ms] z-10 bg-gray-800 border border-gray-700 rounded-lg shadow-xl py-2 px-3 min-w-[200px]"
                            >
                                <div
                                    v-for="hook in item.hooks"
                                    :key="hook.id"
                                    class="flex items-center gap-2 py-1 text-xs text-gray-400"
                                >
                                    <span
                                        class="w-1.5 h-1.5 rounded-full flex-shrink-0"
                                        :class="hookStatusDot(hook.status)"
                                    />
                                    <span class="truncate">{{
                                        hook.hook_name
                                    }}</span>
                                    <span
                                        v-if="hook.duration_ms"
                                        class="text-gray-600 ml-auto"
                                        >{{
                                            formatDuration(hook.duration_ms)
                                        }}</span
                                    >
                                </div>
                            </div>
                        </div>

                        <!-- Single hook execution -->
                        <div
                            v-else-if="
                                item.type === 'hook_execution' && !hideDetails
                            "
                            class="flex items-center gap-2 py-1 px-2 text-xs text-gray-500"
                        >
                            <span
                                class="w-1.5 h-1.5 rounded-full flex-shrink-0"
                                :class="hookStatusDot(item.status)"
                            />
                            <span class="truncate">{{ item.hook_name }}</span>
                            <span :class="hookStatusTextColor(item.status)">{{
                                hookStatusText(item.status)
                            }}</span>
                            <span
                                v-if="item.duration_ms"
                                class="text-gray-600"
                                >{{ formatDuration(item.duration_ms) }}</span
                            >
                            <span
                                v-if="item.error_message"
                                class="text-red-400 truncate"
                                :title="item.error_message"
                            >
                                - {{ item.error_message }}
                            </span>
                            <span class="text-gray-600 ml-auto flex-shrink-0">{{
                                formatActivityTime(item.timestamp)
                            }}</span>
                        </div>

                        <!-- Message -->
                        <div
                            v-else-if="item.type === 'message'"
                            class="flex"
                            :class="
                                item.role === 'user'
                                    ? 'justify-end'
                                    : 'justify-start'
                            "
                        >
                            <div
                                class="max-w-[85%] rounded-2xl px-3 py-2"
                                :class="[
                                    item.role === 'user'
                                        ? 'bg-brand-600 rounded-br-md'
                                        : 'bg-gray-700 rounded-bl-md',
                                ]"
                            >
                                <p
                                    class="text-sm text-gray-100 whitespace-pre-wrap break-words"
                                >
                                    {{ truncateContent(item.content, 500) }}
                                </p>
                                <p
                                    v-if="!hideDetails"
                                    class="text-xs mt-1"
                                    :class="
                                        item.role === 'user'
                                            ? 'text-brand-300'
                                            : 'text-gray-500'
                                    "
                                >
                                    {{ formatActivityTime(item.timestamp) }}
                                </p>
                            </div>
                        </div>

                        <!-- Executor Message (Claude response) -->
                        <div
                            v-else-if="item.type === 'executor_message'"
                            class="flex justify-start"
                        >
                            <div
                                class="max-w-[85%] rounded-2xl px-3 py-2 rounded-bl-md"
                                :class="[
                                    item.role === 'assistant'
                                        ? 'bg-gray-700'
                                        : item.role === 'system'
                                          ? 'bg-gray-800'
                                          : 'bg-gray-700',
                                ]"
                            >
                                <p
                                    class="text-sm text-gray-100 whitespace-pre-wrap break-words"
                                >
                                    {{ truncateContent(item.content, 500) }}
                                </p>
                                <p
                                    v-if="!hideDetails"
                                    class="text-xs mt-1 text-gray-500"
                                >
                                    {{ formatActivityTime(item.timestamp) }}
                                </p>
                            </div>
                        </div>
                    </template>
                </div>
            </div>

            <!-- Input area at bottom -->
            <div class="flex-shrink-0 border-t border-gray-800 p-4">
                <div class="flex flex-col gap-2">
                    <div
                        class="flex items-center gap-2 text-xs text-gray-500 px-1"
                    >
                        <span>Claude Code</span>
                    </div>
                    <div class="flex gap-2">
                        <textarea
                            ref="inputRef"
                            v-model="message"
                            rows="1"
                            placeholder="Enter a prompt... (⌘+Enter to send)"
                            class="flex-1 px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-1 focus:ring-brand-500 resize-none"
                            @keydown="handleKeydown"
                            @input="autoResize"
                        />
                        <button
                            class="px-3 py-2 bg-brand-600 hover:bg-brand-700 text-white rounded-lg transition-colors"
                            title="Send"
                            @click="sendMessage"
                        >
                            <SendIcon class="w-4 h-4" />
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, nextTick, onMounted } from "vue";

// Types
interface Task {
    id: string;
    title: string;
    description: string | null;
    agent_status: string | null;
    agent_status_message: string | null;
    worktree_path: string | null;
    worktree_branch: string | null;
    pr_url: string | null;
    pr_number: number | null;
    pr_status: string | null;
    inserted_at: string;
}

interface ActivityItem {
    id: string;
    type: "hook_execution" | "message" | "executor_message";
    // Hook execution fields
    hook_name?: string;
    status?: string;
    duration_ms?: number;
    error_message?: string;
    // Message fields
    role?: "user" | "assistant" | "system" | "tool";
    content?: string;
    // Executor message fields
    session_id?: string;
    metadata?: Record<string, unknown>;
    // Common
    timestamp: string;
}

interface CollapsedHookGroup {
    type: "hook_group";
    id: string;
    status: string;
    count: number;
    total_duration_ms: number;
    hooks: ActivityItem[];
    timestamp: string;
}

type ProcessedActivityItem = ActivityItem | CollapsedHookGroup;

// Props
const props = defineProps<{
    task: Task;
    activity: ActivityItem[];
    fullscreen: boolean;
    hideDetails: boolean;
}>();

// Emits
const emit = defineEmits<{
    (e: "close"): void;
    (e: "toggleFullscreen"): void;
    (e: "toggleHideDetails"): void;
    (e: "openFolder", data: { taskId: string }): void;
    (e: "openInEditor", data: { taskId: string }): void;
    (e: "showCreatePrModal", data: { taskId: string }): void;
    (e: "sendMessage", data: { taskId: string; message: string }): void;
    (e: "clearError", data: { taskId: string }): void;
}>();

// Refs
const panelRef = ref<HTMLElement | null>(null);
const activityRef = ref<HTMLElement | null>(null);
const inputRef = ref<HTMLTextAreaElement | null>(null);
const message = ref("");

// Computed
const prStatusClass = computed(() => {
    switch (props.task.pr_status) {
        case "open":
            return "bg-green-900/50 text-green-400";
        case "merged":
            return "bg-purple-900/50 text-purple-400";
        case "closed":
            return "bg-red-900/50 text-red-400";
        case "draft":
            return "bg-gray-700 text-gray-400";
        default:
            return "bg-gray-700 text-gray-400";
    }
});

const processedActivity = computed((): ProcessedActivityItem[] => {
    const result: ProcessedActivityItem[] = [];
    let currentGroup: ActivityItem[] = [];
    let currentStatus: string | null = null;

    const flushGroup = () => {
        if (currentGroup.length === 0) return;

        if (currentGroup.length === 1) {
            result.push(currentGroup[0]);
        } else {
            const totalDuration = currentGroup.reduce(
                (sum, h) => sum + (h.duration_ms || 0),
                0,
            );
            result.push({
                type: "hook_group",
                id: `group-${currentGroup[0].id}`,
                status: currentStatus!,
                count: currentGroup.length,
                total_duration_ms: totalDuration,
                hooks: [...currentGroup],
                timestamp: currentGroup[currentGroup.length - 1].timestamp,
            });
        }
        currentGroup = [];
        currentStatus = null;
    };

    for (const item of props.activity) {
        if (item.type === "hook_execution") {
            const itemStatus = String(item.status);
            if (currentStatus === itemStatus) {
                currentGroup.push(item);
            } else {
                flushGroup();
                currentGroup = [item];
                currentStatus = itemStatus;
            }
        } else {
            flushGroup();
            result.push(item);
        }
    }
    flushGroup();

    console.log(
        "[processedActivity] input:",
        props.activity.length,
        "output:",
        result.length,
        result,
    );

    return result;
});

// Methods
function hookStatusDot(status: string): string {
    switch (status) {
        case "completed":
            return "bg-green-400";
        case "running":
            return "bg-blue-400 animate-pulse";
        case "failed":
            return "bg-red-400";
        case "cancelled":
        case "skipped":
            return "bg-gray-400";
        default:
            return "bg-amber-400";
    }
}

function hookStatusTextColor(status: string): string {
    switch (status) {
        case "completed":
            return "text-green-400";
        case "running":
            return "text-blue-400";
        case "failed":
            return "text-red-400";
        case "cancelled":
        case "skipped":
            return "text-gray-400";
        default:
            return "text-amber-400";
    }
}

function hookStatusText(status: string): string {
    return status || "unknown";
}

function formatDuration(ms: number): string {
    if (ms < 1000) return `${ms}ms`;
    if (ms < 60000) return `${(ms / 1000).toFixed(1)}s`;
    return `${(ms / 60000).toFixed(1)}m`;
}

function formatActivityTime(datetime: string | null): string {
    if (!datetime) return "";

    const date = new Date(datetime);
    const now = new Date();
    const diffSeconds = Math.floor((now.getTime() - date.getTime()) / 1000);

    if (diffSeconds < 60) return "just now";
    if (diffSeconds < 3600) return `${Math.floor(diffSeconds / 60)}m ago`;
    if (diffSeconds < 86400) return `${Math.floor(diffSeconds / 3600)}h ago`;

    return date.toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
        hour: "2-digit",
        minute: "2-digit",
    });
}

function truncateContent(content: string | undefined, max: number): string {
    if (!content) return "";
    if (content.length <= max) return content;
    return content.slice(0, max) + "...";
}

function handleKeydown(event: KeyboardEvent) {
    if (event.key === "Enter" && event.metaKey) {
        event.preventDefault();
        sendMessage();
    }
}

function sendMessage() {
    const trimmed = message.value.trim();
    if (trimmed) {
        emit("sendMessage", { taskId: props.task.id, message: trimmed });
        message.value = "";
        nextTick(() => {
            autoResize();
            scrollToBottom();
        });
    }
}

function scrollToBottom() {
    if (activityRef.value) {
        activityRef.value.scrollTop = activityRef.value.scrollHeight;
    }
}

function autoResize() {
    const textarea = inputRef.value;
    if (textarea) {
        textarea.style.height = "auto";
        textarea.style.height = Math.min(textarea.scrollHeight, 200) + "px";
    }
}

// Auto-scroll to bottom when activity changes
watch(
    () => props.activity.length,
    () => {
        nextTick(() => {
            scrollToBottom();
        });
    },
);

// Focus input on mount
onMounted(() => {
    nextTick(() => {
        inputRef.value?.focus();
    });
});
</script>

<script lang="ts">
// Icon components defined inline for simplicity
import { defineComponent, h } from "vue";

const FolderIcon = defineComponent({
    render() {
        return h(
            "svg",
            { fill: "none", stroke: "currentColor", viewBox: "0 0 24 24" },
            [
                h("path", {
                    "stroke-linecap": "round",
                    "stroke-linejoin": "round",
                    "stroke-width": "2",
                    d: "M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z",
                }),
            ],
        );
    },
});

const CodeIcon = defineComponent({
    render() {
        return h(
            "svg",
            { fill: "none", stroke: "currentColor", viewBox: "0 0 24 24" },
            [
                h("path", {
                    "stroke-linecap": "round",
                    "stroke-linejoin": "round",
                    "stroke-width": "2",
                    d: "M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4",
                }),
            ],
        );
    },
});

const PrIcon = defineComponent({
    render() {
        return h("svg", { viewBox: "0 0 16 16", fill: "currentColor" }, [
            h("path", {
                "fill-rule": "evenodd",
                d: "M7.177 3.073L9.573.677A.25.25 0 0110 .854v4.792a.25.25 0 01-.427.177L7.177 3.427a.25.25 0 010-.354zM3.75 2.5a.75.75 0 100 1.5.75.75 0 000-1.5zm-2.25.75a2.25 2.25 0 113 2.122v5.256a2.251 2.251 0 11-1.5 0V5.372A2.25 2.25 0 011.5 3.25zM11 2.5h-1V4h1a1 1 0 011 1v5.628a2.251 2.251 0 101.5 0V5A2.5 2.5 0 0011 2.5zm1 10.25a.75.75 0 111.5 0 .75.75 0 01-1.5 0zM3.75 12a.75.75 0 100 1.5.75.75 0 000-1.5z",
            }),
        ]);
    },
});

const EyeIcon = defineComponent({
    render() {
        return h(
            "svg",
            { fill: "none", stroke: "currentColor", viewBox: "0 0 24 24" },
            [
                h("path", {
                    "stroke-linecap": "round",
                    "stroke-linejoin": "round",
                    "stroke-width": "2",
                    d: "M15 12a3 3 0 11-6 0 3 3 0 016 0z",
                }),
                h("path", {
                    "stroke-linecap": "round",
                    "stroke-linejoin": "round",
                    "stroke-width": "2",
                    d: "M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z",
                }),
            ],
        );
    },
});

const EyeOffIcon = defineComponent({
    render() {
        return h(
            "svg",
            { fill: "none", stroke: "currentColor", viewBox: "0 0 24 24" },
            [
                h("path", {
                    "stroke-linecap": "round",
                    "stroke-linejoin": "round",
                    "stroke-width": "2",
                    d: "M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21",
                }),
            ],
        );
    },
});

const MaximizeIcon = defineComponent({
    render() {
        return h(
            "svg",
            { fill: "none", stroke: "currentColor", viewBox: "0 0 24 24" },
            [
                h("path", {
                    "stroke-linecap": "round",
                    "stroke-linejoin": "round",
                    "stroke-width": "2",
                    d: "M3.75 3.75v4.5m0-4.5h4.5m-4.5 0L9 9M3.75 20.25v-4.5m0 4.5h4.5m-4.5 0L9 15M20.25 3.75h-4.5m4.5 0v4.5m0-4.5L15 9m5.25 11.25h-4.5m4.5 0v-4.5m0 4.5L15 15",
                }),
            ],
        );
    },
});

const MinimizeIcon = defineComponent({
    render() {
        return h(
            "svg",
            { fill: "none", stroke: "currentColor", viewBox: "0 0 24 24" },
            [
                h("path", {
                    "stroke-linecap": "round",
                    "stroke-linejoin": "round",
                    "stroke-width": "2",
                    d: "M9 9V4.5M9 9H4.5M9 9L3.75 3.75M9 15v4.5M9 15H4.5M9 15l-5.25 5.25M15 9h4.5M15 9V4.5M15 9l5.25-5.25M15 15h4.5M15 15v4.5m0-4.5l5.25 5.25",
                }),
            ],
        );
    },
});

const CloseIcon = defineComponent({
    render() {
        return h(
            "svg",
            { fill: "none", stroke: "currentColor", viewBox: "0 0 24 24" },
            [
                h("path", {
                    "stroke-linecap": "round",
                    "stroke-linejoin": "round",
                    "stroke-width": "2",
                    d: "M6 18L18 6M6 6l12 12",
                }),
            ],
        );
    },
});

const PlusIcon = defineComponent({
    render() {
        return h(
            "svg",
            { fill: "none", stroke: "currentColor", viewBox: "0 0 24 24" },
            [
                h("path", {
                    "stroke-linecap": "round",
                    "stroke-linejoin": "round",
                    "stroke-width": "2",
                    d: "M12 6v6m0 0v6m0-6h6m-6 0H6",
                }),
            ],
        );
    },
});

const SendIcon = defineComponent({
    render() {
        return h(
            "svg",
            { fill: "none", viewBox: "0 0 24 24", stroke: "currentColor" },
            [
                h("path", {
                    "stroke-linecap": "round",
                    "stroke-linejoin": "round",
                    "stroke-width": "2",
                    d: "M12 19l9 2-9-18-9 18 9-2zm0 0v-8",
                }),
            ],
        );
    },
});

const AgentStatusBadge = defineComponent({
    props: {
        status: { type: String, required: true },
    },
    emits: ["clearError"],
    setup(props, { emit }) {
        const statusConfig: Record<
            string,
            { bg: string; text: string; label: string }
        > = {
            idle: { bg: "bg-gray-700", text: "text-gray-400", label: "Idle" },
            thinking: {
                bg: "bg-yellow-900/50",
                text: "text-yellow-400",
                label: "Thinking",
            },
            executing: {
                bg: "bg-green-900/50",
                text: "text-green-400",
                label: "Running",
            },
            error: {
                bg: "bg-red-900/50",
                text: "text-red-400",
                label: "Error",
            },
        };

        return () => {
            const config = statusConfig[props.status] || statusConfig.idle;
            const isError = props.status === "error";

            return h(
                isError ? "button" : "span",
                {
                    class: `inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${config.bg} ${config.text}${isError ? " cursor-pointer hover:bg-red-800/50 transition-colors" : ""}`,
                    title: isError ? "Click to clear error" : undefined,
                    onClick: isError ? () => emit("clearError") : undefined,
                },
                config.label,
            );
        };
    },
});

export default {
    components: {
        FolderIcon,
        CodeIcon,
        PrIcon,
        EyeIcon,
        EyeOffIcon,
        MaximizeIcon,
        MinimizeIcon,
        CloseIcon,
        PlusIcon,
        SendIcon,
        AgentStatusBadge,
    },
};
</script>
