import { getData, send } from './request'

export interface IrisUser {
  Name: string
  FullName: string
  Namespace: string
  Enabled: boolean
  Type?: string
}

export interface IrisRole {
  Name: string
  Description: string
}

export interface AuditEvent {
  EventName: string
  Enabled: boolean
  Total: number
  Written: number
  Lost: number
}

export interface X509Credential {
  Name?: string
  Alias?: string
  Expires?: string
}

export interface WalletCollection {
  Name: string
}

export interface WalletSecret {
  Name: string
}

export interface IrisUserDetail {
  Name: string
  FullName: string
  Enabled: boolean
  Roles?: string
  LoginDateTime?: string
  ChangePassword?: boolean
  Comment?: string
  EmailAddress?: string
  [key: string]: unknown
}

export interface ResourceGrant {
  Name: string
  /** IRIS permission letters: R (read), W (write), U (use). */
  Permissions: string
}

export interface IrisRoleDetail {
  Description: string
  GrantedRoles: string[]
  EscalationOnly: boolean
  Resources: ResourceGrant[]
}

export interface IrisResource {
  Name: string
  Description: string
  PublicPermission: string
  ResourceType: string
  AllowDelete: boolean
}

export function listUsers() {
  return getData<IrisUser[]>('/users')
}

export function getUser(name: string) {
  return getData<IrisUserDetail>(`/security/users/${encodeURIComponent(name)}`)
}

export function getRole(name: string) {
  return getData<IrisRoleDetail>(`/security/roles/${encodeURIComponent(name)}`)
}

export function listResources() {
  return getData<IrisResource[]>('/security/resources')
}

export function listOAuthClients() {
  return getData<Record<string, unknown>[]>('/security/oauth/clients')
}

export function getOAuthServer() {
  return getData<Record<string, unknown>>('/security/oauth/server')
}

export function listOAuthResourceServers() {
  return getData<Record<string, unknown>[]>('/security/oauth/resource-servers')
}

export function listRoles() {
  return getData<IrisRole[]>('/roles')
}

export function listAuditEvents() {
  return getData<AuditEvent[]>('/audit/events')
}

export function getAuditEnabled() {
  return getData<Record<string, unknown>>('/security/audit/enabled')
}

export function listAuditRecords(filter: Record<string, unknown> = {}) {
  return send<Record<string, unknown>[] | Record<string, unknown>>('POST', '/security/audit/records', filter)
}

export function listCertificates() {
  return getData<X509Credential[]>('/certificates')
}

export function listWallets() {
  return getData<WalletCollection[]>('/wallets')
}

export function listSecrets(collection: string) {
  return getData<WalletSecret[]>(`/secrets/${encodeURIComponent(collection)}`)
}
