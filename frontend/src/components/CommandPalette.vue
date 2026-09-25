<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { NAV_GROUPS } from '@/router/nav'
import { paletteOpen } from '@/palette'

interface Command {
  label: string
  group: string
  to: string
}

const router = useRouter()
const open = paletteOpen
const query = ref('')
const active = ref(0)

/** Navigation entries, plus the pages that are not in the sidebar. */
const commands = computed<Command[]>(() => {
  const out: Command[] = []
  for (const group of NAV_GROUPS) {
    for (const item of group.items) {
      if (item.soon) continue
      out.push({ label: item.label, group: group.label, to: item.to })
    }
  }
  out.push({ label: 'Global Search', group: 'Tools', to: '/search' })
  out.push({ label: 'Design System', group: 'Tools', to: '/design' })
  return out
})

const matches = computed(() => {
  const needle = query.value.trim().toLowerCase()
  return needle
    ? commands.value.filter((command) => `${command.label} ${command.group}`.toLowerCase().includes(needle))
    : commands.value
})

function toggle() {
  open.value = !open.value
  query.value = ''
  active.value = 0
}

function run(command: Command | undefined) {
  if (!command) return
  // Guard against a second call: the click that follows mousedown is a no-op
  // once the palette is closed.
  if (!open.value) return
  open.value = false
  void router.push(command.to)
}

function onKey(event: KeyboardEvent) {
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
    event.preventDefault()
    toggle()
    return
  }
  if (!open.value) return
  if (event.key === 'Escape') {
    open.value = false
  } else if (event.key === 'ArrowDown') {
    event.preventDefault()
    active.value = Math.min(active.value + 1, matches.value.length - 1)
  } else if (event.key === 'ArrowUp') {
    event.preventDefault()
    active.value = Math.max(active.value - 1, 0)
  } else if (event.key === 'Enter') {
    event.preventDefault()
    run(matches.value[active.value])
  }
}

onMounted(() => window.addEventListener('keydown', onKey))
onUnmounted(() => window.removeEventListener('keydown', onKey))
</script>

<template>
  <div v-if="open" class="overlay" @click.self="open = false">
    <div class="palette card" role="dialog" aria-modal="true">
      <input
        v-model="query"
        class="query"
        type="text"
        autofocus
        placeholder="Jump to a page… (Cmd/Ctrl+K)"
        @input="active = 0"
      />
      <ul class="list">
        <li v-for="(command, index) in matches" :key="command.to">
          <!-- mousedown, not click: the input holds focus, and losing it on
               mousedown can replace the node before a click would fire, which
               made the items unresponsive to the mouse. -->
          <button
            type="button"
            class="item"
            :class="{ 'is-active': index === active }"
            @mousedown.prevent="run(command)"
            @click.prevent="run(command)"
          >
            <span class="label">{{ command.label }}</span>
            <span class="group">{{ command.group }}</span>
          </button>
        </li>
        <li v-if="matches.length === 0" class="empty">No matching page</li>
      </ul>
      <p class="hint">
        Navigation only: actions such as creating or deleting keep their own confirmation on the page they belong to.
      </p>
    </div>
  </div>
</template>

<style scoped>
.overlay {
  position: fixed;
  inset: 0;
  z-index: 60;
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding: 96px 16px;
  background: rgba(20, 26, 38, 0.4);
}
.palette {
  width: min(560px, 100%);
  padding: var(--space-3);
  box-shadow: var(--shadow-md);
}
.query {
  width: 100%;
  font-size: var(--text-lg);
}
.list {
  max-height: 320px;
  margin: var(--space-2) 0 0;
  padding: 0;
  overflow-y: auto;
  list-style: none;
}
.item {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  width: 100%;
  padding: var(--space-2) var(--space-3);
  border: 0;
  border-radius: var(--radius-sm);
  background: none;
  font: inherit;
  text-align: left;
  cursor: pointer;
}
.item.is-active {
  background: var(--status-info-bg);
}
.label {
  font-weight: 600;
}
.group {
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
.empty {
  padding: var(--space-3);
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
.hint {
  margin: var(--space-2) 0 0;
  color: var(--color-text-faint);
  font-size: var(--text-xs);
}
</style>
