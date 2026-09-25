<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, shallowRef } from 'vue'
import * as echarts from 'echarts/core'
import { LineChart } from 'echarts/charts'
import { GridComponent, TooltipComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'
import AppTable from '@/components/AppTable.vue'
import MetricCard from '@/components/MetricCard.vue'
import { getProcesses, type IrisProcess } from '@/api/system'
import type { Column } from '@/types/ui'

echarts.use([LineChart, GridComponent, TooltipComponent, CanvasRenderer])

const POLL_MS = 5000

const loading = ref(true)
const error = ref<string | null>(null)
const processes = ref<IrisProcess[]>([])
const samples = ref<{ time: string; value: number }[]>([])
const chartEl = ref<HTMLElement | null>(null)
const chart = shallowRef<ReturnType<typeof echarts.init> | null>(null)
let timer: ReturnType<typeof setInterval> | undefined
let previousTotal: number | null = null

const columns: Column[] = [
  { key: 'Pid', label: 'PID', align: 'right' },
  { key: 'Routine', label: 'Routine' },
  { key: 'Username', label: 'User' },
  { key: 'CPUTime', label: 'CPU (s)', align: 'right' },
  { key: 'ElapsedTime', label: 'Elapsed (s)', align: 'right' }
]

/** Total CPU seconds consumed by every process, as reported right now. */
function totalCpu(list: IrisProcess[]): number {
  return list.reduce((sum, item) => sum + Number(item.CPUTime || 0), 0)
}

const current = computed(() => {
  const last = samples.value.length ? samples.value[samples.value.length - 1] : null
  return last ? last.value : 0
})
/** A line needs two readings; until then the chart has nothing to draw. */
const chartReady = computed(() => samples.value.length >= 2)
const average = computed(() =>
  samples.value.length ? samples.value.reduce((sum, item) => sum + item.value, 0) / samples.value.length : 0
)
const peak = computed(() => samples.value.reduce((max, item) => Math.max(max, item.value), 0))
const top = computed(() =>
  [...processes.value].sort((a, b) => Number(b.CPUTime || 0) - Number(a.CPUTime || 0)).slice(0, 10)
)

function renderChart() {
  if (!chart.value) return
  chart.value.setOption({
    grid: { left: 56, right: 12, top: 16, bottom: 24 },
    tooltip: { trigger: 'axis' },
    xAxis: { type: 'category', boundaryGap: false, data: samples.value.map((s) => s.time) },
    yAxis: { type: 'value', name: 'CPU s/interval' },
    series: [
      {
        type: 'line',
        name: 'CPU consumed per interval',
        smooth: true,
        showSymbol: false,
        areaStyle: { opacity: 0.12 },
        data: samples.value.map((s) => s.value)
      }
    ]
  })
}

/**
 * The chart lives inside the block that is hidden while loading, so it can only
 * be initialised once that block has actually rendered.
 */
function ensureChart() {
  if (chart.value || !chartEl.value) return
  chart.value = echarts.init(chartEl.value)
  renderChart()
}

async function poll() {
  try {
    const list = await getProcesses()
    processes.value = list
    const total = totalCpu(list)
    if (previousTotal !== null) {
      const delta = Math.max(0, total - previousTotal)
      samples.value.push({ time: new Date().toLocaleTimeString(), value: Number(delta.toFixed(2)) })
      if (samples.value.length > 180) samples.value.shift()
      renderChart()
    }
    previousTotal = total
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : String(cause)
  } finally {
    loading.value = false
  }
  await nextTick()
  ensureChart()
}

onMounted(() => {
  void poll()
  timer = setInterval(() => void poll(), POLL_MS)
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
  chart.value?.dispose()
  chart.value = null
})
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <h1>CPU</h1>
      <small>IRIS process CPU, sampled every 5 s while this page is open</small>
    </div>

    <p v-if="loading" class="state">Loading…</p>
    <p v-else-if="error" class="state is-error">Error: {{ error }}</p>

    <template v-else>
      <div class="metrics">
        <MetricCard label="Current" :value="current" unit="s" hint="since the previous sample" />
        <MetricCard label="Average" :value="average.toFixed(2)" unit="s" hint="this session" />
        <MetricCard label="Peak" :value="peak" unit="s" hint="this session" />
        <MetricCard label="Processes" :value="processes.length" />
      </div>

      <div class="card chart-card">
        <div class="chart-head">
          <span>CPU consumed per interval</span>
          <span class="chart-note">
            IRIS reports per-process CPU time rather than a host CPU percentage, so each point is the CPU seconds all
            processes used since the previous reading.
          </span>
        </div>
        <div ref="chartEl" class="chart"></div>
        <p v-if="!chartReady" class="chart-empty">
          Collecting readings — the line appears once a second reading arrives, about 5 seconds from now. The totals
          above and the processes below are already live.
        </p>
      </div>

      <AppTable :columns="columns" :rows="top as unknown as Record<string, unknown>[]" row-key="Pid" empty-title="No processes">
        <template #cell="{ column, value }">
          <template v-if="column.key === 'Pid'">#{{ value }}</template>
          <template v-else>{{ value ?? '' }}</template>
        </template>
      </AppTable>
    </template>
  </div>
</template>

<style scoped>
.metrics {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: var(--space-3);
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
.chart-empty {
  margin: 0;
  padding: 0 var(--space-4) var(--space-3);
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
.state.is-error {
  color: var(--status-error);
}
</style>
