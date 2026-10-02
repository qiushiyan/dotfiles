/** `done` ran and finished; `started` launched, result pending; `mentioned` only named. */
export type StepStatus = 'done' | 'started' | 'mentioned'

/**
 * How a step showed up in a turn: `skill` its prompt was expanded (slash
 * command or Skill tool), `read` its SKILL.md was read, `snippet` a TabType
 * snippet was pasted, `mention` the prompt named it.
 */
export type StepSignal = 'skill' | 'read' | 'snippet' | 'mention'

export type StepKind = 'skill' | 'snippet'

export type Step = {
  name: string
  kind: StepKind
  status: StepStatus
  /** Turns in which it ran; 0 while only mentioned. */
  runs: number
  firstTurn: number
  lastTurn: number
  signals: StepSignal[]
  note?: string
  /** False while the status is the signals' own reading, before the model judged it. */
  isJudged: boolean
}

export type StepCandidate = { kind: StepKind; signals: StepSignal[] }

declare module 'claude-code' {
  interface PluginState {
    steps: {
      log: Record<string, Step>
      pending: Record<string, StepCandidate>
      pins: string[]
      known: string[]
      turn: number
    }
  }
}
