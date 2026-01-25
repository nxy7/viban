<template>
  <div
    class="task-card p-3 bg-gray-800 hover:bg-gray-750 border border-gray-700 rounded-lg cursor-pointer transition-all"
    :class="{ 'ring-2 ring-brand-500 border-brand-500': selected }"
    :data-task-id="task.id"
    @click="$emit('click')"
  >
    <div class="flex items-start gap-2">
      <div class="flex-1 min-w-0">
        <h4 class="text-sm font-medium text-white truncate">{{ task.title }}</h4>

        <p
          v-if="task.description"
          class="mt-1 text-xs text-gray-400 line-clamp-2"
        >
          {{ task.description }}
        </p>
      </div>

      <div v-if="task.agent_status && task.agent_status !== 'idle'" class="flex-shrink-0">
        <div
          class="w-2 h-2 rounded-full animate-pulse"
          :class="agentStatusClass"
        />
      </div>
    </div>

    <div class="mt-2 flex items-center gap-2 flex-wrap">
      <span
        v-if="task.is_parent"
        class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-blue-900/50 text-blue-400"
      >
        parent
      </span>

      <span
        v-if="task.worktree_branch"
        class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-xs font-medium bg-gray-700 text-gray-300 max-w-[120px]"
      >
        <svg class="w-3 h-3 flex-shrink-0" viewBox="0 0 16 16" fill="currentColor">
          <path fill-rule="evenodd" d="M11.75 2.5a.75.75 0 100 1.5.75.75 0 000-1.5zm-2.25.75a2.25 2.25 0 113 2.122V6A2.5 2.5 0 0110 8.5H6a1 1 0 00-1 1v1.128a2.251 2.251 0 11-1.5 0V5.372a2.25 2.25 0 111.5 0v1.836A2.492 2.492 0 016 7h4a1 1 0 001-1v-.628A2.25 2.25 0 019.5 3.25zM4.25 12a.75.75 0 100 1.5.75.75 0 000-1.5zM3.5 3.25a.75.75 0 111.5 0 .75.75 0 01-1.5 0z"/>
        </svg>
        <span class="truncate">{{ task.worktree_branch }}</span>
      </span>

      <a
        v-if="task.pr_url"
        :href="task.pr_url"
        target="_blank"
        @click.stop
        class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-xs font-medium transition-colors"
        :class="prStatusClass"
      >
        <svg class="w-3 h-3 flex-shrink-0" viewBox="0 0 16 16" fill="currentColor">
          <path fill-rule="evenodd" d="M7.177 3.073L9.573.677A.25.25 0 0110 .854v4.792a.25.25 0 01-.427.177L7.177 3.427a.25.25 0 010-.354zM3.75 2.5a.75.75 0 100 1.5.75.75 0 000-1.5zm-2.25.75a2.25 2.25 0 113 2.122v5.256a2.251 2.251 0 11-1.5 0V5.372A2.25 2.25 0 011.5 3.25zM11 2.5h-1V4h1a1 1 0 011 1v5.628a2.251 2.251 0 101.5 0V5A2.5 2.5 0 0011 2.5zm1 10.25a.75.75 0 111.5 0 .75.75 0 01-1.5 0zM3.75 12a.75.75 0 100 1.5.75.75 0 000-1.5z"/>
        </svg>
        #{{ task.pr_number }}
      </a>
    </div>

    <div
      v-if="task.agent_status_message && task.agent_status !== 'idle'"
      class="mt-2 text-xs text-gray-500 truncate"
    >
      {{ task.agent_status_message }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

interface Task {
  id: string
  title: string
  description: string | null
  position: string
  column_id: string
  parent_task_id: string | null
  is_parent: boolean
  worktree_path: string | null
  worktree_branch: string | null
  agent_status: string | null
  agent_status_message: string | null
  pr_url: string | null
  pr_number: number | null
  pr_status: string | null
}

const props = defineProps<{
  task: Task
  selected: boolean
}>()

defineEmits<{
  (e: 'click'): void
}>()

const agentStatusClass = computed(() => {
  switch (props.task.agent_status) {
    case 'thinking':
      return 'bg-yellow-400'
    case 'executing':
      return 'bg-green-400'
    case 'error':
      return 'bg-red-400'
    default:
      return 'bg-gray-400'
  }
})

const prStatusClass = computed(() => {
  switch (props.task.pr_status) {
    case 'open':
      return 'bg-green-900/50 text-green-400 hover:bg-green-900/70'
    case 'merged':
      return 'bg-purple-900/50 text-purple-400 hover:bg-purple-900/70'
    case 'closed':
      return 'bg-red-900/50 text-red-400 hover:bg-red-900/70'
    case 'draft':
      return 'bg-gray-700 text-gray-400 hover:bg-gray-600'
    default:
      return 'bg-gray-700 text-gray-400 hover:bg-gray-600'
  }
})
</script>
