<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import MetricCard from '@/components/MetricCard.vue'
import { getDashboard, getSystemInfo } from '@/api/dashboard'
import { getSystemUsage, type SystemUsage } from '@/api/system'
import type { SystemInfo } from '@/types/system'

const loading = ref(true)
const error = ref<string | null>(null)
const info = ref<SystemInfo | null>(null)
const usage = ref<SystemUsage | null>(null)
const uptime = ref('—')
const processes = ref(0)
const licensePercent = ref(0)

const LINKS = [
  { to: '/system/cpu', label: 'CPU' },
  { to: '/system/memory', label: 'Memory' },
  { to: '/system/disk', label: 'Disk' },
  { to: '/system/processes', label: 'Processes' },
  { to: '/system/network', label: 'Network' },
  { to: '/system/devices', label: 'Devices' }
]

async function load() {
  loading.value = true
  try {
    const [systemInfo, systemUsage] = await Promise.all([getSystemInfo(), getSystemUsage()])
    info.value = systemInfo
    usage.value = systemUsage
    const dash = await getDashboard().catch(() => null)
    if (dash) {
      uptime.value = dash.Status.UpTime || '—'
      processes.value = dash.SystemUsage.Processes
      const limit = dash.Licensing.LicenseLimit
      licensePercent.value = limit ? Math.round((dash.Licensing.LicenseUse / limit) * 100) : 0
    }
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
      <h1>System</h1>
      <small>{{ info?.instanceName }} · uptime {{ uptime }}</small>
    </div>

    <p v-if="loading" class="state">Loading…</p>
    <p v-else-if="error" class="state is-error">Error: {{ error }}</p>

    <template v-else>
      <div class="metrics">
        <RouterLink class="plain" to="/system/processes">
          <MetricCard label="Processes" :value="processes" />
        </RouterLink>
        <RouterLink class="plain" to="/system">
          <MetricCard label="License used" :value="licensePercent" unit="%" />
        </RouterLink>
        <MetricCard label="Global references" :value="usage?.AllGlobalReferences ?? 0" />
        <MetricCard label="Logical block requests" :value="usage?.LogicalBlockRequests ?? 0" />
        <MetricCard label="Block reads" :value="usage?.BlockReads ?? 0" />
        <MetricCard label="Block writes" :value="usage?.BlockWrites ?? 0" />
        <MetricCard label="Routine calls" :value="usage?.RoutineCalls ?? 0" />
        <MetricCard label="Journal entries" :value="usage?.JournalEntries ?? 0" />
      </div>

      <div class="card panel">
        <dl class="facts">
          <dt>IRIS version</dt>
          <dd>{{ info?.version }}</dd>
          <dt>Namespace</dt>
          <dd>{{ info?.namespace }}</dd>
          <dt>Instance</dt>
          <dd>{{ info?.instanceName }}</dd>
          <dt>Server time</dt>
          <dd>{{ info?.serverTime }}</dd>
          <dt>Counters updated</dt>
          <dd>{{ usage?.LastUpdate || '—' }}</dd>
        </dl>
      </div>

      <nav class="links">
        <RouterLink v-for="link in LINKS" :key="link.to" class="chip" :to="link.to">{{ link.label }}</RouterLink>
      </nav>
    </template>
  </div>
</template>

<style scoped>
.metrics {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: var(--space-3);
}
.plain {
  display: block;
  height: 100%;
  color: inherit;
  text-decoration: none;
}
.plain :deep(.metric-card) {
  height: 100%;
}
.plain:hover {
  text-decoration: none;
}
.panel {
  padding: var(--space-4) var(--space-5);
}
.facts {
  display: grid;
  grid-template-columns: 180px 1fr;
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
.links {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}
.chip {
  padding: 3px 10px;
  border: 1px solid var(--color-border-strong);
  border-radius: 999px;
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  text-decoration: none;
}
.chip:hover {
  border-color: var(--color-primary);
  color: var(--color-primary);
  text-decoration: none;
}
.state.is-error {
  color: var(--status-error);
}
</style>
