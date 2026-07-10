# turn.mjs — engine contract

Runs one headless AI-session turn (claude or codex) and returns it as data. It is not a job manager (Bash `run_in_background` is the job layer) and not a sandbox (write intent is a flag; read-only asks belong in the prompt). Shared by the `/consult`, `/delegate`, and `/review` skills; callable directly.

```
node ~/.claude/skills/sidekick-runtime/turn.mjs --provider <claude|codex> --prompt-file <F> [flags]
node ~/.claude/skills/sidekick-runtime/collect.mjs [out-dir]
node ~/.claude/skills/sidekick-runtime/collect.mjs --pending [--base DIR]
```

`collect.mjs` prints one turn as a single block: the meta summary, the git delta since the recorded baseline (`log --oneline` + `diff --stat` + dirty state), and `result.md` in full. Out-dir omitted → the newest job dir under `<repo>/.sidekick`. `--pending` is discovery-only: it lists uncollected terminal jobs plus non-live or corrupt jobs that need recovery under the default job base (or `--base DIR`), skips live jobs, and neither prints full results nor marks anything collected. Follow the `next:` action printed for each item; terminal items point to explicit collection, while stale or corrupt items prescribe inspection first.

## Host lifecycle

Launch each `turn.mjs` command as exactly one Bash `run_in_background` task, then return and let Claude Code's native task-completion notification wake the host. On that notification, run `collect.mjs` for the reported out-dir. The Bash task already owns completion tracking; an added Monitor, polling loop, or `TaskOutput` call would duplicate it and can act on the wrong lifecycle boundary. After a host restart or compaction that may have hidden a notification, run `collect.mjs --pending` and follow every listed `next:` action before continuing its workflow.

## Flags

| Flag | Default | Notes |
|---|---|---|
| `--provider` | required | `claude` or `codex`. |
| `--prompt-file` | required | The full prompt; archived to `<out-dir>/prompt.md`. |
| `--model` | provider's own config | Free-form; the provider validates at runtime (codex rejects account-unsupported models mid-turn — the session id is still captured, so the failure is inspectable). |
| `--effort` | provider's own config | claude: `low medium high xhigh max` · codex: `none minimal low medium high xhigh max ultra`. Invalid values are rejected before spawn — claude would silently ignore them, codex would burn a turn-start on an API 400. |
| `--resume <id>` | fresh session | Continue that provider session. Never resume across providers. One turn per session at a time: a live turn holds a lock on its session id, so a concurrent second `turn.mjs` on the same id is refused (exit 3, message names the live job). A manual takeover while a turn runs still races it — the lock can't see the interactive CLI. |
| `--allow-write` | off | claude: launches `bypassPermissions` so the session edits/runs unattended; without it, write tools fail. codex: no flag either way — `~/.codex/config.toml` governs its sandbox. |
| `--baseline <sha>` | HEAD when `--allow-write`, else unset | Recorded in `meta.json` as `gitBaseline` — the anchor `collect.mjs` diffs against. Pass explicitly when the review range shouldn't start at the current HEAD. |
| `--cwd DIR` | current dir | Where the session reads (and, with write, edits). |
| `--out-dir DIR` | `<repo>/.sidekick/<stamp>-<label>/` | Self-gitignored on first use; falls back to `~/.local/state/sidekick/<dir>/` outside a git repo. |
| `--timeout-min N` | 30 | Wall-clock (laptop-sleep-proof). `0` = uncapped. |
| `--max-budget-usd N` | off | claude only; rejected for codex (no such flag exists there). |
| `--label TEXT` | provider name | Names the job dir. |

## Output

stdout: `out-dir:`, `watch:` (a `tail -f` on the live raw.log), `baseline:` when recorded, then `session:` + `takeover:` as soon as the id is known (claude: at spawn; codex: seconds in), plus a `next:` instruction telling the host to wait for the native task notification. After the elapsed heartbeats, every terminal block points to explicit collection first; recovery comes only after the host has read and acknowledged the result. The files are authoritative:

