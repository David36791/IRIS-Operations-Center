/** Unified status vocabulary. Every module renders it via StatusBadge. */
export const STATUSES = [
  'HEALTHY',
  'RUNNING',
  'SUCCESS',
  'INFO',
  'WARNING',
  'DEGRADED',
  'ERROR',
  'FAILED',
  'CRITICAL',
  'DISABLED',
  'UNKNOWN'
] as const

export type Status = (typeof STATUSES)[number]

/** Colour families a status maps onto; keeps colour usage to status only. */
export type StatusTone = 'ok' | 'info' | 'warn' | 'error' | 'muted'

export const STATUS_TONES: Record<Status, StatusTone> = {
  HEALTHY: 'ok',
  RUNNING: 'ok',
  SUCCESS: 'ok',
  INFO: 'info',
  WARNING: 'warn',
  DEGRADED: 'warn',
  ERROR: 'error',
  FAILED: 'error',
  CRITICAL: 'error',
  DISABLED: 'muted',
  UNKNOWN: 'muted'
}

export const STATUS_LABELS: Record<Status, string> = {
  HEALTHY: 'Healthy',
  RUNNING: 'Running',
  SUCCESS: 'Success',
  INFO: 'Info',
  WARNING: 'Warning',
  DEGRADED: 'Degraded',
  ERROR: 'Error',
  FAILED: 'Failed',
  CRITICAL: 'Critical',
  DISABLED: 'Disabled',
  UNKNOWN: 'Unknown'
}

export function isStatus(value: string): value is Status {
  return (STATUSES as readonly string[]).includes(value)
}

export function statusTone(value: string): StatusTone {
  const key = value.toUpperCase()
  return isStatus(key) ? STATUS_TONES[key] : 'muted'
}
