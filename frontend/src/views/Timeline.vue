<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import EmptyState from '@/components/EmptyState.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import { getDashboard } from '@/api/dashboard'
import { getAuditLog } from '@/api/logs'
import { listTaskHistory } from '@/api/tasks'

/** Event types on the stream. */
type EventType = 'SYSTEM' | 'TASK' | 'APPLICATION' | 'SECURITY' | 'LOG' | 'NETWORK'

interface TimelineEvent {
  id: string
  timestamp: string
  type: EventType
  severity: string
  source: string
  title: string
  description: string
  related?: { label: string; to: string }
}

const TYPES: EventType[] = ['SYSTEM', 'TASK', 'APPLICATION', 'SECURITY', 'LOG', 'NETWORK']

const loading = ref(true)
const error = ref<string | null>(null)
const events = ref<TimelineEvent[]>([])
const typeFilter = ref<'all' | EventType>('all')
const keyword = ref('')
const limit = ref(100)
const detail = ref<TimelineEvent | null>(null)

const visible = computed(() => {
  const query = keyword.value.trim().toLowerCase()
  return events.value
    .filter((event) => (typeFilter.value === 'all' ? true : event.type === typeFilter.value))
    .filter((event) => (query ? `${event.title} ${event.description} ${event.source}`.toLowerCase().includes(query) : true))
    .slice(0, limit.value)
})

const counts = computed(() => {
  const out: Record<string, number> = { all: events.value.length }
  for (const type of TYPES) out[type] = events.value.filter((event) => event.type === type).length
  return out
})

function suffix(value: string): string {
  return value.replace(' ', 'T')
}

async function load() {
  loading.value = true
  error.value = null
  const collected: TimelineEvent[] = []

  // Task runs are the richest real event source on this instance.
  try {
    const runs = await listTaskHistory()
    for (const run of runs) {
      const succeeded = String(run.Status) === '1' && !Number(run.ErrNumber ?? 0)
      const when = run.Completed || run.LastStart
      if (!when) continue
      collected.push({
        id: `task-${run.TaskId}-${when}`,
        timestamp: when,
        type: 'TASK',
        severity: succeeded ? 'SUCCESS' : 'FAILED',
        source: `Task #${run.TaskId}`,
        title: `${run.Name} ${succeeded ? 'completed' : 'failed'}`,
        description: run.Result || '',
        related: { label: 'Task detail', to: `/tasks/detail/${run.TaskId}` }
      })
    }
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : String(cause)
  }

  // Audit records, when the instance keeps any.
  try {
    const audit = await getAuditLog({})
    const list = Array.isArray(audit) ? audit : []
    for (const record of list) {
      const item = record as Record<string, unknown>
      const when = String(item.TimeStamp ?? item.Time ?? '')
      if (!when) continue
      collected.push({
        id: `audit-${when}-${String(item.Event ?? '')}`,
        timestamp: when,
        type: 'SECURITY',
        severity: 'INFO',
        source: String(item.SystemID ?? 'Audit'),
        title: String(item.Event ?? 'Audit event'),
        description: String(item.Description ?? '')
      })
    }
  } catch {
    /* audit is optional for the timeline */
  }

  // Alerts from the instance dashboard.
  try {
    const dash = await getDashboard()
    const alerts = dash.Alerts
    if (alerts.SeriousAlerts > 0) {
      collected.push({
        id: `alert-serious-${dash.Status.UpTime}`,
        timestamp: new Date().toISOString().slice(0, 19).replace('T', ' '),
        type: 'SYSTEM',
        severity: 'ERROR',
        source: 'System monitor',
        title: `${alerts.SeriousAlerts} serious alert(s) reported`,
        description: ''
      })
    }
    if (alerts.ApplicationErrors > 0) {
      collected.push({
        id: `alert-apperrors-${dash.Status.UpTime}`,
        timestamp: new Date().toISOString().slice(0, 19).replace('T', ' '),
        type: 'SYSTEM',
        severity: 'WARNING',
        source: 'System monitor',
        title: `${alerts.ApplicationErrors} application error(s) reported`,
        description: ''
      })
    }
  } catch {
    /* alerts are optional for the timeline */
  }

  events.value = collected.sort((a, b) => suffix(b.timestamp).localeCompare(suffix(a.timestamp)))
  loading.value = false
}

