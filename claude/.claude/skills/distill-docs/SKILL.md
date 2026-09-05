---
name: distill-docs
description: The periodic whole-tree pass over a project's docs — trim the hot path, prune rot, split what remains into spine and satellites.
user-invocable: true
disable-model-invocation: true
argument-hint: [optional scope, e.g. "docs/agents" — default the whole docs tree]
allowed-tools: Bash(wc:*), Bash(git log:*), Bash(git diff:*), Bash(git status:*), Read, Write, Edit, Glob, Grep, Agent
---

# Distill the doc tree

You're running the periodic distillation pass over a project's documentation — the whole-tree complement to the per-change update-docs skill. Update-docs is diff-scoped: it reads only the docs a change overlaps, so duplication *across* docs, rot in files no recent diff touched, and structure that drifted over many small edits accumulate in the seams. This pass reads the tree whole, consolidates and prunes it, and patches the standards so the same rot can't come back. Typical triggers: the update-docs budget check flagged an overrun, or the weekly standing slot came round. At that cadence many runs will find little — reporting a clean tree is a real result, not a wasted pass.

**The project's standards define "good".** Before anything else, read its `documentation-standards.md` (anywhere under the docs home), or the global `~/dotfiles/docs/documentation-standards.md` when it has none. The standards supply the writing rules — and, just as load-bearing, the **protected set**: sanctioned echoes ("this list deliberately duplicates…"), evidence-tag conventions, the spine/satellite shape, the budget. What counts as rot and what counts as protected both come from there; this skill only carries the process and the catalogue.

## The hot path

The **hot path** is what a session pays for without choosing to — loaded before it knows what it is working on. Everything else is **on demand**, costing nothing until a session reaches for it. Settle membership before step 1: it is the ranking every later judgment appeals to, and deriving it ad hoc mid-pass produces a pass that optimizes the wrong bytes.

Three tiers, in descending certainty:

1. **Auto-loaded** — the tool appends it to every request: `CLAUDE.md` / `AGENTS.md`. Hot by construction; no judgment needed.
2. **Onboarding-mandated** — whatever the project's onboarding or bootstrap skill reads unconditionally. Open that skill and take its list rather than inferring one.
3. **Landing pages** — a `docs/README.md`, an index, a root map: hot because a reader arrives there first and reads down.

**The tier sets the bar, and the same prose can be right in one and wrong in the other.** A hot doc is judged on *bytes per session*: it carries the mental model — vocabulary, load-bearing invariants, and a map of where the rest lives — and states each conclusion without the reasoning that reached it. An on-demand doc is judged on *findability and completeness*, where the full mechanism walkthrough that would be rot on the hot path is exactly the point.

## 1 — Scope and baseline

`$ARGUMENTS` may narrow the pass to a subtree; the default is the whole docs home plus the hot path. Inventory it: `wc -c` per doc, and the hot path measured against the project's budget where one is declared.

**Measure every hot doc by section, not just as a file.** A hot doc bloats section by section, so the file total says only that something is wrong while the per-section count names it — and one oversized section is a far more actionable finding than one oversized file.

Dated evidence dirs (`specs/`, `plans/`, `records/`, `researches/`) enter scope only as distill-and-prune candidates — their contents are history: edited never, deleted only after distilling.

Done when every in-scope doc has a size, a tier (hot / on demand) and a role (design / index / proposal / evidence) on your worksheet, and every hot doc additionally has a per-section byte count.

## 2 — Mechanical sweep

Run the cheap detectors over the whole scope before reading anything end-to-end. These find rot a grep can settle, so each carries its own move; the classes needing judgment wait for the map (§The rot catalogue).

- **Dead references** — every `§"…"` anchor and cited doc basename resolves to a live heading or file. → Repoint it; a reference nobody can follow is worse than none.
- **Dates as narrative** — "added", "as of", "recently", years doing the storytelling in a design doc (dated evidence files exempt). → Rewrite as the present state.
- **Live counts** — "the seven seams", "all 5 rules": numbers a reader never navigates by and the code already knows. → Name the load-bearing few.
- **Future tense in design docs** — "we will", "planned", "upcoming" outside the proposal tier. → Verify it, mark it, or move it to the proposal tier.
- **Status markers to re-check** — "unverified", "known gap", "not yet", "TODO": each is either still true or rot. → Flip or delete; status lives in the project's status surfaces.
- **Outliers** — a doc several times its siblings' size is the usual split candidate. Then pair each doc's churn with its subject's: static doc + churning subject is rot, and goes to the top of the map's reading list; static doc + static subject is a **settled topic**, the strongest candidate to move off the hot path. Read churn as evidence of how often sessions engage a subject, never of what it is worth — an invariant earns its place by what it prevents, and the best ones never change.

Done when every detector has run and its hits sit on the worksheet with file:line.

## 3 — The redundancy map

Dispatch one general-purpose agent to read the scope and return the section-level map, so your own window stays free for the surgery. For each top-level section of each design doc it reports: content kind (mental model / mechanism / policy / inventory / history), overlap (fully duplicated elsewhere / summarized elsewhere / only lives here — naming the other doc and section), staleness signals, and a recommendation — keep, tighten, consolidate into a named home, relocate, split to named satellites (§The split), or prune with the survivor named. It also reports narrative dependencies (sections that must not be separated) and doc-vs-doc contradictions. Read the map critically: it's a subordinate's draft, not a verdict — spot-check any recommendation you'd act on destructively.

Done when every design doc is mapped and every contradiction is listed.

## 4 — The plan is the owner's call

