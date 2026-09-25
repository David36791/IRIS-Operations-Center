<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import AppTable from '@/components/AppTable.vue'
import MetricCard from '@/components/MetricCard.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import { getAuditEnabled, listAuditEvents, listAuditRecords, type AuditEvent } from '@/api/security'
import type { Column } from '@/types/ui'

/** The audit record columns. */
const RECORD_COLUMNS: Column[] = [
  { key: 'timestamp', label: 'Timestamp' },
  { key: 'user', label: 'User' },
  { key: 'action', label: 'Action' },
  { key: 'resourceType', label: 'Resource type' },
  { key: 'resourceId', label: 'Resource' },
  { key: 'result', label: 'Result' },
  { key: 'ip', label: 'IP' },
  { key: 'details', label: 'Details' }
]

const EVENT_COLUMNS: Column[] = [
  { key: 'EventName', label: 'Event' },
  { key: 'Enabled', label: 'Enabled' },
  { key: 'Total', label: 'Total', align: 'right' },
  { key: 'Written', label: 'Written', align: 'right' },
  { key: 'Lost', label: 'Lost', align: 'right' }
]

const loading = ref(true)
const error = ref<string | null>(null)
const enabled = ref<boolean | null>(null)
const events = ref<AuditEvent[]>([])
const records = ref<Record<string, unknown>[]>([])
const recordNote = ref('')
const keyword = ref('')

/** Map whatever the audit record carries onto this table's columns. */
function normalise(record: Record<string, unknown>): Record<string, unknown> {
  const pick = (...candidates: string[]) => {
    for (const name of candidates) {
      const key = Object.keys(record).find((entry) => entry.toLowerCase() === name.toLowerCase())
      if (key && record[key] !== '' && record[key] !== undefined) return String(record[key])
    }
    return '—'
  }
  return {
    timestamp: pick('TimeStamp', 'Time', 'DateTime', 'Timestamp'),
    user: pick('User', 'Username', 'UserID'),
    action: pick('Event', 'Action', 'EventType'),
    resourceType: pick('Resource', 'ResourceType', 'Type'),
    resourceId: pick('ResourceId', 'ResourceID', 'Description'),
    result: pick('Result', 'Status', 'EventResult'),
    ip: pick('IP', 'IPAddress', 'ClientIP'),
    details: pick('Description', 'Details', 'Comment')
  }
}

const visibleRecords = computed(() => {
  const query = keyword.value.trim().toLowerCase()
  if (!query) return records.value
  return records.value.filter((row) =>
    Object.values(row).some((value) => String(value).toLowerCase().includes(query))
  )
})

const enabledEvents = computed(() => events.value.filter((event) => event.Enabled).length)
const recordedTotal = computed(() => events.value.reduce((sum, event) => sum + Number(event.Total || 0), 0))

async function load() {
  loading.value = true
  error.value = null
  try {
    const [state, catalogue] = await Promise.all([getAuditEnabled(), listAuditEvents()])
    const entry = Object.entries(state).find(([key]) => /enabled/i.test(key))
    enabled.value = entry ? Boolean(entry[1]) : null
    events.value = catalogue
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : String(cause)
  }

  try {
    const result = await listAuditRecords({})
    const list = Array.isArray(result) ? result : []
    records.value = list.map(normalise)
    recordNote.value = list.length ? '' : 'The audit database holds no records on this instance.'
  } catch (cause) {
    recordNote.value = cause instanceof Error ? cause.message : String(cause)
  }

  loading.value = false
}

onMounted(load)
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <h1>Audit</h1>
      <small>Audit records and the event catalogue</small>
    </div>

    <p v-if="error" class="state is-error">Error: {{ error }}</p>

    <template v-if="!loading">
      <div class="metrics">
        <MetricCard
          label="Auditing"
          :value="enabled === null ? 'unknown' : enabled ? 'enabled' : 'disabled'"
          :status="enabled ? 'HEALTHY' : 'DISABLED'"
        />
        <MetricCard label="Events tracked" :value="enabledEvents" :hint="`of ${events.length} defined`" />
        <MetricCard label="Audit records" :value="records.length" />
        <MetricCard label="Events recorded" :value="recordedTotal" />
      </div>

      <section class="section">
        <div class="section-head">
          <h2>Records</h2>
          <input v-model="keyword" type="search" placeholder="Filter records…" />
        </div>
        <p v-if="recordNote" class="muted">{{ recordNote }}</p>
        <AppTable :columns="RECORD_COLUMNS" :rows="visibleRecords" row-key="timestamp" empty-title="No audit records">
          <template #cell="{ column, value }">
            <span v-if="column.key === 'timestamp'" class="mono">{{ value }}</span>
            <template v-else>{{ value }}</template>
          </template>
        </AppTable>
      </section>

      <section class="section">
        <h2>Event catalogue</h2>
        <AppTable :columns="EVENT_COLUMNS" :rows="events as unknown as Record<string, unknown>[]" row-key="EventName" empty-title="No audit events defined">
          <template #cell="{ column, value }">
            <StatusBadge v-if="column.key === 'Enabled'" :status="value ? 'HEALTHY' : 'DISABLED'" />
            <template v-else>{{ value }}</template>
          </template>
        </AppTable>
      </section>

      <p class="note">
        Recording reveals of secrets and other IOC-side actions is not wired up: the management API exposes audit
        records for reading only, and the audit write path needs an IRIS API that has not been established here.
        Revealing a secret already requires confirmation and never persists the value.
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
.section {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}
.section h2 {
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
}
.section-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
}
.section-head input {
  max-width: 280px;
}
.mono {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
}
.muted,
.note {
  margin: 0;
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
.state.is-error {
  color: var(--status-error);
}
</style>
