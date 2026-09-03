# Prompt design patterns

Satellite of `tabtype/CLAUDE.md`. Read the section for the snippet family being
changed; `WORKFLOW.md` owns their order.

## Artifact altitude

| Artifact | Must decide | Deliberately leaves open |
|---|---|---|
| Analysis | real problem, goals, design bets, risk | committed interface and build tactics |
| Spec | behavior, module boundaries, seams, target shape, test strategy | code bodies, individual cases, fixtures, commit order |
| Plan | vertical slices, cases, fixtures, helper shape, line anchors | full code bodies |
| Review | correctness, integration, structure, test quality | approved product decisions unless code disproves them |

The spec is half technical. It chooses the public shape before the plan deepens
it. `design-it-twice` therefore belongs in `write-spec`; running it from
`tdd-plan` would challenge an interface after the artifact that owns it has
settled.

```text
product section  → goals and user-visible rules
technical section → boundaries + target shape + test seams
plan              → cases + fixtures + line-level tactics
```

## Analysis and questions

`think-holistic` fights a cold start: read the code, reframe the problem, compare
genuinely different structural bets, then account for hot-path and user-surface
risk. `step-back` is the midstream form: treat the current answer as a hypothesis
and try to break it.

Questions route by ownership:

```text
product/direction fork                 → ask the user, with recommendation
implementation choice                  → decide and record
technical unknown that preserves shape → park for consultation, with working answer
```

`elaborate-questions` rewrites a weak question so the user can decide without
reading the code. `risk-check` isolates the risk accounting when the direction
already exists.

## Reviews and responses

Review starts outside the implementation's framing:

```text
goal → settled constraints → actual code path → structure → local defects
```

`implementation-handoff` mirrors the axes the reviewer will inspect: outcome,
change map, decisions, deviations, tests, and risky areas. It is a map, not a
self-review.

`respond-review` uses an analysis gate because code changes are expensive:

```text
finding → verify → accept or rebut → test implication → proposed fix → wait
```

A confirmed bug asks why the suite stayed green: missing coverage or a weak
test. The answer may add, strengthen, or delete a test. The `*-again` pair drops
the broad analysis gate and converges on remaining valid findings.

## Midpoint checkpoints

Use the midpoint family for a large implementation whose remaining slices would
compound a structural mistake.

```text
midpoint-status  → completed / remaining / deviations / surprises
review-midpoint  → judge completed work + guide unreached work
respond-midpoint → fix now / fold into remaining slice / disagree
```

Unreached slices are intentionally absent, not defects. Weight foundational
problems highest because every remaining slice inherits them.

## Context resets

All context-reset prompts preserve conclusions and anchors, then discard the
journey. Their consumer decides the cut:

| Prompt | Preserve for |
|---|---|
| `compact-for-impl` | settled design, branch state, architectural why |
| `compact-for-review` | implementation state, critical files, decisions, friction |
| `compact-for-cleanup` | finished behavior and remaining small tasks |
| `compact-inflight` | exact live state of the same unfinished task |
| `generate-compact` | a session-specific compaction instruction |
| `brief-for-rewind` | the only state crossing a user-selected history rewind |

`generate-compact` writes the instruction for a later compaction pass;
`brief-for-rewind` writes the handoff itself. `resume-from-brief` supplies a
fixed posture: orient against the real diff, run only named checks, then resume.

## Tests across the workflow

```text
spec   → behaviors + interface under test + fake boundary
plan   → cases + fixtures
build  → red / green / refactor
review → signal quality, refactor survival, deletable tests
repair → why the old suite missed the defect
```

Testing detail arrives only when its phase can act on it. A mock of an owned
module is a design signal at spec time; an assertion or fixture belongs later.
