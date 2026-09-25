import { getData, send } from './request'

export interface SystemUsage {
  AllGlobalReferences: number
  GlobalUpdateReferences: number
  RoutineCalls: number
  LogicalBlockRequests: number
  BlockReads: number
  BlockWrites: number
  JournalEntries: number
  RoutineLines: number
  LastUpdate: string
}

export interface IrisProcess {
  Job: number
  Pid: number
  Username: string
  OSUserName: string
  Nspace: string
  Routine: string
  State: string
  /** Seconds of CPU as a decimal string. */
  CPUTime: string
  /** Seconds elapsed as a decimal string. */
  ElapsedTime: string
  Globals: number
  Commands: number
  IPAddress: string
  Device: string
  ClientName: string
  CanBeTerminated: boolean
  CanBeSuspended: boolean
}

export interface SharedMemoryRow {
  Description: string
  SMHAllocated: number
  SMHAvailable: number
  SMHUsed: number
  SMTUsed: number
  GSTUsed: number
  AllUsed: number
}

export interface DiskRow {
  /** The database directory, which is the mount point the figures describe. */
  Directory: string
  /** Database names sharing this directory, comma-separated. */
  databases: string
  /**
   * Whether the volume figures below were reported. IRIS lists every database
   * but only the directories its storage sensor reaches, so an unmeasured row
   * carries zeros and this flag rather than a misleading figure.
   */
  measured: boolean
  /** Volume figures, in megabytes. */
  total: number
  used: number
  available: number
  /** Percentage of the volume in use. */
  usage: number
}

export interface IrisDevice {
  Name: string
  Type: string
  SubType: string
  PhysicalDevice: string
  Description: string
  Alias: string
  OpenParameters: string
}

export function getSystemUsage() {
  return getData<SystemUsage>('/system/usage')
}

export function getProcesses() {
  return getData<IrisProcess[]>('/system/processes')
}

export function terminateProcess(pid: number) {
  return send<unknown>('DELETE', `/system/processes/${pid}`)
}

export function getMemoryUsage() {
  return getData<SharedMemoryRow[]>('/system/memory')
}

export function getDiskUsage() {
  return getData<DiskRow[]>('/system/disk')
}

export function getDevices() {
  return getData<IrisDevice[]>('/system/devices')
}
