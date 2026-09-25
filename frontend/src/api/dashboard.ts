import { getData } from './request'
import type { SystemInfo } from '@/types/system'

export interface DashboardPerformance {
  GlobalRefsPerSecond: number
  GlobalRefs: number
  LogicalRequests: number
  DiskReads: number
  DiskWrites: number
  CacheEfficiency: number
}

export interface DashboardStatus {
  UpTime: string
  LastBackup: string
  SystemMonitor: boolean
}

export interface DashboardSystemUsage {
  DatabaseSpace: string
  JournalSpace: string
  LockTable: string
  WriteDaemon: string
  Processes: number
  CSPSessions: number
}

export interface DashboardAlerts {
  SeriousAlerts: number
  ApplicationErrors: number
}

export interface DashboardLicensing {
  LicenseLimit: number
  LicenseUse: number
  LicenseUseHigh: number
}

export interface DashboardUpcomingTask {
  Task: string
  Time: string
  Status: string
}

export interface DashboardPayload {
  Performance: DashboardPerformance
  Status: DashboardStatus
  SystemUsage: DashboardSystemUsage
  Alerts: DashboardAlerts
  Licensing: DashboardLicensing
  UpcomingTasks: DashboardUpcomingTask[]
}

export function getDashboard() {
  return getData<DashboardPayload>('/dashboard')
}

export function getSystemInfo() {
  return getData<SystemInfo>('/system')
}
