---
name: distill-handoffs
description: Reconcile this project's handoff briefs against what the repo has done since they were written — close out one landed branch's briefs, sweep the whole folder, or settle a question about which work moves next.
disable-model-invocation: true
argument-hint: [nothing on a feature branch → close out this branch; `folder` → the whole folder; a question, e.g. "can the cutover work move up?" → answer it]
---

# Sweep the brief folder

Handoff briefs live under `~/dev/.handoffs/<project>/`, one per next session, each written by a session that saw only its own PR. What a brief *asks for* usually survives; what it *says about the world* drifts. The sweep owns the cross-brief view — a premise that shipped, a gate that discharged, two briefs on one seam — and keeps the folder a **task board**: `_clusters.md` plus the listing say what to do next, and finished work is gone.

## Pick the pass

| the invocation carries | pass |
|---|---|
| a question | **question-led** — answer it, then make the folder agree |
| `folder`, or nothing while on the default branch | **reconcile** — the whole folder against the repo |
| nothing, or a branch/slug, while on a feature branch | **closeout** — this branch's briefs alone |

Name the pass before anything else. Three rules hold across all of them:

- **Scope is fixed when the pass names it.** A brief outside it is left unread and unedited whatever drift the listing shows; a folder warning about it is reported for the next reconcile, never fixed now.
- **State comes from the repo.** The listing's join resolves PRs and branches through the slug and knows nothing of file sets or production, and every miss reads finished work as nothing — so `git worktree list`, `gh pr list --state open`, and `git diff --stat <default>...<branch>` are read, not inferred.
- **Brief prose follows the handoff skill** — `~/.claude/skills/handoff/SKILL.md` § 4, or the repo's own handoff skill where it ships one. Read it when a verdict writes brief text.

## Closeout

A branch landed and its session is closing: its brief is spent, and the briefs that named it may have moved.

1. **Establish the branch and prove it landed.** `brief closeout <branch> --json` returns the anchor (the brief named `<branch>` or `review-<branch>`, live or retired, or `null` when none was written), the landed state from gh, the changed files, and every live brief that might belong, each with its reasons: `relation` (a lineage field on either side names the other), `path` (its `paths:` overlap the changed files), `cluster`, `run`. An unmerged branch makes the closeout premature — report the state and stop unless the user said to proceed.
   Done when the landed state is read and the anchor is resolved or its absence explained.

2. **Judge the domain from the reasons, before opening any body.** `relation` admits. `path` admits when the overlap is the anchor's subject rather than plumbing both touch — read the overlapping files, not their count. `cluster` or `run` alone excludes: a cluster is a workstream, and on a busy folder it names half the briefs. Write the domain as a list, one reason per line; everything else is out of scope from here.
   Done when every candidate carries admit or exclude with its reason.

3. **Read the anchor and each admitted brief whole; `brief drift` the admitted ones.** The payload is what this branch made *moot* — a premise it shipped, a gate it discharged, a collision it settled — as much as what it falsified.

4. **Verdicts** (§ Verdicts): the anchor deletes when its work landed and rewrites when its premise died; each admitted brief gets a field to correct, a note, or leave.

5. **Report, then stop.** Short prose: what landed, in a line; the anchor's verdict; per admitted brief, what moved and the proposed edit; the `_clusters.md` change; the count of briefs out of scope and unread. The human owns which briefs change.

6. **Write** the approved plan per § Verdicts, references before files. Re-anchor every brief you edited; run `brief check` and report any warning about a brief outside the domain without acting on it.
   Done when `brief check` is clean on every brief you touched and the listing shows the folder as the report described.

## Reconcile

The periodic pass over everything, every few days or after a busy week. Most briefs come out untouched. A folder of one or two briefs has nothing to derive — say so and stop.

1. **State.** `brief` and `brief --json` join every brief against the repo and decorate each gate with its PR's state; then the reads the join is too shallow for (the rule above). The listing closes on what the folder owes — an undefined cluster, a retired or unknown slug named in the note, a cluster with no live brief, a live brief nobody placed in the order. Those are derived, so they are the worklist.
   Done when every branch or PR the folder implies has a state you read.

2. **Read**, yourself — a delegated summary drops the file and path sets collisions are found by. Every brief's head; whole, every brief whose state moved (merged, PR opened, gate discharged, non-zero drift).

3. **Reconcile** — facts to establish, one per brief:
   - a merged branch is finished work → delete (§ Retirement);
   - a legacy `.md.done` without a `kept:` stamp → judge it once under § Retirement, delete or stamp;
   - each `blocked-by` is a claim about the world on the day it was written, and the world discharges gates quietly — verify each against the repo;
   - a brief with no cluster needs one; a cluster whose last brief left leaves the note with its paragraph;
   - `brief drift <slug>` on every non-zero drift, read for the instructions it makes moot as much as the claims it falsifies;
   - step 1's `--stat` file sets against the paths each brief names — a branch grows into a collision with no brief changing.
   Done when every brief carries a verdict.

