export interface SystemInfo {
  version: string
  instanceName: string
  namespace: string
  username: string
  roles: string
  serverTime: string
}

export interface ApiEnvelope<T> {
  success: boolean
  data: T
  meta?: Record<string, unknown>
  error?: {
    code: string
    message: string
    details?: unknown
  }
}
