<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import AppTable from '@/components/AppTable.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import { getDevices, type IrisDevice } from '@/api/system'
import type { Column } from '@/types/ui'

const loading = ref(true)
const error = ref<string | null>(null)
const devices = ref<IrisDevice[]>([])
const search = ref('')

const columns: Column[] = [
  { key: 'Name', label: 'Device' },
  { key: 'Type', label: 'Type' },
  { key: 'SubType', label: 'Status' },
  { key: 'PhysicalDevice', label: 'Physical device' },
  { key: 'Description', label: 'Details' }
]

const visible = computed(() => {
  const query = search.value.trim().toLowerCase()
  if (!query) return devices.value
  return devices.value.filter((device) =>
    `${device.Name} ${device.Type} ${device.SubType} ${device.PhysicalDevice} ${device.Description}`
      .toLowerCase()
      .includes(query)
  )
})

async function load() {
  loading.value = true
  try {
    devices.value = await getDevices()
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
      <h1>Devices</h1>
      <small>{{ devices.length }} configured devices</small>
    </div>

    <p v-if="error" class="state is-error">Error: {{ error }}</p>

    <input v-model="search" class="search" type="search" placeholder="Filter devices…" />

    <AppTable :columns="columns" :rows="visible as unknown as Record<string, unknown>[]" row-key="Name" :loading="loading" empty-title="No devices">
      <template #cell="{ column, value }">
        <StatusBadge v-if="column.key === 'SubType'" :status="value ? 'INFO' : 'DISABLED'" />
        <span v-else-if="column.key === 'Name'" class="mono">{{ value }}</span>
        <template v-else>{{ value || '—' }}</template>
      </template>
    </AppTable>
  </div>
</template>

<style scoped>
.search {
  max-width: 360px;
}
.mono {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
}
.state.is-error {
  color: var(--status-error);
}
</style>
