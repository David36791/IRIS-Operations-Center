<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import EmptyState from '@/components/EmptyState.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import { listApplications, type IrisWebApp } from '@/api/applications'
import {
  getOpenApi,
  sendRequest,
  type ExplorerResponse,
  type OpenApiOperation,
  type OpenApiSpec
} from '@/api/explorer'

const METHODS = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']

const apps = ref<IrisWebApp[]>([])
const loadingApps = ref(true)
const error = ref<string | null>(null)
const appFilter = ref('')

const selectedApp = ref<IrisWebApp | null>(null)
const spec = ref<OpenApiSpec | null>(null)
const loadingSpec = ref(false)
const specError = ref<string | null>(null)
const endpointFilter = ref('')

const method = ref('GET')
const path = ref('')
const paramsText = ref('')
const headersText = ref('')
const authorization = ref('')
const body = ref('')
const response = ref<ExplorerResponse | null>(null)
const sending = ref(false)

const restApps = computed(() => {
  const query = appFilter.value.trim().toLowerCase()
  const list = apps.value.filter((app) => app.DispatchClass)
  if (!query) return list
  return list.filter((app) => `${app.Name} ${app.Namespace} ${app.DispatchClass}`.toLowerCase().includes(query))
})

const endpoints = computed(() => {
  const paths = spec.value?.paths
  if (!paths) return []
  const all: { method: string; path: string; summary: string }[] = []
  for (const [endpointPath, operations] of Object.entries(paths)) {
    for (const [verb, op] of Object.entries(operations as Record<string, OpenApiOperation>)) {
      const upper = verb.toUpperCase()
      if (!METHODS.includes(upper)) continue
      all.push({ method: upper, path: endpointPath, summary: op.summary ?? op.description ?? '' })
    }
  }
  const query = endpointFilter.value.trim().toLowerCase()
  return query ? all.filter((e) => `${e.method} ${e.path} ${e.summary}`.toLowerCase().includes(query)) : all
})

const prettyBody = computed(() => {
  const current = response.value
  if (!current) return ''
  if ((current.contentType ?? '').toLowerCase().includes('json') && current.body) {
    try {
      return JSON.stringify(JSON.parse(current.body), null, 2)
    } catch {
      return current.body
    }
  }
  return current.body
})

const responseHeaders = computed(() => Object.entries(response.value?.headers ?? {}))

async function loadApps() {
  loadingApps.value = true
  error.value = null
  try {
    apps.value = await listApplications()
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : String(cause)
  } finally {
    loadingApps.value = false
  }
}

async function selectApp(app: IrisWebApp) {
  selectedApp.value = app
  spec.value = null
  specError.value = null
  loadingSpec.value = true
  try {
    spec.value = await getOpenApi(app.Namespace, app.Name)
  } catch (cause) {
    specError.value = cause instanceof Error ? cause.message : String(cause)
  } finally {
    loadingSpec.value = false
  }
}

function useEndpoint(verb: string, endpointPath: string) {
  method.value = verb
  const base = spec.value?.basePath ?? ''
  path.value = `${base}${endpointPath}`.replace(/\/{2,}/g, '/')
}

/** "name=value" per line, for query parameters and for headers. */
function parseLines(text: string): Record<string, string> {
  const out: Record<string, string> = {}
  for (const line of text.split('\n')) {
    const trimmed = line.trim()
    if (!trimmed) continue
    const index = trimmed.indexOf('=')
    if (index < 0) continue
    out[trimmed.slice(0, index).trim()] = trimmed.slice(index + 1).trim()
  }
  return out
}

async function run() {
  sending.value = true
  response.value = null
  error.value = null
  try {
    const headers = parseLines(headersText.value)
    if (authorization.value.trim()) headers.Authorization = authorization.value.trim()
    response.value = await sendRequest({
      method: method.value,
      path: path.value,
      params: parseLines(paramsText.value),
      headers,
      body: body.value.trim() ? body.value : undefined
    })
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : String(cause)
  } finally {
    sending.value = false
  }
}

function statusFor(code: number): string {
  if (code >= 200 && code < 300) return 'SUCCESS'
  if (code >= 400 && code < 500) return 'WARNING'
  if (code >= 500) return 'ERROR'
  return 'INFO'
}

onMounted(loadApps)
</script>

