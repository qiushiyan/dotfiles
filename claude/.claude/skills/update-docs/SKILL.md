---
name: update-docs
description: Update a project's documentation after a change lands, so the docs still give a senior engineer the mental model of the system. Use when the user wants docs updated to reflect recent or shipped changes, or brought back in line with the code. Defers to a repo's own update-docs skill or documentation-standards.md when present.
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git merge-base:*), Bash(git symbolic-ref:*), Bash(git show-ref:*), Bash(git branch:*), Read, Write, Edit, Glob, Grep, Agent
---

# Update documentation from the diff

You maintain a project's docs. The goal: after a change lands, the docs still hand a senior engineer — human or agent — the **mental model** to understand the system without reading every file. They cover architecture, intent, relationships, and the load-bearing constraints; they never duplicate code.

**Defer to the project first.** If the repo has its own `update-docs` skill or a `documentation-standards.md` (anywhere under `docs/`), that is authoritative — read it and follow it. This skill is the general default for repos that don't specify their own; the standards in its second half are what you apply when the project is silent.

## Workflow

```
Gather diff
  → Read existing docs
  → Assess significance
  → Propose plan ──→ [user confirms] ──→ Update docs ──→ Verify
       │                    │
       ↓                    ↓
  "No changes needed"   User adjusts scope
   (exit early)
```

Three exit points: (1) the changes are purely implementation-level and need no doc update, (2) the user rejects or defers the proposal, (3) updates are written and verified.

## Step 1 — Gather the diff

Detect the base branch rather than assuming `main` — projects vary (`main`, `master`, `develop`). Diff the **working tree** against the merge-base (`git diff $BASE`, no `..HEAD`) so the diff captures both committed and still-uncommitted work — some workflows commit first, others fold changes into the working tree:

```bash
BASE_BRANCH=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
[ -z "$BASE_BRANCH" ] && for c in main master develop; do
  git show-ref --verify --quiet "refs/heads/$c" && BASE_BRANCH=$c && break
done
BASE=$(git merge-base HEAD "${BASE_BRANCH:-HEAD}")

git diff --stat $BASE
git diff $BASE -- . ':!*lock*' ':!*.snap' ':!node_modules' ':!dist'   # widen/narrow excludes per project
git log --oneline $BASE..HEAD   # committed intent, if any
git status --short              # what's still uncommitted
```

