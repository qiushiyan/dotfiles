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
| `folder`, or nothing while on the default branch and no branch named | **reconcile** — the whole folder against the repo |
| a branch/slug, or nothing while on a feature branch | **closeout** — that branch's briefs alone |

Closeout takes the branch that landed: the argument, else the one the user's words name, else `git branch --show-current`. Name the pass before anything else. Four rules hold across all of them:

- **Scope is the domain the pass names, plus every brief whose listing row reads `#N merged`.** Finished work is finished wherever it sits, so a merged row is a second anchor, carried through the same steps. Any other brief *file* outside the domain is left unread and unedited whatever drift the listing shows; the folder note is the pass's own, whatever the domain.
- **State comes from the repo.** The listing's join resolves PRs and branches through the slug and knows nothing of file sets or production, and every miss reads finished work as nothing — so `git worktree list`, `gh pr list --state open`, and `git diff --stat <default>...<branch>` are read, not inferred.
- **Write in the same turn; the human's turn is for the significant verdicts only** (§ What waits). A verdict the repo already backs — a merged branch deletes, a discharged gate is noted, a retired name leaves the note — is applied as soon as it is reached, and the report is the record of what was written.
- **Brief prose follows the handoff skill** — `~/.claude/skills/handoff/SKILL.md` § 4, or the repo's own handoff skill where it ships one. Read it when a verdict writes brief text.

## Closeout

A branch landed and its session is closing: its brief is spent, and the briefs that named it may have moved.

1. **Establish the branch and prove it landed.** `brief` (the listing) first: every row reading `#N merged` is a second anchor for this pass. Then `brief closeout <branch> --json` returns the anchor (the brief named `<branch>` or `review-<branch>`, live or retired, or `null` when none was written), the landed state from gh, the changed files, and every live brief that might belong, each with its reasons: `relation` (a lineage field on either side names the other), `path` (its `paths:` overlap the changed files), `cluster`, `run`. On a busy folder the JSON runs past the 10 k the harness shows you, so read it from a file:

   ```bash
   S=<your scratchpad directory>
   brief closeout <branch> --json > "$S/closeout.json"
   jq -c '{anchor: .anchor.slug, merged: .landed.merged, pr: .landed.pr.number, files: (.files|length)}' "$S/closeout.json"
   jq -r '.candidates[] | [.slug, ([.reasons[].kind]|unique|join("+")), ([.reasons[]|select(.kind=="relation")|.detail]|join("; "))] | @tsv' "$S/closeout.json"
   ```

   ```
   # the shape — not today's folder
   {"anchor":"feat/client-data-corpus-by-default","merged":true,"pr":5941,"files":26}
   feat/client-data-corpus-reuse-on-publish   cluster+path+prose+relation+run   its rests-on: names the anchor (line 21)
   infra/loopy-master-disk-throughput         cluster+path+relation             anchor's collides-with names it; its rests-on: names the anchor (line 27)
   fix/ux-cut-turn-honesty                    path
   ```

   The path lists behind a `path` reason are in the file when step 2 needs them. When gh reads the branch unmerged but the invocation says it landed, run the command once more — a merge clicked seconds earlier reads open — then do steps 2–4 on what it shows and hold only the writes; the report ends with `/distill-handoffs <branch>` to run once the PR reads merged.
   Done when the landed state is read and the anchor is resolved or its absence explained.

2. **Judge the domain from the reasons, before opening any body.** `relation` admits. `path` admits when the overlap is the anchor's subject rather than plumbing both touch — read the overlapping files, not their count. `cluster` or `run` alone excludes: a cluster is a workstream, and on a busy folder it names half the briefs. Write the domain as a list, one reason per line; everything else is out of scope from here.
   Done when every candidate carries admit or exclude with its reason.

3. **Read the anchor and each admitted brief whole; `brief drift` the admitted ones.** The payload is what this branch made *moot* — a premise it shipped, a gate it discharged, a collision it settled — as much as what it falsified.

4. **Verdicts** (§ Verdicts): the anchor deletes when its work landed and rewrites when its premise died; each admitted brief gets a field to correct, a note, or leave.

5. **Write** per § Verdicts, references before files, holding back only what § What waits names. Re-anchor every brief you edited and `brief check <slug>` each; a bare `brief check` warning on a brief you did not touch goes in the report.
   Done when `brief check <slug>` is clean on every brief you touched.

6. **Report.** Short prose: what landed, in a line; the anchor's verdict and what was written for it; per admitted brief, what moved and the edit made; the `_clusters.md` change; the count of briefs out of scope and unread; then, under their own heading, the items that wait, each with the one word that releases it. A pass with nothing waiting says so.

## Reconcile

The periodic pass over everything, every few days or after a busy week. Most briefs come out untouched. A folder of one or two briefs has no cross-brief view to derive — steps 1 and 3 still run, and the report is the verdicts alone.

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

4. **Write** per § Verdicts, holding back only what § What waits names. Done when every touched brief carries a fresh anchor and `brief check` is clean.

5. **Report.** The refresher is the deliverable, written for someone who wrote these documents and no longer remembers them: what each cluster is about; per brief, its goal in a sentence and its state; the collisions and the order they imply; per brief, **rewrote**, **noted**, **deleted**, or **left** — and, under their own heading, the verdicts that wait for the human with the one word that releases each.

