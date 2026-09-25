<script setup lang="ts">
import { ref, watch } from 'vue'

const AUTH_BITS: [number, string][] = [
  [4, 'Kerberos'],
  [16, 'Delegated'],
  [32, 'Password'],
  [64, 'Unauthenticated']
]

const SERVE_FILES = ['Always', 'Always and cached', 'Use CSP Security', 'No']

const props = defineProps<{
  open: boolean
  mode: 'create' | 'edit'
  initial: Record<string, unknown> | null
  busy: boolean
}>()

const emit = defineEmits<{
  (e: 'save', definition: Record<string, unknown>): void
  (e: 'cancel'): void
}>()

const name = ref('')
const description = ref('')
const namespace = ref('USER')
const path = ref('')
const dispatchClass = ref('')
const enabled = ref(true)
const recurse = ref(false)
const serveFiles = ref('Always')
const timeout = ref(900)
const bits = ref<number[]>([64])

watch(
  () => props.open,
  (isOpen) => {
    if (!isOpen) return
    const source = props.initial ?? {}
    name.value = String(source.Name ?? '')
    description.value = String(source.Description ?? '')
    namespace.value = String(source.NameSpace ?? 'USER')
    path.value = String(source.Path ?? '')
    dispatchClass.value = String(source.DispatchClass ?? '')
    enabled.value = source.Enabled === undefined ? true : Boolean(source.Enabled)
    recurse.value = Boolean(source.Recurse ?? false)
    serveFiles.value = String(source.ServeFiles ?? 'Always')
    timeout.value = Number(source.Timeout ?? 900)
    const authe = Number(source.AutheEnabled ?? 64)
    bits.value = AUTH_BITS.filter(([bit]) => authe & bit).map(([bit]) => bit)
  }
)

function toggleBit(bit: number, checked: boolean) {
  bits.value = checked ? [...bits.value, bit] : bits.value.filter((value) => value !== bit)
}

function save() {
  // Start from the definition we read, so fields this form does not expose keep
  // their values: the management API resets anything it is not sent.
  const definition: Record<string, unknown> = { ...(props.initial ?? {}) }
  definition.Name = name.value
  definition.NameSpace = namespace.value
  definition.Description = description.value
  definition.Path = path.value
  definition.DispatchClass = dispatchClass.value
  definition.Enabled = enabled.value
  definition.Recurse = recurse.value
  definition.ServeFiles = serveFiles.value
  definition.Timeout = timeout.value
  definition.AutheEnabled = bits.value.reduce((sum, bit) => sum + bit, 0)
  emit('save', definition)
}
</script>

<template>
  <div v-if="open" class="overlay" @click.self="emit('cancel')">
    <div class="dialog card" role="dialog" aria-modal="true">
      <h2>{{ mode === 'create' ? 'New application' : `Edit ${name}` }}</h2>

      <div class="grid">
        <label class="field">
          <span>Name (path)</span>
          <input v-model="name" :readonly="mode === 'edit'" placeholder="/my-app" />
        </label>
        <label class="field">
          <span>Namespace</span>
          <input v-model="namespace" />
        </label>
        <label class="field wide">
          <span>Description</span>
          <input v-model="description" />
        </label>
        <label class="field wide">
          <span>Physical path</span>
          <input v-model="path" placeholder="/usr/irissys/csp/…/" />
        </label>
        <label class="field wide">
          <span>Dispatch class</span>
          <input v-model="dispatchClass" placeholder="(none — static files)" />
        </label>
        <label class="field">
          <span>Serve files</span>
          <select v-model="serveFiles">
            <option v-for="option in SERVE_FILES" :key="option" :value="option">{{ option }}</option>
          </select>
        </label>
        <label class="field">
          <span>Session timeout</span>
          <input v-model.number="timeout" type="number" min="0" />
        </label>
      </div>

      <fieldset class="group">
        <legend>Authentication methods</legend>
        <label v-for="[bit, label] in AUTH_BITS" :key="bit" class="check">
          <input
            type="checkbox"
            :checked="bits.includes(bit)"
            @change="toggleBit(bit, ($event.target as HTMLInputElement).checked)"
          />
          {{ label }}
        </label>
      </fieldset>

      <div class="checks">
        <label class="check"><input v-model="enabled" type="checkbox" /> Enabled</label>
        <label class="check"><input v-model="recurse" type="checkbox" /> Recurse to sub-paths</label>
      </div>

      <div class="actions">
        <button class="btn" @click="emit('cancel')">Cancel</button>
        <button class="btn btn-primary" :disabled="busy" @click="save">
          {{ busy ? 'Saving…' : 'Save' }}
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
  align-items: flex-start;
  justify-content: center;
  padding: 48px 16px;
  overflow-y: auto;
  background: rgba(20, 26, 38, 0.4);
}
.dialog {
  width: min(680px, 100%);
  padding: var(--space-5);
  box-shadow: var(--shadow-md);
}
.grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--space-3);
  margin-top: var(--space-4);
}
.field.wide {
  grid-column: 1 / -1;
}
.group {
  margin: var(--space-4) 0 0;
  padding: var(--space-2) var(--space-3);
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
}
legend {
  padding: 0 var(--space-1);
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}
.check {
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
  margin-right: var(--space-4);
}
.checks {
  display: flex;
  gap: var(--space-4);
  margin-top: var(--space-4);
}
.actions {
  display: flex;
  justify-content: flex-end;
  gap: var(--space-2);
  margin-top: var(--space-5);
}
</style>
