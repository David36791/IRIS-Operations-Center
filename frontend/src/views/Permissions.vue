<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { getRole, getUser, listResources, listRoles, listUsers, type IrisResource } from '@/api/security'

type Mode = 'role' | 'user'

const loading = ref(true)
const busy = ref(false)
const error = ref<string | null>(null)
const roles = ref<string[]>([])
const users = ref<string[]>([])
const resources = ref<IrisResource[]>([])

const mode = ref<Mode>('role')
const selection = ref('')
/** resource name -> permission letters, for the current selection. */
const grants = ref<Record<string, string>>({})
const sources = ref<{ source: string; count: number }[]>([])

const matrix = computed(() =>
  Object.entries(grants.value)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([name, permissions]) => ({
      resource: name,
      read: permissions.includes('R'),
      write: permissions.includes('W'),
      use: permissions.includes('U')
    }))
)

const resourceTypeCount = computed(() => {
  const out: Record<string, number> = {}
  for (const resource of resources.value) {
    out[resource.ResourceType] = (out[resource.ResourceType] ?? 0) + 1
  }
  return Object.entries(out).sort(([, a], [, b]) => b - a)
})

function mergeGrant(target: Record<string, string>, grant: { Name: string; Permissions: string }) {
  const combined = (target[grant.Name] ?? '') + grant.Permissions
  target[grant.Name] = Array.from(new Set(combined.split(''))).sort().join('')
}

/**
 * A role grants its own resources plus everything it inherits, and a user
 * holds everything its roles grant. Without following GrantedRoles a role that
 * only bundles others looks empty, which is misleading.
 */
async function collect(
  roleName: string,
  seen: Set<string>,
  target: Record<string, string>,
  sources: { source: string; count: number }[],
  depth = 0
) {
  if (depth > 5 || seen.has(roleName)) return
  seen.add(roleName)
  const role = await getRole(roleName).catch(() => null)
  if (!role) return
  sources.push({ source: `Role ${roleName}`, count: role.Resources.length })
  for (const grant of role.Resources) mergeGrant(target, grant)
  for (const parent of role.GrantedRoles ?? []) await collect(parent, seen, target, sources, depth + 1)
}

async function selectRole(name: string) {
  selection.value = `role:${name}`
  busy.value = true
  error.value = null
  try {
    const next: Record<string, string> = {}
    const contributions: { source: string; count: number }[] = []
    await collect(name, new Set<string>(), next, contributions)
    grants.value = next
    sources.value = contributions
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : String(cause)
  } finally {
    busy.value = false
  }
}

/** A user's effective permissions are the union of everything its roles grant. */
async function selectUser(name: string) {
  selection.value = `user:${name}`
  busy.value = true
  error.value = null
  try {
    const detail = await getUser(name)
    const roleNames = String(detail.Roles ?? '')
      .split(/[,\s]+/)
      .map((value) => value.trim())
      .filter(Boolean)
    const next: Record<string, string> = {}
    const contributions: { source: string; count: number }[] = []
    const seen = new Set<string>()
    for (const roleName of roleNames) await collect(roleName, seen, next, contributions)
    grants.value = next
    sources.value = contributions
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : String(cause)
  } finally {
    busy.value = false
  }
}

async function load() {
  loading.value = true
  try {
    const [roleList, userList, resourceList] = await Promise.all([listRoles(), listUsers(), listResources()])
    roles.value = roleList.map((role) => role.Name).sort()
    users.value = userList.map((user) => user.Name).sort()
    resources.value = resourceList
    // Show something useful straight away rather than an empty matrix.
    if (roles.value.length) await selectRole(roles.value[0])
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
      <h1>Permissions</h1>
      <small>
        What a role grants, and what a user can actually do — pick one on either side of the switch.
        {{ resources.length }} resources defined.
      </small>
    </div>

    <p v-if="loading" class="state">Loading…</p>
    <p v-else-if="error" class="state is-error">Error: {{ error }}</p>

    <template v-else>
      <div class="selector card">
        <div class="tabs">
          <button class="tab" :class="{ 'is-active': mode === 'role' }" @click="mode = 'role'; selection = ''">By role</button>
          <button class="tab" :class="{ 'is-active': mode === 'user' }" @click="mode = 'user'; selection = ''">By user (effective)</button>
        </div>
        <select v-if="mode === 'role'" :disabled="busy" @change="selectRole(($event.target as HTMLSelectElement).value)">
          <option value="">Select a role…</option>
          <option v-for="role in roles" :key="role" :value="role" :selected="selection === `role:${role}`">{{ role }}</option>
        </select>
        <select v-else :disabled="busy" @change="selectUser(($event.target as HTMLSelectElement).value)">
          <option value="">Select a user…</option>
          <option v-for="user in users" :key="user" :value="user" :selected="selection === `user:${user}`">{{ user }}</option>
        </select>
      </div>

      <div v-if="sources.length" class="sources">
        <span v-for="entry in sources" :key="entry.source" class="chip">{{ entry.source }} · {{ entry.count }}</span>
      </div>

      <table class="matrix card">
        <thead>
          <tr>
            <th>Resource</th>
            <th class="center">Read</th>
            <th class="center">Write</th>
            <th class="center">Use</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in matrix" :key="row.resource">
            <td class="mono">{{ row.resource }}</td>
            <td class="center">{{ row.read ? '✓' : '—' }}</td>
            <td class="center">{{ row.write ? '✓' : '—' }}</td>
            <td class="center">{{ row.use ? '✓' : '—' }}</td>
          </tr>
          <tr v-if="matrix.length === 0">
            <td colspan="4" class="muted">
              {{ selection ? 'No resource grants for this selection.' : 'Pick a role or a user to see its permissions.' }}
            </td>
          </tr>
        </tbody>
      </table>

      <p class="note">
        IRIS grants resources with the letters R (read), W (write) and U (use), so those are the columns shown; a
        user's effective permissions are the union of the grants of every role that user holds.
        Resource catalogue: {{ resourceTypeCount.map(([type, count]) => `${type} ${count}`).join(', ') }}.
      </p>
    </template>
  </div>
</template>

<style scoped>
.selector {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
  padding: var(--space-3) var(--space-4);
}
.tabs {
  display: flex;
  gap: var(--space-1);
}
.tab {
  padding: 4px 10px;
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
.sources {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}
.chip {
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--status-muted-bg);
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}
.matrix {
  width: 100%;
  border-collapse: collapse;
}
.matrix th {
  padding: var(--space-2) var(--space-4);
  border-bottom: 1px solid var(--color-border-strong);
  background: var(--color-surface-2);
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  text-align: left;
}
.matrix td {
  padding: var(--space-2) var(--space-4);
  border-bottom: 1px solid var(--color-border);
}
.matrix .center {
  text-align: center;
}
.mono {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
}
.muted {
  padding: var(--space-5) var(--space-4);
  color: var(--color-text-faint);
  text-align: center;
}
.note {
  margin: 0;
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
.state.is-error {
  color: var(--status-error);
}
</style>
