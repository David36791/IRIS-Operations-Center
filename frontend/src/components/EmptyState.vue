<script setup lang="ts">
defineProps<{ title?: string; description?: string }>()
</script>

<template>
  <div class="empty-state">
    <div class="empty-title">{{ title ?? 'Nothing to show' }}</div>
    <p v-if="description" class="empty-desc">{{ description }}</p>
    <div v-if="$slots.default" class="empty-actions"><slot /></div>
  </div>
</template>

<style scoped>
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-6) var(--space-4);
  text-align: center;
}
.empty-title {
  color: var(--color-text-muted);
  font-weight: 600;
}
.empty-desc {
  max-width: 46ch;
  margin: 0;
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
.empty-actions {
  margin-top: var(--space-2);
}
</style>
