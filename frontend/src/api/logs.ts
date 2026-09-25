import { getData, send } from './request'

export interface LogEntry {
  time: string
  severity: string
  namespace: string
  message: string
  pid?: string
}

export interface AuditRecord {
  [key: string]: unknown
}

export interface LogPattern {
  pattern: string
  firstSeen: string
  lastSeen: string
  occurrences: number
  failures: number
  relatedServices: string[]
  severity: string
  message: string
}

/** Pattern analysis of event records, computed with Embedded Python. */
export function getLogIntelligence() {
  return getData<LogPattern[]>('/logs/intelligence')
}

export interface SemanticMatch {
  name: string
  result: string
  time: string
  score: number
}

/** Semantic search; needs the AI endpoint for embeddings. */
export function semanticSearch(query: string) {
  return send<{ query: string; matches: SemanticMatch[] }>('POST', '/search/semantic', { query })
}

/** Audit records; the backend forwards the filter body to the management API. */
export function getAuditLog(filter: Record<string, unknown> = {}) {
  return send<AuditRecord[] | Record<string, unknown>>('POST', '/logs/audit', filter)
}
