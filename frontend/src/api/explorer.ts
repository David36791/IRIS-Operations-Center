import { getData, send } from './request'

export interface OpenApiParameter {
  name: string
  in: string
  required?: boolean
  type?: string
  schema?: { type?: string }
}

export interface OpenApiOperation {
  summary?: string
  description?: string
  operationId?: string
  parameters?: OpenApiParameter[]
  requestBody?: unknown
}

export interface OpenApiSpec {
  info?: { title?: string; version?: string; description?: string }
  basePath?: string
  host?: string
  paths?: Record<string, Record<string, OpenApiOperation>>
}

export interface ExplorerRequest {
  method: string
  path: string
  params: Record<string, string>
  headers: Record<string, string>
  body?: string
}

export interface ExplorerResponse {
  status: number
  durationMs: number
  contentType: string
  headers: Record<string, string>
  body: string
}

/** The instance generates the OpenAPI document for any REST application. */
export function getOpenApi(namespace: string, appPath: string) {
  const path = appPath.replace(/^\//, '')
  return getData<OpenApiSpec>(`/explorer/openapi/${encodeURIComponent(namespace)}/${path}`)
}

export function sendRequest(request: ExplorerRequest) {
  return send<ExplorerResponse>('POST', '/explorer/send', request)
}