- `result.md` — the final text. A non-`ok` turn finalized by the runner includes the observed failure, any recovered partial output, and an **After collecting** recovery action; abandoned-job reconciliation creates that recovery result when none exists. Recovery language follows the recorded `promptState`: `accepted` → inspect, then resume; `not_started` → identical re-dispatch is safe; `unknown` → inspect the tree and `raw.log` before acting.
- `meta.json` — atomically replaced on every update, so a concurrent collector never sees a partial JSON write. It records `status: "running"`, `runnerPid`, `promptState`, and the immediate host-facing `nextAction` as soon as the turn starts, then `providerPid` / `providerPgid` after spawn (a killed runner still leaves enough coordinates to distinguish an orphaned provider from an abandoned job). Terminal metadata makes `nextAction` the explicit collection command and stores any post-collection recovery in `recoveryAction`; after successfully printing a terminal job, collection atomically sets `collectedAt` once and advances `nextAction` to verification/synthesis for `ok` or to `recoveryAction` otherwise. Discovery with `--pending` leaves all three unchanged. Final metadata also records the session id, `resumeFlag`, `takeoverCommand` (`claude --resume <id>` / `codex resume <id>`), `gitBaseline`, timing, and tokens/cost when the provider reports them (`null` = unavailable, never zeroed). Token objects break out the cache and reasoning components where the provider reports them (codex: `cachedInput`, `reasoningOutput`; claude: `cacheRead`, `cacheCreation`) — codex's `input` includes its cached share, so a huge `input` with `cachedInput` close behind is cheap, not alarming.
- `raw.log` — raw provider output. Read it when a result looks misparsed or a failure needs a postmortem.

When collection finds `status: "running"` but `runnerPid` is dead, it checks the provider process group before suggesting an action. PID probes are best-effort because an OS can reuse a PID; “alive” means a process currently holds the recorded id, so the host still inspects before acting:

- provider group alive → **orphaned**: observe or stop that process group; never resume or re-dispatch concurrently;
- runner and provider group dead → **abandoned**: explicit collection finalizes that status and recovery metadata, creating `result.md` when none exists; the host then inspects the recorded work and follows `promptState`;
- provider-group state unavailable → **unknown**: inspect the tree and `raw.log`; do not assume the provider stopped.

## Status → next move

| Status | Exit | Meaning | Next move |
|---|---|---|---|
| `ok` | 0 | Final text in `result.md` | Collect first, then use the result in the invoking skill's verification, judgment, or synthesis step. |
| `failed` | 1 | The provider reported or exited with an error; recovered output is preserved in `result.md` | Collect first, then follow `recoveryAction`; inspect partial output and the working tree before continuing the session. |
| `timeout` | 4 | The wall-clock cap stopped the provider process tree | Collect first, then follow the `recoveryAction` for its recorded `promptState`; partial work may be on disk. |
| `interrupted` | 5 | The runner received a termination signal and stopped the provider process tree | Collect first, then follow the `recoveryAction` for its recorded `promptState`; partial work may be on disk. |
| `infra` | 2 | The runner failed at spawn, parsing, or provider-protocol handling | Collect first. Retry unchanged only when `recoveryAction` says the prompt was not accepted; otherwise inspect the tree and `raw.log`, then resume if a session id exists. |
| `abandoned` | — | Collection proved that a runner died without a terminal result and its provider group is gone | Inspect the recovered result and working tree, then follow `recoveryAction`; never infer that no work occurred. |
| `usage` | 3 | Bad flags, or the session already has a live turn (lock held); the message names the fix | Fix the flag, or wait for / watch the live turn. |

## Tests

`node --test ~/.claude/skills/sidekick-runtime/tests/runtime.test.mjs` runs isolated fake `codex` and `claude` executables through the public runtime. It covers success, provider failure with partial output, spawn failure, stdin closure, atomic metadata, timeout/interruption process-tree cleanup, residual descendants, stale reconciliation, and pending collection without invoking or billing a real model.

## Billing

Both `codex exec` and headless claude (`claude -p`) bill their flat subscriptions. `--max-budget-usd` (claude-only) is retained as an optional per-turn spend cap for future use — the subscription doesn't require it.

Argv facts verified against claude 2.1.206 / codex 0.144.1. After a CLI upgrade, an odd failure means re-checking `--help` before blaming the prompt.
