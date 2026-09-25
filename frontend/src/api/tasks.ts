import { getData, send } from './request'

export interface IrisTask {
  Id: number
  Name: string
  Type: string
  Namespace: string
  Description: string
  Suspended: boolean
  LastFinished: string
  NextScheduled: string
}

export interface TaskRun {
  TaskId: number
  Name: string
  LastStart: string
  Completed: string
  /** "1" when the run succeeded. Result holds descriptive text, not a status. */
  Status: string
  Result: string
  ErrNumber?: number
  Pid?: string
  Username?: string
}

export function runSucceeded(run: TaskRun): boolean {
  return String(run.Status) === '1' && !Number(run.ErrNumber ?? 0)
}

export interface TaskInfo {
  Type: string
  Status: string
  Error: string
  LastSchedule: string
  LastStarted: string
  LastFinished: string
  NextScheduled: string
  Suspended: boolean
}

/** Category used by the list filters. */
export type TaskCategory = 'running' | 'scheduled' | 'failed' | 'completed' | 'suspended'

export function listTasks() {
  return getData<IrisTask[]>('/tasks')
}

export function listTaskHistory() {
  return getData<TaskRun[]>('/tasks/history')
}

export function listTaskHistoryFor(id: number | string) {
  return getData<TaskRun[]>(`/tasks/history/${id}`)
}

export function getTaskDetail(id: number | string) {
  return getData<Record<string, unknown>>(`/tasks/detail/${id}`)
}

export function getTaskInfo(id: number | string) {
  return getData<TaskInfo>(`/tasks/info/${id}`)
}

export function getTaskManager() {
  return getData<{ Status: string }>('/tasks/manager')
}

export function runTask(id: number | string) {
  return send<unknown>('POST', `/tasks/run/${id}`)
}

export function suspendTask(id: number | string) {
  return send<unknown>('POST', `/tasks/${id}/disable`)
}

export function resumeTask(id: number | string) {
  return send<unknown>('POST', `/tasks/${id}/enable`)
}

export function deleteTask(id: number | string) {
  return send<unknown>('DELETE', `/tasks/${id}`)
}

/** Latest run per task, plus the derived category and duration. */
export function summarise(tasks: IrisTask[], runs: TaskRun[]) {
  const latest = new Map<number, TaskRun>()
  for (const run of runs) {
    const current = latest.get(run.TaskId)
    if (!current) {
      latest.set(run.TaskId, run)
      continue
    }
    const a = current.Completed || current.LastStart
    const b = run.Completed || run.LastStart
    if (b > a) latest.set(run.TaskId, run)
  }

  return tasks.map((task) => {
    const run = latest.get(task.Id)
    let category: TaskCategory = 'scheduled'
    if (task.Suspended) category = 'suspended'
    else if (run && !run.Completed) category = 'running'
    else if (run) category = runSucceeded(run) ? 'completed' : 'failed'

    let durationMs: number | null = null
    if (run?.Completed && run.LastStart) {
      const start = Date.parse(run.LastStart.replace(' ', 'T'))
      const end = Date.parse(run.Completed.replace(' ', 'T'))
      if (!Number.isNaN(start) && !Number.isNaN(end)) durationMs = end - start
    }

    const status =
      category === 'suspended'
        ? 'DISABLED'
        : category === 'running'
          ? 'RUNNING'
          : category === 'failed'
            ? 'FAILED'
            : category === 'completed'
              ? 'SUCCESS'
              : 'INFO'

    return { task, run, category, status, durationMs }
  })
}
