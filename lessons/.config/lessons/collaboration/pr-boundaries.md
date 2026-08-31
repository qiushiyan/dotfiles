# PR boundaries — one ambitious PR over a conceptual split

How to draw the boundary between "this PR" and "later work". The default is
inverted from the traditional small-atomic-PRs instinct: with a well-written
spec carrying the whole design, a conceptual split's coordination cost
compounds while the single PR pays design review once.

## The rule

A holistic feature or a holistic refactor ships as **one PR, built in one
session**, however ambitious. Size alone never forces a split — of the PR or
of the session.

When the work is genuinely too large for one session, or carries operational
risk, the first escalation is **phases across sessions on the same branch** —
still one PR. A phase ends with a handoff that carries the baton; the next
session implements the remaining phases and reviews the earlier ones. Two
sessions at most unless there is a really strong reason: a five-phase plan is
not five sessions, and proposing a fresh session per phase re-creates the
splitting instinct one level down.

## Why

- **The interim-broken defect.** A conceptual split ships half a feature:
  between PR 1 merging and PR 2 deploying, the customer sees a broken or
  half-rewired surface. The phases looked clean from the development
  perspective; the boundary was drawn in the code, not in what ships.
- **A split's overhead compounds** — stacked branches, merge conflicts
  between the parts, review context re-established per PR — while a single
  PR built from a settled spec is judged once, against the whole design.
- **The worst case of ambition is a big diff; the worst case of splitting is
  work left half-done** — an abandoned PR 2 leaves production wrong, not
  just a branch stale.

## When multiple PRs are right

Two conditions, both required:

1. **Every intermediate PR is independently correct as a merge state** — the
   product works, nothing is half-rewired, a behavior-preserving preparatory
   refactor counts.
2. **A concrete constraint benefits from the seam**: a repository or
   ownership boundary (a cross-repo feature is one PR per repo by
   construction), release or rollback mechanics, an operational step mid-way
   (an infra apply, a migration that must bake), or a decision that needs
   the first PR merged and producing evidence.

Conceptual slicing — "these are separate logical pieces" — satisfies neither
condition on its own.

## Where the boundary gets decided

The pressure to split shows up early — exploration and consult voices
routinely propose 3–4 "atomic" PRs. The spec is where the boundary is
**settled**: it states the PR scope and the phase plan explicitly, so a
consult voice or an implementing session doesn't quietly re-split it.

Exemplar of the phased exception done right: the PlanChat-deletion refactor —
one PR, two phases, two sessions; phase 1 ended in a baton handoff, session 2
implemented phase 2 and re-reviewed phase 1 before merge.
