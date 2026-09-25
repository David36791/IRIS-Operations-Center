<script setup lang="ts">
import { onMounted, ref } from 'vue'
import EmptyState from '@/components/EmptyState.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import { getOAuthServer, listOAuthClients, listOAuthResourceServers } from '@/api/security'

interface PanelEntry {
  entries: [string, unknown][]
}

interface Panel {
  key: string
  title: string
  note: string
  rows: PanelEntry[]
}

const loading = ref(true)
const error = ref<string | null>(null)
const panels = ref<Panel[]>([])
const serverError = ref<string | null>(null)

function render(rows: Record<string, unknown>[]): PanelEntry[] {
  return rows.map((row) => ({
    entries: Object.entries(row).filter(
      ([, value]) => value !== '' && value !== null && value !== undefined
    ) as [string, unknown][]
  }))
}

async function load() {
  loading.value = true
  try {
    const [clients, resourceServers] = await Promise.all([
      listOAuthClients().catch(() => [] as Record<string, unknown>[]),
      listOAuthResourceServers().catch(() => [] as Record<string, unknown>[])
    ])
    const server = await getOAuthServer().catch((cause: unknown) => {
      serverError.value = cause instanceof Error ? cause.message : String(cause)
      return null
    })
    panels.value = [
      {
        key: 'clients',
        title: 'Clients',
        note: 'OAuth 2.0 clients registered as server definitions.',
        rows: render(clients)
      },
      {
        key: 'server',
        title: 'Authorization Server',
        note: 'The instance acting as an authorization server.',
        rows: server ? render([server]) : []
      },
      {
        key: 'resources',
        title: 'Resource Servers',
        note: 'Resource servers this instance can obtain tokens for.',
        rows: render(resourceServers)
      }
    ]
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
      <h1>OAuth</h1>
      <small>Client secret values are never displayed</small>
    </div>

    <p v-if="error" class="state is-error">Error: {{ error }}</p>

    <template v-else>
      <section v-for="panel in panels" :key="panel.key" class="card panel">
        <div class="panel-head">
          <h2>{{ panel.title }}</h2>
          <StatusBadge :status="panel.rows.length ? 'HEALTHY' : 'UNKNOWN'" />
        </div>
        <p class="muted">{{ panel.note }}</p>

        <p v-if="panel.key === 'server' && serverError" class="muted is-error">{{ serverError }}</p>

        <ul v-else-if="panel.rows.length" class="entries">
          <li v-for="(entry, index) in panel.rows" :key="index">
            <dl class="facts">
              <template v-for="[key, value] in entry.entries" :key="key">
                <dt>{{ key }}</dt>
                <dd>{{ key.toLowerCase().includes('secret') || key.toLowerCase().includes('password') ? '************' : String(value) }}</dd>
              </template>
            </dl>
          </li>
        </ul>

        <EmptyState v-else title="Nothing configured" description="This part of OAuth 2.0 is not configured on this instance." />
      </section>
    </template>
  </div>
</template>

<style scoped>
.panel {
  padding: var(--space-4) var(--space-5);
}
.panel-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.panel h2 {
  font-size: var(--text-md);
}
.muted {
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}
.muted.is-error {
  color: var(--status-error);
}
.entries {
  margin: var(--space-2) 0 0;
  padding: 0;
  list-style: none;
}
.entries li + li {
  margin-top: var(--space-3);
  padding-top: var(--space-3);
  border-top: 1px solid var(--color-border);
}
.facts {
  display: grid;
  grid-template-columns: 200px 1fr;
  gap: 2px var(--space-4);
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
.state.is-error {
  color: var(--status-error);
}
</style>
