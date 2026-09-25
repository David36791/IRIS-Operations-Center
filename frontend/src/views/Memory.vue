<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import AppTable from '@/components/AppTable.vue'
import MetricCard from '@/components/MetricCard.vue'
import { getMemoryUsage, type SharedMemoryRow } from '@/api/system'
import type { Column } from '@/types/ui'

const loading = ref(true)
const error = ref<string | null>(null)
const rows = ref<SharedMemoryRow[]>([])

const columns: Column[] = [
  { key: 'Description', label: 'Subsystem' },
  { key: 'SMHAllocated', label: 'Allocated', align: 'right' },
  { key: 'SMHUsed', label: 'Used', align: 'right' },
  { key: 'SMHAvailable', label: 'Available', align: 'right' },
  { key: 'SMTUsed', label: 'Table used', align: 'right' },
  { key: 'AllUsed', label: 'Total used', align: 'right' }
]

function sum(key: keyof SharedMemoryRow): number {
  return rows.value.reduce((total, row) => total + Number(row[key] || 0), 0)
}

const allocated = computed(() => sum('SMHAllocated'))
const used = computed(() => sum('SMHUsed'))
const available = computed(() => sum('SMHAvailable'))
const usagePercent = computed(() => (allocated.value ? Math.round((used.value / allocated.value) * 100) : 0))

async function load() {
  loading.value = true
  try {
    rows.value = await getMemoryUsage()
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : String(cause)
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <h1>Memory</h1>
      <small>IRIS shared memory (SMH/SMT/GST)</small>
    </div>

    <p v-if="loading" class="state">Loading…</p>
    <p v-else-if="error" class="state is-error">Error: {{ error }}</p>

    <template v-else>
      <div class="metrics">
        <MetricCard label="Allocated" :value="allocated" />
        <MetricCard label="Used" :value="used" />
        <MetricCard label="Available" :value="available" />
        <MetricCard label="Usage" :value="usagePercent" unit="%" status="INFO" />
      </div>

      <AppTable :columns="columns" :rows="rows as unknown as Record<string, unknown>[]" row-key="Description" empty-title="No shared memory segments">
        <template #cell="{ column, value }">
          <template v-if="column.align === 'right'">{{ Number(value || 0).toLocaleString() }}</template>
          <template v-else>{{ value }}</template>
        </template>
      </AppTable>

      <p class="note">
        These are IRIS shared-memory segments, which is what the instance reports about its own memory use; host
        total/free memory is not exposed by the IRIS management API.
      </p>
    </template>
  </div>
</template>

<style scoped>
.metrics {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: var(--space-3);
}
.note {
  margin: 0;
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
.state.is-error {
  color: var(--status-error);
}
</style>
