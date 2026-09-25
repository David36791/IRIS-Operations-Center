<script setup lang="ts">
import { ref } from 'vue'
import AppTable from '@/components/AppTable.vue'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import EmptyState from '@/components/EmptyState.vue'
import LogItem from '@/components/LogItem.vue'
import MetricCard from '@/components/MetricCard.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import { STATUSES } from '@/types/status'
import type { Column } from '@/types/ui'

const columns: Column[] = [
  { key: 'name', label: 'Name' },
  { key: 'status', label: 'Status' },
  { key: 'value', label: 'Value', align: 'right' }
]

const rows: Record<string, unknown>[] = [
  { name: 'IRIS', status: 'HEALTHY', value: 12 },
  { name: 'ECP', status: 'DEGRADED', value: 3 }
]

const dialogOpen = ref(false)
</script>

<template>
  <div class="page">
    <section class="sg-section">
      <h2>Status badges</h2>
      <div class="row">
        <StatusBadge v-for="status in STATUSES" :key="status" :status="status" />
      </div>
    </section>

    <section class="sg-section">
      <h2>Metric cards</h2>
      <div class="metrics">
        <MetricCard label="Global references" value="1.24" unit="M" status="HEALTHY" hint="last minute" />
        <MetricCard label="Processes" value="25" />
        <MetricCard label="License used" value="2" unit="%" status="WARNING" />
      </div>
    </section>

    <section class="sg-section">
      <h2>Table</h2>
      <AppTable :columns="columns" :rows="rows" row-key="name">
        <template #cell="{ column, value }">
          <StatusBadge v-if="column.key === 'status'" :status="String(value)" />
          <template v-else>{{ value }}</template>
        </template>
      </AppTable>
    </section>

    <section class="sg-section">
      <h2>Log items</h2>
      <div class="card">
        <LogItem time="2026-09-23 10:00:23" status="SUCCESS" source="%SYS" message="Task nightly-backup completed" />
        <LogItem time="2026-09-23 09:58:01" status="ERROR" source="ECP" message="Data server connection refused" />
      </div>
    </section>

    <section class="sg-section">
      <h2>Empty state</h2>
      <div class="card">
        <EmptyState title="No data" description="Nothing matched the current filter." />
      </div>
    </section>

    <section class="sg-section">
      <h2>Confirm dialog</h2>
      <button class="btn btn-danger" @click="dialogOpen = true">Delete application</button>
      <ConfirmDialog
        :open="dialogOpen"
        title="Delete application"
        message="This cannot be undone."
        confirm-label="Delete"
        danger
        @confirm="dialogOpen = false"
        @cancel="dialogOpen = false"
      />
    </section>
  </div>
</template>

<style scoped>
.sg-section {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
}
.sg-section h2 {
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
}
.row {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}
.metrics {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: var(--space-3);
}
</style>
