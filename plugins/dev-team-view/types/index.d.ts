export type Task = {
  id: string
  wave: string
  agent: string
  model: string
  status: string
  review: string
  branch: string
  note: string
}

export type Run = {
  file: string
  title: string
  status: string
  wave: string
  base: string
  updated: string
  tasks: Task[]
  rulings: string[]
  memory: string[]
  others: number
}

declare module 'claude-code' {
  interface PluginState {
    'dev-team-view': {
      run: Shaped<Run | null>
      hiddenFor: string
    }
  }
}
