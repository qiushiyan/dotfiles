---
name: handoff-sweep
description: Periodic pass over this project's handoff briefs — reconcile the folder against what the repo has done since they were written, or answer a question about which work should move next.
disable-model-invocation: true
argument-hint: [optional: a question to settle, e.g. "can the cutover work move up?"; or a cluster to scope to; or nothing, for the reconcile pass]
allowed-tools: Bash(brief:*), Bash(git log:*), Bash(git diff:*), Bash(git show:*), Bash(git branch:*), Bash(git status:*), Bash(git merge-base:*), Bash(git rev-list:*), Bash(git worktree list:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh api:*), Bash(obelisk:*), Read, Edit, Write, Glob, Grep, Agent
---

# Sweep the brief folder

Briefs accumulate faster than memory holds them. Several land in a busy week, each written by a session that saw only its own PR; they are picked up a day or a weekend later, and by then the folder is a set of half-remembered names.

**Two passes, chosen by what `$ARGUMENTS` carries.** They share their first two steps and their last two, and differ in the middle — in how much judgement the human is asking for.

- **Nothing, or a cluster name → the reconcile pass** (step 3). Mechanical, and the one that runs every few days: retire what merged, discharge what is no longer blocked, keep the folder's own note true. Most briefs come out untouched, because what a brief *asks for* usually survives — what goes stale is what it *says about the world*.
- **A question → the question-led pass** (step 4). "Can the cutover work move up?" is a judgement about the work, not about the folder. The human will normally have warmed the context before invoking — an onboarding pass, a live-state read — so that reading is already paid for; spend it rather than repeating it. Answer the question first, then make the folder agree with the answer.

**What the sweep owns is the cross-brief view.** A single brief's own drift already has a home: it carries an anchor, and its receiving session runs the drift check at pickup. What no brief can see is the folder around it — that two of them edit the same seam, that one silently blocks another, what order they should run in. That is the payload of both passes.

A reconcile pass over a folder of one or two briefs has nothing to derive. Say so and stop. A question about one brief is always fair.

## 1 — State, before anything

```sh
brief          # the folder joined against git and gh
brief --json   # the same, typed — declared fields and derived state kept apart
```

Each brief's declared fields joined against the live repo: cluster, anchor age, drift count, whether a branch or PR exists for the slug — and every gate decorated with the live state of any PR it mentions, which pre-sorts step 3's verification: a gate whose PR already shows merged is half-discharged before you start.

**Then a state pass, because the join is deliberately shallow and every miss fails the same direction: finished work reported as nothing.** The join resolves PRs and branches through the slug and says nothing about file sets or production. Run `git worktree list`, `gh pr list --state open`, and for every brief with a branch, `git diff --stat <default-branch>...<branch>`: the file set and its size, not merely whether it exists.

State is the most load-bearing input to everything below, and the first thing a human asks about. Take it from the repo, never from the listing alone.

Done when every brief appears in the listing, and every branch or PR the folder implies has been resolved to a state you read rather than inferred.

The listing closes on **what the folder owes** — a cluster a brief names that `_clusters.md` defines nowhere, an ordering entry pointing at a brief that no longer exists, a live brief nobody has placed in the order. Those three are derived, so they are the reconcile pass's worklist rather than something to notice: whatever it lists, step 5 resolves.

## 2 — Read the folder

Yourself, not delegated: a subagent's summary drops the file and path sets that collisions are found by.

- **Reconcile pass** — every brief's head, plus whole any brief whose state moved: merged, PR opened, gate discharged, or non-zero drift. If the pass ends up touching the order rather than only membership, read the rest whole before doing so.
- **Question-led pass** — every brief, whole. Reading four of nine produces a confident map of the wrong shape, and the question is exactly what that map answers.

Done when every brief in scope has been read at the depth its pass asks for.

## 3 — The reconcile pass

Work the folder against the state you just read. Each item is a fact to establish, not a judgement call:

- **Retirements.** A brief whose branch merged is finished work; it goes to step 6 as a retire.
- **Gates.** Every `blocked-by` is a claim about the world on the day it was written, and the world discharges gates quietly — a dependency merges, a constant lands on the default branch, a fix starts serving in production. Verify each against the repo, and against production where the gate is a claim about running behaviour. A stale gate is worse than a stale anchor: it suppresses runnable work, and nobody looks inside a brief that says it cannot start.
- **Membership.** A brief the listing shows as `(none)` needs a cluster named. A retirement that empties a cluster, or a new brief that coins one, is a change to the folder's own note.
- **Drift with teeth.** For every brief the listing shows with non-zero drift, run `brief drift <slug>` and read what it reports. Report the instructions the drift makes *moot* — a shipped premise, a merged dependency, a restructured landing site — not only the claims it falsifies: naming the code as the truth resolves a brief's wrong claims and says nothing about an instruction that shipped while the brief sat.
- **Collisions that appeared without anyone writing one.** Compare the file sets from step 1's `--stat` against the paths each brief names. A branch can open a collision with no brief changing: one brief that read `collides-with: none`, and whose ordering note said it "slots anywhere", was a day later blocked across a third of its scope by a sibling that had grown from an unstarted brief into eighty-seven files, and unblocked again the day that merged.