If `BASE` equals `HEAD` (you're on the base branch), `git diff $BASE` is just the working-tree diff — still correct. Read the diff and identify:

- **New modules, endpoints, jobs, schemas, config** — may need a new doc section or a structure-map mention.
- **Changed interfaces or control flow** between components — relationship and flow updates.
- **Removed or renamed concepts** — doc cleanup or deletion.
- **Behavioral or policy changes** — updated descriptions of what happens when.

Asked to update docs more than once in a session? Don't re-diff the whole range — start from the first change after the previous pass.

## Step 2 — Read the existing docs

Find the docs home (commonly `docs/` plus the always-loaded mental-model file — `CLAUDE.md` or `AGENTS.md`). Read every doc that overlaps the changed areas end-to-end; understand the current narrative before touching it. Also scan for **stale content** the change may have outdated — a description of behavior that no longer holds, a "known gaps" note now closed, a forward-looking spec that just shipped and should distill into a durable doc.

## Step 3 — Assess significance

Apply the significance tiers in the standards below. If the change is implementation-level, stop here: _"These changes are implementation-level — no documentation updates needed."_

## Step 4 — Propose a plan

**Do not start writing yet.** Present a concrete proposal and wait for confirmation:

```
## Proposed documentation updates

### Scope
[One sentence: what the work does at a high level]

### Changes
- `docs/<area>.md` — add section "X"; update the data-flow description
- `docs/README.md` — add the new module to the structure map
- `CLAUDE.md` / `AGENTS.md` — no change (no new cross-cutting rule)

### Distillation
- `docs/specs/<name>.md` — shipped; fold surviving decisions into `docs/<area>.md`, then prune

### Deletions
[Only when a doc / section is fully superseded. Be deliberate.]

### No action
- `docs/<other>.md` — not affected
```

The user may adjust scope, skip docs, or add areas you missed.

## Step 5 — Update the docs

Write the updates from your confirmed plan, applying the **Documentation standards** below. Two rules carry this step — apply them as defined there: **consolidation** (every doc you touch gets tighter, not just longer) and **distillation** (a shipped spec's surviving decisions fold into the durable doc, then the spec is pruned). When the change alters the system's shape, also update the structure map / file index and any always-loaded mental-model file.

## Step 6 — Verify

1. Re-read each modified doc end-to-end for a coherent narrative.
2. Check cross-references between docs still resolve.
3. Confirm no absolute paths leaked in — repo-root-relative only.
4. Confirm no source code was pasted (prose / pseudo-code call chains are fine).
5. Grep across the docs tree for the basenames of any file you moved, renamed, or deleted — every hit should resolve.
6. Check: _"If a teammate reads this cold, do the docs give them the mental model without reading every file?"_

## Step 7 — Maintain the surfaces above the docs

- **A topic-scoped onboarding / bootstrap skill**, if the project has one: check the branch didn't break it — a new top-level doc its routing doesn't cover, a renamed doc on its always-read list, a drifted file path. Routine edits inside an existing doc don't touch it.
- **The always-loaded mental-model file** (`CLAUDE.md` / `AGENTS.md`) is appended to *every* request, so every word is paid on every task. Keep it to load-bearing facts plus a map of *where to read the rest*; point rather than re-explain (an invariant states its conclusion and points to the doc holding the mechanism), and never let an enumeration, count, or status dump settle here. Touch it only when a new cross-cutting rule emerged or one's framing rotted — the bar is high; most branches need no change.

Close with a short summary of what you updated, what you deleted, what needed no change, and why.

---

## Documentation standards

What good docs look like, and the rules to hold while editing. A project's own standards override these.

### The three that matter most

1. **Descriptive mental models, not code.** Describe how to _think_ about the subsystem — the core abstraction, the relationships, the invariants, the decisions and their _why_. Never paste source: function bodies, signatures, and type definitions rot instantly and duplicate what the code already says. Include a technical detail only when it makes the mental model easier to grasp — not for completeness. Point at the code with one-line references (`the parser: src/parse.ts`); let readers grep the real names.

2. **Directory structures as an indented tree.** When showing where code or docs live, indent under the directory name — don't repeat the full path on every file. Inline `#` comments are welcome. Concise and scannable beats exhaustive:

   ```
   src/
     payments/
       checkout.ts     # session creation
       webhooks.ts     # event handlers
     auth.ts
   docs/
     payments.md
   ```

   Not: `src/payments/checkout.ts`, `src/payments/webhooks.ts`, `src/auth.ts` listed one full path at a time.

3. **Describe the current state, never a changelog.** No "added X", "changed Y", "as of version Z". When something changes, restructure the prose so it describes what is true _now_ — git history is the changelog. Present tense for what exists; future tense ("we will…") is a smell that a proposal has leaked into a description of reality.

### The rest

- **No absolute file paths** — repo-root-relative only.
- **No API reference tables generated from code**, and no descriptions of things obvious from a filename or folder. That's what the code is for.
- **Don't describe unverified or aspirational behavior in the present tense.** If something is planned or unproven, mark it as such (a status line, a spec, an open-question note) — don't launder a hope into a fact.
- **Docs lead, code follows.** A doc/code disagreement is a doc bug or a design regression — resolve it explicitly, don't silently match a stale doc to the code or vice versa.
- **Do write:** the core abstraction and how to reason about it; decisions and the alternatives they beat; module relationships and boundaries; behavioral flows as prose or pseudo-code; the load-bearing invariants a newcomer would otherwise violate; one-line pointers to the files that matter.

### Documentation shape — design vs proposal

Organize docs by **kind of content**, not by feature churn:

- **Design / architecture docs** describe what is true today. Durable — updated in place, never appended to.
- **Forward-looking specs / plans / roadmaps** are proposals: what we might build and why. When a proposal ships, distill its surviving decisions into the design doc it touches, then prune or archive the proposal. The drift to avoid: a shipped spec left in place "for history," so two docs now describe one subsystem and no reader can tell which is live.
- **Status and rationale** (a README status line, an open-questions log) is the honest home for "shipped vs not" and "why this way." Keep those markers out of the design docs themselves.

### When docs need updating

**Update when** a new module / interface / flow / config was introduced and isn't reflected; a doc describes behavior the change altered or removed; the structure map no longer matches reality; a cross-reference went stale; or a shipped proposal should distill into a durable doc.

**No update needed when** the change is implementation-level (internal refactor, bug fix, test) and doesn't change how a developer thinks about the system.

**Significance tiers:**

- **None** — bug fixes, internal refactors, test additions, dependency bumps.
- **Module-level** — a new function, flow, or option inside an existing subsystem. Update the one doc that owns it.
- **Architecture-level** — a new subsystem, integration, boundary, or policy. May touch the structure map, a new doc, the status line, and the always-loaded mental-model file.

### Spotlight the load-bearing, not the complete

The reader is a senior engineer who will read the code. Re-listing what the code already enumerates spends their attention and rots the moment the code changes. Name what is load-bearing; leave the complete list to the source.

- **Don't enumerate exhaustively.** List the interfaces, modules, or fields a reader *must* grasp to hold the mental model; let the rest live in the code or get one grouped mention. A complete catalogue is the code's job.
- **A table row is earned, not automatic.** A new function or type is not a reason for a new row — fold a secondary change into an existing entry; add a row only when a reader needs that item to navigate.
- **No live counts.** "Seven handlers", "the five rules" — a cardinal number is a maintenance tax that silently rots (and drifts: one doc says seven while another says five), and a reader never navigates by it. Name the few that matter; the count is the code's to know.
- **Draw a flow, don't narrate it.** A relationship or sequence reads better as an indented tree or an arrow chain (`request → middleware → handler`) than threaded through a long sentence.

### Consolidation — adding is an opportunity to simplify

Every time you touch a doc, make it tighter, not just longer — the goal is a stable size as the system grows.

- Re-read the whole doc, not just the section you're editing.
- Merge overlap instead of writing a second description of the same concept; edit in place rather than appending a new section.
- Combine small related sections; restructure if the reading order has gone disjoint.
- Cut anything that drifted into implementation detail back to the mental model.
- **Deletion is maintenance.** A branch that adds 30 lines and deletes none of the newly-redundant prose has done half the work. For an architecture-level change, assume the doc _structure_ needs reconsidering, not just a wording patch at the point of change.

### Maintenance cadence

Every few months, or after a major model release, re-read the docs structure and any doc-maintenance skills. Guardrails written for an older model can become friction for a newer one. Treat removing stale guidance with the same weight as adding new.
