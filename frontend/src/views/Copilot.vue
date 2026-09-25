<script setup lang="ts">
import { onMounted, ref } from 'vue'
import StatusBadge from '@/components/StatusBadge.vue'
import { askCopilot, getCopilotStatus, type CopilotStatus } from '@/api/copilot'
import { getDashboard, getSystemInfo } from '@/api/dashboard'
import { listCertificates } from '@/api/security'
import { listTaskHistory, listTasks } from '@/api/tasks'

interface Suggestion {
  label: string
  question: string
  build: () => Promise<Record<string, unknown>>
}

/** The seeded questions, each gathering what the instance reports. */
const SUGGESTIONS: Suggestion[] = [
  {
    label: 'Explain System Status',
    question: 'Explain the current system status of this IRIS instance.',
    build: async () => ({ system: await getSystemInfo(), dashboard: await getDashboard() })
  },
  {
    label: 'Summarize Logs',
    question: 'Summarize recent task activity and point out anything unusual.',
    build: async () => ({ taskRuns: (await listTaskHistory()).slice(0, 40) })
  },
  {
    label: 'Analyze Failed Task',
    question: 'Analyse the tasks in a non-normal state and explain what to look at.',
    build: async () => {
      const [tasks, runs] = await Promise.all([listTasks(), listTaskHistory()])
      return {
        tasks: tasks.filter((task) => task.Suspended),
        failedRuns: runs.filter((run) => String(run.Status) !== '1' || Number(run.ErrNumber ?? 0) !== 0)
      }
    }
  },
  {
    label: 'Explain Certificate Warning',
    question: 'Explain the state of the X.509 credentials, including expiry.',
    build: async () => ({ certificates: await listCertificates() })
  },
  {
    label: 'Find Related Events',
    question: 'Group the most recent events and suggest likely relationships.',
    build: async () => ({ recentRuns: (await listTaskHistory()).slice(0, 20) })
  },
  {
    label: 'Explain Error',
    question: 'Explain the errors this instance is reporting and what they mean.',
    build: async () => ({ dashboard: await getDashboard() })
  }
]

const loading = ref(true)
const busy = ref(false)
const error = ref<string | null>(null)
const status = ref<CopilotStatus | null>(null)
const question = ref('')
const answer = ref('')
const usedContext = ref('')
const asked = ref('')

async function ask(prompt: string, build?: () => Promise<Record<string, unknown>>) {
  busy.value = true
  error.value = null
  answer.value = ''
  asked.value = prompt
  try {
    const context = build ? await build() : undefined
    usedContext.value = context ? JSON.stringify(context).slice(0, 400) : ''
    const result = await askCopilot(prompt, context)
    answer.value = result.answer
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : String(cause)
  } finally {
    busy.value = false
  }
}

onMounted(async () => {
  try {
    status.value = await getCopilotStatus()
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : String(cause)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <h1>IRIS Copilot</h1>
      <StatusBadge v-if="status" :status="status.configured ? 'HEALTHY' : 'DISABLED'" />
    </div>

    <p v-if="loading" class="state">Loading…</p>

    <template v-else>
      <div class="card panel">
        <dl class="facts">
          <dt>Enabled</dt>
          <dd>{{ status?.enabled ? 'yes' : 'no' }}</dd>
          <dt>Configured</dt>
          <dd>{{ status?.configured ? 'yes' : 'no' }}</dd>
          <dt>Base URL</dt>
          <dd>{{ status?.baseUrl || '—' }}</dd>
          <dt>Model</dt>
          <dd>{{ status?.model || '—' }}</dd>
          <dt>Mode</dt>
          <dd>read-only</dd>
        </dl>
        <p v-if="!status?.enabled" class="muted">
          Set IOC_AI_ENABLED=true together with IOC_AI_BASE_URL and IOC_AI_MODEL (and IOC_AI_API_KEY if the endpoint
          needs one) to point the copilot at any OpenAI-compatible endpoint. With AI disabled the questions below
          will report that it is switched off.
        </p>
      </div>

      <div class="card panel">
        <h2>Suggested questions</h2>
        <div class="suggestions">
          <button v-for="suggestion in SUGGESTIONS" :key="suggestion.label" class="chip" :disabled="busy" @click="ask(suggestion.question, suggestion.build)">
            {{ suggestion.label }}
          </button>
        </div>
      </div>

      <div class="card panel">
        <h2>Ask</h2>
        <textarea v-model="question" rows="3" placeholder="Ask about what this instance reports…" />
        <div class="actions">
          <button class="btn btn-primary" :disabled="busy || !question.trim()" @click="ask(question)">
            {{ busy ? 'Asking…' : 'Ask' }}
          </button>
        </div>
        <p v-if="error" class="state is-error">{{ error }}</p>
        <div v-if="answer" class="answer">
          <h3>{{ asked }}</h3>
          <pre>{{ answer }}</pre>
          <details v-if="usedContext">
            <summary>Instance data sent as context</summary>
            <pre class="context">{{ usedContext }}</pre>
          </details>
        </div>
      </div>

      <p class="note">
        The copilot is read-only: it cannot delete, restart, terminate, reveal secrets or change security. Those
        operations only happen through their page, with the proposal → confirmation → permission check → execution →
        audit flow that page already implements.
      </p>
    </template>
  </div>
</template>

<style scoped>
.panel {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
  padding: var(--space-4) var(--space-5);
}
.panel h2,
.answer h3 {
  margin: 0;
  font-size: var(--text-md);
}
.facts {
  display: grid;
  grid-template-columns: 140px 1fr;
  gap: var(--space-2) var(--space-4);
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
.suggestions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}
.chip {
  padding: 4px 12px;
  border: 1px solid var(--color-border-strong);
  border-radius: 999px;
  background: var(--color-surface);
  color: var(--color-text);
  font: inherit;
  font-size: var(--text-sm);
  cursor: pointer;
}
.chip:hover:not(:disabled) {
  border-color: var(--color-primary);
  color: var(--color-primary);
}
.chip:disabled {
  color: var(--color-text-faint);
  cursor: default;
}
textarea {
  width: 100%;
  font-family: var(--font-mono);
  font-size: var(--text-sm);
  resize: vertical;
}
.actions {
  display: flex;
  justify-content: flex-end;
}
.answer pre {
  margin: var(--space-2) 0 0;
  padding: var(--space-3);
  border-radius: var(--radius);
  background: #0f172a;
  color: #e2e8f0;
  font-size: var(--text-sm);
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
.answer .context {
  max-height: 200px;
  overflow: auto;
  background: var(--color-surface-2);
  color: var(--color-text-muted);
}
.answer details {
  margin-top: var(--space-2);
}
.muted,
.note {
  margin: 0;
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
.state.is-error {
  color: var(--status-error);
}
</style>
