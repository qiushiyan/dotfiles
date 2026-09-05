---
name: update-docs
description: Update a project's documentation after a change lands, so the docs still give a senior engineer the mental model of the system. Use when the user wants docs updated to reflect recent or shipped changes, or brought back in line with the code. Defers to a repo's own update-docs skill or documentation-standards.md when present; otherwise the global standards in ~/dotfiles/docs/documentation-standards.md.
---

# Update documentation from the diff

A change has landed. Bring the project's docs back in line with it so that a senior engineer — human or agent — can still pick up the system's **mental model** without reading every file: architecture, intent, relationships, load-bearing constraints. Docs describe how to think about the system; the code carries the rest.

**Read the standards now.** The repo's own `update-docs` skill or `documentation-standards.md` (anywhere under `docs/`) where one exists; otherwise `~/dotfiles/docs/documentation-standards.md`. Steps 3, 5 and 6 cite its sections by heading.

## Workflow

1. **Gather the diff.** Detect the base branch instead of assuming `main`, and diff the working tree against the merge-base so committed and uncommitted work both count:

   ```bash
   BASE_BRANCH=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
   [ -z "$BASE_BRANCH" ] && for c in main master develop; do
     git show-ref --verify --quiet "refs/heads/$c" && BASE_BRANCH=$c && break
   done
   BASE=$(git merge-base HEAD "${BASE_BRANCH:-HEAD}")

   git diff --stat $BASE
   git diff $BASE -- . ':!*lock*' ':!*.snap' ':!node_modules' ':!dist'   # adjust excludes per project
   git log --oneline $BASE..HEAD
   git status --short
   ```

   On the base branch with a clean tree — the user says the branch merged and `git log $BASE..HEAD` is empty — diff the merge itself: `git log --merges -1`, then `git diff <merge>^1 <merge>`, or `git diff $BASE_BRANCH...<branch>` while the ref exists. When git disagrees with the user's account (the branch is not merged, the diff is empty), say so before planning. A second pass in one session records the sha the first pass diffed from and diffs from it.

   Read the diff for what changes how a developer thinks about the system: new modules, endpoints, jobs, schemas, or config; changed interfaces or control flow between components; removed or renamed concepts; changed behavior or policy.

2. **Read the docs that overlap.** Find the docs home — usually `docs/` plus the always-loaded file (`CLAUDE.md` or `AGENTS.md`). Read every overlapping doc end-to-end so you hold its narrative before editing it. While reading, note what the change outdated: behavior described that no longer holds, a known-gaps note now closed, a spec that shipped and should distill into a durable doc.

3. **Assess significance** with the standards' tiers (§ When docs need updating). Implementation-level ⇒ say so and stop: *"These changes are implementation-level — no documentation updates needed."*

4. **State the plan, then gate only what changes the tree's shape.** Write the plan out before editing. Edits inside docs that already exist — syncing prose to the code, correcting a stale claim, merging duplicated sections, fixing cross-references, folding a shipped spec's decisions into the doc that owns them — start as soon as the plan is stated; the plan is the record, and an approval prompt on them is a round trip with no decision behind it. Wait for the user on any item that would:

   - create a doc file (a page, a route, a status surface);
   - delete, archive, move, or rename a doc file — pruning a shipped spec included;
   - add or remove a rule in `CLAUDE.md` / `AGENTS.md`, or change an onboarding skill's always-read list — rewording an existing line there to match the code is an in-place edit and starts now;
   - reorganize the tree (split a hub, merge folders, restructure an index);
   - settle a doc/code disagreement by changing the described design rather than the wording.

   A mixed plan does the in-place edits now and holds only the gated items:

   ```
   ## Documentation updates

   ### Scope
   [One sentence: what the work does]

   ### Changes (starting now)
   - `docs/<area>.md` — update the data-flow description; merge the two "retry" paragraphs
   - `CLAUDE.md` — no change (no new cross-cutting rule)

   ### Gated — waiting on you
   - `docs/<new-area>.md` — new doc (why no existing doc can own this)
   - `docs/specs/<name>.md` — shipped; fold into `docs/<area>.md`, then prune the file

   ### No action
   - `docs/<other>.md` — not affected
   ```

   With nothing gated, the plan ends on "starting now".

5. **Write the updates** to the standards, the gated items once confirmed: every touched doc ends tighter (§ Writing standards), a shipped proposal's decisions move into the durable doc and the proposal goes (§ Documentation shape). When the change alters the system's shape, the index and the always-loaded file change too; an entry there is earned (§ What earns documentation).

6. **Verify** every doc you touched:

   - re-read it end-to-end as a cold reader: does it hand over the mental model without a tour of the files?
   - the standards' check block (§ Before you commit a doc change) — its greps see what a re-read does not. Skip the status-page loop where the tree has no status page; where the design doc is `CLAUDE.md` and there is no `docs/`, the design-doc checks scan `CLAUDE.md`.

7. **Check the surfaces above the docs.** An onboarding or bootstrap skill, if the project has one: a new top-level doc its routing misses, a renamed doc on its always-read list, a drifted path — routine edits inside an existing doc leave it alone. `CLAUDE.md` / `AGENTS.md` (the standards' § The hot path) changes only when a cross-cutting rule appeared or one's framing rotted, which most branches don't do.

Close with what you updated, deleted, and left alone, with the reason for each.