## Question-led

"Can the cutover work move up?" is a judgement about the work; the folder edits follow from it. The human has usually warmed the context before asking — spend that reading rather than repeating it.

- Read every brief whole; a partial read yields a confident map of the wrong shape, and the map is what the question asks.
- Verify what the answer turns on — a gate said to be discharged, a status paragraph, a quoted number — against the repo, and for running behaviour against production. The briefs are the documents the human is asking you to doubt.
- Derive only the cross-brief view the question needs: clusters, collisions from the diffs rather than the declared fields, the gates, the order those imply. Weigh the note's ordering properties rather than re-ranking from scratch, and treat any state it asserts as a claim the reconcile pass measures.
- Answer plainly, "no" included, naming what would change the answer and what you could not verify.

Then run Reconcile steps 3–5, which the answer usually moves; the report leads with the answer and carries the verdicts under it.

## What waits

Four verdicts spend a judgment the repo cannot back, and those alone wait for the human — the pass does everything else first and lists these under their own heading, each with the one word that releases it:

- **rewrite** — a successor brief is a new goal, and a goal is a design;
- **keep** over delete — a `kept:` retirement;
- **delete** of a brief whose branch does not read merged;
- a change to the note's **order** beyond slotting an unplaced brief or dropping a retired name, and a cluster coined or removed.

## Verdicts

Four, and each is a fact the sweep found, not a design it chose — the receiving session keeps the design. A solution shape written into a brief converts it into a work order and spends the judgement that session exists to apply; where a shape must be recorded, record its provenance beside it (proposed by whom, costed or not, what it has yet to answer).

- **Delete** — the work landed. § Retirement.
- **Rewrite** — the premise died: `brief new <forward-slug>` scaffolds the successor, every lesson and dead-end that still holds moves into it, and the superseded brief is deleted. Two briefs for one goal is the rot this skill clears.
- **Note** — the edges drifted: a discharged gate, a collision that appeared, a measurement already paid for, folded into the section it bears on as the case rather than the verdict. A gate on a production read is discharged only by a read you ran with the project's own production-reading skills; otherwise note the merge and leave the gate — "deployed" in the invocation is the release, not the read. A boundary move is written into both briefs, so neither session learns of it from the other's absence.
- **Leave** — nothing moved.

Writing order: references first (`_clusters.md`, the sibling head fields the CLI lists), then the file, then `brief anchor <slug> --by sweep` on every brief edited — an edited brief on its old anchor sends the next session to re-run drift you already resolved. `brief set <slug> <key> <value>` rewrites `pickup`, `cluster` or `run`; a lineage list (`rests-on`, `blocked-by`, `collides-with`) is edited in the file, one `  - ` item at a time, and `brief check <slug>` proves the head still parses before anything else is touched.

## Retirement

A brief is a view onto durable artifacts — the PR, the docs the sync pass updated, the issue or spec record. Once the work lands the view has nothing left to show, so:

- **Delete** — `brief delete <slug>`, exact slug, live or retired — once you can name the durable home the report will cite. It refuses while a head field or `_clusters.md` still names the slug: amend the note, drop the sibling items (a `supersedes:` entry naming a deleted brief points at nothing), fold any lesson a successor still needs into the successor's body, then delete. Read a live successor's lineage before deleting what it names — once a referrer is gone the reference report is silent about it. An `.evidence/` dir stays behind on purpose: the repo's docs cite these by path, so grep `docs/` for `.evidence` before removing one by hand.
- **Keep** — the one exception: a named live successor depends on a specific passage unique to this brief, and no durable owner can take that passage without loss. Folding is still preferred; keeping is for when folding would lose it. `brief retire <slug> --reason "kept: <successor-slug> needs § <section>"` — the `kept:` prefix is what the next reconcile reads to know the judgement was made, and the file is re-judged when the successor lands.

## The folder note

`_clusters.md` holds what the listing cannot derive: what each cluster *means*, and the order to work the live briefs in with the properties that order rests on. Membership, goals and state live in the listing; a copy in the note is stale by the next merge.

- It names live briefs only — a retirement removes the slug in the same write, and `brief check` flags a retired or unknown name and an empty cluster.
- A live brief `brief check` reports unplaced — in the domain or not — is slotted from its listing row where the order's stated properties put it, in the same pass, and the report says where and why; a rank the human wants elsewhere is one word back, where a deferred slot is the same warning re-read on every pass.
- Its "In flight" line is one live slug or "nothing". What a landed branch settled, when it deployed, what it measured — the docs and PRs are that archive.
- A date or identifier appears only as an unresolved constraint on a live brief ("run `<slug>` before the vendor cutoff on 2026-09-01"). A watch that requires action gets a brief; one that requires none lives in its issue or runbook.

Amend it when a cluster's meaning shifts, a name is coined or retired, or an ordering property proves wrong. A folder that has grown clusters worth naming earns a note; a wave list with dates is the listing, and goes stale in days.

## Escalation — session history

When a brief's provenance is genuinely unclear — what it was written from, or work the human recalls that no PR or doc records — the transcripts hold it: the `obelisk` skill, with the question named first. A dig costs real minutes and a large subagent budget; it earns its place on one specific unknown, not on a brief that reads thin.