Assemble sweep + map into a per-doc plan: consolidations (surviving home named), splits (spine and satellites named), prunes (live copy of the content named), tightenings, relocations, and any generator fixes (step 7) already visible. Surface the genuinely owner-level calls as questions, each with your recommendation: membership of the hot path, any doc you propose to demote off it, retire-vs-reconcile for a stale doc, an apparent rot that might be a deliberate convention the standards forgot to sanction. Wait for confirmation — this pass deletes.

## 5 — Surgery

Work doc by doc, finishing one before opening the next. The standards bind at the keyboard; four rules carry the pass:

- **One home per meaning.** Every consolidation names the surviving copy and repoints the others; every deletion names the live copy that outlives it.
- **Present tense, edited in place.** Restructure prose to describe what is true now; git holds the history.
- **The protected set survives verbatim** — sanctioned echoes, evidence tags, each doc's voice. Distillation compresses meaning; it doesn't flatten register.
- **Deletion is the win condition — the split is its partner.** Accumulated rot is usually whole sections and whole files, so a pass that only tightened sentences has skimmed the surface. Reserve deletion for content nothing needs; live content that only some sessions need earns a satellite instead (§The split).

Done when every planned action landed, or was consciously dropped with a one-line reason.

## 6 — Verify

1. Re-read each modified doc end-to-end for a coherent narrative.
2. Grep the tree — docs, the hot path, README, and any doc-reading skills — for every basename and section heading you moved, renamed, or deleted: every hit resolves, or sits in a dated evidence file as history.
3. Every doc created this pass is reachable on its own terms: each satellite has its in-place pointer and its navigation entry; each standalone topic has a name built from the words its subject would be searched by.
4. Re-measure the hot path against the budget, and the tree separately; record before → after bytes for both.
5. Confirm the protected set is untouched.

## 7 — Fix the generator

For each rot class that appeared more than once — or that a previous distillation already cleaned — propose the amendment to the project's `documentation-standards.md` or update-docs skill that would have prevented it: a new verify-step check, a sanctioned-exception entry, a split trigger. Recurring rot means the per-change pass has a hole, and cleaning it twice without patching the hole schedules a third cleaning. Check whether the standards already name the class: a rule that exists and was still violated needs a **verify-step check**, not a second statement of the rule.

Done when every class that recurred carries either a proposed amendment or a one-line reason it needs none — a clean generator being a valid finding.

## Output

Per doc: split / consolidated / pruned / tightened / untouched, with bytes before → after.

**Report the hot path's before → after separately from the tree's.** Moving bulk off the hot path can leave the tree *larger* — each new doc carries a lead placing it against its spine — and that is a win reported as a loss if the two numbers are merged. Give both, and say which one the pass was buying.

Then: every deletion with its survivor, every satellite with its route, every doc that changed tier, and the generator amendments proposed (or "none needed").

## The split — spine, satellites, standalone topics

Reference for steps 3–5, and the usual resolution of a budget overrun. Deletion cures rot; the split cures bulk — a doc too big for its place in the reading order whose content is still live. The doc stays at its own path as the **spine**, keeping what a reader needs to *think about* the subsystem: the mental model, the vocabulary, the load-bearing invariants. What a reader needs only to *work on* one corner — operational detail, edge-case walkthroughs, per-feature mechanism — moves out into smaller docs read on demand. The step-3 map already grades the cut: *mental model* and *policy* sections are spine; *mechanism* sections are the ones that move.

- **The spine keeps its path and its place.** Navigation maps keep pointing at it and inbound references keep resolving, so the hot path slims without moving.
- **Route by whether a reader would hit a hole.** Ask it of each doc you carve out: *following some other doc, would a reader reach a gap where this used to be?*
  - **Yes — a satellite.** It earns a pointer where the content sat, worded with when to read it ("operating the cron: `run-operations.md`"), plus an entry in the tree's navigation surfaces.
  - **No — a standalone topic.** A self-contained subject nobody reads *through* on the way to something else: one tool's quirks, one incident's lesson. Its **filename is its index entry**. Name it after the words someone would grep when the topic finally comes up — the subject's own nouns, never a clever name — and let the file tree list it. That is the whole connection it needs.
  
  A pointer costs whatever its holder costs: one written into a hot doc is paid by every session, including the overwhelming majority that never follow it. Spend it to keep a reader from being stranded mid-thought, not as a receipt that a file exists.
- **Demoting is a legitimate outcome.** A settled topic sitting on the hot path becomes a standalone doc plus, at most, one line in the map.
- **Splitting is lossless; distill after.** The move itself deletes nothing — the same rot rules then run inside spine, satellites and standalones alike.

## The rot catalogue

Reference for steps 3–4: the classes **no grep finds**, each needing the map's judgment about what a doc is for. The greppable classes carry their own moves in step 2. Where a project's standards overlap this, the standards win.

| Rot | Looks like | The move |
|---|---|---|
| Cross-doc duplication | One concept described in two-plus docs — a config block in both a design doc and the README, a policy restated per workflow | Pick the owning home; the others point |
| Shipped proposal in place | A spec or plan whose feature shipped, still sitting beside the design docs as if live | Distill its surviving decisions into the design doc, then prune it |
| Altitude creep | Mechanism piling up in a hot-path doc — paid by every session, needed by few | §The split — the model stays, the mechanism moves out |
| Settled topic on the hot path | A self-contained subject neither it nor its doc has moved in months | §The split — demote to a standalone topic with a greppable name |
| Structural rot | Reading order gone disjoint; sibling sections describing one thing | Merge, reorder, or re-home |
| Inventory the environment owns | A doc restating what a config file, directory listing or `--help` already says | Delete it and point at the source; cache only what a lookup cannot reach |
