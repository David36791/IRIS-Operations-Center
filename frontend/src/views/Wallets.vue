<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import AppTable from '@/components/AppTable.vue'
import { listWallets, type WalletCollection } from '@/api/security'
import type { Column } from '@/types/ui'

const columns: Column[] = [
  { key: 'Name', label: 'Wallet' },
  { key: 'secrets', label: 'Secrets', align: 'right' },
  { key: 'actions', label: 'Actions', align: 'right' }
]

const loading = ref(true)
const error = ref<string | null>(null)
const rows = ref<Record<string, unknown>[]>([])

async function load() {
  loading.value = true
  try {
    const wallets = await listWallets()
    rows.value = wallets.map((wallet: WalletCollection) => ({
      Name: wallet.Name,
      secrets: '—'
    }))
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
      <h1>Wallets</h1>
      <small>Secret collections</small>
    </div>

    <p v-if="error" class="state is-error">Error: {{ error }}</p>

    <AppTable
      :columns="columns"
      :rows="rows"
      row-key="Name"
      :loading="loading"
      empty-title="No wallet collections are configured"
      empty-description="A wallet is created on the instance, for example under System Administration → Security → Wallets. This instance has none, so there is nothing to list."
    >
      <template #cell="{ column, value }">
        <RouterLink v-if="column.key === 'actions'" to="/security/secrets">Secrets</RouterLink>
        <span v-else-if="column.key === 'Name'" class="mono">{{ value }}</span>
        <template v-else>{{ value }}</template>
      </template>
    </AppTable>

    <p class="note">
      Wallet contents are read through the Secrets page, which masks every value until it is explicitly revealed.
      This instance currently has no wallet collections.
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
