<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import AppTable from '@/components/AppTable.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import { getUser, listUsers, type IrisUser, type IrisUserDetail } from '@/api/security'
import type { Column } from '@/types/ui'

const columns: Column[] = [
  { key: 'Name', label: 'Username' },
  { key: 'FullName', label: 'Name' },
  { key: 'Enabled', label: 'Status' },
  { key: 'roles', label: 'Roles' },
  { key: 'lastLogin', label: 'Last login' }
]

type Row = {
  Name: string
  FullName: string
  Type: string
  Enabled: boolean
  roles: string
  lastLogin: string
}

const loading = ref(true)
const error = ref<string | null>(null)
const rows = ref<Row[]>([])
const search = ref('')
const selected = ref<IrisUserDetail | null>(null)

const visible = computed(() => {
  const query = search.value.trim().toLowerCase()
  if (!query) return rows.value
  return rows.value.filter((row) => `${row.Name} ${row.FullName} ${row.roles}`.toLowerCase().includes(query))
})

async function load() {
  loading.value = true
  error.value = null
  try {
    const users = await listUsers()
    // Roles and last login only come from the per-user record.
    const details = await Promise.all(
      users.map((user: IrisUser) => getUser(user.Name).catch(() => null))
    )
    rows.value = users.map((user, index) => {
      const detail = details[index]
      return {
        Name: user.Name,
        FullName: user.FullName,
        Type: user.Type ?? '',
        Enabled: user.Enabled,
        roles: detail?.Roles ? String(detail.Roles) : '—',
        lastLogin: detail?.LoginDateTime ? String(detail.LoginDateTime) : '—'
      }
    })
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : String(cause)
  } finally {
    loading.value = false
  }
}

async function showDetail(name: string) {
  try {
    selected.value = await getUser(name)
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : String(cause)
  }
}

onMounted(load)
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <h1>Users</h1>
      <small>{{ rows.length }} users</small>
    </div>

    <p v-if="error" class="state is-error">Error: {{ error }}</p>

    <input v-model="search" class="search" type="search" placeholder="Filter users…" />

    <AppTable :columns="columns" :rows="visible as unknown as Record<string, unknown>[]" row-key="Name" :loading="loading" empty-title="No users">
      <template #cell="{ column, row, value }">
        <StatusBadge v-if="column.key === 'Enabled'" :status="value ? 'RUNNING' : 'DISABLED'" />
        <button v-else-if="column.key === 'Name'" class="link-button" @click="showDetail(String(row.Name))">
          {{ value }}
        </button>
        <template v-else>{{ value || '—' }}</template>
      </template>
    </AppTable>

    <div v-if="selected" class="card panel">
      <div class="panel-head">
        <h2>{{ selected.Name }}</h2>
        <button class="btn btn-quiet" @click="selected = null">Close</button>
      </div>
      <dl class="facts">
        <dt>Full name</dt>
        <dd>{{ selected.FullName || '—' }}</dd>
        <dt>Roles</dt>
        <dd>{{ selected.Roles || '—' }}</dd>
        <dt>Type</dt>
        <dd>{{ selected.Type || '—' }}</dd>
        <dt>Last login</dt>
        <dd>{{ selected.LoginDateTime || '—' }}</dd>
        <dt>Change password</dt>
        <dd>{{ selected.ChangePassword ? 'Required' : 'Not required' }}</dd>
        <dt>Comment</dt>
        <dd>{{ selected.Comment || '—' }}</dd>
      </dl>
    </div>
  </div>
</template>

<style scoped>
.search {
  max-width: 360px;
}
.panel {
  padding: var(--space-4) var(--space-5);
  margin-top: var(--space-4);
}
.panel-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.facts {
  display: grid;
  grid-template-columns: 180px 1fr;
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
  cursor: pointer;
}
.state.is-error {
  color: var(--status-error);
}
</style>
