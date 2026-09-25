<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import EmptyState from '@/components/EmptyState.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import {
  deleteTask,
  getTaskDetail,
  getTaskInfo,
  listTaskHistoryFor,
  resumeTask,
  runSucceeded,
  runTask,
  suspendTask,
  type TaskInfo,
  type TaskRun
} from '@/api/tasks'

type TabId = 'overview' | 'schedule' | 'history' | 'logs' | 'configuration'

const TABS: { id: TabId; label: string }[] = [
  { id: 'overview', label: 'Overview' },
  { id: 'schedule', label: 'Schedule' },
  { id: 'history', label: 'Execution History' },
  { id: 'logs', label: 'Logs' },
  { id: 'configuration', label: 'Configuration' }
]

const route = useRoute()
const id = computed(() => String(route.params.id ?? ''))

const loading = ref(true)
const busy = ref(false)
const error = ref<string | null>(null)
const detail = ref<Record<string, unknown> | null>(null)
const info = ref<TaskInfo | null>(null)
const runs = ref<TaskRun[]>([])
const tab = ref<TabId>('overview')
const pending = ref<'run' | 'enable' | 'disable' | 'delete' | null>(null)

function format(value: unknown): string {
  if (value === null || value === undefined || value === '') return '—'
  if (Array.isArray(value)) return value.length ? value.join(', ') : '—'
  if (typeof value === 'object') return JSON.stringify(value)
  return String(value)
}

const entries = computed<[string, string][]>(() =>
  Object.entries(detail.value ?? {})
    .filter(([key]) => key !== 'Name')
    .map(([key, value]) => [key, format(value)] as [string, string])
)

const scheduleEntries = computed(() =>
  entries.value.filter(([key]) => /sched|freq|time|date|interval|day|month/i.test(key))
)

const overviewEntries = computed<[string, string][]>(() => {
  if (!info.value) return []
  return [
    ['Name', String(detail.value?.Name ?? '—')],
    ['Type', info.value.Type],
    ['Status', info.value.Status],
    ['Last scheduled', format(info.value.LastSchedule)],
    ['Last started', format(info.value.LastStarted)],
    ['Last finished', format(info.value.LastFinished)],
    ['Next scheduled', format(info.value.NextScheduled)],
    ['Last error', format(info.value.Error)]
  ]
})

const status = computed(() => {
  if (info.value?.Suspended || detail.value?.Suspended) return 'DISABLED'
  const latest = runs.value[0]
  if (latest && !latest.Completed) return 'RUNNING'
  if (latest) return runSucceeded(latest) ? 'SUCCESS' : 'FAILED'
  return 'INFO'
})

const dialogTitle = computed(() => {
  switch (pending.value) {
    case 'run':
      return 'Run task now'
    case 'enable':
      return 'Enable task'
    case 'disable':
      return 'Disable task'
    case 'delete':
      return 'Delete task'
    default:
      return ''
  }
})

function fail(cause: unknown) {
  error.value = cause instanceof Error ? cause.message : String(cause)
}

async function load() {
  loading.value = true
  error.value = null
  try {
    detail.value = await getTaskDetail(id.value)
  } catch (cause) {
    fail(cause)
  }
  const [infoResult, historyResult] = await Promise.allSettled([
    getTaskInfo(id.value),
    listTaskHistoryFor(id.value)
  ])
  if (infoResult.status === 'fulfilled') info.value = infoResult.value
  if (historyResult.status === 'fulfilled') runs.value = historyResult.value
  loading.value = false
}

function confirmPending() {
  const action = pending.value
  if (!action) return
  busy.value = true
  error.value = null
  void (async () => {
    try {
      if (action === 'run') await runTask(id.value)
      else if (action === 'enable') await resumeTask(id.value)
      else if (action === 'disable') await suspendTask(id.value)
      else await deleteTask(id.value)
      pending.value = null
      if (action === 'delete') window.location.hash = '#/tasks'
      else await load()
    } catch (cause) {
      fail(cause)
    } finally {
      busy.value = false
    }
  })()
}

