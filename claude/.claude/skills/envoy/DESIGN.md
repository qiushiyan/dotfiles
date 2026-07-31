# Design philosophy — /consult, /delegate & /review

The skill bodies say what to do; this file records **why** — the assumptions
and rejected alternatives a future redesign needs but can't see in the skills
themselves. Deliberately unlinked from any SKILL.md: runtime agents never
need it. It describes current state only; the history behind it lives in the
engine's evidence log (`~/dev/envoy/DESIGN.md`).

## The governing lesson

These skills replaced a tmux-pane cross-reviewer that screen-scraped a
provider CLI — watchers false-positiving on input prompts, a human typing
"seems it finished". The lesson that governs everything: **a screen is not
an API.** Sessions are driven headless and read back as data, never
`capture-pane`.

## Division of labor

- **The engine (`envoy`)** is deterministic mechanism: one turn in, files
  out, zero judgment — no retries, no review loops, no gates. Its help page
  and the shared [DISPATCH.md](DISPATCH.md) carry all mechanics, so the
  skill bodies never restate them.
- **The skills** are judgment procedures for the host: when to dispatch,
  what the prompt must contain, how to collect, verify, and route what
  comes back.
- **The prompt files** (brief / dispatch prompt) carry all task-specific
  intelligence. Templates hold the invariant scaffold so per-run authoring
  is only the judgment slots.

**Fold-back trigger:** if the engine ever wants review loops, gates, or
unattended-resilience machinery, it has outgrown a personal tool — reach for
duet instead. Don't grow the engine.

## Shared commitments

- **Human at every boundary.** Dispatch, collection, round 2, verdicts — a
  person (or the host acting in front of one) sits between every stage.
  That is what lets the engine stay judgment-free.
- **No model substitution, ever.** No `--model`/`--effort` → the provider's
  own config governs. The host never picks a model the user didn't name.
- **Independence picks the default provider.** The host is usually Claude
  Code, so a codex sidekick buys cross-family review for free; both bill a
  flat subscription, so cost isn't the tiebreaker. Default codex; claude is
  opt-in by name.
- **One brief, one job.** Several takes on one brief are a single
  `envoy fan` — one completion, so "one voice is back: wait or synthesize?"
  never becomes a question the host holds. Recovery stays per voice (a
  `partial` fan-out is acted on voice by voice); a follow-up round continues
  the whole set with `fan --resume-from`, or not at all.
- **Background is the default posture**; collection is notification-driven.
  Polling a background task is a smell — the one sanctioned read is the
  coordinate block right after dispatch — and watch is observation, never a
  completion signal: a quiet log means the model is thinking, and a busy one
  still proves nothing about completion.
- **Durable artifacts over stdout.** Files are authoritative; stdout is a
  convenience view of them.

## /consult — independent second opinions

- The host is the **lead**; voices are peers, not authorities. The product
  is the host's synthesis — adopt what survives scrutiny, rebut with
  reasons, present unresolvable forks to the user. Silently deferring to the
  voice and silently overriding it are equal failures.
- **Independence is the payload.** Every voice gets the same brief and never
  another voice's output; a fan-out keeps that true by construction. The
  host still judges point by point rather than counting agreement — voices
  sharing a blind spot or the brief's framing look exactly like voices
  confirming each other.
- Two modes with opposite information hygiene, one shared failure model
  (*the voice anchored on what it should have judged*):
  - **Design mode** — the host's proposal is withheld; an anchored voice
    critiques instead of designing.
  - **Review mode** — the artifact is handed over, but settled direction is
    fenced off ("decided, not up for relitigation") with an evidence-gated
    escape hatch for foundational objections; an unfenced voice relitigates
    instead of executing.
- **Round 2 resumes the same session** — fresh would restart from zero; a
  fan-out continues whole. Optional: handing the user the takeover command
  is the cheap substitute.

## /delegate — implement a written spec

- **The spec is the entry ticket and is out of scope.** Delegation quality
  is mostly spec quality; the skill can't fix a bad spec and doesn't try.
- **The audience model: a senior engineer who hasn't made the journey.**
  Capability is assumed — no babysitting, no how-to — but the exploration
  behind the spec is not, so the dispatch prompt's real cargo is the
  hard-won context the conversation paid for. *Transfer context, not
  competence.*
- The dispatch prompt owns exactly two things, and nothing the spec owns:
  **task instructions** (baseline, commit discipline, conventions, checks,
  report shape) and **onboarding** (the reading list, the key files, the
  hard-won context). WHAT lives in the spec; HOW lives in the prompt.
- **Clean baseline is the load-bearing invariant** — it makes the review
  diff exact and the work revertible. Same-tree dispatch +
  host-freezes-its-hands is the default; a worktree is opt-in, because a
  fresh one lacks installed dependencies and env files.
- **The handoff report is shaped by the review that consumes it**: each
  section pre-loads an evaluation axis; where-to-look-hardest points but
  never self-grades. Test results account for every test file *touched*,
  not just suites run — an edited-but-never-run suite is invisible inside a
  "tests pass" claim.
- **Trust but verify:** the host re-runs the project's checks itself,
  always.

## /review — independent review of committed work

- **The mirror of /delegate, and the invariant both serve:** whoever wrote
  the code never gets to be its only reviewer.
- **The brief makes a warm review cold-startable.** An in-conversation
  reviewer holds the spec, plan, and range already; a fresh session must be
  handed them explicitly — authority paths, a settled-decisions fence, the
  commit range, a do-not-flag list. Industry echo (Cloudflare, 131k+ review
  runs): "what not to flag" is where prompt value concentrates, and
  evidence-gating (cite code or don't report) is the strongest
  false-positive filter.
- **Report by provenance.** The reviewer's map comes from wherever the work
  came from: delegate → its handoff report verbatim; host-built → written
  fresh in the handoff shape; user-built → reconstructed from commits and
  labeled as such.
- **Judge pass before any fix.** Findings hallucinate with full confidence;
  the host re-verifies each against the code. The host's conflict of
  interest cuts both ways: agreeable adoption and defensive rebuttal are
  equal failures.
- **Strategic-over-tactical posture leads the brief.** Reviewers' default
  failure is optimizing inside the implementation's frame — a local
  optimum — instead of stepping back to the reshape. The fence bounds it:
  shape of the code, never settled product decisions.
- **No agreement-weighting across multiple reviewers** — the host's judge
  pass already is the aggregator.

## Deliberately not built

- No daemon, polling status command, or cancel service — Bash background
  tasks remain the live job layer. `envoy pending` is only a recovery index
  over durable job files after a notification may have been missed.
- No prompt-templating engine — templates are markdown files the host edits
  with judgment.
- No effort aliases, no model fallbacks, no automatic provider selection.
- No activity-based "hung" detector. Healthy reasoning and stalled work
  overlap in silence; the wall-clock cap is only a safety bound. Timeout
  policy follows task scale — consult 30, review 60, delegate 180 minutes —
  and applies equally to resumed turns.

## The improvement loop

Real usage is the test bench: the engine repo's `usage-lab` skill mines the
central job store and session transcripts for friction — workarounds,
hand-rolled repetition, drift between skills and installed binary,
unexercised margins — and routes each finding to an engine change, a skill
change, or a recorded lesson. Findings land here as current state; their
history lands in the engine's evidence log.
