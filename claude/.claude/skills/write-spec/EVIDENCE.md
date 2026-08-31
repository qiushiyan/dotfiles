# write-spec — evidence log

## 2026-08-31 — founding pass (improve-tool over the snippet family)

Corpus: obelisk index through 2026-08-31; signatures = each snippet's
distinctive phrase in user text (`%wherever this project conventionally
keeps specs%` for write-spec). A codex consult
(`~/.local/state/envoy/jobs/dotfiles-4f711dad/20260831-231951-consult`)
independently re-ran the mining; its corrections are folded in below.

Usage shape:

| snippet | msgs / sessions | window |
|---|---|---|
| write-spec (current text) | 33 / 29 | 08-06 → 08-30 |
| compact-for-impl | 46 / 20 | 08-06 → 08-30 |
| update-spec | 33 / 15 | died 07-07 |
| review-spec-again | 20 / 11 | died 07-03 |
| update-spec-again | 12 / 9 | died 07-07 |
| review-spec | 2 / 2 | died 06-25 |
| compact-for-plan | 1 / 1 | 07-03, once |

Frictions and verdicts:

- **F1 — hand-typed preamble, 33/33 invocations** ("general mindset below,
  adapt as you see fit"). Verdict: this skill; the adapt/simplify license is
  standing in the body.
- **F2 — post-spec choreography manual.** Riders: commit 5/33, bundled
  validation consult 5/33, validation consult as the next turn 5/33
  (codex counts); immediate `/compact` next in 17/17. Rider sessions
  executed fully without further prompting (6–12 envoy calls, e.g.
  361f63c6, 8c728f33). Verdict (user): **commit + validation consult
  hardcoded as defaults**, free-text arguments override; the consult is
  warm (continuing the session's prior consult, 26/29 sessions had one) or
  fresh (3/29 had none); **no compaction instructions** — stage transitions
  are the user's, never the skill's; the skill never dispatches envoy
  directly — it invokes `/consult`.
- **F3 — dead limbs.** Round-2 snippet chain superseded by `/consult` since
  early July; compact-for-plan dead (the plan stage collapsed into the
  spec). Verdict: deleted review-spec, update-spec, review-spec-again,
  update-spec-again, compact-for-plan from the tabtype config; the
  write-spec snippet **kept** as the paste-in escape hatch; doc-loop.md's
  stale plan-stage language replaced.
- **F4 — per-project riders** (issue-first 5/4, branch handling 4/3,
  cross-repo ordering, standards riders 3/3). Verdict: outside the skill —
  free-text arguments and project workflows own them. Spec-location
  detection already works (20/20 recent specs in the conventional dir); the
  skill spends one line on it plus a read of documentation-standards.md
  when present.
- **PR boundaries** (user vision + codex-refined): pushback toward one PR
  in 8 msgs / 6 sessions (9b313950, 2ef842f1, f10869c8, 024a9e0e,
  42ebd772, fcf7bce5). Doctrine: one PR **and one session** by default;
  phases across ≤2 sessions on one branch as the rare escalation (PlanChat
  exemplar, 2ef842f1 → f4d85b55); multiple PRs only when every intermediate
  PR is independently correct *and* a concrete constraint benefits from the
  seam (cross-repo receipt: 95c0ad90). Landed as
  `lessons/collaboration/pr-boundaries.md`; reach is the skill's Scope
  pointer only, by user decision — see re-measure below.
- **Emphasis heuristics** (user vision, codex-reframed): the axis is where
  the change's load-bearing novelty lives, with refactor → structure/API
  and feature → product as worked examples, explicitly inspirations rather
  than a taxonomy (receipt for the refactor example: PlanChat round-2 rider
  "naming and model structures are very important", 2ef842f1).

Non-frictions (measured): spec quality — corrections after write-spec are
substantive design steering, not process repairs; a spec-shortfall sweep in
implementing sessions came back near-empty. Specs are read by 3–7 later
sessions each (top: durable-steer-inbox 7s/12r).

Consult findings adopted: spike-before-spec ordering (a blocking technical
unknown stops the skill, step 1); "validation consult" naming (round-2
collided with /consult's own resume semantics); spec-only staging, revision
commit only on change, report path/SHAs/out-dir; SPEC-BAR.md split
(261-line body buried the hot path); the two-condition multi-PR rule; the
vocabulary fix (domain/interface naming is the spec's, call-site rename
inventories are not). Rejected: widening the lesson's reach to consult and
exploration surfaces — kept at the Scope pointer per user decision.

Cold readers (two routes: warm consult + rider; fresh + "don't commit"):
both stalled at step 4's warm branch — no route to resume mechanics, and
/consult's round-2 trigger list didn't sanction spec validation. Fixed by a
pointer to /consult step 6 + a fourth-trigger line added there, a decidable
branch condition (out-dir in reach), a fall-through when the set can't
resume, and the override-cascade sentence ("don't commit" carries into
validation reading uncommitted files). SPEC-BAR's reading list now scales
to the novelty; its design-it-twice procedure deduped to the lesson it
already cites. Deliberate keeps, flagged by readers but kept on purpose:
the Emphasis closing note (user-mandated independent-thinking echo of the
opening license); the Scope section's in-line two-condition rule (the spec
author needs it without a file hop; the lesson adds why + exemplar); the
frontmatter defaults line (human-facing gallery text); the vague-verbs
enumeration (trigger vocabulary).

Goal review (codex, cold, out-dir 20260831-235200-review): verdict
"partly" — the phase runs end to end, but SKILL step 2's follow-the-project
convention and SPEC-BAR's own anatomy had no precedence. Fixed: convention
governs names/order/format, SPEC-BAR governs decisions and doneness, its
layout the fallback. Also trimmed on its findings: the interview recipe's
clustering/anatomy scripting (batch discipline kept), the generic
form-submission tree (the prose and the structure/API sketch carry the
pattern). Escalated, recommended keep: rebuilding SPEC-BAR as an outcome
rubric instead of a document anatomy — the anatomy is the user's measured
formula; revisit only if specs come back formally complete but
over-sectioned. The first-party doctrine behind the objection, a sketch of
the rubric variant, and the switch/hold evidence bar are researched in
`RESEARCH-goal-driven-specs.md` (2026-09-01): verdict hold-until-trigger,
then migrate by deletion-with-evals.

Re-measure next pass: does the default choreography hold without riders;
warm-vs-fresh consult branch taken correctly; do split proposals persist in
consult rounds (if so, escalate the lesson pointer into /consult's brief
guidance); snippet-vs-skill door counts; sessions-per-PR against the ≤2
default.
