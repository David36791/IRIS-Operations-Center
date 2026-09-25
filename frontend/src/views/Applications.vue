<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import AppTable from '@/components/AppTable.vue'
import ApplicationFormDialog from '@/components/ApplicationFormDialog.vue'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import {
  deleteApplication,
  encodeAppSegment,
  getApplication,
  listApplications,
  saveApplication,
  setApplicationEnabled,
  type IrisWebApp
} from '@/api/applications'
import type { Column } from '@/types/ui'

const columns: Column[] = [
  { key: 'Name', label: 'Name' },
  { key: 'Namespace', label: 'Namespace' },
  { key: 'Type', label: 'Type' },
  { key: 'Enabled', label: 'Status' },
  { key: 'AuthenticationMethods', label: 'Authentication' },
  { key: 'DispatchClass', label: 'Dispatch class' },
  { key: 'actions', label: 'Actions', align: 'right' }
]

type Pending = { kind: 'delete' | 'toggle'; app: IrisWebApp }
type Editing = { mode: 'create' | 'edit'; initial: Record<string, unknown> | null }

const loading = ref(true)
const busy = ref(false)
const error = ref<string | null>(null)
const applications = ref<IrisWebApp[]>([])
const search = ref('')
const pending = ref<Pending | null>(null)
const editing = ref<Editing | null>(null)

const filtered = computed(() => {
  const query = search.value.trim().toLowerCase()
  if (!query) return applications.value
  return applications.value.filter((app) =>
    `${app.Name} ${app.Namespace} ${app.Type} ${app.DispatchClass}`.toLowerCase().includes(query)
  )
})

const dialogTitle = computed(() => {
  if (!pending.value) return ''
  return pending.value.kind === 'delete' ? 'Delete application' : 'Change application state'
})

const dialogMessage = computed(() => {
  const current = pending.value
  if (!current) return ''
  if (current.kind === 'delete') {
    return `Delete ${current.app.Name}? This removes the web application configuration.`
  }
  return `${current.app.Enabled ? 'Disable' : 'Enable'} ${current.app.Name}?`
})

function labelFor(value: unknown): string {
  return Array.isArray(value) ? value.join(', ') : String(value ?? '')
}

function fail(cause: unknown) {
  error.value = cause instanceof Error ? cause.message : String(cause)
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

function ask(kind: Pending['kind'], app: IrisWebApp) {
  pending.value = { kind, app }
}

function confirmPending() {
  const current = pending.value
  if (!current) return
  void withBusy(async () => {
    if (current.kind === 'delete') {
      await deleteApplication(current.app.Name)
    } else {
      await setApplicationEnabled(current.app.Name, !current.app.Enabled)
    }
    pending.value = null
    await load()
  })
}

function openCreate() {
  editing.value = { mode: 'create', initial: null }
}

function openEdit(app: IrisWebApp) {
  void withBusy(async () => {
    const detail = await getApplication(app.Name)
    editing.value = { mode: 'edit', initial: detail as unknown as Record<string, unknown> }
  })
}

function saveForm(definition: Record<string, unknown>) {
  const name = String(definition.Name ?? '')
  void withBusy(async () => {
    await saveApplication(name, definition)
    editing.value = null
    await load()
  })
}

async function load() {
  loading.value = true
  try {
    applications.value = await listApplications()
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
      <h1>Applications</h1>
      <small>{{ applications.length }} web applications</small>
      <span class="spacer" />
      <button class="btn btn-primary" :disabled="busy" @click="openCreate">New application</button>
    </div>

    <p v-if="error" class="state is-error">Error: {{ error }}</p>

    <input v-model="search" class="search" type="search" placeholder="Filter by name, namespace, type…" />

    <AppTable :columns="columns" :rows="filtered" row-key="Name" :loading="loading" empty-title="No applications">
      <template #cell="{ column, row, value }">
        <StatusBadge v-if="column.key === 'Enabled'" :status="value ? 'RUNNING' : 'DISABLED'" />

        <span v-else-if="column.key === 'actions'" class="actions">
          <RouterLink :to="{ name: '/applications/detail', params: { app: encodeAppSegment(String(row.Name)) } }">
            View
          </RouterLink>
          <template v-if="!row.IsSystemApp">
            <button class="link-button" :disabled="busy" @click="openEdit(row as unknown as IrisWebApp)">Edit</button>
            <button class="link-button" :disabled="busy" @click="ask('toggle', row as unknown as IrisWebApp)">
              {{ row.Enabled ? 'Disable' : 'Enable' }}
            </button>
            <button
              class="link-button is-danger"
              :disabled="busy"
              @click="ask('delete', row as unknown as IrisWebApp)"
            >
              Delete
            </button>
          </template>
          <span v-else class="system-note" title="System applications are protected">system</span>
        </span>

        <span v-else-if="column.key === 'Name'" class="mono">{{ labelFor(value) }}</span>
        <template v-else>{{ labelFor(value) || '—' }}</template>
      </template>
    </AppTable>

    <ConfirmDialog
      :open="pending !== null"
      :title="dialogTitle"
      :message="dialogMessage"
      :confirm-label="pending?.kind === 'delete' ? 'Delete' : 'Confirm'"
      :danger="pending?.kind === 'delete'"
      :busy="busy"
      @confirm="confirmPending"
      @cancel="pending = null"
    />

    <ApplicationFormDialog
      :open="editing !== null"
      :mode="editing?.mode ?? 'create'"
      :initial="editing?.initial ?? null"
      :busy="busy"
      @save="saveForm"
      @cancel="editing = null"
    />
  </div>
</template>

<style scoped>
.search {
  max-width: 360px;
}
.spacer {
  flex: 1;
}
.mono {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
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
.link-button.is-danger {
  color: var(--status-error);
}
.system-note {
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
</style>
