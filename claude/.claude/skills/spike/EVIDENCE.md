# Evidence log — spike skill

Mining passes behind the skill's rules, one entry per pass, written so the
next pass can re-run the counts.

## 2026-09-01 — first improve-tool pass (session af44333d)

**Corpus:** spike invoked by path in 4 sessions ever (2026-08-06 → 08-25);
`pl-loopy-verify` — the conceptually-adjacent planlab skill — named in 48
sessions / 106 mentions, mostly via the loopy tabtype snippets. The concept
runs ~50 sessions; the skill ran 4. Signatures: `messages.skill='spike'`,
`%skills/spike/SKILL.md%` in user text; `%pl-loopy-verify%` in user text.

**Frictions and verdicts:**

- **F1 · stated moment was half the real usage** — 2 of 4 invocations were
  verification/repro, not pre-build design (`c4054a8f`, `521c800d`); user
  verdict 2026-08-10 (`521c800d` 15:21): "day-to-day development is just not
  that pure… there just happen to be times where you want to run a skill
  before." Fixed: opening + description teach two moments (before the build /
  around a change), sourced from planlab `docs/loopy/debug-workflow.md` §route
  by claim ("the same instrument serves both moments").
- **F2 · no baseline discipline** — worktree add 31 / remove 23 across 20/17
  plv sessions; user correction `2e11be20` (08-26, cleanup after one-shot
  spikes, previously landed in loopy snippets as dotfiles `55c7a72`);
  pl-loopy-verify's "a green with no red proves nothing". Fixed: step 4
  baseline-checkout passage (parent-commit variant for merged changes, one-shot
  removal).
- **F3 · real data under-taught** — user (`521c800d` 15:18): spike "with real
  data or queried from a production database". Fixed: step 2 names the data in
  the real/faked line, conditioned on the claim being about specific data.
- **F4 · discoverability (4 invocations)** — verdict **confirmed by user**
  (2026-09-01): keep `disable-model-invocation`; explicit reference and the
  consult/review-verify snippets are the intended doors. Description widened
  instead.

**Cold readers** (one per route, post-edit): verification route stalled on
baseline-for-merged-change and on step 1's write-that-test escape routing the
spike away (both fixed); design route stalled on the missing pre-build entry
point and unanchored time box (fixed: new-file-in-existing-runner, 30-minute
default); both flagged the opening's hybrid sentence (moved to step 4) and
"only ever confirm was never an experiment" (cut; step 1's two-observables
carries it). Added: multiple runs for concurrency/timing claims; verdict
destination when no plan exists on disk.

**Lesson that survived:** the spike/verify split is a moment, not a skill
boundary — planlab distilled it first (debug-workflow.md, 2026-08-10) and the
global skill inherited it a month late. When a project-local skill and a
global skill share a concept, the local one's distillations are mining input
for the global one.

## 2026-10-12/13 — second improve-tool pass (session 7513cde5)

**Question (user):** does the skill beat a free-form spike, and does the
verification moment's "one spike per claimed behavior, against a baseline"
(and the loopy-review-verify snippet routing through pl-loopy-verify) cost
the big picture? Verification quality over the report's readability.

**Corpus:** `loopy-review-verify` snippet (`%run pl-loopy-verify with local
spikes%`, user text, not continuations) mac 50 sessions 2026-08-25 → 09-30,
mini 30 sessions 09-25 → 10-12; generic review-verify / consult-diagnosis /
spike-check by path, 9 real spike runs read. Three readers: 12 mac lrv
sessions, 18 mini lrv sessions (+6702aa58), 9 spike sessions; 5 receipts
spot-checked. Notes stayed in the session scratchpad.

**Findings:**

- **Shape.** About half the runs verified a table of one predicate per claim.
  Every defect that escaped verification was an interaction, a lifecycle
  sequence, the real entry path, or a claim checked on one input when it
  covered a class. None was a single claim wrongly verified on its own input
  (mac 7ce5db3c 432d4383, 9ba78130 09b83425, cc8ba647; mini 1b6596c4,
  d179c550 292e8fee, 8b475c03; spike 10f230af, 66268e9d).
- **Baselines for features.** For a new capability the baseline went red only
  because the capability was absent (mac d691723c, 0dee9c51, cc8ba647; mini
  d5ca20f7, 1b6596c4, 75b65cfd, 5c89a1ed). For bug fixes the baselines were
  meaningful.
- **What verification caught.** Its own catches came from its most
  end-to-end step (mini 2c408cef, 5c89a1ed, c16a847a, d179c550; spike
  4c9f87a2). The review found most defects.
- **User voice.** It always pushed toward real end-to-end runs (mac cc8ba647
  62a17b25, mini d5ca20f7 be5836c2, mac 10f230af 1cf27963). It never asked
  for per-claim tables.
- **Rules used.** Agents visibly applied the real/faked line, real data,
  baseline with cleanup, the home rule and repeated runs. The 30-minute time
  box was never stated, and the fake-flip test was never visibly run.

**Change:** the skill was rewritten shorter (1121 → 677 words) around
the same two moments. Verification now starts from the scenarios a user or
caller runs, through their entry point, with the claimed behaviors meeting as
they do in use. It then takes each claim across the inputs it covers and
reruns the existing flows. A baseline red for a capability the base lacks is
named as proof of nothing. VERIFIED covers only what was driven. The time box
is dropped.

**Eval** (`~/dev/skill-evals`, subscription, Opus 5.5, judge gpt-6-sol, 5
runs per arm, mini, 2026-10-13):

| case | 1f2b456 | candidate | patch of 1f2b456 | free-form, no skill |
|---|---|---|---|---|
| verify (jobq: R1 resend after interleaved submit, R2 upgrade over develop's DB, R3 cross-process cancel) | 5/5, 174 s | 5/5, 218 s | 5/5, 197 s | 5/5, 99 s |
| design (plan.md: RETURNING on conflict, ADD COLUMN UNIQUE false; concurrent claim true) | 5/5, 200 s | 5/5, 206 s | — | 5/5, 114 s |

Every check passed in every arm, so the cases are **saturated**. The rewrite
shows no regression, not an improvement. Free-form Opus 5.5 found the same
defects at about half the time. A fixture calibration explains why: two
read-only reviewers found all the planted defects by reading the diff (a
first draft's in 31 s). On tasks this small the model needs no skill, so the
skill's value, if any, is on large PRs.

**Large-PR replays (pending).** Three answer keys were built from history:
#8860, #8874 and #8858, with heads `73c98e4e6e`, `582ad63d63` and
`a79ee0dd10`. A live replay runner (`skill-evals/replay`) ran them on the
mini, and its first matrix was stopped. Each replay was a separate clone, and
planlab's lane gc diffs the shared lane registry against its own repo's
worktree list, so a replay's `lane up` dropped the lane databases of four of
the owner's checkouts. The runner now refuses to run until it becomes
worktrees of the owner's clone or the gc checks the path on disk.

Directional results, one run per arm:
- #8874 `current`: 0 of 10 checked defects, 19 min.
- #8874 `change` (pilot, read the shipped Bench card): 1 of 10.
- #8860 `current`: invalidated by the rig.

**Next pass compares:**
- the replays, once rerunnable, `current` against the `verify-change` draft
  (cases/replay-verify/skills/change) against free-form, on the lane-scorable
  defects;
- live verification sessions after this release, counting defects later
  found by review, CI or production in areas the verification called
  VERIFIED, against this pass's sample. The skill is reverted if they rise or
  if verification reports stop carrying the baseline evidence that fixes
  needed.
