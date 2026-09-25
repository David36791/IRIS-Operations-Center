<script setup lang="ts">
import StatusBadge from './StatusBadge.vue'

defineProps<{
  time: string
  message: string
  status?: string
  source?: string
}>()
</script>

<template>
  <div class="log-item">
    <span class="log-time">{{ time }}</span>
    <StatusBadge v-if="status" :status="status" />
    <span v-if="source" class="log-source">{{ source }}</span>
    <span class="log-message">{{ message }}</span>
  </div>
</template>

<style scoped>
.log-item {
  display: grid;
  grid-template-columns: 132px 84px 1fr;
  align-items: baseline;
  gap: var(--space-3);
  padding: var(--space-2) var(--space-4);
  border-bottom: 1px solid var(--color-border);
}
.log-time {
  color: var(--color-text-faint);
  font-family: var(--font-mono);
  font-size: var(--text-sm);
}
.log-source {
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}
.log-message {
  min-width: 0;
  overflow-wrap: anywhere;
}
</style>
