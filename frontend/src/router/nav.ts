export interface NavItem {
  label: string
  to: string
  /** Listed in the navigation but not yet routable. */
  soon?: boolean
}

export interface NavGroup {
  label: string
  items: NavItem[]
}

/** Left navigation; paths are the per-page routes. */
export const NAV_GROUPS: NavGroup[] = [
  {
    label: 'Overview',
    items: [{ label: 'Dashboard', to: '/dashboard' }]
  },
  {
    label: 'Management',
    items: [
      { label: 'Applications', to: '/applications' },
      { label: 'REST API Explorer', to: '/rest-explorer' },
      { label: 'Tasks', to: '/tasks' }
    ]
  },
  {
    label: 'Security',
    items: [
      { label: 'Users', to: '/security/users' },
      { label: 'Roles', to: '/security/roles' },
      { label: 'Permissions', to: '/security/permissions' },
      { label: 'Secrets', to: '/security/secrets' },
      { label: 'Certificates', to: '/security/certificates' },
      { label: 'Wallets', to: '/security/wallets' },
      { label: 'OAuth', to: '/security/oauth' }
    ]
  },
  {
    label: 'System',
    items: [
      { label: 'Overview', to: '/system' },
      { label: 'Processes', to: '/system/processes' },
      { label: 'CPU', to: '/system/cpu' },
      { label: 'Memory', to: '/system/memory' },
      { label: 'Disk', to: '/system/disk' },
      { label: 'Network', to: '/system/network' },
      { label: 'Devices', to: '/system/devices' }
    ]
  },
  {
    label: 'Observability',
    items: [
      { label: 'Logs', to: '/logs' },
      { label: 'Timeline', to: '/timeline' }
    ]
  },
  {
    label: 'Tools',
    items: [
      { label: 'Global Search', to: '/search' },
      { label: 'Command Palette', to: '/command-palette', soon: true }
    ]
  },
  {
    label: 'AI',
    items: [{ label: 'IRIS Copilot', to: '/copilot' }]
  }
]
