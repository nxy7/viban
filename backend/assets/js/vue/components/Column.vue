<template>
  <div
    class="flex-shrink-0 w-80 flex flex-col bg-gray-900/50 rounded-xl border border-gray-800"
  >
    <div class="flex items-center justify-between p-3 border-b border-gray-800">
      <div class="flex items-center gap-2">
        <div
          class="w-3 h-3 rounded-full"
          :style="{ backgroundColor: column.color }"
        />
        <h3 class="font-medium text-white">{{ column.name }}</h3>
        <span class="text-xs text-gray-500 ml-1">{{ column.tasks.length }}</span>
      </div>
      <button
        @click="handleOpenSettings"
        class="p-1 text-gray-400 hover:text-white hover:bg-gray-800 rounded transition-colors"
        title="Column settings"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
        </svg>
      </button>
    </div>

    <div
      ref="taskListRef"
      class="flex-1 overflow-y-auto p-2 space-y-2 min-h-[100px]"
      :data-column-id="column.id"
    >
      <TaskCard
        v-for="task in column.tasks"
        :key="task.id"
        :task="task"
        :selected="task.id === selectedTaskId"
        @click="handleSelectTask(task.id)"
      />
    </div>

    <div v-if="isFirstColumn" class="p-2 border-t border-gray-800">
      <button
        @click="handleCreateTask"
        class="w-full flex items-center justify-center gap-2 p-2 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
        </svg>
        <span class="text-sm">Create task</span>
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch } from 'vue'
import Sortable from 'sortablejs'
import TaskCard from './TaskCard.vue'

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

interface ColumnData {
  id: string
  name: string
  position: number
  color: string
  tasks: Task[]
}

const props = defineProps<{
  column: ColumnData
  selectedTaskId: string | null
  isFirstColumn: boolean
}>()

const emit = defineEmits<{
  (e: 'selectTask', data: { taskId: string }): void
  (e: 'moveTask', data: { taskId: string; columnId: string; prevTaskId: string | null; nextTaskId: string | null }): void
  (e: 'createTask', data: { columnId: string }): void
  (e: 'openSettings', data: { columnId: string }): void
}>()

const taskListRef = ref<HTMLElement | null>(null)
let sortable: Sortable | null = null

function handleSelectTask(taskId: string) {
  emit('selectTask', { taskId })
}

function handleCreateTask() {
  emit('createTask', { columnId: props.column.id })
}

function handleOpenSettings() {
  emit('openSettings', { columnId: props.column.id })
}

function initSortable() {
  if (!taskListRef.value) return

  sortable = Sortable.create(taskListRef.value, {
    group: 'tasks',
    animation: 150,
    ghostClass: 'opacity-50',
    dragClass: 'rotate-2',
    handle: '.task-card',
    draggable: '.task-card',

    onEnd(evt) {
      const taskId = evt.item.getAttribute('data-task-id')
      const toColumnId = evt.to.getAttribute('data-column-id')

      if (!taskId || !toColumnId) return

      const siblings = Array.from(evt.to.children)
      const newIndex = evt.newIndex ?? 0

      const prevSibling = siblings[newIndex - 1] as HTMLElement | undefined
      const nextSibling = siblings[newIndex + 1] as HTMLElement | undefined

      const prevTaskId = prevSibling?.getAttribute('data-task-id') || null
      const nextTaskId = nextSibling?.getAttribute('data-task-id') || null

      emit('moveTask', {
        taskId,
        columnId: toColumnId,
        prevTaskId,
        nextTaskId
      })
    }
  })
}

onMounted(() => {
  initSortable()
})

onUnmounted(() => {
  sortable?.destroy()
})

watch(() => props.column.tasks, () => {
  sortable?.destroy()
  initSortable()
}, { deep: true })
</script>
