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
    /consult                 ← position taken, then fresh voices judge it → the settled direction
    /spike                   ← optional: throwaway code settles what the direction rests on
    /write-spec              ← the direction becomes a committed spec + validation consult
    …implement…              ← the host builds from the spec
    /review                  ← a cold session judges the committed range → the PR
/update-docs                 ← docs reconciled with the diff (may run mid-session too)
/handoff [next: …]           ← lessons + a brief in ~/dev/.handoffs, itself the next first prompt
  → brief start <slug> places the worktree and hands over the pointer
/distill-handoffs            ← after the merge: the spent brief deleted, its siblings settled
```

`/update-docs` and `/handoff` are separable on purpose: a routine change wants a
doc pass with no handoff; a mid-task stop wants a handoff with the doc pass
deferred. `/handoff` _contains_ the doc pass (it defers to the project's
update-docs skill) — never the reverse.

## The work loop — consult → build → review

The bookends carry knowledge between sessions; the work loop introduces
independent judgment inside one. An artifact's author is never its only judge.

| Checkpoint | Input → output |
|---|---|
| `/consult` | host position → independent designs → settled direction + continuable out-dir |
| `/spike` | one technical uncertainty → executable evidence → verdict that amends the direction |
| `/write-spec` | settled direction → committed design → validation consult |
| `/review` | committed range + design anchor → verified findings → merge verdict |

The host verifies outside findings against source; a peer is evidence, not
authority. Implementation is ordinarily the host's, with `/delegate` as the
explicit alternative. The `;;write-spec` snippet remains the paste-in escape
hatch.

Compact at artifact boundaries. Once a spec or committed range carries the
state, the exploration that produced it is disposable.

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

The brief **is** the next session's first prompt, not a document about the work:
`brief start <slug>` places the worktree and hands the session its pointer —
the invocation and the goal on line 1, the file's path on line 2. It lands at
`~/dev/.handoffs/<project>/<slug>.md`, outside every worktree and outside git,
carrying state, lessons and dead-ends with their _why_, and first moves.

Two rules are worth knowing even from outside: a gate decides up front whether
this is a full handoff, a brief-only stop, or a doc pass with no brief at all;
and the slug names the **next** session's branch, so one token serves as brief,
branch, worktree and PR lookup key.

The pointer's last line names the **pickup gate** — `build` or `design`,
`claude/.claude/skills/handoff/pickup/` — which fixes the receiving session's
first turn: no edits; a re-grounding written for the user, who picks a brief
up days after writing it; the brief's premises checked against the code;
and the next move named, usually `/consult`. `design` puts the problem and
the approach on trial (a fix brief's claimed cause included); `build` takes
the direction as settled and tries the premises and the scope.

Where the machinery lives and which repo owns which half: `docs/handoff.md`.

## The doc shape that keeps onboarding cheap

`docs/documentation-standards.md` owns the spine/satellite model, hot-path
budget, protected set, and verification checks. This loop supplies the cadence:
`/update-docs` reconciles one change; `/distill-docs` periodically reconciles
the tree.

## The periodic passes — `/distill-docs` and `/distill-handoffs`

Each per-change pass has a periodic twin that clears what per-change passes
cannot see: `/update-docs` ↔ `/distill-docs` over the doc tree,
`/handoff` ↔ `/distill-handoffs` over the brief folder. The handoff twin runs
mostly as a **closeout** — from the branch that just merged, deleting the
brief that spawned it and settling only the briefs that named it — and, from
the default branch, as the whole-folder reconcile; `docs/handoff.md` places
its machinery.

Update-docs is diff-scoped; distill-docs catches tree-wide duplication, stale
proposals, and misplaced mechanism. Run it when the hot-path budget flags an
overrun and otherwise in the weekly standing slot:

```text
sweep + redundancy map → owner-confirmed surgery → verify → fix the generator
```

Both passes defer to `docs/documentation-standards.md`.

A complaint about a tool the loop runs — `brief`, a skill, obelisk, a
snippet — is `/improve-tool <tool> [engine] [the complaint]`: a mining pass
over the sessions that used it, its verdicts interviewed, its rules landing
in `lessons/agent-tooling/usage-lessons.md`.

## Principles

```text
session knowledge → docs (durable model) or handoff (next-session state)
artifact boundary → compact or hand off
changed behavior → update-docs
merged branch → distill-handoffs
```

Point to claims the next session can verify. Wrap up at task boundaries; when
context is already heavy, write the brief before the doc pass because only the
brief needs this session's memory.
