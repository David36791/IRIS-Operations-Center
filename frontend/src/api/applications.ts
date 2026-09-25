import { getData, send } from './request'

/** Row shape of GET /applications. */
export interface IrisWebApp {
  Name: string
  Namespace: string
  NamespaceDefault: boolean
  Enabled: boolean
  Type: string
  Resource: string
  AuthenticationMethods: string[]
  IsSystemApp: boolean
  DispatchClass: string
}

/** Full web application record behind GET /applications/detail. */
export interface IrisWebAppDetail {
  Name: string
  NameSpace: string
  Enabled: boolean
  Description: string
  Path: string
  DispatchClass: string
  AutheEnabled: number
  Recurse: boolean
  ServeFiles: string
  ServeFilesTimeout: number
  Timeout: number
  CookiePath: string
  CSRFToken: boolean
  InbndWebServicesEnabled: boolean
  RedirectEmptyPath: boolean
  IsNameSpaceDefault: boolean
  MatchRoles: string[]
  Resource: string
  LoginPage: string
  ErrorPage: string
  TraceEnabled: boolean
  TwoFactorEnabled: boolean
  UseCookies: string
  SessionScope: string
  UserCookieScope: string
  Package: string
  SuperClass: string
}

export function listApplications() {
  return getData<IrisWebApp[]>('/applications')
}

/** Application names contain "/", which cannot travel in a single path segment. */
export function encodeAppSegment(name: string): string {
  return encodeURIComponent(name.split('/').join('~'))
}

export function getApplication(name: string) {
  return getData<IrisWebAppDetail>(`/applications/detail/${encodeAppSegment(name)}`)
}

/** Create or update. The body is the definition exactly as GET returns it. */
export function saveApplication(name: string, definition: Record<string, unknown>) {
  return send<IrisWebAppDetail>('PUT', `/applications/${encodeAppSegment(name)}`, definition)
}

export function deleteApplication(name: string) {
  return send<unknown>('DELETE', `/applications/${encodeAppSegment(name)}`)
}

/** Enable/disable is an update of the full definition with Enabled flipped. */
export async function setApplicationEnabled(name: string, enabled: boolean) {
  const detail = await getApplication(name)
  const definition = { ...(detail as unknown as Record<string, unknown>), Enabled: enabled }
  return saveApplication(name, definition)
}
