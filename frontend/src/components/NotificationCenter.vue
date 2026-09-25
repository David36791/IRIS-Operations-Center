<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import StatusBadge from '@/components/StatusBadge.vue'
import { getDashboard } from '@/api/dashboard'
import { listCertificates } from '@/api/security'
import { listTaskHistory, listTasks, summarise, type TaskCategory } from '@/api/tasks'

interface Alert {
  id: string
  severity: string
  title: string
  detail: string
  to: string
}

const open = ref(false)
const loading = ref(true)
const alerts = ref<Alert[]>([])

const counts = computed(() => ({
  critical: alerts.value.filter((alert) => alert.severity === 'CRITICAL').length,
  warning: alerts.value.filter((alert) => alert.severity === 'WARNING').length,
  info: alerts.value.filter((alert) => alert.severity === 'INFO').length
}))

/** Certificate expiry bands. */
function expirySeverity(record: Record<string, unknown>): string | null {
  const entry = Object.entries(record).find(([key]) => /valid.*to|expires|expiry|notafter/i.test(key))
  if (!entry || !entry[1]) return null
  const when = Date.parse(String(entry[1]).replace(' ', 'T'))
  if (Number.isNaN(when)) return null
  const days = Math.floor((when - Date.now()) / 86400000)
  if (days < 0) return 'CRITICAL'
  if (days <= 7) return 'CRITICAL'
  if (days <= 30) return 'WARNING'
  return null
}

async function load() {
  loading.value = true
  const collected: Alert[] = []

  const [tasks, runs, certificates, dashboard] = await Promise.allSettled([
    listTasks(),
    listTaskHistory(),
    listCertificates(),
    getDashboard()
  ])

  if (tasks.status === 'fulfilled' && runs.status === 'fulfilled') {
    const rows = summarise(tasks.value, runs.value)
    for (const row of rows) {
      const category: TaskCategory = row.category
      if (category === 'failed') {
        collected.push({
          id: `task-${row.task.Id}`,
          severity: 'CRITICAL',
          title: `Task failed: ${row.task.Name}`,
          detail: row.run?.Result || '',
          to: `/tasks/detail/${row.task.Id}`
        })
      } else if (category === 'suspended') {
        collected.push({
          id: `task-${row.task.Id}`,
          severity: 'WARNING',
          title: `Task disabled: ${row.task.Name}`,
          detail: `${row.task.Type} · ${row.task.Namespace}`,
          to: `/tasks/detail/${row.task.Id}`
        })
      }
    }
  }

  if (certificates.status === 'fulfilled') {
    for (const certificate of certificates.value) {
      const record = certificate as unknown as Record<string, unknown>
      const severity = expirySeverity(record)
      if (!severity) continue
      collected.push({
        id: `cert-${String(record.Subject ?? record.Name ?? Math.random())}`,
        severity,
        title: 'Certificate expiring',
        detail: String(record.Subject ?? record.Alias ?? record.Name ?? ''),
        to: '/security/certificates'
      })
    }
  }

  if (dashboard.status === 'fulfilled') {
    const { Alerts } = dashboard.value
    if (Alerts.SeriousAlerts > 0) {
      collected.push({
        id: 'alerts-serious',
        severity: 'CRITICAL',
        title: `${Alerts.SeriousAlerts} serious system alert(s)`,
        detail: 'Reported by the instance system monitor',
        to: '/dashboard'
      })
    }
    if (Alerts.ApplicationErrors > 0) {
      collected.push({
        id: 'alerts-apperrors',
        severity: 'WARNING',
        title: `${Alerts.ApplicationErrors} application error(s)`,
        detail: 'Reported by the instance system monitor',
        to: '/dashboard'
      })
    }
  }

  alerts.value = collected
  loading.value = false
}

function toggle() {
  open.value = !open.value
  if (open.value) void load()
}

onMounted(load)
</script>

<template>
  <div class="center">
    <button class="bell" :title="`${alerts.length} notifications`" @click="toggle">
      Notifications
      <span v-if="alerts.length" class="count">{{ alerts.length }}</span>
    </button>

    <div v-if="open" class="panel card">
      <div class="panel-head">
        <h2>Notifications</h2>
        <button class="btn btn-quiet" @click="open = false">Close</button>
      </div>

      <p v-if="loading" class="muted">Loading…</p>
      <template v-else>
        <p class="bands">
          <span>Critical {{ counts.critical }}</span>
          <span>Warning {{ counts.warning }}</span>
          <span>Info {{ counts.info }}</span>
        </p>
        <ul v-if="alerts.length" class="list">
          <li v-for="alert in alerts" :key="alert.id">
            <RouterLink :to="alert.to" class="item" @click="open = false">
              <StatusBadge :status="alert.severity" />
              <span class="body">
                <span class="title">{{ alert.title }}</span>
                <span v-if="alert.detail" class="detail">{{ alert.detail }}</span>
              </span>
            </RouterLink>
          </li>
        </ul>
        <p v-else class="muted">
          Nothing needs attention. Alerts are derived from what this instance reports: failed or disabled tasks,
          certificates near expiry, and the system monitor's own counters.
        </p>
      </template>
    </div>
  </div>
</template>

<style scoped>
.center {
  position: relative;
}
.bell {
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
  padding: 6px 12px;
  border: 1px solid transparent;
  border-radius: var(--radius-sm);
  background: transparent;
  color: var(--color-text-muted);
  font: inherit;
  font-size: var(--text-md);
  cursor: pointer;
}
.bell:hover {
  background: rgba(20, 26, 38, 0.06);
}
.count {
  padding: 0 6px;
  border-radius: 999px;
  background: var(--status-error-bg);
  color: var(--status-error);
  font-size: var(--text-sm);
  font-weight: 700;
}
.panel {
  position: absolute;
  top: calc(100% + 6px);
  right: 0;
  z-index: 40;
  width: min(420px, 90vw);
  padding: var(--space-3) var(--space-4);
  box-shadow: var(--shadow-md);
}
.panel-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.panel-head h2 {
  font-size: var(--text-md);
}
.bands {
  display: flex;
  gap: var(--space-3);
  margin: var(--space-2) 0;
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}
.list {
  max-height: 320px;
  margin: 0;
  padding: 0;
  overflow-y: auto;
  list-style: none;
}
.item {
  display: flex;
  gap: var(--space-2);
  padding: var(--space-2) 0;
  border-top: 1px solid var(--color-border);
  color: inherit;
  text-decoration: none;
}
.item:hover {
  text-decoration: none;
}
.body {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.title {
  font-weight: 600;
}
.detail {
  color: var(--color-text-faint);
  font-size: var(--text-sm);
  overflow-wrap: anywhere;
}
.muted {
  margin: var(--space-2) 0 0;
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
</style>
