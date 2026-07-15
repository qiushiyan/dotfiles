# turn.mjs — engine contract

Runs one headless AI-session turn (`claude` or `codex`) and returns it as durable data. It is not a job manager (Bash `run_in_background` is the job layer) and not a sandbox (write intent is a flag; read-only asks belong in the prompt). It is shared by `/consult`, `/review`, and `/delegate` and is also callable directly.

```sh
node ~/.claude/skills/sidekick-runtime/turn.mjs --provider <claude|codex> --prompt-file <F> [flags]
node ~/.claude/skills/sidekick-runtime/collect.mjs [out-dir]
node ~/.claude/skills/sidekick-runtime/collect.mjs --pending [--base DIR]
```

## Host lifecycle

Launch one `turn.mjs` command as exactly one Bash `run_in_background` task. Relay its startup coordinate lines, then return. Claude Code's native task-completion notification is the completion signal; on that notification, run `collect.mjs` for the reported out-dir. `watch:` is an optional live view, not a second lifecycle or a prompt-acceptance test. Do not add a Monitor, polling loop, or `TaskOutput` call.

After a host restart or compaction that may have hidden a notification, run `collect.mjs --pending` and follow each printed `next:` action before continuing the invoking workflow. `--pending` is discovery-only: it skips provably live jobs, does not print full results, and does not mark anything collected.

## Flags

| Flag | Default | Notes |
|---|---|---|
| `--provider` | required | `claude` or `codex`. |
| `--prompt-file` | required | Full prompt, copied to `<out-dir>/prompt.md` before spawn. |
| `--model` | provider config | Free-form provider override. Omitted means the runner does **not know** the resolved model; report `(provider default)`, not an inferred “effective model.” |
| `--effort` | provider config | claude: `low medium high xhigh max` · codex: `none minimal low medium high xhigh max ultra`. Invalid values are rejected before spawn. |
| `--resume <id>` | fresh session | Continue the same provider session. Never cross providers. A resume id is known before setup, so any existing lock is refused before job artifacts are touched. A dead owner may have left a live orphan provider, so stale locks are never auto-reclaimed: collect/inspect the recorded job, account for its work, remove the lock only after the provider is gone, then retry. A fresh Codex id arrives after spawn; the improbable case that it collides with a lock stops and finalizes the new provider instead of continuing unlocked. |
| `--allow-write` | off | claude: `bypassPermissions`; without it, unattended write tools fail. codex: no permission flag — `~/.codex/config.toml` governs. This is intent, not a sandbox guarantee. |
| `--baseline <sha>` | HEAD for write turns; otherwise unset | Review anchor stored as `gitBaseline`; `collect.mjs` prints the commits, diffstat, and dirty state since it. |
| `--cwd DIR` | current dir | Provider working directory. |
| `--out-dir DIR` | `<repo>/.sidekick/<stamp>-<label>/` | Self-gitignored. Outside a repo, uses `~/.local/state/sidekick/<dir>/`. |
| `--timeout-min N` | 30 | Hard wall-clock safety cap for this one turn. It counts healthy work, does not reset on output, and is **not** a stall detector. `0` disables it. Caller policy: consult 30, review 60, delegate 180 minutes, on fresh and resumed turns alike. |
| `--max-budget-usd N` | off | claude only. |
| `--label TEXT` | provider | Job-dir label. |

The timeout compares the current wall clock with a fixed deadline, so laptop sleep cannot silently stretch the cap. Reaching it says only that the cap elapsed; a healthy deep review may still have been working.

## Provider protocol

- Claude runs `claude -p --output-format stream-json --verbose`. `stream-json` is the realtime headless format; the runner deliberately omits `--include-partial-messages` so logs carry completed event boundaries rather than token deltas. A final `result` event remains the result/usage envelope.
- Codex runs `codex exec --json` and streams its JSONL events. The last-message file is retained as a recovery surface.
- Both stdout streams use UTF-8 decoding with an incremental line buffer, including a final unterminated JSON record. JSON fragments, a split multi-byte code point, and non-JSON noise do not corrupt later events.
- Claude `system/init` proves process initialization, not prompt acceptance. Assistant/user/stream events or a terminal success/budget result prove semantic activity. On interruption/timeout, the runner can also recover same-turn evidence from the exact Claude session transcript, but ignores transcript rows older than this turn's `startedAt`.
- An authoritative Claude `result` or Codex `turn.completed` / `turn.failed` fixes the provider outcome. If the hard cap fires while the CLI or a residual descendant is still draining, the runtime still stops the process tree but publishes that already-complete outcome instead of downgrading it to a timeout.

## Output is a caller interface

The runner prints a small startup coordinate block:

```text
out-dir: ...
provider: claude · model (provider default) · effort (provider default) · hard cap 30m
watch: tail -f '.../progress.log' '.../raw.log'
raw: .../raw.log
stderr: .../stderr.log
session: ...
takeover-after-terminal: claude --resume ...
next: return now; wait for the native background-task notification, then collect this job
```

