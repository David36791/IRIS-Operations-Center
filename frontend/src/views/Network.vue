<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import AppTable from '@/components/AppTable.vue'
import MetricCard from '@/components/MetricCard.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import { getDashboard } from '@/api/dashboard'
import { getProcesses, type IrisProcess } from '@/api/system'
import type { Column } from '@/types/ui'

const loading = ref(true)
const error = ref<string | null>(null)
const ecp = ref<Record<string, unknown>>({})
const processes = ref<IrisProcess[]>([])

const columns: Column[] = [
  { key: 'Interface', label: 'Interface' },
  { key: 'State', label: 'Status' },
  { key: 'RX', label: 'RX', align: 'right' },
  { key: 'TX', label: 'TX', align: 'right' }
]

/** IRIS exposes its network view as ECP links and client connections. */
const links = computed(() => {
  const values = Object.entries(ecp.value).filter(([key]) => /client|server|shadow/i.test(key))
  return values
    .filter(([key]) => !/traffic/i.test(key))
    .map(([key, value]) => ({
      Interface: key,
      State: String(value),
      RX: '—',
      TX: '—'
    }))
})

const clientCount = computed(() => processes.value.filter((item) => item.IPAddress || item.ClientName).length)

const traffic = computed(() => {
  const entry = Object.entries(ecp.value).find(([key]) => /traffic/i.test(key))
  return entry ? String(entry[1]) : '—'
})

async function load() {
  loading.value = true
  try {
    const [dash, list] = await Promise.all([getDashboard(), getProcesses()])
    ecp.value = (dash as unknown as { ECP?: Record<string, unknown> }).ECP ?? {}
    processes.value = list
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
      <h1>Network</h1>
      <small>IRIS-level connectivity (ECP links and client connections)</small>
    </div>

    <p v-if="loading" class="state">Loading…</p>
    <p v-else-if="error" class="state is-error">Error: {{ error }}</p>

    <template v-else>
      <div class="metrics">
        <MetricCard label="Client connections" :value="clientCount" />
        <MetricCard label="ECP traffic" :value="traffic" />
      </div>

      <AppTable :columns="columns" :rows="links as unknown as Record<string, unknown>[]" row-key="Interface" empty-title="No ECP links reported">
        <template #cell="{ column, value }">
          <StatusBadge v-if="column.key === 'State'" :status="String(value).toLowerCase() === 'normal' ? 'HEALTHY' : 'WARNING'" />
          <template v-else>{{ value }}</template>
        </template>
      </AppTable>

      <p class="note">
        IRIS reports connectivity, not host interfaces: interface-level RX/TX counters are not available through the
        IRIS management API, so they are shown as “—”.
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
