<script setup lang="ts">
import { computed } from 'vue'
import { RouterLink, RouterView, useRoute } from 'vue-router'
import { auth, clearCredentials } from '@/auth'
import CommandPalette from '@/components/CommandPalette.vue'
import NotificationCenter from '@/components/NotificationCenter.vue'
import { NAV_GROUPS } from '@/router/nav'
import { openPalette } from '@/palette'
import { theme, toggleTheme } from '@/theme'

const route = useRoute()
const title = computed(() => String(route.meta.title ?? ''))
const group = computed(() => String(route.meta.group ?? ''))

function signOut() {
  clearCredentials()
}
</script>

<template>
  <div class="layout">
    <aside class="sidebar">
      <div class="brand">
        <span class="brand-mark">IOC</span>
        <span class="brand-name">IRIS Operations Center</span>
      </div>
      <nav class="nav">
        <div v-for="navGroup in NAV_GROUPS" :key="navGroup.label" class="nav-group">
          <div class="nav-group-label">{{ navGroup.label }}</div>
          <template v-for="item in navGroup.items" :key="item.to">
            <!-- The command palette is an overlay, not a page, so it opens
                 rather than navigating. -->
            <button v-if="item.soon" class="nav-link is-button" title="Press Cmd/Ctrl+K" @click="openPalette()">
              {{ item.label }}
            </button>
            <RouterLink v-else :to="item.to" class="nav-link">{{ item.label }}</RouterLink>
          </template>
        </div>
      </nav>
    </aside>

    <div class="main">
      <header class="topbar">
        <div class="topbar-title">
          <span class="topbar-group">{{ group }}</span>
          <h1>{{ title }}</h1>
        </div>
        <div class="topbar-right">
          <NotificationCenter />
          <button class="btn btn-quiet" :title="theme === 'dark' ? 'Switch to light theme' : 'Switch to dark theme'" @click="toggleTheme">
            {{ theme === 'dark' ? 'Light' : 'Dark' }}
          </button>
          <span class="topbar-user">{{ auth.username }}</span>
          <button class="btn btn-quiet" title="Cmd/Ctrl+K">⌘K</button>
          <button class="btn btn-quiet" @click="signOut">Sign out</button>
        </div>
      </header>
      <section class="content">
        <RouterView />
      </section>
    </div>

    <CommandPalette />
  </div>
</template>

<style scoped>
.layout {
  display: flex;
  height: 100%;
}

.sidebar {
  display: flex;
  flex: 0 0 var(--sidebar-width);
  flex-direction: column;
  border-right: 1px solid var(--color-border);
  background: var(--color-surface);
}

.brand {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  height: var(--header-height);
  padding: 0 var(--space-4);
  border-bottom: 1px solid var(--color-border);
}
.brand-mark {
  padding: 2px 6px;
  border-radius: var(--radius-sm);
  background: var(--color-primary);
  color: #fff;
  font-size: var(--text-sm);
  font-weight: 700;
  letter-spacing: 0.4px;
}
.brand-name {
  font-size: var(--text-md);
  font-weight: 600;
}

.nav {
  flex: 1;
  overflow-y: auto;
  padding: var(--space-3) var(--space-2);
}
.nav-group + .nav-group {
  margin-top: var(--space-4);
}
.nav-group-label {
  padding: 0 var(--space-2) var(--space-1);
  color: var(--color-text-faint);
  font-size: var(--text-xs);
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
}
.nav-link {
  display: block;
  padding: 5px var(--space-2);
  border-radius: var(--radius-sm);
  color: var(--color-text);
  text-decoration: none;
}
.nav-link:hover {
  background: var(--color-surface-2);
  text-decoration: none;
}
.nav-link.router-link-active {
  background: var(--status-info-bg);
  color: var(--color-primary);
  font-weight: 600;
}
.nav-link.is-button {
  width: 100%;
  border: 0;
  background: none;
  color: var(--color-text-faint);
  font: inherit;
  text-align: left;
  cursor: pointer;
}
.nav-link.is-button:hover {
  background: var(--color-surface-2);
  color: var(--color-text);
}

.main {
  display: flex;
  flex: 1;
  min-width: 0;
  flex-direction: column;
}

.topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-4);
  height: var(--header-height);
  padding: 0 var(--space-5);
  border-bottom: 1px solid var(--color-border);
  background: var(--color-surface);
}
.topbar-title {
  display: flex;
  align-items: baseline;
  gap: var(--space-2);
  min-width: 0;
}
.topbar-group {
  color: var(--color-text-faint);
  font-size: var(--text-sm);
}
.topbar-title h1 {
  font-size: var(--text-lg);
}
.topbar-right {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}
.topbar-user {
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}

.content {
  flex: 1;
  overflow-y: auto;
  padding: var(--space-5);
}
</style>
