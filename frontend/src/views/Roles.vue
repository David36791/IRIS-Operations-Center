<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import AppTable from '@/components/AppTable.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import { getRole, listRoles, type IrisRole, type IrisRoleDetail } from '@/api/security'
import type { Column } from '@/types/ui'

const columns: Column[] = [
  { key: 'Name', label: 'Role' },
  { key: 'Description', label: 'Description' },
  { key: 'CreatedBy', label: 'Created by' },
  { key: 'EscalationOnly', label: 'Escalation only' },
  { key: 'resources', label: 'Resources', align: 'right' }
]

const loading = ref(true)
const error = ref<string | null>(null)
const roles = ref<IrisRole[]>([])
const counts = ref<Record<string, number>>({})
const selectedName = ref('')
const selected = ref<IrisRoleDetail | null>(null)
const search = ref('')

const visible = computed(() => {
  const query = search.value.trim().toLowerCase()
  return query
    ? roles.value.filter((role) => `${role.Name} ${role.Description}`.toLowerCase().includes(query))
    : roles.value
})

async function showDetail(name: string) {
  selectedName.value = name
  error.value = null
  try {
    selected.value = await getRole(name)
  } catch (cause) {
    selected.value = null
    error.value = cause instanceof Error ? cause.message : String(cause)
  }
}

async function load() {
  loading.value = true
  try {
    roles.value = await listRoles()
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
      <h1>Roles</h1>
      <small>{{ roles.length }} roles</small>
    </div>

    <p v-if="error" class="state is-error">Error: {{ error }}</p>

    <input v-model="search" class="search" type="search" placeholder="Filter roles…" />

    <AppTable :columns="columns" :rows="visible as unknown as Record<string, unknown>[]" row-key="Name" :loading="loading" empty-title="No roles">
      <template #cell="{ column, row, value }">
        <StatusBadge v-if="column.key === 'EscalationOnly'" :status="value ? 'WARNING' : 'INFO'" />
        <button v-else-if="column.key === 'Name'" class="link-button" @click="showDetail(String(row.Name))">
          {{ value }}
        </button>
        <template v-else-if="column.key === 'resources'">
          <button class="link-button" @click="showDetail(String(row.Name))">
            {{ counts[String(row.Name)] ?? 'view' }}
          </button>
        </template>
        <template v-else>{{ value || '—' }}</template>
      </template>
    </AppTable>

    <div v-if="selected" class="card panel">
      <div class="panel-head">
        <h2>{{ selectedName }}</h2>
        <button class="btn btn-quiet" @click="selected = null">Close</button>
      </div>
      <p class="muted">{{ selected.Description || '—' }}</p>

      <h3>Resources</h3>
      <p v-if="selected.Resources.length === 0" class="muted">This role has no resource grants.</p>
      <table v-else class="grants">
        <thead>
          <tr><th>Resource</th><th>Permissions</th></tr>
        </thead>
        <tbody>
          <tr v-for="grant in selected.Resources" :key="grant.Name">
            <td class="mono">{{ grant.Name }}</td>
            <td>
              <span v-for="letter in grant.Permissions.split('')" :key="letter" class="perm">{{ letter }}</span>
            </td>
          </tr>
        </tbody>
      </table>

      <h3>Granted roles</h3>
      <p class="muted">{{ selected.GrantedRoles.length ? selected.GrantedRoles.join(', ') : '—' }}</p>
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
.panel h3 {
  margin-top: var(--space-4);
  font-size: var(--text-md);
}
.mono {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
}
.muted {
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}
.grants {
  width: 100%;
  border-collapse: collapse;
}
.grants th {
  padding: var(--space-2) 0;
  border-bottom: 1px solid var(--color-border-strong);
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  text-align: left;
}
.grants td {
  padding: var(--space-2) 0;
  border-bottom: 1px solid var(--color-border);
}
.perm {
  display: inline-block;
  min-width: 20px;
  margin-right: 4px;
  padding: 0 4px;
  border-radius: var(--radius-sm);
  background: var(--status-info-bg);
  color: var(--status-info);
  font-family: var(--font-mono);
  font-size: var(--text-sm);
  font-weight: 700;
  text-align: center;
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
