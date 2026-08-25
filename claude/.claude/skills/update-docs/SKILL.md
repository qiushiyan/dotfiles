---
name: update-docs
description: Update a project's documentation after a change lands, so the docs still give a senior engineer the mental model of the system. Use when the user wants docs updated to reflect recent or shipped changes, or brought back in line with the code. Defers to a repo's own update-docs skill or documentation-standards.md when present.
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git merge-base:*), Bash(git symbolic-ref:*), Bash(git show-ref:*), Bash(git branch:*), Read, Write, Edit, Glob, Grep, Agent
---

# Update documentation from the diff

A change has landed. Bring the project's docs back in line with it so that a senior engineer — human or agent — can still pick up the system's **mental model** without reading every file: architecture, intent, relationships, load-bearing constraints. Docs describe how to think about the system; the code carries the rest.

**The project's own rules win.** If the repo has an `update-docs` skill or a `documentation-standards.md` (anywhere under `docs/`), read it and follow it. Everything under [Documentation standards](#documentation-standards) below applies only where the project is silent.

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

3. **Assess significance** with the tiers in the standards. Implementation-level ⇒ say so and stop: *"These changes are implementation-level — no documentation updates needed."*

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

5. **Write the updates** to the standards below, the gated items once confirmed. Two moves carry this step: **consolidation** — every doc you touch ends tighter, not longer — and **distillation** — a shipped spec's surviving decisions move into the durable doc and the spec goes. When the change alters the system's shape, update the structure map and the always-loaded file as well; both are curated, and an entry there is earned (see *Spotlight the load-bearing*).

6. **Verify** every doc you touched:

   - re-read it end-to-end as a cold reader: does it hand over the mental model without a tour of the files?
   - cross-references resolve; paths are repo-root-relative; no source pasted (prose or pseudo-code call chains are fine);
   - grep the docs tree for the basename of anything you moved, renamed, or deleted — every hit resolves;
   - grep for each concept the change replaced — a surviving mention passes the future-need test in *Describe the current state*.

7. **Check the surfaces above the docs.** An onboarding or bootstrap skill, if the project has one: a new top-level doc its routing misses, a renamed doc on its always-read list, a drifted path — routine edits inside an existing doc leave it alone. `CLAUDE.md` / `AGENTS.md` is paid on every request, so it holds load-bearing facts plus a map of where to read the rest; it changes only when a cross-cutting rule appeared or one's framing rotted, which most branches don't do.

Close with what you updated, deleted, and left alone, with the reason for each.

---

## Documentation standards

What good docs look like and the rules to hold while editing. A project's own standards override these.

### The three that matter most

1. **Mental models, not code.** Describe how to _think_ about a subsystem — its core abstraction, relationships, invariants, decisions and their why. Function bodies, signatures, and type definitions rot on the next commit and duplicate what the code says; a technical detail earns a place only when it makes the model easier to grasp. Point at code with one-line references (`the parser: src/parse.ts`) and let readers grep the real names.

2. **Directory structures as an indented tree.** Indent under the directory name, with inline `#` comments; concise and scannable beats exhaustive:

   ```
   src/
     payments/
       checkout.ts     # session creation
       webhooks.ts     # event handlers
     auth.ts
   docs/
     payments.md
   ```

3. **Describe the current state.** Git history is the changelog, so a doc has no "added X", "changed Y", "as of version Z". When something changes, reshape the prose so it states what is true now, in the present tense. Watch for the diff leaking in with a present-tense disguise — "B, not A", "replaces A", "no longer" — every word true, the sentence shaped like the change instead of the system. The **future-need test** for any trace of the before-state: *will a reader who never saw A need this?* Usually not — name B and let history keep A. A earns a mention while the answer is yes: it still bites today (state the hazard as a present fact, without the narrative), or the transition is mid-flight and the coexistence is part of the system.

### The rest

- Paths are repo-root-relative.
- No API reference tables generated from code, and nothing a filename or folder already says.
- Planned or unproven behavior is marked as such (a status line, a spec, an open question) rather than stated as fact.
- **Docs lead, code follows.** A doc/code disagreement is a doc bug or a design regression; resolve it explicitly rather than silently matching either side to the other.
- Worth writing: the core abstraction and how to reason with it; decisions and the alternatives they beat; module boundaries and relationships; behavioral flows as prose or pseudo-code; the invariants a newcomer would otherwise violate; one-line pointers to the files that matter.

### Documentation shape — design vs proposal

Organize by kind of content, not by feature churn:

- **Design / architecture docs** say what is true today — updated in place, never appended to.
- **Specs, plans, roadmaps** are proposals. When one ships, distill its surviving decisions into the design doc it touches and prune or archive the proposal; a shipped spec left "for history" leaves two docs describing one subsystem with no way to tell which is live.
- **Status and rationale** (a README status line, an open-questions log) is the home for "shipped vs not" and "why this way", keeping those markers out of the design docs.

### When docs need updating

**Update when** a new module, interface, flow, or config isn't reflected; a doc describes behavior the change altered or removed; the structure map no longer matches; a cross-reference went stale; or a shipped proposal should distill into a durable doc. **No update** when the change is implementation-level and leaves the developer's model of the system intact.

Significance tiers:

- **None** — bug fixes, internal refactors, tests, dependency bumps.
- **Module-level** — a new function, flow, or option inside an existing subsystem: update the one doc that owns it.
- **Architecture-level** — a new subsystem, integration, boundary, or policy: may touch the structure map, a new doc, the status line, and the always-loaded file. Assume the doc _structure_ needs reconsidering, not just a wording patch at the point of change.

### Spotlight the load-bearing, not the complete

The reader is a senior engineer who will read the code. Re-listing what the code enumerates spends their attention and rots when the code changes; name what is load-bearing and leave the complete list to the source.

- List the interfaces, modules, or fields a reader _must_ grasp to hold the model; the rest lives in the code or gets one grouped mention.
- A table row, an index entry, a structure-map line is earned, not automatic: fold a secondary change into an existing entry; add one only when a reader needs it to navigate. A specialized deep-dive doc is linked from its owning subsystem doc and stays out of the map.
- No live counts ("seven handlers"). A cardinal number rots silently, drifts between docs, and nobody navigates by it. Name the few that matter.
- Draw a flow rather than narrate it: an indented tree or an arrow chain (`request → middleware → handler`) beats a long sentence threading the same path.

### Consolidation — adding is an opportunity to simplify

Every touch leaves the doc tighter, so its size stays stable as the system grows: re-read the whole doc, not just the section you're editing; merge overlap instead of writing a second description; combine small related sections and restructure when the reading order has gone disjoint; cut what drifted into implementation detail back to the mental model; edit in place rather than appending. Deletion is half the work — a branch that adds thirty lines and deletes none of the newly redundant prose has done the other half only.

### Maintenance cadence

Every few months, or after a major model release, re-read the docs structure and any doc-maintenance skills. Guardrails written for an older model can become friction for a newer one; removing stale guidance carries the same weight as adding new.
