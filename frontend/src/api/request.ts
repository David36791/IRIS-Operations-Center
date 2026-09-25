import client from './client'
import type { ApiEnvelope } from '@/types/system'

/** GET a path and unwrap the { success, data } envelope. */
export async function getData<T>(url: string): Promise<T> {
  const { data } = await client.get<ApiEnvelope<T>>(url)
  return data.data
}

/** Send a body-bearing request and unwrap the { success, data } envelope. */
export async function send<T>(method: 'PUT' | 'POST' | 'DELETE', url: string, body?: unknown): Promise<T> {
  const { data } = await client.request<ApiEnvelope<T>>({ method, url, data: body })
  return data.data
}

/** Read a field off an untyped management-API payload. */
export function field<T>(source: unknown, key: string, fallback: T): T {
  if (source && typeof source === 'object' && key in source) {
    return (source as Record<string, T>)[key]
  }
  return fallback
}
