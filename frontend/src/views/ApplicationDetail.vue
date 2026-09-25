<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import EmptyState from '@/components/EmptyState.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import { getApplication, type IrisWebAppDetail } from '@/api/applications'

type TabId = 'general' | 'security' | 'rest' | 'configuration' | 'activity'

const TABS: { id: TabId; label: string }[] = [
  { id: 'general', label: 'General' },
  { id: 'security', label: 'Security' },
  { id: 'rest', label: 'REST API' },
  { id: 'configuration', label: 'Configuration' },
  { id: 'activity', label: 'Activity' }
]

const KNOWN_AUTH_BITS: [number, string][] = [
  [4, 'Kerberos'],
  [16, 'Delegated'],
  [32, 'Password'],
  [64, 'Unauthenticated']
]

const route = useRoute()
// The route segment carries the name with "/" replaced by "~"; show it decoded.
const name = computed(() => String(route.params.app ?? '').split('~').join('/'))

const loading = ref(true)
const error = ref<string | null>(null)
const app = ref<IrisWebAppDetail | null>(null)
const tab = ref<TabId>('general')

function decodeAuthMethods(bits: number): string[] {
  const methods = KNOWN_AUTH_BITS.filter(([bit]) => bits & bit).map(([, label]) => label)
  const accounted = KNOWN_AUTH_BITS.reduce((sum, [bit]) => sum + (bits & bit), 0)
  const rest = bits & ~accounted
  if (rest) methods.push(`Other (${rest})`)
  return methods
}

function facts(pairs: [string, unknown][]): [string, string][] {
  return pairs.map(([label, value]) => [
    label,
    Array.isArray(value) ? value.join(', ') : String(value ?? '') || '—'
  ])
}

const generalFacts = computed(() =>
  facts([
    ['Name', app.value?.Name],
    ['Namespace', app.value?.NameSpace],
    ['Description', app.value?.Description],
    ['Path', app.value?.Path],
    ['Dispatch class', app.value?.DispatchClass],
    ['Package', app.value?.Package],
    ['Super class', app.value?.SuperClass]
  ])
)

const securityFacts = computed(() =>
  facts([
    ['Authentication methods', decodeAuthMethods(app.value?.AutheEnabled ?? 0)],
    ['Match roles', app.value?.MatchRoles],
    ['Resource', app.value?.Resource],
    ['CSRF token', app.value?.CSRFToken ? 'Enabled' : 'Disabled'],
    ['Inbound web services', app.value?.InbndWebServicesEnabled ? 'Enabled' : 'Disabled'],
    ['Two-factor', app.value?.TwoFactorEnabled ? 'Enabled' : 'Disabled']
  ])
)

const restFacts = computed(() =>
  facts([
    ['Dispatch class', app.value?.DispatchClass],
    ['Recurse to sub-paths', app.value?.Recurse ? 'Yes' : 'No']
  ])
)

const configurationFacts = computed(() =>
  facts([
    ['Path', app.value?.Path],
    ['Cookie path', app.value?.CookiePath],
    ['Serve files', app.value?.ServeFiles],
    ['Serve files timeout', app.value?.ServeFilesTimeout],
    ['Session timeout', app.value?.Timeout],
    ['Use cookies', app.value?.UseCookies],
    ['Session scope', app.value?.SessionScope],
    ['User cookie scope', app.value?.UserCookieScope],
    ['Redirect empty path', app.value?.RedirectEmptyPath ? 'Yes' : 'No'],
    ['Login page', app.value?.LoginPage],
    ['Error page', app.value?.ErrorPage]
  ])
)

async function load() {
  loading.value = true
  error.value = null
  try {
    app.value = await getApplication(name.value)
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
      <RouterLink to="/applications">← Applications</RouterLink>
      <h1 class="mono">{{ name }}</h1>
      <StatusBadge v-if="app" :status="app.Enabled ? 'RUNNING' : 'DISABLED'" />
    </div>

    <p v-if="loading" class="state">Loading…</p>
    <p v-else-if="error" class="state is-error">Error: {{ error }}</p>

    <template v-else-if="app">
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
        <dl v-if="tab === 'general'" class="facts">
          <template v-for="[label, value] in generalFacts" :key="label">
            <dt>{{ label }}</dt>
            <dd>{{ value }}</dd>
          </template>
        </dl>

        <dl v-else-if="tab === 'security'" class="facts">
          <template v-for="[label, value] in securityFacts" :key="label">
            <dt>{{ label }}</dt>
            <dd>{{ value }}</dd>
          </template>
        </dl>

        <div v-else-if="tab === 'rest'" class="stack">
          <dl class="facts">
            <template v-for="[label, value] in restFacts" :key="label">
              <dt>{{ label }}</dt>
              <dd>{{ value }}</dd>
            </template>
          </dl>
          <RouterLink class="btn" to="/rest-explorer">Open in REST API Explorer</RouterLink>
        </div>

        <dl v-else-if="tab === 'configuration'" class="facts">
          <template v-for="[label, value] in configurationFacts" :key="label">
            <dt>{{ label }}</dt>
            <dd>{{ value }}</dd>
          </template>
        </dl>

        <EmptyState
          v-else
          title="No per-application activity"
          description="IRIS does not report per-application request history here, and the instance message log cannot be read from a web application, so there is nothing to show rather than a fabricated timeline."
        />
      </div>
    </template>
  </div>
</template>

<style scoped>
.mono {
  font-family: var(--font-mono);
  font-size: var(--text-lg);
}
.state.is-error {
  color: var(--status-error);
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
  font-size: var(--text-md);
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
  overflow-wrap: anywhere;
}
.facts dd {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
}
.stack {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: var(--space-4);
}
</style>
