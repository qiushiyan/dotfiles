---
name: distill-docs
description: Periodic whole-tree documentation distillation — consolidate duplication, prune rot against the project's own standards, and patch the standards so the same rot can't recur.
user-invocable: true
disable-model-invocation: true
argument-hint: [optional scope, e.g. "docs/agents" — default the whole docs tree]
allowed-tools: Bash(wc:*), Bash(git log:*), Bash(git diff:*), Bash(git status:*), Read, Write, Edit, Glob, Grep, Agent
---

# Distill the doc tree

You're running the periodic distillation pass over a project's documentation — the whole-tree complement to the per-change update-docs skill. Update-docs is diff-scoped: it reads only the docs a change overlaps, so duplication *across* docs, rot in files no recent diff touched, and structure that drifted over many small edits accumulate in the seams. This pass reads the tree whole, consolidates and prunes it, and patches the standards so the same rot can't come back. Typical triggers: the update-docs budget check flagged an overrun, or a month of sessions has passed.

**The project's standards define "good".** Before anything else, read its `documentation-standards.md` (anywhere under the docs home), or the global `/update-docs` skill's standards when it has none. The standards supply the writing rules — and, just as load-bearing, the **protected set**: sanctioned echoes ("this list deliberately duplicates…"), evidence-tag conventions, the spine/satellite shape, the budget. What counts as rot and what counts as protected both come from there; this skill only carries the process and the catalogue.

## 1 — Scope and baseline

`$ARGUMENTS` may narrow the pass to a subtree; the default is the whole docs home plus the always-loaded mental-model file (`CLAUDE.md` / `AGENTS.md`). Inventory it: `wc -c` per doc, the always-read set measured against the project's budget where one is declared. Dated evidence dirs (`specs/`, `plans/`, `records/`, `researches/`) enter scope only as distill-and-prune candidates — their contents are history: edited never, deleted only after distilling.

Done when every in-scope doc has a size and a role (design / index / proposal / evidence) on your worksheet.

## 2 — Mechanical sweep

Run the cheap detectors over the whole scope before reading anything end-to-end — these find rot that needs no judgment:

- **Dead references** — every `§"…"` anchor and cited doc basename resolves to a live heading or file.
- **Dates as narrative** — "added", "as of", "recently", years doing the storytelling in a design doc (dated evidence files exempt).
- **Live counts** — "the seven seams", "all 5 rules": numbers a reader never navigates by and the code already knows.
- **Future tense in design docs** — "we will", "planned", "upcoming" outside the proposal tier.
- **Status markers to re-check** — "unverified", "known gap", "not yet", "TODO": each is either still true or rot.
- **Outliers** — a doc several times its siblings' size, or untouched by git for months while its subject churned, goes to the top of the map's reading list.

Done when every detector has run and its hits sit on the worksheet with file:line.

## 3 — The redundancy map

Dispatch one general-purpose agent to read the scope and return the section-level map, so your own window stays free for the surgery. For each top-level section of each design doc it reports: content kind (mental model / mechanism / policy / inventory / history), overlap (fully duplicated elsewhere / summarized elsewhere / only lives here — naming the other doc and section), staleness signals, and a recommendation — keep, tighten, consolidate into a named home, relocate, or prune with the survivor named. It also reports narrative dependencies (sections that must not be separated) and doc-vs-doc contradictions. Read the map critically: it's a subordinate's draft, not a verdict — spot-check any recommendation you'd act on destructively.

Done when every design doc is mapped and every contradiction is listed.

## 4 — The plan is the owner's call

Assemble sweep + map into a per-doc plan: consolidations (surviving home named), prunes (live copy of the content named), tightenings, relocations, and any generator fixes (step 7) already visible. Surface the genuinely owner-level calls as questions, each with your recommendation: membership of the always-read set, retire-vs-reconcile for a stale doc, an apparent rot that might be a deliberate convention the standards forgot to sanction. Wait for confirmation — this pass deletes.

## 5 — Surgery

Work doc by doc, finishing one before opening the next. The standards bind at the keyboard; four rules carry the pass:

- **One home per meaning.** Every consolidation names the surviving copy and repoints the others. A deletion with no named survivor is a lost meaning, not a distillation.
- **Present tense, edited in place.** Restructure prose to describe what is true now; git holds the history.
- **The protected set survives verbatim** — sanctioned echoes, evidence tags, each doc's voice. Distillation compresses meaning; it doesn't flatten register.
- **Deletion is the win condition.** Accumulated rot is usually whole sections and whole files; a pass that only tightened sentences has skimmed the surface.

Done when every planned action landed, or was consciously dropped with a one-line reason.

## 6 — Verify

1. Re-read each modified doc end-to-end for a coherent narrative.
2. Grep the tree — docs, the always-loaded file, README, and any doc-reading skills — for every basename and section heading you moved, renamed, or deleted: every hit resolves, or sits in a dated evidence file as history.
3. Re-measure the always-read set against the budget; record before → after bytes.
4. Confirm the protected set is untouched.

## 7 — Fix the generator

For each rot class that appeared more than once — or that a previous distillation already cleaned — propose the amendment to the project's `documentation-standards.md` or update-docs skill that would have prevented it: a new verify-step check, a sanctioned-exception entry, a split trigger. Recurring rot means the per-change pass has a hole, and cleaning it twice without patching the hole schedules a third cleaning. If nothing recurred, say so — a clean generator is a valid finding.

## Output

Per doc: consolidated / pruned / tightened / untouched, with bytes before → after. Then: budget status, every deletion with its survivor, and the generator amendments proposed (or "none needed").

## The rot catalogue

Reference for steps 2–4. Where a project's standards overlap it, the standards win.

| Rot | Looks like | The move |
|---|---|---|
| Cross-doc duplication | One concept described in two-plus docs — a config block in both a design doc and the README, a policy restated per workflow | Pick the owning home; the others point |
| Shipped proposal in place | A spec or plan whose feature shipped, still sitting beside the design docs as if live | Distill its surviving decisions into the design doc, then prune it |
| Changelog-ism | "added X", "as of …", dates carrying the narrative | Rewrite as the present state |
| Aspirational present | Unverified or planned behavior stated as fact | Verify it, mark it, or move it to the proposal tier |
| Stale status marker | "unverified" on a since-verified feature; a "known gap" since closed | Flip or delete; status lives in the project's status surfaces |
| Dead reference | An anchor to a renamed section; a path to a moved file | Repoint it — a reference nobody can follow is worse than none |
| Live count / inventory | A number or table re-listing what the code enumerates | Name the load-bearing few; the count is the code's to know |
| Altitude creep | Mechanism piling up in a mental-model doc | Split: the model stays always-read, the mechanism moves to an on-demand doc (the standards' spine/satellite trigger, where declared) |
| Structural rot | Reading order gone disjoint; sibling sections describing one thing | Merge, reorder, or re-home |
