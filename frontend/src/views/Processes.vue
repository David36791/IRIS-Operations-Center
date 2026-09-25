<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import AppTable from '@/components/AppTable.vue'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import { getProcesses, terminateProcess, type IrisProcess } from '@/api/system'
import type { Column } from '@/types/ui'

const POLL_MS = 5000

const columns: Column[] = [
  { key: 'Pid', label: 'PID', align: 'right' },
  { key: 'Routine', label: 'Process' },
  { key: 'Username', label: 'User' },
  { key: 'CPUTime', label: 'CPU (s)', align: 'right' },
  { key: 'ElapsedTime', label: 'Elapsed (s)', align: 'right' },
  { key: 'State', label: 'Status' },
  { key: 'Nspace', label: 'Namespace' },
  { key: 'actions', label: 'Actions', align: 'right' }
]

const loading = ref(true)
const busy = ref(false)
const error = ref<string | null>(null)
const processes = ref<IrisProcess[]>([])
const search = ref('')
const stateFilter = ref('all')
const sortBy = ref<'cpu' | 'elapsed' | 'pid' | 'routine'>('cpu')
const pending = ref<IrisProcess | null>(null)
let timer: ReturnType<typeof setInterval> | undefined

const states = computed(() => Array.from(new Set(processes.value.map((p) => p.State).filter(Boolean))).sort())

const visible = computed(() => {
  const query = search.value.trim().toLowerCase()
  const filtered = processes.value.filter((item) => {
    if (stateFilter.value !== 'all' && item.State !== stateFilter.value) return false
    if (!query) return true
    return `${item.Pid} ${item.Routine} ${item.Username} ${item.Nspace} ${item.IPAddress}`
      .toLowerCase()
      .includes(query)
  })
  const compare = {
    cpu: (a: IrisProcess, b: IrisProcess) => Number(b.CPUTime || 0) - Number(a.CPUTime || 0),
    elapsed: (a: IrisProcess, b: IrisProcess) => Number(b.ElapsedTime || 0) - Number(a.ElapsedTime || 0),
    pid: (a: IrisProcess, b: IrisProcess) => a.Pid - b.Pid,
    routine: (a: IrisProcess, b: IrisProcess) => String(a.Routine).localeCompare(String(b.Routine))
  }[sortBy.value]
  return [...filtered].sort(compare)
})

async function poll() {
  try {
    processes.value = await getProcesses()
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : String(cause)
  } finally {
    loading.value = false
  }
}

function confirmTerminate() {
  const target = pending.value
  if (!target) return
  busy.value = true
  error.value = null
  void (async () => {
    try {
      await terminateProcess(target.Pid)
      pending.value = null
      await poll()
    } catch (cause) {
      error.value = cause instanceof Error ? cause.message : String(cause)
    } finally {
      busy.value = false
    }
  })()
}

onMounted(() => {
  void poll()
  timer = setInterval(() => void poll(), POLL_MS)
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
})
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <h1>Processes</h1>
      <small>{{ processes.length }} processes · refreshed every 5 s</small>
    </div>

    <p v-if="error" class="state is-error">Error: {{ error }}</p>

    <div class="controls">
      <input v-model="search" type="search" placeholder="Search PID, routine, user, namespace…" />
      <label class="field-inline">
        <span>Status</span>
        <select v-model="stateFilter">
          <option value="all">All</option>
          <option v-for="state in states" :key="state" :value="state">{{ state }}</option>
        </select>
      </label>
      <label class="field-inline">
        <span>Sort by</span>
        <select v-model="sortBy">
          <option value="cpu">CPU</option>
          <option value="elapsed">Elapsed</option>
          <option value="pid">PID</option>
          <option value="routine">Routine</option>
        </select>
      </label>
    </div>

    <AppTable :columns="columns" :rows="visible as unknown as Record<string, unknown>[]" row-key="Pid" :loading="loading" empty-title="No processes">
      <template #cell="{ column, row, value }">
        <StatusBadge v-if="column.key === 'State'" :status="String(value) === 'RUN' ? 'RUNNING' : 'INFO'" />

        <span v-else-if="column.key === 'actions'">
          <button
            v-if="row.CanBeTerminated"
            class="link-button is-danger"
            :disabled="busy"
            @click="pending = row as unknown as IrisProcess"
          >
            Terminate
          </button>
          <span v-else class="muted" title="IRIS does not allow terminating this process">protected</span>
        </span>

        <template v-else-if="column.key === 'Pid'">#{{ value }}</template>
        <template v-else>{{ value || '—' }}</template>
      </template>
    </AppTable>

    <ConfirmDialog
      :open="pending !== null"
      title="Terminate process"
      :message="`Terminate PID ${pending?.Pid} (${pending?.Routine || 'unknown routine'})? IRIS permits this only for processes it flags as terminable.`"
      confirm-label="Terminate"
      danger
      :busy="busy"
      @confirm="confirmTerminate"
      @cancel="pending = null"
    />
  </div>
</template>

<style scoped>
.controls {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
}
.controls input[type='search'] {
  flex: 1;
  min-width: 220px;
}
.field-inline {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}
.muted {
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
.link-button {
  padding: 0;
  border: 0;
  background: none;
  color: var(--color-primary);
  font: inherit;
  cursor: pointer;
}
.link-button.is-danger {
  color: var(--status-error);
}
.link-button:disabled {
  color: var(--color-text-faint);
  cursor: default;
}
.state.is-error {
  color: var(--status-error);
}
</style>
