<template>
  <div class="h-full flex overflow-x-auto p-4 gap-4">
    <Column
      v-for="(column, index) in columns"
      :key="column.id"
      :column="column"
      :selected-task-id="selectedTaskId"
      :is-first-column="index === 0"
      @select-task="handleSelectTask"
      @move-task="handleMoveTask"
      @create-task="handleCreateTask"
      @open-settings="handleOpenSettings"
    />
  </div>
</template>

<script setup lang="ts">
import { defineProps, defineEmits } from 'vue'
import Column from './Column.vue'

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

interface Board {
  id: string
  name: string
  description: string | null
}

const props = defineProps<{
  board: Board
  columns: ColumnData[]
  selectedTaskId: string | null
}>()

const emit = defineEmits<{
  (e: 'selectTask', data: { taskId: string }): void
  (e: 'moveTask', data: { taskId: string; columnId: string; prevTaskId: string | null; nextTaskId: string | null }): void
  (e: 'createTask', data: { columnId: string }): void
  (e: 'openSettings', data: { columnId: string }): void
}>()

function handleSelectTask(data: { taskId: string }) {
  emit('selectTask', data)
}

function handleMoveTask(data: { taskId: string; columnId: string; prevTaskId: string | null; nextTaskId: string | null }) {
  emit('moveTask', data)
}

function handleCreateTask(data: { columnId: string }) {
  emit('createTask', data)
}

function handleOpenSettings(data: { columnId: string }) {
  emit('openSettings', data)
}
</script>
