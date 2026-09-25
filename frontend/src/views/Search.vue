<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import EmptyState from '@/components/EmptyState.vue'
import { listApplications } from '@/api/applications'
import { listCertificates, listRoles, listUsers, listWallets } from '@/api/security'
import { semanticSearch, type SemanticMatch } from '@/api/logs'
import { getProcesses } from '@/api/system'
import { listTaskHistory, listTasks } from '@/api/tasks'

interface Hit {
  type: string
  label: string
  detail: string
  to: string
}

const GROUPS = ['Applications', 'Tasks', 'Users', 'Roles', 'Certificates', 'Secrets', 'Processes', 'Logs']

const loading = ref(true)
const error = ref<string | null>(null)
const query = ref('')
const mode = ref<'keyword' | 'semantic'>('keyword')
const semanticQuery = ref('')
const semanticMatches = ref<SemanticMatch[]>([])
const semanticNote = ref('')
const semanticBusy = ref(false)

async function runSemantic() {
  semanticBusy.value = true
  semanticNote.value = ''
  semanticMatches.value = []
  try {
    const result = await semanticSearch(semanticQuery.value)
    semanticMatches.value = result.matches
  } catch (cause) {
    semanticNote.value = cause instanceof Error ? cause.message : String(cause)
  } finally {
    semanticBusy.value = false
  }
}
const corpus = ref<Hit[]>([])
const counts = ref<Record<string, number>>({})

const results = computed(() => {
  const needle = query.value.trim().toLowerCase()
  if (!needle) return []
  return corpus.value.filter((hit) =>
    `${hit.label} ${hit.detail} ${hit.type}`.toLowerCase().includes(needle)
  )
})

const grouped = computed(() => {
  const out = new Map<string, Hit[]>()
  for (const hit of results.value) {
    const list = out.get(hit.type) ?? []
    list.push(hit)
    out.set(hit.type, list)
  }
  return Array.from(out.entries())
})

async function load() {
  loading.value = true
  error.value = null
  const hits: Hit[] = []

  const [apps, tasks, runs, users, roles, certs, wallets, processes] = await Promise.allSettled([
    listApplications(),
    listTasks(),
    listTaskHistory(),
    listUsers(),
    listRoles(),
    listCertificates(),
    listWallets(),
    getProcesses()
  ])

  if (apps.status === 'fulfilled') {
    for (const app of apps.value) {
      hits.push({
        type: 'Applications',
        label: app.Name,
        detail: `${app.Namespace} · ${app.DispatchClass || app.Type}`,
        to: `/applications/detail/${app.Name.split('/').join('~')}`
      })
    }
  } else {
    error.value = apps.reason instanceof Error ? apps.reason.message : String(apps.reason)
  }

  if (tasks.status === 'fulfilled') {
    for (const task of tasks.value) {
      hits.push({
        type: 'Tasks',
        label: task.Name,
        detail: `${task.Type} · ${task.Namespace}`,
        to: `/tasks/detail/${task.Id}`
      })
    }
  }

  if (runs.status === 'fulfilled') {
    for (const run of runs.value.slice(0, 60)) {
      hits.push({
        type: 'Logs',
        label: `${run.Name} — ${run.Result || 'run'}`,
        detail: run.Completed || run.LastStart,
        to: '/timeline'
      })
    }
  }

  if (users.status === 'fulfilled') {
    for (const user of users.value) {
      hits.push({ type: 'Users', label: user.Name, detail: user.FullName, to: '/security/users' })
    }
  }

  if (roles.status === 'fulfilled') {
    for (const role of roles.value) {
      hits.push({ type: 'Roles', label: role.Name, detail: role.Description, to: '/security/roles' })
    }
  }

  if (certs.status === 'fulfilled') {
    for (const cert of certs.value) {
      const record = cert as unknown as Record<string, unknown>
      hits.push({
        type: 'Certificates',
        label: String(record.Subject ?? record.Alias ?? record.Name ?? 'certificate'),
        detail: String(record.Issuer ?? ''),
        to: '/security/certificates'
      })
    }
  }

  if (wallets.status === 'fulfilled') {
    for (const wallet of wallets.value) {
      hits.push({ type: 'Secrets', label: wallet.Name, detail: 'wallet collection', to: '/security/secrets' })
    }
  }

  if (processes.status === 'fulfilled') {
    for (const process of processes.value) {
      hits.push({
        type: 'Processes',
        label: `PID ${process.Pid} — ${process.Routine || 'unknown'}`,
        detail: `${process.Username || 'system'} · ${process.Nspace || ''}`.trim(),
        to: '/system/processes'
      })
    }
  }

  corpus.value = hits
  const tally: Record<string, number> = {}
  for (const hit of hits) tally[hit.type] = (tally[hit.type] ?? 0) + 1
  counts.value = tally
  loading.value = false
}

