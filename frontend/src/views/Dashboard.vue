<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, shallowRef } from 'vue'
import { RouterLink } from 'vue-router'
import * as echarts from 'echarts/core'
import { LineChart } from 'echarts/charts'
import { GridComponent, TooltipComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'
import EmptyState from '@/components/EmptyState.vue'
import MetricCard from '@/components/MetricCard.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import { getDashboard, getSystemInfo, type DashboardPayload } from '@/api/dashboard'
import { listTaskHistory, listTasks, runSucceeded, type IrisTask, type TaskRun } from '@/api/tasks'
import LogItem from '@/components/LogItem.vue'
import { listCertificates, listRoles, listSecrets, listUsers, listWallets } from '@/api/security'
import { getMemoryUsage, getProcesses } from '@/api/system'
import type { SystemInfo } from '@/types/system'

echarts.use([LineChart, GridComponent, TooltipComponent, CanvasRenderer])

const POLL_MS = 5000

const loading = ref(true)
const error = ref<string | null>(null)

const info = ref<SystemInfo | null>(null)
const dash = ref<DashboardPayload | null>(null)

const tasks = ref({ running: 0, scheduled: 0, failed: 0, completed: 0 })
const security = ref({ users: 0, roles: 0, certificates: 0, expiring: 0, secrets: 0 })
const cpuSeconds = ref(0)
const memoryUsed = ref(0)
const recentEvents = ref<{ id: string; time: string; severity: string; source: string; message: string }[]>([])

const chartEl = ref<HTMLElement | null>(null)
const chart = shallowRef<ReturnType<typeof echarts.init> | null>(null)
const samples = ref<{ time: string; value: number }[]>([])
let timer: ReturnType<typeof setInterval> | undefined

const status = computed(() => {
  const payload = dash.value
  if (!payload) return 'UNKNOWN'
  const subsystems = [
    payload.SystemUsage.DatabaseSpace,
    payload.SystemUsage.JournalSpace,
    payload.SystemUsage.LockTable,
    payload.SystemUsage.WriteDaemon
  ]
  const unhealthy = subsystems.filter((value) => value && value !== 'Normal').length
  if (unhealthy >= 2) return 'CRITICAL'
  if (unhealthy === 1) return 'DEGRADED'
  if (payload.Alerts.SeriousAlerts > 0) return 'WARNING'
  return 'HEALTHY'
})

const licensePercent = computed(() => {
  const licensing = dash.value?.Licensing
  if (!licensing || !licensing.LicenseLimit) return 0
  return Math.round((licensing.LicenseUse / licensing.LicenseLimit) * 100)
})

function countTasks(list: IrisTask[], runs: TaskRun[]) {
  const activeIds = new Set<number>()
  let failed = 0
  let completed = 0
  let running = 0
  for (const run of runs) {
    const result = (run.Result ?? '').toLowerCase()
    if (!run.Completed) running += 1
    else if (result.includes('success')) completed += 1
    else failed += 1
    if (run.TaskId !== undefined) activeIds.add(run.TaskId)
  }
  return {
    running,
    failed,
    completed,
    scheduled: list.filter((task) => !task.Suspended && task.NextScheduled).length
  }
}

async function loadResourceUsage() {
  const [processes, memory] = await Promise.all([getProcesses(), getMemoryUsage()])
  cpuSeconds.value = Math.round(processes.reduce((sum, item) => sum + Number(item.CPUTime || 0), 0))
  memoryUsed.value = memory.reduce((sum, row) => sum + Number(row.AllUsed || 0), 0)
}

async function loadTasks() {
  const [list, history] = await Promise.all([listTasks(), listTaskHistory()])
  tasks.value = countTasks(list, history)
  // Task runs are the richest event source this instance reports.
  recentEvents.value = history.slice(0, 6).map((run: TaskRun) => ({
    id: `${run.TaskId}-${run.Completed || run.LastStart}`,
    time: (run.Completed || run.LastStart || '').slice(11) || '—',
    severity: runSucceeded(run) ? 'SUCCESS' : 'FAILED',
    source: `Task #${run.TaskId}`,
    message: `${run.Name}: ${run.Result || ''}`
  }))
}

async function loadSecurity() {
  const [users, roles, certificates, wallets] = await Promise.all([
    listUsers(),
    listRoles(),
    listCertificates(),
    listWallets()
  ])
  let secrets = 0
  for (const wallet of wallets) {
    secrets += (await listSecrets(wallet.Name)).length
  }
  security.value = {
    users: users.length,
    roles: roles.length,
    certificates: certificates.length,
    expiring: 0,
    secrets
  }
}

function pushSample(value: number) {
  samples.value.push({ time: new Date().toLocaleTimeString(), value })
  if (samples.value.length > 180) samples.value.shift()
  renderChart()
}

/** The chart sits inside the block hidden while loading, so initialise it
 *  only after that block has rendered. */
function ensureChart() {
  if (chart.value || !chartEl.value) return
  chart.value = echarts.init(chartEl.value)
  renderChart()
}

function renderChart() {
  if (!chart.value) return
  chart.value.setOption({
    grid: { left: 52, right: 12, top: 16, bottom: 24 },
    tooltip: { trigger: 'axis' },
    xAxis: { type: 'category', boundaryGap: false, data: samples.value.map((s) => s.time) },
    yAxis: { type: 'value', name: 'refs/s' },
    series: [
      {
        type: 'line',
        name: 'Global references/s',
        smooth: true,
        showSymbol: false,
        areaStyle: { opacity: 0.12 },
        data: samples.value.map((s) => s.value)
      }
    ]
  })
}

async function refresh() {
  try {
    const payload = await getDashboard()
    dash.value = payload
    pushSample(payload.Performance.GlobalRefsPerSecond)
  } catch {
    /* a missed sample must not disturb the page */
  }
}

async function load() {
  loading.value = true
  error.value = null
  try {
    const [systemInfo, payload] = await Promise.all([getSystemInfo(), getDashboard()])
    info.value = systemInfo
    dash.value = payload
    pushSample(payload.Performance.GlobalRefsPerSecond)
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : String(cause)
    loading.value = false
    return
  }
  await Promise.allSettled([loadTasks(), loadSecurity(), loadResourceUsage()])
  loading.value = false
  await nextTick()
  ensureChart()
}

onMounted(() => {
  void load()
  timer = setInterval(() => void refresh(), POLL_MS)
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
  chart.value?.dispose()
  chart.value = null
})
</script>

<template>
  <div class="page">
    <p v-if="loading" class="state">Loading…</p>
    <p v-else-if="error" class="state is-error">Error: {{ error }}</p>

    <template v-else>
      <section class="section">
        <h2>System Status</h2>
        <div class="card status-card">
          <div class="status-head">
            <StatusBadge :status="status" />
            <RouterLink class="link" to="/system">System detail →</RouterLink>
          </div>
          <dl class="facts">
            <div><dt>IRIS Version</dt><dd>{{ info?.version }}</dd></div>
            <div><dt>Namespace</dt><dd>{{ info?.namespace }}</dd></div>
            <div><dt>Server</dt><dd>{{ info?.instanceName }}</dd></div>
            <div><dt>Uptime</dt><dd>{{ dash?.Status.UpTime || '—' }}</dd></div>
          </dl>
        </div>
      </section>

      <section class="section">
        <h2>System Metrics</h2>
        <div class="metrics">
          <RouterLink class="metric-link" to="/system/processes">
            <MetricCard label="Processes" :value="dash?.SystemUsage.Processes ?? 0" hint="→ processes" />
          </RouterLink>
          <RouterLink class="metric-link" to="/system/cpu">
            <MetricCard label="Process CPU time" :value="cpuSeconds" unit="s" hint="→ cpu" />
          </RouterLink>
          <RouterLink class="metric-link" to="/system/memory">
            <MetricCard label="Shared memory used" :value="memoryUsed" hint="→ memory" />
          </RouterLink>
          <RouterLink class="metric-link" to="/system/disk">
            <MetricCard
              label="Disk I/O"
              :value="(dash?.Performance.DiskReads ?? 0) + (dash?.Performance.DiskWrites ?? 0)"
              hint="reads + writes"
            />
          </RouterLink>
          <RouterLink class="metric-link" to="/system">
            <MetricCard label="Global refs/s" :value="dash?.Performance.GlobalRefsPerSecond ?? 0" />
          </RouterLink>
          <RouterLink class="metric-link" to="/system">
            <MetricCard label="Cache efficiency" :value="dash?.Performance.CacheEfficiency ?? 0" unit="%" />
          </RouterLink>
          <RouterLink class="metric-link" to="/system">
            <MetricCard label="License used" :value="licensePercent" unit="%" :hint="`limit ${dash?.Licensing.LicenseLimit ?? 0}`" />
          </RouterLink>
          <RouterLink class="metric-link" to="/system">
            <MetricCard label="CSP sessions" :value="dash?.SystemUsage.CSPSessions ?? 0" />
          </RouterLink>
        </div>
        <div class="card chart-card">
          <div class="chart-head">
            <span>Global references per second</span>
            <span class="chart-note">live, since this page opened (CPU / memory / disk trends arrive with System Monitoring)</span>
          </div>
          <div ref="chartEl" class="chart"></div>
        </div>
      </section>

      <div class="two-col">
        <section class="section">
          <h2>Task Summary</h2>
          <div class="card">
            <ul class="counts">
              <li><StatusBadge status="RUNNING" /><b>{{ tasks.running }}</b><span>Running</span></li>
              <li><StatusBadge status="INFO" /><b>{{ tasks.scheduled }}</b><span>Scheduled</span></li>
              <li><StatusBadge status="FAILED" /><b>{{ tasks.failed }}</b><span>Failed</span></li>
              <li><StatusBadge status="SUCCESS" /><b>{{ tasks.completed }}</b><span>Completed</span></li>
            </ul>
            <RouterLink class="link" to="/tasks">All tasks →</RouterLink>
          </div>
        </section>

        <section class="section">
          <h2>Security Summary</h2>
          <div class="card">
            <ul class="counts">
              <li><b>{{ security.certificates }}</b><span>Certificates</span></li>
              <li><b>{{ security.expiring }}</b><span>Expiring Soon</span></li>
              <li><b>{{ security.secrets }}</b><span>Secrets</span></li>
              <li><b>{{ dash?.Alerts.SeriousAlerts ?? 0 }}</b><span>Security Alerts</span></li>
            </ul>
            <RouterLink class="link" to="/security/users">Security →</RouterLink>
          </div>
        </section>
      </div>

      <section class="section">
        <h2>Recent Events</h2>
        <div class="card">
          <template v-if="recentEvents.length">
            <LogItem
              v-for="event in recentEvents"
              :key="event.id"
              :time="event.time"
              :status="event.severity"
              :source="event.source"
              :message="event.message"
            />
            <div class="center">
              <RouterLink class="link" to="/logs">All events and log sources →</RouterLink>
            </div>
          </template>
          <EmptyState
            v-else
            title="No events recorded yet"
            description="The log centre shows the sources this instance can report: task runs and audit records."
          />
        </div>
      </section>
    </template>
  </div>
</template>

<style scoped>
.section {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}
.section h2 {
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
}
.state {
  color: var(--color-text-muted);
}
.state.is-error {
  color: var(--status-error);
}
.status-card {
  padding: var(--space-4);
}
.status-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: var(--space-3);
}
.facts {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: var(--space-3);
  margin: 0;
}
.facts dt {
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
.facts dd {
  margin: 2px 0 0;
  font-family: var(--font-mono);
  font-size: var(--text-sm);
  overflow-wrap: anywhere;
}
.metrics {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: var(--space-3);
}
.metric-link {
  display: block;
  height: 100%;
  color: inherit;
  text-decoration: none;
}
.metric-link :deep(.metric-card) {
  height: 100%;
}
.metric-link:hover {
  text-decoration: none;
}
.metric-link:hover :deep(.metric-card) {
  border-color: var(--color-border-strong);
}
.chart-card {
  padding: var(--space-3) var(--space-4) var(--space-2);
}
.chart-head {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: var(--space-2);
  font-weight: 600;
}
.chart-note {
  color: var(--color-text-faint);
  font-size: var(--text-sm);
  font-weight: 400;
}
.chart {
  height: 220px;
}
.two-col {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
  gap: var(--space-5);
}
.counts {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--space-3);
  margin: 0;
  padding: var(--space-4);
  list-style: none;
}
.counts li {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.counts b {
  font-size: 20px;
  font-variant-numeric: tabular-nums;
}
.counts span {
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}
.link {
  display: inline-block;
  padding: var(--space-2) var(--space-4);
  font-size: var(--text-sm);
}
.center {
  text-align: center;
}
</style>
