# Dispatching envoy turns

`envoy` runs a headless AI-session **turn** — a fresh `claude` or `codex` session — and returns it as files, `result.md` being the return value. `envoy turn` runs one; `envoy fan` runs one per model on the same brief and supervises them as a single job; `envoy steer` routes a late supplement to a job already dispatched. Mechanics, flags, and recovery semantics: `envoy -h`.

A turn starts **cold**: it has none of this conversation. Everything it needs lives in the prompt file.

**Codex default: `gpt-6-astra`.** `codex/.codex/config.toml` in dotfiles (linked as `~/.codex/config.toml`) owns the model and reasoning effort. The default patterns below omit `--model` and `--effort` to inherit that config, including `--with codex` in a fan-out. Honour an explicit user override; continuations keep their recorded settings. Consult, review, and delegate share this recommendation.

## The loop

```sh
# 1. dispatch — exactly one Bash run_in_background task, with a coordinate
#    file minted for this dispatch (a reused path may still hold last round's block)
C=$(mktemp <scratchpad>/coords.XXXXXX)
envoy turn --provider codex --prompt-file <brief> --timeout-min 30 --label consult --coordinate-file $C
# ...or one fan-out for the same brief on several models — still one task
envoy fan --prompt-file <brief> --with codex --with claude:opus --timeout-min 30 --label consult --coordinate-file $C

# 2. read the coordinates once — the startup block a background task's stdout
#    hides until it exits; still empty after the bound = dispatch refused, read the task output
for i in $(seq 30); do [ -s $C ] && break; sleep 1; done; cat $C
#    relay out-dir and watch, then return

# 3. collect once, on the task-completion notification; re-read a persisted
#    output or result.md afterwards (collecting stamps collectedAt)
envoy collect <out-dir>
```

Between dispatch and the notification the turn is on its own: no polling, no tailing, no second dispatch; other work is fine outside the turn's tree. The coordinate file is the only read that belongs to this dispatch — the harness's task output and `envoy jobs`'s newest row can belong to another.

**When the notification may be lost** — a compaction, a restart, "while you wait, do X" finished first — go down this list only as far as needed:

```sh
# 1. what needs attention now, each with its next: line — a provably live job
#    is omitted, so an empty list means "nothing to do yet", not "nothing running"
envoy pending

# 2. the task handle still exists → Monitor that task; the process exiting is completion

# 3. handle gone, out-dir known → Monitor for a POSITIVE terminal observation
#    (a negated test also passes on a missing file)
until grep -Eq '"status": "(ok|failed|infra|timeout|interrupted|abandoned)"' <out-dir>/meta.json; do sleep 30; done   # turn
until grep -q '"endedAt": "' <out-dir>/group.json; do sleep 30; done                                                    # fan-out

# 4. Monitor timed out or files unreadable → envoy pending again
```

## Patterns

`<fresh>` is a coordinate file allocated for that dispatch alone, as the loop does (`mktemp`).

```sh
# the default: one codex turn, inheriting gpt-6-astra from the user's config
envoy turn --provider codex --prompt-file brief.md --timeout-min 30 --label consult --coordinate-file <fresh>

# pin Astra when the command must select it independently of provider config
envoy turn --provider codex --model gpt-6-astra --prompt-file brief.md --timeout-min 30 --coordinate-file <fresh>
# the corresponding fan-out member: --with codex:gpt-6-astra

# a claude turn — the user names the model; yours is not a default
envoy turn --provider claude --model opus --prompt-file brief.md --timeout-min 60 --label review --coordinate-file <fresh>

# effort, when the user names one
envoy turn --provider codex --effort xhigh --prompt-file brief.md --timeout-min 60 --coordinate-file <fresh>

# one brief, two model families — one background task, one collect
envoy fan --prompt-file brief.md --with codex --with claude:opus --timeout-min 30 --label consult --coordinate-file <fresh>

# a fan-out member is provider[:model[:effort]] — two models of one family; the model
# slot takes a pinned id (claude-fable-5-1) or a provider alias (opus = its latest Opus)
envoy fan --prompt-file brief.md --with claude:claude-fable-5-1:high --with claude:opus --timeout-min 30 --coordinate-file <fresh>

# a turn that writes code, anchored for the review diff
envoy turn --provider codex --allow-write --baseline "$(git rev-parse HEAD)" \
  --prompt-file prompt.md --timeout-min 180 --label delegate --coordinate-file <fresh>

# a turn in a worktree, so the user keeps editing meanwhile
envoy turn --provider codex --allow-write --cwd ../wt-feature ...

# round 2 — same session, NEW prompt file (collect prints this command for
# you; every background dispatch takes its own coordinate file)
envoy turn --provider codex --resume <session> --prompt-file round2.md --timeout-min 30 --coordinate-file <fresh>

# round 2 for a fan-out — the whole set on one NEW prompt, as one new fan-out
# (roster, sessions, cwd, baseline all read from the original's records)
envoy fan --resume-from <fan-out-dir> --prompt-file round2.md --timeout-min 30 --coordinate-file <fresh>

# a later phase continues an earlier phase's session (a review picking up a
# consult, say) — session and settings read from the finished job's records,
# so nothing depends on a remembered session id that may have gone stale
envoy turn --resume-from <consult-out-dir> --prompt-file review-brief.md --timeout-min 60 --label review --coordinate-file <fresh>

# a warm voice beside a cold one: one member continues a finished job's
# session, the rest start cold. A fan-out consult holds one session per
# member, so --with-from names a member dir
envoy fan --prompt-file review-brief.md --with-from <consult-out-dir>/codex --with claude:opus --timeout-min 60 --label review --coordinate-file <fresh>

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

# lost the out-dir? this project's jobs, newest first, each with its dir
# (recovery only — the dispatch handoff is the coordinate file)
envoy jobs
```

## House rules

- **Cross-family by default.** codex, because the host is usually claude, and a different model family is the independence being bought. A claude turn runs only on a model the user named.
- **No model substitution.** Omitting `--model`/`--effort` hands the choice to the user's provider config; relay `(provider default)` literally rather than guessing what ran.
- **One brief, however many models.** Several takes on one question is a single `envoy fan`, never several dispatches: one task to wait on, one collect, and the members still never see each other's output — that is what keeps their takes independent. Different briefs mean different turns.
- **A non-`ok` status is a fork in the road, not a failure to retry.** Collect it and do what its `next:` line says: envoy knows whether the provider accepted the prompt, which is what separates a safe retry from duplicated work. A `provider stream:` line is the count of reconnect events the provider itself reported, first and last observed — relay the count; it settles neither why the turn went quiet nor whether the link is back. The recovery line governs: `accepted` means resume.
- **A fan-out's members are independent turns.** Exit `6 partial` means some returned a result and some did not — act member by member from each section's own `next:` line. One member's outcome licenses nothing about another, and recovery is never group-wide. A follow-up *round* is not recovery: `envoy fan --resume-from` continues the whole set on one NEW prompt, and is refused unless every member can continue.
- **A supplement is a follow-up turn, not an interruption.** No provider accepts input into a running turn, so `envoy steer` answers "not delivered" by design, plus the exact follow-up command carrying your file — collect the job, then run it. Never re-dispatch the original prompt with the supplement folded in: the session already accepted the original.
- **Read-only is a prompt convention.** Without `--allow-write` the turn cannot edit, but "analyse only, change nothing" still belongs in the brief. Fan-outs are read-only outright (members share one tree); parallel work that writes means a worktree and a separate turn each.
