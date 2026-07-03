# turn.mjs — engine contract

Runs one headless AI-session turn (claude or codex) and returns it as data. It is not a job manager (Bash `run_in_background` is the job layer) and not a sandbox (write intent is a flag; read-only asks belong in the prompt). Shared by the `/consult` and `/delegate` skills; callable directly.

```
node ~/.claude/skills/sidekick-runtime/turn.mjs --provider <claude|codex> --prompt-file <F> [flags]
```

## Flags

| Flag | Default | Notes |
|---|---|---|
| `--provider` | required | `claude` or `codex`. |
| `--prompt-file` | required | The full prompt; archived to `<out-dir>/prompt.md`. |
| `--model` | provider's own config | Free-form; the provider validates at runtime (codex rejects account-unsupported models mid-turn — the session id is still captured, so the failure is inspectable). |
| `--effort` | provider's own config | claude: `low medium high xhigh max` · codex: `none minimal low medium high xhigh`. Invalid values are rejected before spawn — claude would silently ignore them, codex would burn a turn-start on an API 400. |
| `--resume <id>` | fresh session | Continue that provider session. Never resume across providers. One turn per session at a time: a concurrent second turn — including a manual takeover while a turn runs — races the live one. |
| `--allow-write` | off | claude: launches `bypassPermissions` so the session edits/runs unattended; without it, write tools fail. codex: no flag either way — `~/.codex/config.toml` governs its sandbox. |
| `--cwd DIR` | current dir | Where the session reads (and, with write, edits). |
| `--out-dir DIR` | `<repo>/.sidekick/<stamp>-<label>/` | Self-gitignored on first use; falls back to `~/.local/state/sidekick/<dir>/` outside a git repo. |
| `--timeout-min N` | 30 | Wall-clock (laptop-sleep-proof). `0` = uncapped. |
| `--max-budget-usd N` | off | claude only; rejected for codex (no such flag exists there). |
| `--label TEXT` | provider name | Names the job dir. |

## Output

stdout: `out-dir:` and `session:` lines as soon as known, an elapsed heartbeat every 30s, then a final scannable block (`status:` / `result:` / `meta:` / `session:` / `takeover:`). The files are authoritative:

- `result.md` — the final text; on failure, the provider's own error plus any recovered partial output.
- `meta.json` — session id, `resumeFlag`, `takeoverCommand` (`claude --resume <id>` / `codex resume <id>`), timing, tokens/cost when the provider reports them (`null` = unavailable, never zeroed).
- `raw.log` — raw provider output. Read it when a result looks misparsed or a failure needs a postmortem.

## Status → next move

| Status | Exit | Meaning | Next move |
|---|---|---|---|
| `ok` | 0 | Final text in `result.md` | Proceed. |
| `failed` | 1 | The provider reported an error (its text in `result.md`) | Read the error. A claude budget cutoff says raise the cap and `--resume` for the remainder. |
| `timeout` | 4 | Killed at the cap | `result.md` says whether the prompt was **accepted** (inspect, then `--resume` — re-sending would duplicate the conversation) or never accepted (re-dispatching the identical turn is safe). |
| `infra` | 2 | Spawn/parse failure, no provider result | Retry the identical call once; a second failure → read `raw.log`, report to the user. |
| usage | 3 | Bad flags; the message names the valid values | Fix the flag. |

## Billing

Headless claude (`claude -p`) bills metered API rates — the flat subscription does not cover it; that is what `--max-budget-usd` is for. `codex exec` bills the ChatGPT subscription.

Argv facts verified against claude 2.1.x / codex 0.142.x. After a CLI upgrade, an odd failure means re-checking `--help` before blaming the prompt.
