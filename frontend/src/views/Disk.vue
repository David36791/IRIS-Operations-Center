<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import AppTable from '@/components/AppTable.vue'
import MetricCard from '@/components/MetricCard.vue'
import { getDiskUsage, type DiskRow } from '@/api/system'
import type { Column } from '@/types/ui'

const loading = ref(true)
const error = ref<string | null>(null)
const rows = ref<DiskRow[]>([])

const columns: Column[] = [
  { key: 'Directory', label: 'Mount' },
  { key: 'databases', label: 'Databases' },
  { key: 'total', label: 'Total', align: 'right' },
  { key: 'used', label: 'Used', align: 'right' },
  { key: 'available', label: 'Available', align: 'right' },
  { key: 'usage', label: 'Usage', align: 'right' }
]

/** No rows means the source could not be read, not that nothing is used. */
const hasData = computed(() => rows.value.length > 0)

function names(row: DiskRow): string[] {
  return row.databases ? row.databases.split(', ') : []
}

/** Each database is named on exactly one directory, so this counts them all. */
const databaseCount = computed(() => rows.value.reduce((sum, row) => sum + names(row).length, 0))

/** The fullest volume, which is the one worth calling out. */
const fullest = computed(() => rows.value.reduce((worst, row) => (row.usage > worst.usage ? row : worst), rows.value[0]))

/** The metrics report megabytes; a whole volume reads better in gigabytes. */
function parts(megabytes: number): { value: string; unit: string } {
  return megabytes >= 1024
    ? { value: (megabytes / 1024).toFixed(1), unit: 'GB' }
    : { value: megabytes.toFixed(1), unit: 'MB' }
}

function size(megabytes: number): string {
  const { value, unit } = parts(megabytes)
  return `${value} ${unit}`
}

const freeSpace = computed(() => parts(hasData.value ? fullest.value.available : 0))

async function load() {
  loading.value = true
  try {
    rows.value = await getDiskUsage()
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
      <h1>Disk</h1>
      <small>Capacity of the volume behind each database directory</small>
    </div>

    <p v-if="loading" class="state">Loading…</p>
    <p v-else-if="error" class="state is-error">Error: {{ error }}</p>

    <template v-else>
      <div class="metrics">
        <MetricCard label="Databases" :value="hasData ? databaseCount : '—'" :hint="hasData ? '' : 'not readable'" />
        <MetricCard label="Mount points" :value="hasData ? rows.length : '—'" />
        <MetricCard
          label="Volume in use"
          :value="hasData ? fullest.usage.toFixed(1) : '—'"
          :unit="hasData ? '%' : ''"
          :hint="hasData ? fullest.Directory : ''"
        />
        <MetricCard
          label="Volume available"
          :value="hasData ? freeSpace.value : '—'"
          :unit="hasData ? freeSpace.unit : ''"
          :hint="hasData ? 'free on the fullest volume' : ''"
        />
      </div>

      <AppTable
        :columns="columns"
        :rows="rows as unknown as Record<string, unknown>[]"
        row-key="Directory"
        empty-title="No database directories reported"
        empty-description="The instance's system metrics answered, but listed no database directories."
      >
        <template #cell="{ row, column, value }">
          <template v-if="column.key === 'Directory' || column.key === 'databases'">{{ value || '—' }}</template>
          <template v-else-if="!row.measured">—</template>
          <template v-else-if="column.key === 'usage'">
            <span class="usage">
              <span class="bar"><span class="fill" :style="{ width: `${Math.min(100, Number(value || 0))}%` }" /></span>
              {{ Number(value || 0).toFixed(1) }}%
            </span>
          </template>
          <template v-else>{{ size(Number(value || 0)) }}</template>
        </template>
      </AppTable>

      <p v-if="hasData" class="note">
        Total, used and available are the storage volume's, from the instance's own system metrics. IRIS reports the
        volume each database directory sits on rather than that directory's footprint, so directories sharing a volume
        repeat the figures, and the volume size is derived from the free space and the percentage used — the two
        figures IRIS publishes. A directory the storage sensor does not reach shows — instead of a zero.
      </p>
    </template>
  </div>
</template>

<style scoped>
.metrics {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: var(--space-3);
}
.usage {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  font-variant-numeric: tabular-nums;
}
.bar {
  display: inline-block;
  width: 90px;
  height: 6px;
  border-radius: 3px;
  background: var(--status-muted-bg);
  overflow: hidden;
}
.fill {
  display: block;
  height: 100%;
  background: var(--status-info);
}
.state.is-error {
  color: var(--status-error);
}
</style>
