---
name: update-docs
description: Update a project's documentation after a change lands, so the docs still give a senior engineer the mental model of the system. Use when the user wants docs updated to reflect recent or shipped changes, or brought back in line with the code. Defers to a repo's own update-docs skill or documentation-standards.md when present; otherwise the global standards in ~/dotfiles/docs/documentation-standards.md.
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git merge-base:*), Bash(git symbolic-ref:*), Bash(git show-ref:*), Bash(git branch:*), Read, Write, Edit, Glob, Grep, Agent
---

# Update documentation from the diff

A change has landed. Bring the project's docs back in line with it so that a senior engineer — human or agent — can still pick up the system's **mental model** without reading every file: architecture, intent, relationships, load-bearing constraints. Docs describe how to think about the system; the code carries the rest.

**The project's own rules win.** If the repo has an `update-docs` skill or a `documentation-standards.md` (anywhere under `docs/`), read it and follow it. Where the project is silent, the standards are `~/dotfiles/docs/documentation-standards.md` ([Documentation standards](#documentation-standards) below).

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

   On the base branch itself this is just the working-tree diff, which is still right. Second pass in one session: diff from the end of the previous pass, not the whole range.

   Read the diff for what changes how a developer thinks about the system: new modules, endpoints, jobs, schemas, or config; changed interfaces or control flow between components; removed or renamed concepts; changed behavior or policy.

2. **Read the docs that overlap.** Find the docs home — usually `docs/` plus the always-loaded file (`CLAUDE.md` or `AGENTS.md`). Read every overlapping doc end-to-end so you hold its narrative before editing it. While reading, note what the change outdated: behavior described that no longer holds, a known-gaps note now closed, a spec that shipped and should distill into a durable doc.

3. **Assess significance** with the standards' tiers (§ When docs need updating). Implementation-level ⇒ say so and stop: *"These changes are implementation-level — no documentation updates needed."*

4. **State the plan, then gate only what changes the tree's shape.** Write the plan out before editing. Edits inside docs that already exist — syncing prose to the code, correcting a stale claim, merging duplicated sections, fixing cross-references, folding a shipped spec's decisions into the doc that owns them — start as soon as the plan is stated; the plan is the record, and an approval prompt on them is a round trip with no decision behind it. Wait for the user on any item that would:

   - create a doc file (a page, a route, a status surface);
   - delete, archive, move, or rename a doc file — pruning a shipped spec included;
   - touch `CLAUDE.md` / `AGENTS.md` or an onboarding skill's always-read list;
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

5. **Write the updates** to the standards, the gated items once confirmed. Two moves carry this step: **consolidation** — every doc you touch ends tighter, not longer — and **distillation** — a shipped spec's surviving decisions move into the durable doc and the spec goes. When the change alters the system's shape, update the structure map and the always-loaded file as well; both are curated, and an entry there is earned (the standards' § What earns documentation).

6. **Verify** every doc you touched:

   - re-read it end-to-end as a cold reader: does it hand over the mental model without a tour of the files?
   - grep the docs tree for the basename of anything you moved, renamed, or deleted, and for each concept the change replaced — every hit resolves, or passes the standards' future-need test;
   - last, the standards' check block (§ Before you commit a doc change) — its greps see what a re-read does not.

7. **Check the surfaces above the docs.** An onboarding or bootstrap skill, if the project has one: a new top-level doc its routing misses, a renamed doc on its always-read list, a drifted path — routine edits inside an existing doc leave it alone. `CLAUDE.md` / `AGENTS.md` is paid on every request, so it holds load-bearing facts plus a map of where to read the rest; it changes only when a cross-cutting rule appeared or one's framing rotted, which most branches don't do.

Close with what you updated, deleted, and left alone, with the reason for each.

---

## Documentation standards

The rules are one file, `~/dotfiles/docs/documentation-standards.md`: what each kind of doc is for, the status-page item and its owed read, the hot-path budget, what earns documentation, the writing rules, the significance tiers step 3 uses, and the check block step 6 ends on. Read it before step 3. A project's own `documentation-standards.md` overrides it.