Done when every brief carries a verdict — retire, or a named field to correct, or nothing to do.

## 4 — The question-led pass

The question is the deliverable; the folder edits follow from it. Answer it the way the human would if they had the folder in their head:

- **Ground it in what you read, and verify what it turns on.** The claims that decide the answer — a gate said to be discharged, a status paragraph, an ordering property, a number someone quoted — get checked against the repo and, where they are claims about running behaviour, against production. A sweep that answers from the briefs alone is quoting the documents the human is asking you to doubt.
- **Derive the cross-brief view the question needs**, and only that: clusters, collisions from the diffs rather than from the declared fields, the gates, and the order the two imply. Declared `collides-with` fields are hypotheses to check.
- **Weigh the folder note's ordering properties** against what you now see, rather than re-deriving a ranking from scratch — but treat any state it asserts, a cluster marked done or a brief called merged, as the thing step 1 just measured.
- **Answer plainly, including "no".** Name what would change the answer, and what the answer rests on that you could not verify.

Then work step 3's list, which the answer usually moves.

Done when the question has an answer with its evidence named, and every brief in scope has a verdict.

## 5 — Report, then stop

The refresher is the deliverable of a reconcile pass, and decayed recall is why it exists — so write it as prose for someone who wrote these documents and no longer remembers them, not as a table restating the listing. Cover: what each cluster is about; per brief, its goal in a sentence or two and its current state; the collisions and the resulting order; and per brief, the verdict you propose — **rewrite**, **note**, **retire**, or **leave**.

A question-led pass leads with the answer and carries the same per-brief verdicts under it.

Then wait. The human owns which briefs change and how ambitious their scope should be.

Done when the human has approved a per-brief plan.

## 6 — Write

**Brief prose belongs to the handoff skill, not this one.** Whenever a verdict writes or edits brief text, its rules live in `~/.claude/skills/handoff/SKILL.md` § 4 — the head fields, the body registers, the cold-read slug, repo-relative paths, "this brief" — and where the repo ships its own handoff skill, that one is authoritative. Read it rather than working from memory of it; restating it here would fork it. The general document-writing levers are `~/.claude/skills/writing-for-agents/SKILL.md`.

Work the approved plan:

- **Rewrite** when the premise died: `brief new <forward-slug>` scaffolds the replacement (the handoff skill's naming rule — the branch the next session will work on); carry forward every lesson and dead-end that still holds, then retire the superseded file into it (below). Two briefs for one goal is the rot this skill exists to clear.
- **Note** when the edges drifted: fold it into the section it bears on, as the case rather than the verdict.
- **Retire** when the work landed: `brief retire <slug> --reason "<how it landed>" [--into <successor>]` — a rename rather than a delete, so the text survives in a folder with no version control, stamped with why at the only moment it is known. It reports every sibling reference the retirement dangles; those are yours to judge.
- **Boundary moves** get written into both briefs — the one gaining scope and the one losing it — so neither session discovers the move from the other's absence.
- **The folder's own note.** Where a `_clusters.md` exists, amend it when a cluster's meaning shifts, a name is coined or retired, or an ordering property proves wrong — it holds only what cannot be derived, so membership and state stay in the briefs and the listing. Where none exists and the folder has grown clusters worth naming, writing it is a reasonable outcome; a wave list with dates is not, because the listing regenerates that and a page of it goes stale in days.

**What a sweep adds is facts.** It sees the folder, so what it owes a brief is what the folder knows: a gate discharged, a collision that appeared, a premise that shipped, a measurement someone already paid for and the next session would otherwise buy twice. The receiving session keeps the design. A solution shape written in as a segmented plan converts a brief into a work order and spends the judgement that session existed to apply — and a sweep is the likeliest moment for it, because you have just built the folder-wide picture and the plan feels obvious. Where a shape must be recorded — it constrains the schedule, or it was the human's call — record its provenance beside it: proposed by whom, costed or not, what it has yet to answer. Then the next session can discard it on evidence rather than read it as scope.

Then **re-anchor every brief you touched**: `brief anchor <slug> --by sweep` — its claims now rest on the tree you just read. An edited brief left on its old anchor invites the next session to re-run drift you already resolved.

Done when every touched brief carries a fresh anchor and `brief check` reports the folder clean — it resolves what the files only claim, so a dangling sibling reference, a lost sha, or a malformed field fails loudly here instead of surviving in prose, and a second `brief` shows the folder as your report describes it.

## Escalation — session history

A branch, not a step. When a brief's provenance is genuinely unclear — you cannot tell what it was written from, or the human recalls work that no PR or doc records — the transcripts hold it: read them with the `obelisk` skill, naming the question first. A full dig costs real minutes and a large subagent budget, so it earns its place on one specific unknown, not on a brief that merely reads thin.
