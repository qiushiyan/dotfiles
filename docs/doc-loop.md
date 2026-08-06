# The doc loop — onboarding → work → handoff

How durable knowledge crosses coding-agent sessions: **the project's docs are the
memory; each session deserializes them at start (onboarding) and serializes what
it learned at end (update-docs / handoff)**. Sessions are ephemeral; a fresh
session with a distilled artifact beats a long session with `/compact`. Between
those bookends the work has its own checkpoints, each buying a judgment this
session cannot make about itself and leaving an artifact the next phase reads.
All checkpoints are user-triggered by design — the skills never fire themselves.

## The loop

```
/onboarding <topic>          ← first prompt: spine reads + topic-scoped deep dive
    /consult                 ← position taken, then fresh voices judge it → the plan
    /spike                   ← optional: throwaway code settles what the plan rests on
    …implement…              ← the host builds from the synthesis
    /review                  ← a cold session judges the committed range → the PR
/update-docs                 ← docs reconciled with the diff (may run mid-session too)
/handoff [next: …]           ← lessons + a baton in ~/dev/.handoffs, itself the next first prompt
  → new worktree, pbcopy < the baton, paste — line 1 fires /onboarding <topic>
```

`/update-docs` and `/handoff` are separable on purpose: a routine change wants a
doc pass with no handoff; a mid-task stop wants a handoff with the doc pass
deferred. `/handoff` _contains_ the doc pass (it defers to the project's
update-docs skill) — never the reverse.

## The work loop — consult → build → review

The bookends carry knowledge across sessions; these three carry **independent
judgment** into one. Their shared invariant: whoever authored a thing never gets
to be its only judge — of the design (`/consult`) or of the code (`/review`).
Both dispatch fresh sessions through `envoy`; both make the host verify every
finding against the code and answer to the user for each verdict, because a
voice is a peer, not an authority.

- **`/consult`** — before code. The host works the user's answers and new
  requirements through _first_ and lands on a position it would defend; only then
  do the voices weigh in. Design mode keeps that position out of the brief so the
  voices design unanchored; review mode puts it in as the artifact under review.
  Output: the plan, plus an out-dir that stays continuable.
- **`/spike`** — optional, only when asked. Throwaway code on a simplified
  foundation, where the thing under test stays real and everything around it is
  faked, settling one question the plan leans on that reading cannot answer.
  Output: a verdict that amends the plan — or kills it, and sends the shape back
  to `/consult`.
- **`/review`** — after the range is committed. Fresh-eyes when nothing outside
  the implementation ever judged the design; spec-anchored when a consult or an
  approved spec settled it. A consult in this session means the review defaults
  to a fan-out: that voice warm (`--with-from <out-dir>`, the best judge of
  follow-through) beside a cold one (the strategic read). Naming the consult
  out-dir in the synthesis is what keeps that seam available.

Implementation between them is ordinarily the host's, straight from the
synthesis — `/delegate` is the alternative, and the reason `/review` asks where
the implementation report came from. Compacting is safest at the phase joins,
after the plan is written and after the range is committed: the artifact each
phase leaves is what makes the context it consumed disposable, which is the same
reason a distilled artifact beats a long session.

## The commands, by project

| Project | Onboard | Wrap up |
|---|---|---|
| duet | `/onboarding [harness \| providers \| prompts \| surface \| design]` | project `/update-docs`, global `/handoff` |
| itell (`apps/platform`) | `/onboarding [topic]` | project `/update-docs`, global `/handoff` |
| planlab — Loopy agent/triage | `/pl-loopy-onboarding [agent \| triage]` | `/pl-loopy-update-docs` |
| planlab — infra migration | `/pl-loopy-infra-onboarding [topic]` | `/pl-loopy-infra-handoff` (global `/handoff` defers to it) |
| anywhere else | read the docs tree by hand | global `/update-docs`, global `/handoff` |

Global skills live in `claude/.claude/skills/{update-docs,handoff}/` (this repo);
project skills in each repo's `.claude/skills/`. Both globals defer to a
project's own skill or `documentation-standards.md` when present.

## The handoff (`/handoff`, `~/dev/.handoffs`)

The baton **is** the next session's first prompt, not a document about the work:
new worktree → `pbcopy <` the baton → paste, and line 1 is the `/onboarding`
invocation. It lands at `~/dev/.handoffs/<repo>/<slug>.md`, outside every
worktree and outside git, carrying state, lessons and dead-ends with their
_why_, and first moves.

Two rules are worth knowing even from outside: a gate decides up front whether
this is a full handoff, a baton-only stop, or a doc pass with no baton at all;
and the slug names the **next** session's branch, so one token serves as baton,
branch and worktree (`gwt <slug>`).

Path derivation, slug edge cases, and the honesty floor:
`docs/handoff.md`.

## The doc shape that keeps onboarding cheap

Onboarding cost is doc-tree shape, not skill wording. Each project encodes this
contract in its own `documentation-standards.md`, enforced by its update-docs
verify step; this repo has no such file, so these paragraphs are its contract
and the global skills' standards apply:

- **Spine / satellites.** The always-read Phase-1 set carries the mental model —
  principles, vocabulary, workflows, invariants; mechanism lives in topic
  satellites that onboarding Phase 2 routes to. A spine section that grows past
  its mental model is a split waiting to happen.
- **Budget: ~100KB (`wc -c`) for the Phase-1 set** — roughly 25k tokens, well
  under 10% of the window after overhead. The update-docs skill's verify step
  measures it and must flag an overrun, naming the split candidate, even when the
  split is deferred. Exceeding it is allowed only as a recorded decision, never
  as drift.
- **duet is the reference implementation**, and itell already has the shape —
  both separate repos, so their satellite names live there rather than here.

## The periodic pass — `/distill-docs`

Update-docs is diff-scoped, so cross-doc duplication and rot in untouched files
accumulate in the seams no matter how disciplined the per-change passes are —
duet accumulated duplicate copies of one key list, and two shipped specs left
sitting beside the design docs, across many update-docs runs. Roughly monthly, or
when update-docs' budget check flags an overrun, run the global `/distill-docs`:
mechanical sweeps and a delegated redundancy map → owner-confirmed surgery →
verify → a _fix-the-generator_ step that patches the project's standards or
update-docs skill whenever a rot class recurs. It defers to each project's
`documentation-standards.md`, including its protected exceptions.

## Principles

- **Docs lead, code follows; sessions evaporate.** Anything worth keeping lands
  in the docs (durable, shared) or the handoff (session-to-session bridge) —
  never only in a transcript.
- **Every edit nets tighter.** Adding content is the moment to cut; deletion is
  maintenance; spotlight the load-bearing, let the code hold the inventory.
- **Point, don't pre-chew.** Onboarding and handoffs hand the next session
  pointers and claims-to-verify, not answers — verification is what makes the
  knowledge its own.
- **Wrap up at task boundaries, not context exhaustion.** Past ~50% window, write
  the baton first (it needs the session's memory) and run the doc pass fresh (it
  only needs the diff).
