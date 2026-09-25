<script setup lang="ts">
defineProps<{
  open: boolean
  title: string
  message?: string
  confirmLabel?: string
  cancelLabel?: string
  danger?: boolean
  busy?: boolean
}>()

const emit = defineEmits<{
  (e: 'confirm'): void
  (e: 'cancel'): void
}>()
</script>

<template>
  <div v-if="open" class="overlay" @click.self="emit('cancel')">
    <div class="dialog card" role="dialog" aria-modal="true">
      <h2>{{ title }}</h2>
      <p v-if="message" class="dialog-message">{{ message }}</p>
      <slot />
      <div class="dialog-actions">
        <button class="btn" @click="emit('cancel')">{{ cancelLabel ?? 'Cancel' }}</button>
        <button
          class="btn"
          :class="danger ? 'btn-danger' : 'btn-primary'"
          :disabled="busy"
          @click="emit('confirm')"
        >
          {{ confirmLabel ?? 'Confirm' }}
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.overlay {
  position: fixed;
  inset: 0;
  z-index: 50;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(20, 26, 38, 0.4);
}
.dialog {
  width: min(440px, calc(100vw - 32px));
  padding: var(--space-5);
  box-shadow: var(--shadow-md);
}
.dialog-message {
  margin: var(--space-3) 0 0;
  color: var(--color-text-muted);
}
.dialog-actions {
  display: flex;
  justify-content: flex-end;
  gap: var(--space-2);
  margin-top: var(--space-5);
}
</style>
