# Dispatching envoy turns

`envoy` runs a headless AI-session **turn** — a fresh `claude` or `codex` session — and returns it as files, `result.md` being the return value. `envoy turn` runs one; `envoy fan` runs one per model on the same brief and supervises them as a single job; `envoy steer` routes a late supplement to a job already dispatched. Mechanics, flags, and recovery semantics: `envoy -h`.

A turn starts **cold**: it has none of this conversation. Everything it needs lives in the prompt file.

## The loop

```sh
# 1. dispatch — always exactly one Bash run_in_background task
envoy turn --provider codex --prompt-file <brief> --timeout-min 30 --label consult

# ...or, for the same brief on several models, still exactly one task
envoy fan --prompt-file <brief> --with codex --with claude:opus --timeout-min 30 --label consult

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

# one brief, two model families — one background task, one collect
envoy fan --prompt-file brief.md --with codex --with claude:opus --timeout-min 30 --label consult

# a fan-out member is provider[:model[:effort]] — two models of one family
envoy fan --prompt-file brief.md --with claude:opus:high --with claude:sonnet --timeout-min 30

# a turn that writes code, anchored for the review diff
envoy turn --provider codex --allow-write --baseline "$(git rev-parse HEAD)" \
  --prompt-file prompt.md --timeout-min 180 --label delegate

# a turn in a worktree, so the user keeps editing meanwhile
envoy turn --provider codex --allow-write --cwd ../wt-feature ...

# round 2 — same session, NEW prompt file (collect prints this command for you)
envoy turn --provider codex --resume <session> --prompt-file round2.md --timeout-min 30

# round 2 for a fan-out — the whole set on one NEW prompt, as one new fan-out
# (roster, sessions, cwd, baseline all read from the original's records)
envoy fan --resume-from <fan-out-dir> --prompt-file round2.md --timeout-min 30

# a later phase continues an earlier phase's session (a review picking up a
# consult, say) — session and settings read from the finished job's records,
# so nothing depends on a remembered session id that may have gone stale
envoy turn --resume-from <consult-out-dir> --prompt-file review-brief.md --timeout-min 60 --label review

# a warm voice beside a cold one: one member continues a finished job's
# session, the rest start cold — one fan-out, one collect
envoy fan --prompt-file review-brief.md --with-from <consult-out-dir> --with claude:opus --timeout-min 60 --label review

# rare: a supplement for an already-dispatched job ("forgot to mention X")
envoy steer --prompt-file supplement.md <out-dir>   # out-dir omitted = newest job

# the payload alone (a non-ok job prints its full block instead — its status
# IS the result then)
envoy collect --result-only <out-dir>

# everything but the payload: settings, tokens, prompt state, log paths — the
# diagnostics an ok job's own block holds back. Stamps nothing, so the result
# stays owed.
envoy collect --status-only <out-dir>

# after a restart or compaction that may have eaten a notification
envoy pending

# lost the out-dir? list this project's jobs, newest first, with the dir each
# one takes — never rebuild a job path from the stamp, which only the dispatch
# knew. `envoy collect` with no dir also means "this project's newest job".
envoy jobs
```

## House rules

- **Cross-family by default.** codex, because the host is usually claude, and a different model family is the independence being bought. A claude turn runs only on a model the user named.
- **No model substitution.** Omitting `--model`/`--effort` hands the choice to the user's provider config; relay `(provider default)` literally rather than guessing what ran.
- **One brief, however many models.** Several takes on one question is a single `envoy fan`, never several dispatches: one task to wait on, one collect, and the members still never see each other's output — that is what keeps their takes independent. Different briefs mean different turns.
- **A non-`ok` status is a fork in the road, not a failure to retry.** Collect it and do what its `next:` line says: envoy knows whether the provider accepted the prompt, which is what separates a safe retry from duplicated work.
- **A fan-out's members are independent turns.** Exit `6 partial` means some returned a result and some did not — act member by member from each section's own `next:` line. One member's outcome licenses nothing about another, and recovery is never group-wide. A follow-up *round* is not recovery: `envoy fan --resume-from` continues the whole set on one NEW prompt, and is refused unless every member can continue.
- **A supplement is a follow-up turn, not an interruption.** No provider accepts input into a running turn, so `envoy steer` answers "not delivered" by design, plus the exact follow-up command carrying your file — collect the job, then run it. Never re-dispatch the original prompt with the supplement folded in: the session already accepted the original.
- **Read-only is a prompt convention.** Without `--allow-write` the turn cannot edit, but "analyse only, change nothing" still belongs in the brief. Fan-outs are read-only outright (members share one tree); parallel work that writes means a worktree and a separate turn each.