onMounted(load)
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <RouterLink to="/tasks">← Tasks</RouterLink>
      <h1>{{ detail?.Name ?? id }}</h1>
      <StatusBadge :status="status" />
    </div>

    <p v-if="loading" class="state">Loading…</p>
    <p v-else-if="error" class="state is-error">Error: {{ error }}</p>

    <template v-else>
      <div class="actions-bar">
        <button class="btn" :disabled="busy" @click="pending = 'run'">Run Now</button>
        <button class="btn" :disabled="busy" @click="pending = 'enable'">Enable</button>
        <button class="btn" :disabled="busy" @click="pending = 'disable'">Disable</button>
        <button class="btn btn-danger" :disabled="busy" @click="pending = 'delete'">Delete</button>
      </div>

      <nav class="tabs">
        <button
          v-for="entry in TABS"
          :key="entry.id"
          class="tab"
          :class="{ 'is-active': tab === entry.id }"
          @click="tab = entry.id"
        >
          {{ entry.label }}
        </button>
      </nav>

      <div class="card panel">
        <dl v-if="tab === 'overview'" class="facts">
          <template v-for="[label, value] in overviewEntries" :key="label">
            <dt>{{ label }}</dt>
            <dd>{{ value }}</dd>
          </template>
        </dl>

        <dl v-else-if="tab === 'schedule'" class="facts">
          <template v-for="[label, value] in scheduleEntries" :key="label">
            <dt>{{ label }}</dt>
            <dd>{{ value }}</dd>
          </template>
          <p v-if="scheduleEntries.length === 0" class="muted">No schedule fields reported for this task.</p>
        </dl>

        <table v-else-if="tab === 'history'" class="runs">
          <thead>
            <tr>
              <th>Started</th>
              <th>Completed</th>
              <th>Result</th>
              <th>User</th>
              <th>PID</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(run, index) in runs" :key="index">
              <td class="mono">{{ run.LastStart || '—' }}</td>
              <td class="mono">{{ run.Completed || '—' }}</td>
              <td><StatusBadge :status="runSucceeded(run) ? 'SUCCESS' : 'FAILED'" /> {{ run.Result }}</td>
              <td>{{ run.Username || '—' }}</td>
              <td class="mono">{{ run.Pid || '—' }}</td>
            </tr>
            <tr v-if="runs.length === 0">
              <td colspan="5"><EmptyState title="No runs recorded" /></td>
            </tr>
          </tbody>
        </table>

        <dl v-else-if="tab === 'configuration'" class="facts">
          <template v-for="[label, value] in entries" :key="label">
            <dt>{{ label }}</dt>
            <dd>{{ value }}</dd>
          </template>
        </dl>

        <div v-else class="logs-note">
          <EmptyState
            title="No per-task log output"
            description="Task runs are listed under Execution History. The instance message log that would carry per-task output cannot be read from a web application, which is why the log centre works from task runs and audit records instead."
          />
          <RouterLink class="link" to="/logs">Open the log centre →</RouterLink>
        </div>
      </div>
    </template>

    <ConfirmDialog
      :open="pending !== null"
      :title="dialogTitle"
      :message="pending === 'delete' ? `Delete ${detail?.Name ?? id}? This removes the task definition.` : `Proceed with ${dialogTitle.toLowerCase()} for ${detail?.Name ?? id}?`"
      :confirm-label="pending === 'run' ? 'Run' : pending === 'delete' ? 'Delete' : 'Confirm'"
      :danger="pending === 'delete'"
      :busy="busy"
      @confirm="confirmPending"
      @cancel="pending = null"
    />
  </div>
</template>

<style scoped>
.state.is-error {
  color: var(--status-error);
}
.logs-note {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-2);
}
.muted {
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
.actions-bar {
  display: flex;
  gap: var(--space-2);
}
.tabs {
  display: flex;
  gap: var(--space-1);
  border-bottom: 1px solid var(--color-border);
}
.tab {
  padding: var(--space-2) var(--space-3);
  border: 0;
  border-bottom: 2px solid transparent;
  background: transparent;
  color: var(--color-text-muted);
  font: inherit;
  cursor: pointer;
}
.tab.is-active {
  border-bottom-color: var(--color-primary);
  color: var(--color-text);
  font-weight: 600;
}
.panel {
  padding: var(--space-4) var(--space-5);
}
.facts {
  display: grid;
  grid-template-columns: 220px 1fr;
  gap: var(--space-2) var(--space-4);
  margin: 0;
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
.runs {
  width: 100%;
  border-collapse: collapse;
}
.runs th {
  padding: var(--space-2) 0;
  border-bottom: 1px solid var(--color-border-strong);
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  text-align: left;
}
.runs td {
  padding: var(--space-2) 0;
  border-bottom: 1px solid var(--color-border);
}
.mono {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
}
</style>
