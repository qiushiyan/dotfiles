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
- **F4 · discoverability (4 invocations)** — `assumed: keep
  disable-model-invocation` (snippets are the designed doors); description
  widened instead. Reversible.

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
