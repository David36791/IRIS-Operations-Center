<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import AppTable from '@/components/AppTable.vue'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import {
  getTaskManager,
  listTaskHistory,
  listTasks,
  resumeTask,
  runTask,
  summarise,
  suspendTask,
  type TaskCategory
} from '@/api/tasks'
import type { Column } from '@/types/ui'

const FILTERS: { id: TaskCategory | 'all'; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'running', label: 'Running' },
  { id: 'scheduled', label: 'Scheduled' },
  { id: 'failed', label: 'Failed' },
  { id: 'completed', label: 'Completed' }
]

const columns: Column[] = [
  { key: 'name', label: 'Name' },
  { key: 'status', label: 'Status' },
  { key: 'last', label: 'Last run' },
  { key: 'next', label: 'Next run' },
  { key: 'duration', label: 'Duration' },
  { key: 'actions', label: 'Actions', align: 'right' }
]

type Row = {
  id: number
  name: string
  type: string
  namespace: string
  status: string
  category: TaskCategory
  suspended: boolean
  last: string
  next: string
  duration: string
}

type Pending = { kind: 'run' | 'enable' | 'disable'; row: Row }

const loading = ref(true)
const busy = ref(false)
const error = ref<string | null>(null)
const rows = ref<Row[]>([])
const managerStatus = ref('')
const filter = ref<TaskCategory | 'all'>('all')
const search = ref('')
const pending = ref<Pending | null>(null)

const visible = computed(() => {
  const query = search.value.trim().toLowerCase()
  return rows.value.filter((row) => {
    if (filter.value !== 'all' && row.category !== filter.value) return false
    if (!query) return true
    return `${row.name} ${row.type} ${row.namespace}`.toLowerCase().includes(query)
  })
})

const counts = computed(() => {
  const out: Record<string, number> = { all: rows.value.length }
  for (const name of ['running', 'scheduled', 'failed', 'completed', 'suspended'] as TaskCategory[]) {
    out[name] = rows.value.filter((row) => row.category === name).length
  }
  return out
})

const dialogTitle = computed(() => {
  if (!pending.value) return ''
  return pending.value.kind === 'run'
    ? 'Run task now'
    : pending.value.kind === 'disable'
      ? 'Disable task'
      : 'Enable task'
})

const dialogMessage = computed(() => {
  if (!pending.value) return ''
  const { kind, row } = pending.value
  if (kind === 'run') return `Run ${row.name} immediately, outside its schedule?`
  return `${kind === 'disable' ? 'Disable' : 'Enable'} ${row.name}?`
})

function fail(cause: unknown) {
  error.value = cause instanceof Error ? cause.message : String(cause)
}

function ask(kind: Pending['kind'], row: Row) {
  pending.value = { kind, row }
}

function confirmPending() {
  const current = pending.value
  if (!current) return
  void withBusy(async () => {
    if (current.kind === 'run') await runTask(current.row.id)
    else if (current.kind === 'disable') await suspendTask(current.row.id)
    else await resumeTask(current.row.id)
    pending.value = null
    await load()
  })
}

async function withBusy(action: () => Promise<void>) {
  busy.value = true
  error.value = null
  try {
    await action()
  } catch (cause) {
    fail(cause)
  } finally {
    busy.value = false
  }
}

async function load() {
  loading.value = true
  try {
    const [tasks, runs] = await Promise.all([listTasks(), listTaskHistory()])
    rows.value = summarise(tasks, runs).map(({ task, run, category, status, durationMs }) => ({
      id: task.Id,
      name: task.Name,
      type: task.Type,
      namespace: task.Namespace,
      status,
      category,
      suspended: task.Suspended,
      last: run?.Completed || task.LastFinished || '—',
      next: task.NextScheduled || '—',
      duration: durationMs === null ? '—' : `${durationMs} ms`
    }))
    try {
      managerStatus.value = (await getTaskManager()).Status
    } catch {
      managerStatus.value = ''
    }
  } catch (cause) {
    fail(cause)
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <h1>Tasks</h1>
      <small v-if="managerStatus">Task manager: {{ managerStatus }}</small>
    </div>

    <p v-if="error" class="state is-error">Error: {{ error }}</p>

    <div class="filters">
      <button
        v-for="entry in FILTERS"
        :key="entry.id"
        class="chip"
        :class="{ 'is-active': filter === entry.id }"
        @click="filter = entry.id"
      >
        {{ entry.label }} <b>{{ counts[entry.id] ?? 0 }}</b>
      </button>
      <input v-model="search" type="search" placeholder="Filter by name…" />
    </div>

    <AppTable :columns="columns" :rows="visible" row-key="id" :loading="loading" empty-title="No tasks">
      <template #cell="{ column, row, value }">
        <StatusBadge v-if="column.key === 'status'" :status="String(value)" />

        <span v-else-if="column.key === 'name'">
          <RouterLink class="mono" :to="{ name: '/tasks/detail', params: { id: String(row.id) } }">
            {{ row.name }}
          </RouterLink>
          <small class="muted"> {{ row.type }} · {{ row.namespace }}</small>
        </span>

        <span v-else-if="column.key === 'actions'" class="actions">
          <button class="link-button" :disabled="busy" @click="ask('run', row as unknown as Row)">Run now</button>
          <button class="link-button" :disabled="busy" @click="ask(row.suspended ? 'enable' : 'disable', row as unknown as Row)">
            {{ row.suspended ? 'Enable' : 'Disable' }}
          </button>
          <RouterLink :to="{ name: '/tasks/detail', params: { id: String(row.id) } }">View</RouterLink>
        </span>

        <template v-else>{{ value }}</template>
      </template>
    </AppTable>

    <ConfirmDialog
      :open="pending !== null"
      :title="dialogTitle"
      :message="dialogMessage"
      :confirm-label="pending?.kind === 'run' ? 'Run' : 'Confirm'"
      :busy="busy"
      @confirm="confirmPending"
      @cancel="pending = null"
    />
  </div>
</template>

<style scoped>
.filters {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2);
}
.chip {
  padding: 3px 10px;
  border: 1px solid var(--color-border-strong);
  border-radius: 999px;
  background: var(--color-surface);
  color: var(--color-text-muted);
  font: inherit;
  font-size: var(--text-sm);
  cursor: pointer;
}
.chip.is-active {
  border-color: var(--color-primary);
  background: var(--status-info-bg);
  color: var(--color-primary);
  font-weight: 600;
}
.chip b {
  font-variant-numeric: tabular-nums;
}
.filters input {
  margin-left: auto;
  max-width: 260px;
}
.mono {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
}
.muted {
  color: var(--color-text-faint);
  font-size: var(--text-xs);
}
.state.is-error {
  color: var(--status-error);
}
.actions {
  display: inline-flex;
  align-items: baseline;
  gap: var(--space-3);
}
.link-button {
  padding: 0;
  border: 0;
  background: none;
  color: var(--color-primary);
  font: inherit;
  cursor: pointer;
}
.link-button:disabled {
  color: var(--color-text-faint);
  cursor: default;
}
</style>
