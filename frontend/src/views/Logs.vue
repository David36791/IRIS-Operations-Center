<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import AppTable from '@/components/AppTable.vue'
import EmptyState from '@/components/EmptyState.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import { getAuditLog, getLogIntelligence, type LogEntry, type LogPattern } from '@/api/logs'
import { listTaskHistory, type TaskRun } from '@/api/tasks'
import type { Column } from '@/types/ui'

type Source = 'system' | 'task' | 'audit'

const SOURCES: { id: Source; label: string }[] = [
  { id: 'system', label: 'System' },
  { id: 'task', label: 'Task' },
  { id: 'audit', label: 'Audit' }
]

const SEVERITIES = ['all', 'CRITICAL', 'ERROR', 'WARNING', 'INFO']

const columns: Column[] = [
  { key: 'time', label: 'Time' },
  { key: 'severity', label: 'Severity' },
  { key: 'subsystem', label: 'Subsystem' },
  { key: 'message', label: 'Message' },
  { key: 'source', label: 'Source' }
]

const PATTERN_COLUMNS: Column[] = [
  { key: 'pattern', label: 'Pattern' },
  { key: 'severity', label: 'Severity' },
  { key: 'occurrences', label: 'Occurrences', align: 'right' },
  { key: 'failures', label: 'Failures', align: 'right' },
  { key: 'firstSeen', label: 'First seen' },
  { key: 'lastSeen', label: 'Last seen' },
  { key: 'relatedServices', label: 'Related services' }
]

const patterns = ref<LogPattern[]>([])
const loadingIntelligence = ref(true)
const intelligenceError = ref('')

const loading = ref(true)
const error = ref<string | null>(null)
const source = ref<Source>('system')
const entries = ref<LogEntry[]>([])
const taskRuns = ref<TaskRun[]>([])
const auditNote = ref('')
const severity = ref('all')
const keyword = ref('')
const subsystem = ref('all')
const detail = ref<Record<string, unknown> | null>(null)

const rows = computed<Record<string, unknown>[]>(() => {
  if (source.value === 'task') {
    return taskRuns.value.map((run) => ({
      time: run.Completed || run.LastStart || '—',
      severity: String(run.Status) === '1' && !Number(run.ErrNumber ?? 0) ? 'INFO' : 'ERROR',
      subsystem: 'Task',
      message: `${run.Name}: ${run.Result || ''}`,
      source: 'Task',
      raw: run
    }))
  }
  return entries.value.map((entry) => ({
    time: entry.time,
    severity: entry.severity,
    subsystem: entry.namespace || '—',
    message: entry.message,
    source: source.value === 'audit' ? 'Audit' : 'System',
    raw: entry
  }))
})

const subsystems = computed(() => {
  const values = new Set(entries.value.map((entry) => entry.namespace).filter(Boolean))
  return Array.from(values).sort()
})

const visible = computed(() => {
  const query = keyword.value.trim().toLowerCase()
  return rows.value.filter((row) => {
    if (severity.value !== 'all' && row.severity !== severity.value) return false
    if (subsystem.value !== 'all' && row.subsystem !== subsystem.value) return false
    if (!query) return true
    return `${row.message} ${row.time} ${row.subsystem}`.toLowerCase().includes(query)
  })
})

async function loadIntelligence() {
  loadingIntelligence.value = true
  intelligenceError.value = ''
  try {
    patterns.value = await getLogIntelligence()
  } catch (cause) {
    intelligenceError.value = cause instanceof Error ? cause.message : String(cause)
  } finally {
    loadingIntelligence.value = false
  }
}

async function load() {
  loading.value = true
  error.value = null
  try {
    taskRuns.value = await listTaskHistory().catch(() => [])
    if (source.value === 'audit') await loadAudit()
    await loadIntelligence()
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : String(cause)
  } finally {
    loading.value = false
  }
}

async function loadAudit() {
  try {
    const result = await getAuditLog({})
    const list = Array.isArray(result) ? result : []
    entries.value = list.map((record) => {
      const item = record as Record<string, unknown>
      return {
        time: String(item.TimeStamp ?? item.Time ?? '—'),
        severity: 'INFO',
        namespace: String(item.SystemID ?? item.Namespace ?? '—'),
        message: String(item.Event ?? item.Description ?? JSON.stringify(item).slice(0, 160)),
        pid: String(item.PID ?? '')
      }
    })
    auditNote.value = list.length ? '' : 'The audit database has no records on this instance.'
  } catch (cause) {
    entries.value = []
    auditNote.value = cause instanceof Error ? cause.message : String(cause)
  }
}

async function switchSource(next: Source) {
  source.value = next
  if (next === 'audit') await loadAudit()
}