<template>
  <div class="explorer">
    <aside class="pane apps">
      <h2>REST applications</h2>
      <input v-model="appFilter" type="search" placeholder="Filter…" />
      <p v-if="loadingApps" class="muted">Loading…</p>
      <p v-else-if="restApps.length === 0" class="muted">No REST applications</p>
      <ul v-else class="list">
        <li v-for="app in restApps" :key="app.Name">
          <button class="item" :class="{ 'is-active': selectedApp?.Name === app.Name }" @click="selectApp(app)">
            <span class="mono">{{ app.Name }}</span>
            <small>{{ app.Namespace }} · {{ app.DispatchClass }}</small>
          </button>
        </li>
      </ul>
    </aside>

    <section class="pane endpoints">
      <h2>Endpoints</h2>
      <input v-model="endpointFilter" type="search" placeholder="Filter…" :disabled="!spec" />
      <p v-if="loadingSpec" class="muted">Loading specification…</p>
      <p v-else-if="specError" class="muted is-error">{{ specError }}</p>
      <p v-else-if="!spec" class="muted">Pick an application</p>
      <ul v-else class="list">
        <li v-for="endpoint in endpoints" :key="`${endpoint.method} ${endpoint.path}`">
          <button class="item" @click="useEndpoint(endpoint.method, endpoint.path)">
            <span class="verb" :class="`verb-${endpoint.method}`">{{ endpoint.method }}</span>
            <span class="mono">{{ endpoint.path }}</span>
            <small v-if="endpoint.summary">{{ endpoint.summary }}</small>
          </button>
        </li>
      </ul>
    </section>

    <section class="pane builder">
      <h2>Request</h2>
      <p v-if="error" class="muted is-error">{{ error }}</p>

      <div class="row">
        <select v-model="method">
          <option v-for="verb in METHODS" :key="verb" :value="verb">{{ verb }}</option>
        </select>
        <input v-model="path" class="path" placeholder="/api/…" />
        <button class="btn btn-primary" :disabled="sending || !path" @click="run">
          {{ sending ? 'Sending…' : 'Send' }}
        </button>
      </div>

      <div class="grid">
        <label class="field">
          <span>Query parameters (name=value per line)</span>
          <textarea v-model="paramsText" rows="3" />
        </label>
        <label class="field">
          <span>Headers (name=value per line)</span>
          <textarea v-model="headersText" rows="3" />
        </label>
        <label class="field wide">
          <span>Authorization</span>
          <input v-model="authorization" placeholder="not stored anywhere" />
        </label>
        <label class="field wide">
          <span>Request body</span>
          <textarea v-model="body" rows="4" placeholder="{ }" />
        </label>
      </div>

      <h2 class="response-head">Response</h2>
      <EmptyState v-if="!response" title="No response yet" description="Send a request to see status, headers and body." />
      <template v-else>
        <div class="response-meta">
          <StatusBadge :status="statusFor(response.status)" />
          <b class="mono">{{ response.status }}</b>
          <span class="muted">{{ response.durationMs }} ms</span>
          <span class="muted mono">{{ response.contentType }}</span>
        </div>
        <dl class="headers">
          <template v-for="[key, value] in responseHeaders" :key="key">
            <dt class="mono">{{ key }}</dt>
            <dd class="mono">{{ value }}</dd>
          </template>
        </dl>
        <pre class="body">{{ prettyBody }}</pre>
      </template>
    </section>
  </div>
</template>

<style scoped>
.explorer {
  display: grid;
  grid-template-columns: 260px 320px minmax(0, 1fr);
  gap: var(--space-4);
  align-items: start;
}
.pane {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
  min-width: 0;
}
.pane h2 {
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
}
.response-head {
  margin-top: var(--space-4);
}
.list {
  margin: 0;
  padding: 0;
  list-style: none;
  max-height: 60vh;
  overflow-y: auto;
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  background: var(--color-surface);
}
.item {
  display: flex;
  flex-direction: column;
  gap: 2px;
  width: 100%;
  padding: var(--space-2) var(--space-3);
  border: 0;
  border-bottom: 1px solid var(--color-border);
  background: none;
  text-align: left;
  font: inherit;
  cursor: pointer;
}
.item:hover {
  background: var(--color-surface-2);
}
.item.is-active {
  background: var(--status-info-bg);
}
.item small {
  color: var(--color-text-faint);
  font-size: var(--text-xs);
}
.mono {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
}
.muted {
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
.muted.is-error {
  color: var(--status-error);
}
.verb {
  align-self: flex-start;
  padding: 0 6px;
  border-radius: var(--radius-sm);
  font-family: var(--font-mono);
  font-size: var(--text-xs);
  font-weight: 700;
  background: var(--status-muted-bg);
  color: var(--status-muted);
}
.verb-GET {
  background: var(--status-info-bg);
  color: var(--status-info);
}
.verb-POST {
  background: var(--status-ok-bg);
  color: var(--status-ok);
}
.verb-PUT,
.verb-PATCH {
  background: var(--status-warn-bg);
  color: var(--status-warn);
}
.verb-DELETE {
  background: var(--status-error-bg);
  color: var(--status-error);
}
.row {
  display: flex;
  gap: var(--space-2);
}
.row .path {
  flex: 1;
}
.grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--space-2);
}
.field.wide {
  grid-column: 1 / -1;
}
textarea {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
  resize: vertical;
}
.response-meta {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}
.headers {
  display: grid;
  grid-template-columns: minmax(160px, auto) 1fr;
  gap: 2px var(--space-3);
  margin: 0;
}
.headers dt {
  color: var(--color-text-faint);
}
.headers dd {
  margin: 0;
  overflow-wrap: anywhere;
}
.body {
  max-height: 40vh;
  margin: 0;
  padding: var(--space-3);
  overflow: auto;
  border-radius: var(--radius);
  background: #0f172a;
  color: #e2e8f0;
  font-size: var(--text-sm);
}
</style>
