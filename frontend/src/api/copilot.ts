import { getData, send } from './request'

export interface CopilotStatus {
  enabled: boolean
  configured: boolean
  baseUrl: string
  model: string
  readOnly: boolean
}

export interface CopilotAnswer {
  answer: string
  model: string
}

export function getCopilotStatus() {
  return getData<CopilotStatus>('/copilot/status')
}

export function askCopilot(prompt: string, context?: Record<string, unknown>) {
  return send<CopilotAnswer>('POST', '/copilot/ask', { prompt, context })
}