onMounted(load)
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <h1>Logs</h1>
      <small>Unified log centre</small>
      <span class="spacer" />
      <RouterLink class="btn" to="/audit">Audit records →</RouterLink>
    </div>

    <p v-if="error" class="state is-error">Error: {{ error }}</p>

    <div class="controls">
      <div class="tabs">
        <button
          v-for="entry in SOURCES"
          :key="entry.id"
          class="tab"
          :class="{ 'is-active': source === entry.id }"
          @click="switchSource(entry.id)"
        >
          {{ entry.label }}
        </button>
      </div>

      <label class="field-inline">
        <span>Severity</span>
        <select v-model="severity">
          <option v-for="value in SEVERITIES" :key="value" :value="value">{{ value === 'all' ? 'All' : value }}</option>
        </select>
      </label>

      <label v-if="source !== 'task'" class="field-inline">
        <span>Subsystem</span>
        <select v-model="subsystem">
          <option value="all">All</option>
          <option v-for="value in subsystems" :key="value" :value="value">{{ value }}</option>
        </select>
      </label>

      <input v-model="keyword" class="search" type="search" placeholder="Keyword…" />
    </div>

    <p v-if="source === 'audit' && auditNote" class="muted">{{ auditNote }}</p>
    <p v-if="source === 'system'" class="muted">
      The instance's message log cannot be read from here: IRIS blocks web applications from reading arbitrary
      files, and it exposes no API that returns the log. This tab is kept so the source is not silently missing.
    </p>

    <AppTable :columns="columns" :rows="visible" row-key="time" :loading="loading" empty-title="No log entries">
      <template #cell="{ column, row, value }">
        <StatusBadge v-if="column.key === 'severity'" :status="String(value)" />
        <button v-else-if="column.key === 'message'" class="link-button" @click="detail = row">
          {{ String(value).slice(0, 160) }}
        </button>
        <span v-else-if="column.key === 'time'" class="mono">{{ value }}</span>
        <template v-else>{{ value }}</template>
      </template>
    </AppTable>

    <div v-if="detail" class="card panel">
      <div class="panel-head">
        <h2>Log entry</h2>
        <button class="btn btn-quiet" @click="detail = null">Close</button>
      </div>
      <dl class="facts">
        <dt>Time</dt>
        <dd>{{ detail.time }}</dd>
        <dt>Severity</dt>
        <dd><StatusBadge :status="String(detail.severity)" /></dd>
        <dt>Subsystem</dt>
        <dd>{{ detail.subsystem }}</dd>
        <dt>Source</dt>
        <dd>{{ detail.source }}</dd>
        <dt>Message</dt>
        <dd>{{ detail.message }}</dd>
        <dt>Related events</dt>
        <dd>
          <RouterLink to="/timeline">Open in Timeline</RouterLink>
          <span class="muted"> — correlation needs a request or task id, which this log does not carry.</span>
        </dd>
      </dl>
    </div>

    <EmptyState
      v-if="!loading && !error && rows.length === 0"
      title="No entries for this source"
      description="Pick another source above."
    />

    <section class="section">
      <div class="section-head">
        <h2>Intelligence</h2>
        <small class="muted">pattern analysis of the event records, computed with Embedded Python</small>
      </div>
      <p v-if="intelligenceError" class="muted">{{ intelligenceError }}</p>
      <AppTable
        :columns="PATTERN_COLUMNS"
        :rows="patterns as unknown as Record<string, unknown>[]"
        row-key="pattern"
        :loading="loadingIntelligence"
        empty-title="Nothing to analyse yet"
      >
        <template #cell="{ column, value }">
          <StatusBadge v-if="column.key === 'severity'" :status="String(value)" />
          <span v-else-if="column.key === 'relatedServices'">{{ (value as string[]).join(', ') || '—' }}</span>
          <span v-else-if="column.key === 'pattern'" class="mono">{{ value }}</span>
          <template v-else>{{ value }}</template>
        </template>
      </AppTable>
    </section>
  </div>
</template>

<style scoped>
.controls {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
}
.spacer {
  flex: 1;
}
.section {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
  margin-top: var(--space-4);
}
.section-head {
  display: flex;
  align-items: baseline;
  gap: var(--space-3);
}
.section-head h2 {
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
}
.tabs {
  display: flex;
  gap: var(--space-1);
}
.tab {
  padding: 4px 12px;
  border: 1px solid var(--color-border-strong);
  border-radius: var(--radius-sm);
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
.field-inline {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}
.search {
  flex: 1;
  min-width: 200px;
}
.mono {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
}
.muted {
  color: var(--color-text-faint);
  font-size: var(--text-sm);
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
.link-button {
  padding: 0;
  border: 0;
  background: none;
  color: var(--color-primary);
  font: inherit;
  text-align: left;
  cursor: pointer;
}
.state.is-error {
  color: var(--status-error);
}
</style>
