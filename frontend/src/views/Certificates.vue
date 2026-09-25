<script setup lang="ts">
import { onMounted, ref } from 'vue'
import AppTable from '@/components/AppTable.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import { listCertificates, type X509Credential } from '@/api/security'
import type { Column } from '@/types/ui'

const columns: Column[] = [
  { key: 'Subject', label: 'Subject' },
  { key: 'Issuer', label: 'Issuer' },
  { key: 'ValidFrom', label: 'Valid from' },
  { key: 'ValidTo', label: 'Valid to' },
  { key: 'days', label: 'Days remaining', align: 'right' },
  { key: 'status', label: 'Status' }
]

const loading = ref(true)
const error = ref<string | null>(null)
const rows = ref<Record<string, unknown>[]>([])

/** Expiry bands: >30 Healthy · 8-30 Warning · 1-7 Critical · <1 or expired Error. */
function expiry(record: Record<string, unknown>) {
  const entry = Object.entries(record).find(([key]) => /valid.*to|expires|expiry|notafter/i.test(key))
  if (!entry || !entry[1]) return { days: null as number | null, status: 'UNKNOWN' }
  const when = Date.parse(String(entry[1]).replace(' ', 'T'))
  if (Number.isNaN(when)) return { days: null, status: 'UNKNOWN' }
  const days = Math.floor((when - Date.now()) / 86400000)
  if (days < 0) return { days, status: 'EXPIRED' as const }
  if (days <= 7) return { days, status: 'CRITICAL' as const }
  if (days <= 30) return { days, status: 'WARNING' as const }
  return { days, status: 'HEALTHY' as const }
}

function pick(record: Record<string, unknown>, pattern: RegExp): string {
  const entry = Object.entries(record).find(([key]) => pattern.test(key))
  return entry && entry[1] ? String(entry[1]) : '—'
}

const view = (list: X509Credential[]) =>
  list.map((credential) => {
    const record = credential as unknown as Record<string, unknown>
    const { days, status } = expiry(record)
    return {
      Subject: pick(record, /subject|common.*name|cn$/i),
      Issuer: pick(record, /issuer/i),
      ValidFrom: pick(record, /valid.*from|notbefore/i),
      ValidTo: pick(record, /valid.*to|expires|notafter/i),
      days: days === null ? '—' : String(days),
      status,
      raw: record
    }
  })

async function load() {
  loading.value = true
  try {
    const list = await listCertificates()
    rows.value = view(list) as unknown as Record<string, unknown>[]
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
      <h1>Certificates</h1>
      <small>X.509 credentials</small>
    </div>

    <p v-if="error" class="state is-error">Error: {{ error }}</p>

    <AppTable
      :columns="columns"
      :rows="rows"
      row-key="Subject"
      :loading="loading"
      empty-title="No X.509 credentials are configured"
      empty-description="Credentials are imported into the instance's PKI (System Administration → Security → X.509 Credentials). When one is added it shows here with the days remaining and an expiry status."
    >
      <template #cell="{ column, value }">
        <StatusBadge v-if="column.key === 'status'" :status="String(value)" />
        <span v-else-if="column.key === 'Subject' || column.key === 'Issuer'" class="mono">{{ value }}</span>
        <template v-else>{{ value }}</template>
      </template>
    </AppTable>

    <p class="note">
      Status follows the project's expiry bands: over 30 days healthy, 8–30 warning, 7 or fewer critical, and expired
      is an error. This instance currently has no X.509 credentials, so the table is empty.
    </p>
  </div>
</template>

<style scoped>
.mono {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
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
