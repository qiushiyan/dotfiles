# Claude Code auto-compaction

Claude Code summarizes older history in place once a session's context crosses a
threshold. The threshold is a **window size in tokens**, set in
`claude/.claude/settings.json` — which every account's `~/.claude` symlinks to,
so one number governs every `x` launcher (`docs/claude-accounts.md`).

## TL;DR

```jsonc
"autoCompactEnabled": true,
"autoCompactWindow": 833000,   // compaction fires at 800k — 80% of a 1M window
```

The trigger is derived, not written:

```
effective = min(model_window, autoCompactWindow) − min(model_max_output, 20_000)
threshold = effective − 13_000
```

833000 on a 1M model reserves 20k for the reply and 13k for the summary, landing
the trigger on 800k. Claude Code caps the window at the model's own, so the same
number on a 200k model collapses to the stock trigger (~83.5%) instead of
breaking.

Supported surfaces, highest priority first: `CLAUDE_CODE_AUTO_COMPACT_WINDOW`,
`claude --autocompact`, `/autocompact`, the `autoCompactWindow` setting
(`code.claude.com/docs/en/model-config`). All take 100k–1M.

## The load-bearing fact: naming a window is what enforces the threshold

A model at 1M runs **reactive** on its default window — no proactive pass, the
session grows until the API rejects it for length. What switches a session to an
enforced threshold is where the window came from, not what it is:

| Window source | Threshold |
|---|---|
| `autoCompactWindow`, or `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | enforced |
| model default at 1M | reactive — the trigger never fires |

So a percentage alone cannot deliver a threshold on a 1M model: there is nothing
to take a percentage of until a window is named. Setting the window is the lever;
any percentage rides on top of it.

## Trap: the `env` block does not reach the setting

`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` (1–100, and it can only *lower* the trigger,
never raise it past the derivation above) is read from the process environment.
Placed in the `env` block of `settings.json` it reaches subprocesses only —
Claude Code's own threshold logic never sees it, and nothing reports the miss. It
has to come from the parent shell, which for these launchers means
`zsh/.config/zsh/claude.zsh`.

`autoCompactWindow` has no such split: it is a settings key, read from the
settings file.

## Why the window setting over the percentage variable

`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80` exported from `claude.zsh` reaches the same
target and reads more directly. The setting wins because it survives a launch
that bypasses `x`, depends on no export ordering, stays one tracked file, and is
the thing that moves a 1M session out of reactive mode at all.

## Verify

The derivation and the reactive predicate are read out of the shipped binary, so
a Claude Code upgrade can move them — the same class of drift `x-check` covers
for headroom (`docs/claude-accounts.md`).

```bash
# the summary buffer and the percentage clamp, straight out of the binary
strings -a "$(readlink -f "$(command -v claude)")" | grep -o '.\{34\}testPctOverride.\{120\}' | head -1

# the file parses and the key is accepted — an unknown key prints a settings warning
claude -p ok --model haiku
```

In a session, `/context` counts down to the configured window rather than the
model limit. Settings are read at startup, so a running session keeps the
threshold it booted with.
