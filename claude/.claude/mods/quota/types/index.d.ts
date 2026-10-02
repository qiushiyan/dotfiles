export type QuotaSample = { at: number; percent: number }

/** One rate-limit window as this session has watched it. */
export type QuotaWindow = {
  samples: QuotaSample[]
  /** The highest threshold already announced for this window; 0 for none. */
  alerted: number
}

declare module 'claude-code' {
  interface PluginState {
    quota: { windows: Record<string, QuotaWindow> }
  }
}
