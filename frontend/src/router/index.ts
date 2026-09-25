import { createRouter, createWebHashHistory, type RouteRecordRaw } from 'vue-router'
import type { Component } from 'vue'
import MainLayout from '@/layouts/MainLayout.vue'
import { NAV_GROUPS } from './nav'

type LazyView = () => Promise<{ default: Component }>

/** Pages get a real view as their phase lands; the rest show a placeholder. */
const VIEWS: Record<string, LazyView> = {
  '/dashboard': () => import('@/views/Dashboard.vue'),
  '/applications': () => import('@/views/Applications.vue'),
  '/rest-explorer': () => import('@/views/RestExplorer.vue'),
  '/tasks': () => import('@/views/Tasks.vue'),
  '/system': () => import('@/views/System.vue'),
  '/system/cpu': () => import('@/views/Cpu.vue'),
  '/system/memory': () => import('@/views/Memory.vue'),
  '/system/disk': () => import('@/views/Disk.vue'),
  '/system/processes': () => import('@/views/Processes.vue'),
  '/system/network': () => import('@/views/Network.vue'),
  '/system/devices': () => import('@/views/Devices.vue'),
  '/security/users': () => import('@/views/Users.vue'),
  '/security/roles': () => import('@/views/Roles.vue'),
  '/security/permissions': () => import('@/views/Permissions.vue'),
  '/security/secrets': () => import('@/views/Secrets.vue'),
  '/security/certificates': () => import('@/views/Certificates.vue'),
  '/security/wallets': () => import('@/views/Wallets.vue'),
  '/security/oauth': () => import('@/views/OAuth.vue'),
  '/logs': () => import('@/views/Logs.vue'),
  '/timeline': () => import('@/views/Timeline.vue'),
  '/search': () => import('@/views/Search.vue'),
  '/copilot': () => import('@/views/Copilot.vue'),
  '/design': () => import('@/views/DesignSystem.vue')
}

const comingSoon: LazyView = () => import('@/views/ComingSoon.vue')

/** Sub-pages that are not navigation entries themselves. */
const SUB_ROUTES: RouteRecordRaw[] = [
  {
    path: 'applications/detail/:app',
    name: '/applications/detail',
    component: () => import('@/views/ApplicationDetail.vue'),
    meta: { title: 'Application Detail', group: 'Management' }
  },
  {
    path: 'tasks/detail/:id',
    name: '/tasks/detail',
    component: () => import('@/views/TaskDetail.vue'),
    meta: { title: 'Task Detail', group: 'Management' }
  },
  {
    // Not in the sidebar, reached from Logs.
    path: 'audit',
    name: '/audit',
    component: () => import('@/views/Audit.vue'),
    meta: { title: 'Audit', group: 'Observability' }
  }
]

/** Every navigation entry becomes a page. */
const pageRoutes: RouteRecordRaw[] = NAV_GROUPS.flatMap((group) =>
  group.items
    .filter((item) => !item.soon)
    .map((item) => ({
      path: item.to.replace(/^\//, ''),
      name: item.to,
      component: VIEWS[item.to] ?? comingSoon,
      meta: { title: item.label, group: group.label }
    }))
)

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    {
      path: '/',
      component: MainLayout,
      children: [{ path: '', redirect: '/dashboard' }, ...pageRoutes, ...SUB_ROUTES]
    },
    {
      path: '/design',
      component: MainLayout,
      children: [
        {
          path: '',
          name: 'design-system',
          component: VIEWS['/design'],
          meta: { title: 'Design System', group: 'Tools' }
        }
      ]
    }
  ]
})

export default router
