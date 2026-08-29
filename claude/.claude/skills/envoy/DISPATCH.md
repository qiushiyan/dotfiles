# Dispatching envoy turns

`envoy` runs a headless AI-session **turn** — a fresh `claude` or `codex` session — and returns it as files, `result.md` being the return value. `envoy turn` runs one; `envoy fan` runs one per model on the same brief and supervises them as a single job; `envoy steer` routes a late supplement to a job already dispatched. Mechanics, flags, and recovery semantics: `envoy -h`.

A turn starts **cold**: it has none of this conversation. Everything it needs lives in the prompt file.

## The loop

```sh
# 1. dispatch — always exactly one Bash run_in_background task, with a
#    coordinate file at a path only this dispatch uses (the scratchpad)
C=<scratchpad>/consult.coords
envoy turn --provider codex --prompt-file <brief> --timeout-min 30 --label consult --coordinate-file $C

# ...or, for the same brief on several models, still exactly one task
envoy fan --prompt-file <brief> --with codex --with claude:opus --timeout-min 30 --label consult --coordinate-file $C

# 2. read the coordinates once — the file is the startup block a background
#    task's stdout keeps hidden until it exits
until [ -s $C ]; do sleep 1; done; cat $C
#    relay out-dir and watch to the user, then return

# 3. collect on the task-completion notification, once
envoy collect <out-dir>
```

Between dispatch and the notification the turn is on its own: no polling, no tailing, no second dispatch. Other work is fine while you wait, as long as it stays out of the turn's tree. The coordinate file is the one read that belongs to this dispatch; the harness's task output and `envoy jobs`'s newest row can belong to another.

**Collect once.** A long collect output the harness persists to a file is read from that file or from `result.md` *afterwards*: collecting is what stamps `collectedAt`, and an unstamped job stays owed in `envoy pending` for the life of the project.

**When the notification may be lost** (a compaction, a restart, or "while you wait, do X" finished first and nothing arrived), in this order and no further than needed:

1. `envoy pending` once, and do what each job's `next:` line says. It lists jobs needing attention — a terminal job never collected, a dead runner — and omits a job that is provably still live, so an empty list means "nothing to do yet", not "nothing running".
2. If it named nothing and the background task handle still exists, block on that task with the harness's Monitor tool — the completion signal is the process exiting.
3. Only when the handle is gone but the out-dir survives, Monitor for a **positive** terminal observation; a negated test (`! grep running`) also passes on a missing file:
   - a turn: `until grep -Eq '"status": "(ok|failed|infra|timeout|interrupted|abandoned)"' <out-dir>/meta.json; do sleep 30; done`
   - a fan-out: `until grep -q '"endedAt": "' <out-dir>/group.json; do sleep 30; done`
4. If Monitor times out or the files turn unreadable, `envoy pending` again.

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
# session, the rest start cold — one fan-out, one collect. A consult that
# ran as a fan-out holds one session per member, so the flag names a member
# dir (<consult-out-dir>/codex)
envoy fan --prompt-file review-brief.md --with-from <consult-out-dir>/codex --with claude:opus --timeout-min 60 --label review

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
# Recovery only — the dispatch handoff is the coordinate file.
envoy jobs
```

## House rules

- **Cross-family by default.** codex, because the host is usually claude, and a different model family is the independence being bought. A claude turn runs only on a model the user named.
- **No model substitution.** Omitting `--model`/`--effort` hands the choice to the user's provider config; relay `(provider default)` literally rather than guessing what ran.
- **One brief, however many models.** Several takes on one question is a single `envoy fan`, never several dispatches: one task to wait on, one collect, and the members still never see each other's output — that is what keeps their takes independent. Different briefs mean different turns.
- **A non-`ok` status is a fork in the road, not a failure to retry.** Collect it and do what its `next:` line says: envoy knows whether the provider accepted the prompt, which is what separates a safe retry from duplicated work. A capped or failed block's `provider stream:` line tells a link that dropped mid-turn (reconnect events, first and last observed) from a provider that stalled (quiet, none) — useful for the report, while the recovery line still governs: `accepted` means resume, once the network is back.
- **A fan-out's members are independent turns.** Exit `6 partial` means some returned a result and some did not — act member by member from each section's own `next:` line. One member's outcome licenses nothing about another, and recovery is never group-wide. A follow-up *round* is not recovery: `envoy fan --resume-from` continues the whole set on one NEW prompt, and is refused unless every member can continue.
- **A supplement is a follow-up turn, not an interruption.** No provider accepts input into a running turn, so `envoy steer` answers "not delivered" by design, plus the exact follow-up command carrying your file — collect the job, then run it. Never re-dispatch the original prompt with the supplement folded in: the session already accepted the original.
- **Read-only is a prompt convention.** Without `--allow-write` the turn cannot edit, but "analyse only, change nothing" still belongs in the brief. Fan-outs are read-only outright (members share one tree); parallel work that writes means a worktree and a separate turn each.
