---
name: handoff-sweep
description: Periodic pass over this project's handoff batons — reconcile the folder against what the repo has done since they were written, or answer a question about which work should move next.
disable-model-invocation: true
argument-hint: [optional: a question to settle, e.g. "can the cutover work move up?"; or a cluster to scope to; or nothing, for the reconcile pass]
allowed-tools: Bash(bash ~/.claude/skills/handoff-sweep/baton-index.sh:*), Bash(git log:*), Bash(git diff:*), Bash(git show:*), Bash(git branch:*), Bash(git status:*), Bash(git merge-base:*), Bash(git rev-list:*), Bash(git worktree list:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh api:*), Bash(obelisk:*), Read, Edit, Write, Glob, Grep, Agent
---

# Sweep the baton folder

Batons accumulate faster than memory holds them. Several land in a busy week, each written by a session that saw only its own PR; they are picked up a day or a weekend later, and by then the folder is a set of half-remembered names.

**Two passes, chosen by what `$ARGUMENTS` carries.** They share their first two steps and their last two, and differ in the middle — in how much judgement the human is asking for.

- **Nothing, or a cluster name → the reconcile pass** (step 3). Mechanical, and the one that runs every few days: retire what merged, discharge what is no longer blocked, keep the folder's own note true. Most batons come out untouched, because what a baton *asks for* usually survives — what goes stale is what it *says about the world*.
- **A question → the question-led pass** (step 4). "Can the cutover work move up?" is a judgement about the work, not about the folder. The human will normally have warmed the context before invoking — an onboarding pass, a live-state read — so that reading is already paid for; spend it rather than repeating it. Answer the question first, then make the folder agree with the answer.

**What the sweep owns is the cross-baton view.** A single baton's own drift already has a home: it carries an anchor and opens with a drift check its receiving session runs at pickup. What no baton can see is the folder around it — that two of them edit the same seam, that one silently blocks another, what order they should run in. That is the payload of both passes.

A reconcile pass over a folder of one or two batons has nothing to derive. Say so and stop. A question about one baton is always fair.

## 1 — State, before anything

```sh
bash ~/.claude/skills/handoff-sweep/baton-index.sh
```

Each baton's declared fields joined against live git: cluster, anchor, how far the default branch has moved since that anchor, and whether a branch or PR exists for the slug. This is the lookup — read it, never reconstruct it from memory.

**Then a state pass, because the index's join is deliberately shallow and every miss it makes fails the same direction: finished work reported as nothing.** It matches a PR by head branch equal to the slug, so a baton whose branch carries a convention prefix (`feat/<slug>`) reads `unstarted` over an open, review-ready PR; and a branch nobody has filed a PR for is invisible to it entirely — which is exactly the state a large finished branch sits in for days. Run `git worktree list`, `gh pr list --state open`, and for every baton with a branch, `git diff --stat <default-branch>...<branch>`: the file set and its size, not merely whether it exists.

State is the most load-bearing input to everything below, and the first thing a human asks about. Take it from the repo, never from the index alone.

Done when every baton appears in the index, and every branch or PR the folder implies has been resolved to a state you read rather than inferred.

The index closes on **what the folder owes** — a cluster a baton names that `_clusters.md` defines nowhere, an ordering entry pointing at a baton that no longer exists, a live baton nobody has placed in the order. Those three are derived, so they are the reconcile pass's worklist rather than something to notice: whatever it lists, step 5 resolves.

## 2 — Read the folder

Yourself, not delegated: a subagent's summary drops the file and path sets that collisions are found by.

- **Reconcile pass** — every baton's head block, plus whole any baton whose state moved: merged, PR opened, gate discharged, or non-zero drift. If the pass ends up touching the order rather than only membership, read the rest whole before doing so.
- **Question-led pass** — every baton, whole. Reading four of nine produces a confident map of the wrong shape, and the question is exactly what that map answers.

Done when every baton in scope has been read at the depth its pass asks for.

## 3 — The reconcile pass

Work the folder against the state you just read. Each item is a fact to establish, not a judgement call:

- **Retirements.** A baton whose branch merged is finished work; it goes to step 6 as a retire.
- **Gates.** Every `blocked-by` is a claim about the world on the day it was written, and the world discharges gates quietly — a dependency merges, a constant lands on the default branch, a fix starts serving in production. Verify each against the repo, and against production where the gate is a claim about running behaviour. A stale gate is worse than a stale anchor: it suppresses runnable work, and nobody looks inside a baton that says it cannot start.
- **Membership.** A baton the index shows as `(none)` needs a cluster named. A retirement that empties a cluster, or a new baton that coins one, is a change to the folder's own note.
- **Drift with teeth.** For every baton the index shows with non-zero drift, run its own drift query and read the result. Report the instructions the drift makes *moot* — a shipped premise, a merged dependency, a restructured landing site — not only the claims it falsifies: naming the code as the truth resolves a brief's wrong claims and says nothing about an instruction that shipped while the brief sat.
- **Collisions that appeared without anyone writing one.** Compare the file sets from step 1's `--stat` against the paths each baton names. A branch can open a collision with no baton changing: one brief that read `collides-with: none`, and whose ordering note said it "slots anywhere", was a day later blocked across a third of its scope by a sibling that had grown from an unstarted brief into eighty-seven files, and unblocked again the day that merged.