4. **Report, then stop.** The refresher is the deliverable, written for someone who wrote these documents and no longer remembers them: what each cluster is about; per brief, its goal in a sentence and its state; the collisions and the order they imply; per brief, **rewrite**, **note**, **delete**, or **leave**. The human owns the per-brief plan.

5. **Write** the approved plan per § Verdicts. Done when every touched brief carries a fresh anchor and `brief check` is clean.

## Question-led

"Can the cutover work move up?" is a judgement about the work; the folder edits follow from it. The human has usually warmed the context before asking — spend that reading rather than repeating it.

- Read every brief whole; a partial read yields a confident map of the wrong shape, and the map is what the question asks.
- Verify what the answer turns on — a gate said to be discharged, a status paragraph, a quoted number — against the repo, and for running behaviour against production. The briefs are the documents the human is asking you to doubt.
- Derive only the cross-brief view the question needs: clusters, collisions from the diffs rather than the declared fields, the gates, the order those imply. Weigh the note's ordering properties rather than re-ranking from scratch, and treat any state it asserts as a claim the reconcile pass measures.
- Answer plainly, "no" included, naming what would change the answer and what you could not verify.

Then run Reconcile steps 3–5, which the answer usually moves; the report leads with the answer and carries the verdicts under it.

## Verdicts

Four, and each is a fact the sweep found, not a design it chose — the receiving session keeps the design. A solution shape written into a brief converts it into a work order and spends the judgement that session exists to apply; where a shape must be recorded, record its provenance beside it (proposed by whom, costed or not, what it has yet to answer).

- **Delete** — the work landed. § Retirement.
- **Rewrite** — the premise died: `brief new <forward-slug>` scaffolds the successor, every lesson and dead-end that still holds moves into it, and the superseded brief is deleted. Two briefs for one goal is the rot this skill clears.
- **Note** — the edges drifted: a discharged gate, a collision that appeared, a measurement already paid for, folded into the section it bears on as the case rather than the verdict. A boundary move is written into both briefs, so neither session learns of it from the other's absence.
- **Leave** — nothing moved.

Writing order: references first (`_clusters.md`, the sibling head fields the CLI lists), then the file, then `brief anchor <slug> --by sweep` on every brief edited — an edited brief on its old anchor sends the next session to re-run drift you already resolved. A head field changes through `brief set <slug> <key> <value>`; a hand splice of the fenced head takes a neighbouring field with it, and `brief check` only finds that afterwards.

## Retirement

A brief is a view onto durable artifacts — the PR, the docs the sync pass updated, the issue or spec record. Once the work lands the view has nothing left to show, so:

- **Delete** — `brief delete <slug>`, exact slug, live or retired — once you can name the durable home the report will cite. It refuses while a head field or `_clusters.md` still names the slug: amend the note, drop the sibling items (a `supersedes:` entry naming a deleted brief points at nothing), fold any lesson a successor still needs into the successor's body, then delete. Read a live successor's lineage before deleting what it names — once a referrer is gone the reference report is silent about it. An `.evidence/` dir stays behind on purpose: the repo's docs cite these by path, so grep `docs/` for `.evidence` before removing one by hand.
- **Keep** — the one exception: a named live successor depends on a specific passage unique to this brief, and no durable owner can take that passage without loss. Folding is still preferred; keeping is for when folding would lose it. `brief retire <slug> --reason "kept: <successor-slug> needs § <section>"` — the `kept:` prefix is what the next reconcile reads to know the judgement was made, and the file is re-judged when the successor lands.

## The folder note

`_clusters.md` holds what the listing cannot derive: what each cluster *means*, and the order to work the live briefs in with the properties that order rests on. Membership, goals and state live in the listing; a copy in the note is stale by the next merge.

- It names live briefs only — a retirement removes the slug in the same write, and `brief check` flags a retired or unknown name and an empty cluster.
- Its "In flight" line is one live slug or "nothing". What a landed branch settled, when it deployed, what it measured — the docs and PRs are that archive.
- A date or identifier appears only as an unresolved constraint on a live brief ("run `<slug>` before the vendor cutoff on 2026-09-01"). A watch that requires action gets a brief; one that requires none lives in its issue or runbook.

Amend it when a cluster's meaning shifts, a name is coined or retired, or an ordering property proves wrong. A folder that has grown clusters worth naming earns a note; a wave list with dates is the listing, and goes stale in days.

## Escalation — session history

When a brief's provenance is genuinely unclear — what it was written from, or work the human recalls that no PR or doc records — the transcripts hold it: the `obelisk` skill, with the question named first. A dig costs real minutes and a large subagent budget; it earns its place on one specific unknown, not on a brief that reads thin.
