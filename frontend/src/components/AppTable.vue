<script setup lang="ts">
import EmptyState from './EmptyState.vue'
import type { Column } from '@/types/ui'

defineProps<{
  columns: Column[]
  rows: Record<string, unknown>[]
  rowKey?: string
  loading?: boolean
  emptyTitle?: string
  /** Shown under the empty title, to say why there is nothing and how to get some. */
  emptyDescription?: string
}>()

defineSlots<{
  cell?(props: { row: Record<string, unknown>; column: Column; value: unknown }): unknown
}>()
</script>

<template>
  <div class="table-wrap card">
    <table class="app-table">
      <thead>
        <tr>
          <th
            v-for="column in columns"
            :key="column.key"
            :style="{ textAlign: column.align ?? 'left', width: column.width }"
          >
            {{ column.label }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="loading">
          <td :colspan="columns.length" class="table-state">Loading…</td>
        </tr>
        <tr v-else-if="rows.length === 0">
          <td :colspan="columns.length" class="table-state">
            <EmptyState :title="emptyTitle ?? 'No data'" :description="emptyDescription" />
          </td>
        </tr>
        <template v-else>
          <tr v-for="(row, index) in rows" :key="rowKey ? String(row[rowKey]) : index">
            <td
              v-for="column in columns"
              :key="column.key"
              :style="{ textAlign: column.align ?? 'left' }"
            >
              <slot name="cell" :row="row" :column="column" :value="row[column.key]">
                {{ row[column.key] }}
              </slot>
            </td>
          </tr>
        </template>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
.table-wrap {
  overflow-x: auto;
}
.app-table {
  width: 100%;
  border-collapse: collapse;
}
.app-table th {
  padding: var(--space-2) var(--space-4);
  border-bottom: 1px solid var(--color-border-strong);
  background: var(--color-surface-2);
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  font-weight: 600;
  white-space: nowrap;
}
.app-table td {
  padding: var(--space-2) var(--space-4);
  border-bottom: 1px solid var(--color-border);
  vertical-align: top;
}
.app-table tbody tr:last-child td {
  border-bottom: 0;
}
.app-table tbody tr:hover td {
  background: var(--color-surface-2);
}
.table-state {
  color: var(--color-text-muted);
  text-align: center;
}
</style>