`baseline:` appears when set. A fresh Codex `session:` and `takeover-after-terminal:` appear when its first `thread.started` event supplies the id. Copy these lines as facts: `(provider default)` means no override was passed, not that the runner resolved the provider's configuration. Manual takeover is only safe after terminal state.

At terminal state stdout prints `status:`, `result:`, `meta:`, `session:`, `takeover:`, and one `next:` collection command. The durable files are authoritative:

- `prompt.md` — the exact dispatched prompt.
- `progress.log` — runner-owned semantic progress. It records lifecycle milestones (`starting`, provider initialization/retry, `accepted`, `running` heartbeat, stopping, terminal), elapsed time, provider-process observation, prompt state, and event counts. A 30-second heartbeat makes runner/process liveness visible while the provider is quiet without pretending silence proves health or contaminating provider output.
- `raw.log` — **provider stdout only**: Claude stream-json or Codex JSONL, preserved verbatim through the UTF-8 stream decoder. It contains no runner headers, heartbeats, or stderr.
- `stderr.log` — provider stderr only.
- `result.md` — final provider text, or the observed failure plus any recovered partial output. It does not duplicate recovery instructions.
- `meta.json` — atomically replaced state and the single machine-readable source of lifecycle/recovery truth: status, prompt state/evidence, `resultKind` (`final`, `partial`, `none`), deadline/timing, runner/provider PIDs, session/resume/takeover coordinates, log paths/watch command, provider event/activity observations, tokens/cost, `nextAction`, `recoveryAction`, and `collectedAt`. `resumeFlag` remains the session-only fragment; `resumeArgs` adds the current `--timeout-min` so a recovery turn does not silently fall back to the engine default. A fresh Codex lock collision retains `sessionId` only as diagnostic identity, records `sessionLockConflict`, and suppresses resume/takeover coordinates everywhere.

`collect.mjs` prints the metadata summary, optional git delta, and `result.md` as one block. On first terminal collection it stamps `collectedAt` and advances `nextAction`: success goes to the invoking skill's verify/judge/synthesize step; failure goes to `recoveryAction`. This keeps the proven next action in one place instead of making the host reconcile prose in multiple files.

## Recovery invariant

Never redispatch merely because output was quiet.

- `promptState: accepted` — inspect recovered output, `progress.log`, `stderr.log`, and the working tree; continue the same session with the recorded `--resume … --timeout-min …` fragment. Re-sending the original prompt may duplicate work.
- `promptState: not_started` — the provider did not start; one identical retry is safe.
- `promptState: unknown` — absence of output is not proof of no work. Inspect `progress.log`, `raw.log`, `stderr.log`, provider state, and the tree. Redispatch only with positive evidence that work never began; otherwise resume the recorded session.

When collection finds `status: running` but the recorded runner is dead, it checks the provider process group:

- provider alive → `orphaned`: wait for or stop it; never resume/redispatch concurrently;
- runner and provider dead → `abandoned`: collection reconciles terminal metadata/result, then applies the prompt-state invariant;
- liveness unavailable → `unknown`: inspect; do not assume it stopped.

PID probes are best-effort because operating systems can reuse IDs.

## Status → next move

| Status | Exit | Meaning | Next move |
|---|---:|---|---|
| `ok` | 0 | Final text is in `result.md`. | Collect, then verify/judge/synthesize. |
| `failed` | 1 | Provider reported or exited with an error; partial output may be present. | Collect, then follow `recoveryAction`. |
| `infra` | 2 | Spawn, protocol, or unexpected-signal failure. | Collect. Retry unchanged only when evidence says `not_started`; otherwise inspect/resume. |
| `usage` | 3 | Bad flags or a session-lock conflict. | Fix the named input. For a live owner, wait; for a dead owner, collect and inspect the recorded job before removing the stale lock. |
| `timeout` | 4 | Hard wall-clock cap stopped the provider process tree. | Collect; a timeout is not a hang diagnosis. Follow prompt-state recovery. |
| `interrupted` | 5 | Host signal stopped the provider process tree. | Collect, then follow prompt-state recovery. |
| `abandoned` | — | Collection proved the runner/provider ended without terminal publication. | Inspect reconciled output/tree, then follow `recoveryAction`. |

## Tests and CLI facts

```sh
node --test ~/.claude/skills/sidekick-runtime/tests/runtime.test.mjs
```

The isolated fake-provider suite exercises both public entry points without billing a model: streaming success, a heartbeat during semantic silence, fragmented JSON and UTF-8, provider failure/partial recovery, stderr isolation, spawn/stdin failures, atomic metadata, live/stale session-lock safety, hard-cap/result cleanup races, timeouts/interruption and process-tree cleanup, same-turn transcript recovery, legacy resume-cap preservation, stale reconciliation, and pending discovery.

Argv facts verified against Claude Code 2.1.207 and codex-cli 0.144.1. Re-check local `--help` after upgrades before blaming a prompt or parser.

Both `codex exec` and headless Claude bill their flat subscriptions. `--max-budget-usd` remains an optional Claude-only per-turn cap.
