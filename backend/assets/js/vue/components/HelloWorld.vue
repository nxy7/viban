<script setup lang="ts">
defineProps<{
  message?: string
}>()
</script>

<template>
  <div class="p-4 bg-gray-800 rounded-lg">
    <h1 class="text-2xl font-bold text-white">{{ message || 'Hello from Vue!' }}</h1>
    <p class="text-gray-400 mt-2">LiveVue is working!</p>
  </div>
</template>
