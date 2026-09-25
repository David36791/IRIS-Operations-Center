<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import AppTable from '@/components/AppTable.vue'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import { listSecrets, listWallets, type WalletSecret } from '@/api/security'
import type { Column } from '@/types/ui'

const MASK = '************'

const columns: Column[] = [
  { key: 'Name', label: 'Secret' },
  { key: 'collection', label: 'Wallet' },
  { key: 'value', label: 'Value' },
  { key: 'actions', label: 'Actions', align: 'right' }
]

const loading = ref(true)
const error = ref<string | null>(null)
const rows = ref<Record<string, unknown>[]>([])
const revealing = ref<Record<string, unknown> | null>(null)

/** Revealed values live in this map only — nothing is persisted anywhere. */
const revealed = ref<Record<string, string>>({})

const columnsWithValue = computed(() => columns)

async function load() {
  loading.value = true
  try {
    const wallets = await listWallets()
    const collected: Record<string, unknown>[] = []
    for (const wallet of wallets) {
      const secrets = await listSecrets(wallet.Name).catch(() => [] as WalletSecret[])
      for (const secret of secrets) {
        const record = secret as unknown as Record<string, unknown>
        collected.push({
          Name: String(record.Name ?? '—'),
          collection: wallet.Name,
          value: String(record.Value ?? record.Secret ?? ''),
          raw: record
        })
      }
    }
    rows.value = collected
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : String(cause)
  } finally {
    loading.value = false
  }
}

function valueFor(row: Record<string, unknown>): string {
  const key = `${row.collection}/${row.Name}`
  return revealed.value[key] ?? MASK
}

function confirmReveal() {
  const target = revealing.value
  if (!target) return
  const key = `${target.collection}/${target.Name}`
  revealed.value = { ...revealed.value, [key]: String(target.value || '(empty)') }
  revealing.value = null
}

onMounted(load)
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <h1>Secrets</h1>
      <small>Values are masked until revealed for the current view only</small>
    </div>

    <p v-if="error" class="state is-error">Error: {{ error }}</p>

    <AppTable
      :columns="columnsWithValue"
      :rows="rows"
      row-key="Name"
      :loading="loading"
      empty-title="No secrets are configured"
      empty-description="Secrets live in wallet collections on the instance. Once a wallet holds secrets they appear here, masked until you reveal them."
    >
      <template #cell="{ column, row, value }">
        <span v-if="column.key === 'value'" class="mono">{{ valueFor(row) }}</span>
        <span v-else-if="column.key === 'actions'">
          <button class="link-button" @click="revealing = row">Reveal</button>
        </span>
        <span v-else-if="column.key === 'Name' || column.key === 'collection'" class="mono">{{ value }}</span>
        <template v-else>{{ value }}</template>
      </template>
    </AppTable>

    <p class="note">
      Secrets are never displayed by default. Revealing happens through a confirmation, is held in memory only for
      this view, and is never written to storage. This instance has no wallet collections, so there is nothing to
      list.
    </p>

    <ConfirmDialog
      :open="revealing !== null"
      title="Reveal secret"
      :message="`Show the value of ${revealing?.Name} from wallet ${revealing?.collection}? It will be displayed until you leave this page.`"
      confirm-label="Reveal"
      danger
      @confirm="confirmReveal"
      @cancel="revealing = null"
    />
  </div>
</template>

<style scoped>
.mono {
  font-family: var(--font-mono);
  font-size: var(--text-sm);
  overflow-wrap: anywhere;
}
.note {
  margin: 0;
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
.link-button {
  padding: 0;
  border: 0;
  background: none;
  color: var(--color-primary);
  font: inherit;
  cursor: pointer;
}
.state.is-error {
  color: var(--status-error);
}
</style>