Done when every baton carries a verdict — retire, or a named field to correct, or nothing to do.

## 4 — The question-led pass

The question is the deliverable; the folder edits follow from it. Answer it the way the human would if they had the folder in their head:

- **Ground it in what you read, and verify what it turns on.** The claims that decide the answer — a gate said to be discharged, a status paragraph, an ordering property, a number someone quoted — get checked against the repo and, where they are claims about running behaviour, against production. A sweep that answers from the batons alone is quoting the documents the human is asking you to doubt.
- **Derive the cross-baton view the question needs**, and only that: clusters, collisions from the diffs rather than from the declared fields, the gates, and the order the two imply. Declared `collides-with` fields are hypotheses to check.
- **Weigh the folder note's ordering properties** against what you now see, rather than re-deriving a ranking from scratch — but treat any state it asserts, a cluster marked done or a baton called merged, as the thing step 1 just measured.
- **Answer plainly, including "no".** Name what would change the answer, and what the answer rests on that you could not verify.

Then work step 3's list, which the answer usually moves.

Done when the question has an answer with its evidence named, and every baton in scope has a verdict.

## 5 — Report, then stop

The refresher is the deliverable of a reconcile pass, and decayed recall is why it exists — so write it as prose for someone who wrote these documents and no longer remembers them, not as a table restating the index. Cover: what each cluster is about; per baton, its goal in a sentence or two and its current state; the collisions and the resulting order; and per baton, the verdict you propose — **rewrite**, **note**, **retire**, or **leave**.

A question-led pass leads with the answer and carries the same per-baton verdicts under it.

Then wait. The human owns which batons change and how ambitious their scope should be.

Done when the human has approved a per-baton plan.

## 6 — Write

**Baton prose belongs to the handoff skill, not this one.** Whenever a verdict writes or edits baton text, its rules live in `~/.claude/skills/handoff/SKILL.md` § 4 — the two registers, the anchor, the cold-paste test, repo-relative paths, "this brief" — and where the repo ships its own handoff skill, that one is authoritative. Read it rather than working from memory of it; restating it here would fork it. The general document-writing levers are `~/.claude/skills/writing-for-agents/SKILL.md`.

Work the approved plan:

- **Rewrite** when the premise died: write the replacement under a forward slug (the handoff skill's naming rule — the branch the next session will work on), carry forward every lesson and dead-end that still holds, and remove the superseded file. Two batons for one goal is the rot this skill exists to clear.
- **Note** when the edges drifted: fold it into the section it bears on, as the case rather than the verdict.
- **Retire** when the work landed. A baton whose branch merged goes on drawing sweeps, slots and ordering arguments until it leaves the folder. These folders are usually not version-controlled, so prefer a rename (`<slug>.md.done`) to a delete — the index globs `*.md`, so the renamed file drops out of the table while its text survives — and say plainly that you renamed rather than removed.
- **Boundary moves** get written into both batons — the one gaining scope and the one losing it — so neither session discovers the move from the other's absence.
- **The folder's own note.** Where a `_clusters.md` exists, amend it when a cluster's meaning shifts, a name is coined or retired, or an ordering property proves wrong — it holds only what the index cannot derive, so membership and state stay in the batons and the table. Where none exists and the folder has grown clusters worth naming, writing it is a reasonable outcome; a wave list with dates is not, because the index regenerates that and a page of it goes stale in days.

**What a sweep adds is facts.** It sees the folder, so what it owes a baton is what the folder knows: a gate discharged, a collision that appeared, a premise that shipped, a measurement someone already paid for and the next session would otherwise buy twice. The receiving session keeps the design. A solution shape written in as a segmented plan converts a brief into a work order and spends the judgement that session existed to apply — and a sweep is the likeliest moment for it, because you have just built the folder-wide picture and the plan feels obvious. Where a shape must be recorded — it constrains the schedule, or it was the human's call — record its provenance beside it: proposed by whom, costed or not, what it has yet to answer. Then the next session can discard it on evidence rather than read it as scope.

Then **re-anchor every baton you touched**: today's date and the current default-branch sha, because its claims now rest on the tree you just read. An edited baton left on its old anchor invites the next session to re-run drift you already resolved.

Done when every touched baton carries a fresh anchor, a second index run shows the folder as you now describe it, and every row in that run parses. The index reads declared fields from a short head block, so a field pushed below it by a long opening, or a phrase in line 1 that shadows a field name, renders a baton clusterless or mis-clustered without erroring — and the note you just wrote then disagrees with the table it calls authoritative.

## Escalation — session history

A branch, not a step. When a baton's provenance is genuinely unclear — you cannot tell what it was written from, or the human recalls work that no PR or doc records — the transcripts hold it: read them with the `obelisk` skill, naming the question first. A full dig costs real minutes and a large subagent budget, so it earns its place on one specific unknown, not on a baton that merely reads thin.
