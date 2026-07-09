# turn.mjs — engine contract

Runs one headless AI-session turn (claude or codex) and returns it as data. It is not a job manager (Bash `run_in_background` is the job layer) and not a sandbox (write intent is a flag; read-only asks belong in the prompt). Shared by the `/consult`, `/delegate`, and `/review` skills; callable directly.

```
node ~/.claude/skills/sidekick-runtime/turn.mjs --provider <claude|codex> --prompt-file <F> [flags]
node ~/.claude/skills/sidekick-runtime/collect.mjs [out-dir]
```

`collect.mjs` prints one finished (or running) turn as a single block: the meta summary, the git delta since the recorded baseline (`log --oneline` + `diff --stat` + dirty state), and `result.md` in full. Out-dir omitted → the newest job dir under `<repo>/.sidekick`.

## Flags

| Flag | Default | Notes |
|---|---|---|
| `--provider` | required | `claude` or `codex`. |
| `--prompt-file` | required | The full prompt; archived to `<out-dir>/prompt.md`. |
| `--model` | provider's own config | Free-form; the provider validates at runtime (codex rejects account-unsupported models mid-turn — the session id is still captured, so the failure is inspectable). |
| `--effort` | provider's own config | claude: `low medium high xhigh max` · codex: `none minimal low medium high xhigh`. Invalid values are rejected before spawn — claude would silently ignore them, codex would burn a turn-start on an API 400. |
| `--resume <id>` | fresh session | Continue that provider session. Never resume across providers. One turn per session at a time: a live turn holds a lock on its session id, so a concurrent second `turn.mjs` on the same id is refused (exit 3, message names the live job). A manual takeover while a turn runs still races it — the lock can't see the interactive CLI. |
| `--allow-write` | off | claude: launches `bypassPermissions` so the session edits/runs unattended; without it, write tools fail. codex: no flag either way — `~/.codex/config.toml` governs its sandbox. |
| `--baseline <sha>` | HEAD when `--allow-write`, else unset | Recorded in `meta.json` as `gitBaseline` — the anchor `collect.mjs` diffs against. Pass explicitly when the review range shouldn't start at the current HEAD. |
| `--cwd DIR` | current dir | Where the session reads (and, with write, edits). |
| `--out-dir DIR` | `<repo>/.sidekick/<stamp>-<label>/` | Self-gitignored on first use; falls back to `~/.local/state/sidekick/<dir>/` outside a git repo. |
| `--timeout-min N` | 30 | Wall-clock (laptop-sleep-proof). `0` = uncapped. |
| `--max-budget-usd N` | off | claude only; rejected for codex (no such flag exists there). |
| `--label TEXT` | provider name | Names the job dir. |

## Output

stdout: `out-dir:`, `watch:` (a `tail -f` on the live raw.log), `baseline:` when recorded, then `session:` + `takeover:` as soon as the id is known (claude: at spawn; codex: seconds in), an elapsed heartbeat every 30s, then a final scannable block (`status:` / `result:` / `meta:` / `session:` / `takeover:`). The files are authoritative:

- `result.md` — the final text; on failure, the provider's own error plus any recovered partial output.
- `meta.json` — written with `status: "running"` as soon as the turn starts (a killed job still leaves its coordinates) and finalized on exit: session id, `resumeFlag`, `takeoverCommand` (`claude --resume <id>` / `codex resume <id>`), `gitBaseline`, timing, tokens/cost when the provider reports them (`null` = unavailable, never zeroed). Token objects break out the cache and reasoning components where the provider reports them (codex: `cachedInput`, `reasoningOutput`; claude: `cacheRead`, `cacheCreation`) — codex's `input` includes its cached share, so a huge `input` with `cachedInput` close behind is cheap, not alarming.
- `raw.log` — raw provider output. Read it when a result looks misparsed or a failure needs a postmortem.

## Status → next move

| Status | Exit | Meaning | Next move |
|---|---|---|---|
| `ok` | 0 | Final text in `result.md` | Proceed. |
| `failed` | 1 | The provider reported an error (its text in `result.md`) | Read the error. A claude budget cutoff says raise the cap and `--resume` for the remainder. |
| `timeout` | 4 | Killed at the cap | `result.md` says whether the prompt was **accepted** (inspect, then `--resume` — re-sending would duplicate the conversation) or never accepted (re-dispatching the identical turn is safe). |
| `infra` | 2 | Spawn/parse failure, no provider result | Retry the identical call once; a second failure → read `raw.log`, report to the user. |
| usage | 3 | Bad flags, or the session already has a live turn (lock held); the message names the fix | Fix the flag, or wait for / watch the live turn. |

## Billing

Both `codex exec` and headless claude (`claude -p`) bill their flat subscriptions. `--max-budget-usd` (claude-only) is retained as an optional per-turn spend cap for future use — the subscription doesn't require it.

Argv facts verified against claude 2.1.x / codex 0.142.x. After a CLI upgrade, an odd failure means re-checking `--help` before blaming the prompt.
