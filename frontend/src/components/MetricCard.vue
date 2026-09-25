<script setup lang="ts">
import StatusBadge from './StatusBadge.vue'

defineProps<{
  label: string
  value: string | number
  unit?: string
  status?: string
  hint?: string
}>()
</script>

<template>
  <div class="metric-card card">
    <div class="metric-label">{{ label }}</div>
    <div class="metric-value">
      {{ value }}<span v-if="unit" class="metric-unit">{{ unit }}</span>
    </div>
    <!-- Always rendered, even when empty: the row it reserves is what keeps a
         card with a hint or a status the same height as one without. -->
    <div class="metric-foot">
      <StatusBadge v-if="status" :status="status" />
      <span v-if="hint" class="metric-hint">{{ hint }}</span>
    </div>
  </div>
</template>

<style scoped>
.metric-card {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
  padding: var(--space-3) var(--space-4);
  min-width: 0;
}
.metric-label {
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}
.metric-value {
  font-size: 22px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}
.metric-unit {
  margin-left: 3px;
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  font-weight: 400;
}
.metric-foot {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  min-height: 18px;
}
.metric-hint {
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
</style>