onMounted(load)
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <h1>Global Search</h1>
      <small>{{ corpus.length }} searchable objects</small>
    </div>

    <p v-if="error" class="state is-error">Error: {{ error }}</p>

    <div class="modes">
      <button class="mode" :class="{ 'is-active': mode === 'keyword' }" @click="mode = 'keyword'">Keyword</button>
      <button class="mode" :class="{ 'is-active': mode === 'semantic' }" @click="mode = 'semantic'">Semantic</button>
    </div>

    <template v-if="mode === 'semantic'">
      <div class="row">
        <input
          v-model="semanticQuery"
          class="query"
          type="search"
          placeholder="Describe what you are looking for, e.g. database connection failure"
          @keyup.enter="runSemantic"
        />
        <button class="btn btn-primary" :disabled="semanticBusy || !semanticQuery.trim()" @click="runSemantic">
          {{ semanticBusy ? 'Searching…' : 'Search' }}
        </button>
      </div>
      <p v-if="semanticNote" class="muted">{{ semanticNote }}</p>
      <ol v-if="semanticMatches.length" class="semantic">
        <li v-for="(match, index) in semanticMatches" :key="`${match.name}-${index}`">
          <span class="score mono">{{ match.score.toFixed(3) }}</span>
          <span class="label">{{ match.name }}</span>
          <span class="detail">{{ match.result }}</span>
        </li>
      </ol>
      <p class="muted">
        Keyword search finds the words you type; this finds events that mean the same thing. A query like "database
        connection problem" should surface timeouts and failed connections that never use those words.
      </p>
      <p class="muted">
        It embeds the query and the events with the configured AI endpoint and ranks them by cosine similarity,
        computed in Embedded Python. The query can be in any language, because it is compared as a vector rather than
        matched on keywords. Without that endpoint it reports why instead of pretending a keyword match is semantic.
      </p>
    </template>

    <input
      v-else
      v-model="query"
      class="query"
      type="search"
      autofocus
      placeholder="Search applications, tasks, users, roles, certificates, secrets, logs, processes…"
    />

    <div class="coverage">
      <span v-for="group in GROUPS" :key="group" class="chip" :class="{ 'is-empty': !counts[group] }">
        {{ group }} <b>{{ counts[group] ?? 0 }}</b>
      </span>
    </div>

    <p v-if="loading" class="state">Loading…</p>

    <template v-else-if="mode === 'keyword' && query.trim()">
      <section v-for="[type, hits] in grouped" :key="type" class="group">
        <h2>{{ type }} <small>{{ hits.length }}</small></h2>
        <ul class="hits">
          <li v-for="hit in hits.slice(0, 25)" :key="`${type}-${hit.label}`">
            <RouterLink :to="hit.to" class="hit">
              <span class="label">{{ hit.label }}</span>
              <span v-if="hit.detail" class="detail">{{ hit.detail }}</span>
            </RouterLink>
          </li>
        </ul>
      </section>

      <EmptyState
        v-if="results.length === 0"
        title="Nothing matched"
        description="Try a shorter term, or search for something the instance reports."
      />
    </template>

    <EmptyState
      v-else-if="mode === 'keyword'"
      title="Type to search"
      description="Results are grouped by object type and link straight to the relevant page."
    />
  </div>
</template>

<style scoped>
.modes {
  display: flex;
  gap: var(--space-1);
}
.mode {
  padding: 4px 12px;
  border: 1px solid var(--color-border-strong);
  border-radius: var(--radius-sm);
  background: var(--color-surface);
  color: var(--color-text-muted);
  font: inherit;
  font-size: var(--text-sm);
  cursor: pointer;
}
.mode.is-active {
  border-color: var(--color-primary);
  background: var(--status-info-bg);
  color: var(--color-primary);
  font-weight: 600;
}
.row {
  display: flex;
  gap: var(--space-2);
  align-items: center;
}
.row .query {
  flex: 1;
}
.semantic {
  margin: 0;
  padding: 0;
  list-style: none;
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  background: var(--color-surface);
}
.semantic li {
  display: flex;
  align-items: baseline;
  gap: var(--space-3);
  padding: var(--space-2) var(--space-4);
  border-bottom: 1px solid var(--color-border);
}
.semantic li:last-child {
  border-bottom: 0;
}
.score {
  min-width: 56px;
  color: var(--status-info);
  font-weight: 700;
}
.query {
  width: 100%;
  max-width: 640px;
  font-size: var(--text-lg);
}
.coverage {
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
.chip.is-empty {
  opacity: 0.55;
}
.chip b {
  font-variant-numeric: tabular-nums;
}
.group {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}
.group h2 {
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
}
.group h2 small {
  color: var(--color-text-faint);
  font-weight: 400;
}
.hits {
  margin: 0;
  padding: 0;
  list-style: none;
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  background: var(--color-surface);
}
.hit {
  display: flex;
  align-items: baseline;
  gap: var(--space-3);
  padding: var(--space-2) var(--space-4);
  border-bottom: 1px solid var(--color-border);
  color: inherit;
  text-decoration: none;
}
.hits li:last-child .hit {
  border-bottom: 0;
}
.hit:hover {
  background: var(--color-surface-2);
  text-decoration: none;
}
.label {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
}
.detail {
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
.state.is-error {
  color: var(--status-error);
}
</style>
