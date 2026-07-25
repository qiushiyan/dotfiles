# Dispatching envoy turns

`envoy` runs one headless AI-session **turn** — a fresh `claude` or `codex` session — and returns it as files, `result.md` being the return value. Mechanics, flags, and recovery semantics: `envoy -h`.

A turn starts **cold**: it has none of this conversation. Everything it needs lives in the prompt file.

## The loop

```sh
# 1. dispatch — always exactly one Bash run_in_background task
envoy turn --provider codex --prompt-file <brief> --timeout-min 30 --label consult

# 2. relay the coordinate block it prints (out-dir, provider, session, watch, next), then return

# 3. collect on the task-completion notification
envoy collect <out-dir>
```

Between dispatch and the notification the turn is on its own: no polling, no tailing, no second dispatch. Other work is fine while you wait, as long as it stays out of the turn's tree.

## Patterns

```sh
# the default: one codex turn, the user's provider config picks the model
envoy turn --provider codex --prompt-file brief.md --timeout-min 30 --label consult

# a claude turn — the user names the model; yours is not a default
envoy turn --provider claude --model opus --prompt-file brief.md --timeout-min 60 --label review

# effort, when the user names one
envoy turn --provider codex --effort xhigh --prompt-file brief.md --timeout-min 60

# a turn that writes code, anchored for the review diff
envoy turn --provider codex --allow-write --baseline "$(git rev-parse HEAD)" \
  --prompt-file prompt.md --timeout-min 180 --label delegate

# a turn in a worktree, so the user keeps editing meanwhile
envoy turn --provider codex --allow-write --cwd ../wt-feature ...

# round 2 — same session, NEW prompt file (collect prints this command for you)
envoy turn --provider codex --resume <session> --prompt-file round2.md --timeout-min 30

# after a restart or compaction that may have eaten a notification
envoy pending
```

## House rules

- **Cross-family by default.** codex, because the host is usually claude, and a different model family is the independence being bought. A claude turn runs only on a model the user named.
- **No model substitution.** Omitting `--model`/`--effort` hands the choice to the user's provider config; relay `(provider default)` literally rather than guessing what ran.
- **One brief per turn.** Parallel turns get the same brief and never each other's output — that is what keeps their takes independent.
- **A non-`ok` status is a fork in the road, not a failure to retry.** Collect it and do what its `next:` line says: envoy knows whether the provider accepted the prompt, which is what separates a safe retry from duplicated work.
- **Read-only is a prompt convention.** Without `--allow-write` the turn cannot edit, but "analyse only, change nothing" still belongs in the brief.
