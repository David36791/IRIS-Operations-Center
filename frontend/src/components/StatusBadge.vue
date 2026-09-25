<script setup lang="ts">
import { computed } from 'vue'
import { STATUS_LABELS, isStatus, statusTone } from '@/types/status'

const props = defineProps<{ status: string }>()

const tone = computed(() => statusTone(props.status))
const label = computed(() => {
  const key = props.status.toUpperCase()
  return isStatus(key) ? STATUS_LABELS[key] : props.status
})
</script>

<template>
  <span class="status-badge" :class="`tone-${tone}`" :title="status">{{ label }}</span>
</template>

<style scoped>
.status-badge {
  display: inline-block;
  padding: 1px 7px;
  border-radius: var(--radius-sm);
  font-size: var(--text-sm);
  font-weight: 600;
  line-height: 17px;
  white-space: nowrap;
}

.tone-ok {
  color: var(--status-ok);
  background: var(--status-ok-bg);
}
.tone-info {
  color: var(--status-info);
  background: var(--status-info-bg);
}
.tone-warn {
  color: var(--status-warn);
  background: var(--status-warn-bg);
}
.tone-error {
  color: var(--status-error);
  background: var(--status-error-bg);
}
.tone-muted {
  color: var(--status-muted);
  background: var(--status-muted-bg);
}
</style>