onMounted(load)
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <h1>Timeline</h1>
      <small>{{ counts.all }} events from the sources this instance can report</small>
    </div>

    <p v-if="error" class="state is-error">Error: {{ error }}</p>

    <div class="controls">
      <div class="tabs">
        <button class="tab" :class="{ 'is-active': typeFilter === 'all' }" @click="typeFilter = 'all'">
          All <b>{{ counts.all }}</b>
        </button>
        <button
          v-for="type in TYPES"
          :key="type"
          class="tab"
          :class="{ 'is-active': typeFilter === type }"
          @click="typeFilter = type"
        >
          {{ type }} <b>{{ counts[type] }}</b>
        </button>
      </div>
      <input v-model="keyword" class="search" type="search" placeholder="Keyword…" />
    </div>

    <p v-if="loading" class="state">Loading…</p>

    <ol v-else-if="visible.length" class="stream">
      <li v-for="event in visible" :key="event.id" class="event">
        <span class="rail">
          <span class="dot" :class="`dot-${event.severity.toLowerCase()}`" />
        </span>
        <div class="body">
          <div class="head">
            <span class="time mono">{{ event.timestamp }}</span>
            <span class="type">{{ event.type }}</span>
            <StatusBadge :status="event.severity" />
            <span class="source muted">{{ event.source }}</span>
          </div>
          <button class="title" @click="detail = event">{{ event.title }}</button>
          <p v-if="event.description" class="desc">{{ event.description }}</p>
        </div>
      </li>
    </ol>

    <EmptyState v-else title="No events for this filter" description="Pick another event type above." />

    <div v-if="detail" class="card panel">
      <div class="panel-head">
        <h2>{{ detail.title }}</h2>
        <button class="btn btn-quiet" @click="detail = null">Close</button>
      </div>
      <dl class="facts">
        <dt>Timestamp</dt>
        <dd>{{ detail.timestamp }}</dd>
        <dt>Type</dt>
        <dd>{{ detail.type }}</dd>
        <dt>Severity</dt>
        <dd><StatusBadge :status="detail.severity" /></dd>
        <dt>Source</dt>
        <dd>{{ detail.source }}</dd>
        <dt>Description</dt>
        <dd>{{ detail.description || '—' }}</dd>
        <dt>Related</dt>
        <dd>
          <RouterLink v-if="detail.related" :to="detail.related.to">{{ detail.related.label }}</RouterLink>
          <span v-else class="muted">—</span>
        </dd>
      </dl>
    </div>
  </div>
</template>

<style scoped>
.controls {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
}
.tabs {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-1);
}
.tab {
  padding: 3px 10px;
  border: 1px solid var(--color-border-strong);
  border-radius: 999px;
  background: var(--color-surface);
  color: var(--color-text-muted);
  font: inherit;
  font-size: var(--text-sm);
  cursor: pointer;
}
.tab.is-active {
  border-color: var(--color-primary);
  background: var(--status-info-bg);
  color: var(--color-primary);
  font-weight: 600;
}
.tab b {
  font-variant-numeric: tabular-nums;
}
.search {
  flex: 1;
  min-width: 200px;
}
.stream {
  margin: 0;
  padding: 0;
  list-style: none;
}
.event {
  display: flex;
  gap: var(--space-3);
}
.rail {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  width: 16px;
}
.rail::after {
  content: '';
  flex: 1;
  width: 1px;
  background: var(--color-border);
}
.event:last-child .rail::after {
  background: transparent;
}
.dot {
  width: 9px;
  height: 9px;
  margin-top: 6px;
  border-radius: 50%;
  background: var(--status-muted);
}
.dot-success {
  background: var(--status-ok);
}
.dot-failed,
.dot-error,
.dot-critical {
  background: var(--status-error);
}
.dot-warning {
  background: var(--status-warn);
}
.dot-info {
  background: var(--status-info);
}
.body {
  flex: 1;
  min-width: 0;
  padding-bottom: var(--space-4);
}
.head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2);
}
.time {
  color: var(--color-text-muted);
}
.type {
  color: var(--color-text-faint);
  font-size: var(--text-xs);
  font-weight: 700;
  letter-spacing: 0.6px;
}
.source,
.desc {
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
.desc {
  margin: 2px 0 0;
}
.title {
  display: block;
  margin-top: 2px;
  padding: 0;
  border: 0;
  background: none;
  color: var(--color-text);
  font: inherit;
  font-weight: 600;
  text-align: left;
  cursor: pointer;
}
.title:hover {
  color: var(--color-primary);
}
.mono {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
}
.muted {
  color: var(--color-text-faint);
}
.panel {
  padding: var(--space-4) var(--space-5);
}
.panel-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.facts {
  display: grid;
  grid-template-columns: 150px 1fr;
  gap: var(--space-2) var(--space-4);
  margin: var(--space-3) 0 0;
}
.facts dt {
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
.facts dd {
  margin: 0;
  font-family: var(--font-mono);
  font-size: var(--text-sm);
  overflow-wrap: anywhere;
}
.state.is-error {
  color: var(--status-error);
}
</style>
