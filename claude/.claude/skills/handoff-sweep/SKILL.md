---
name: handoff-sweep
description: Periodic pass over this project's handoff batons — a refresher on what each one is really about, and a reconcile against what the repo has done since they were written.
disable-model-invocation: true
argument-hint: [optional: a cluster to scope to, e.g. "eval"; or "refresher only" to skip the reconcile]
allowed-tools: Bash(bash ~/.claude/skills/handoff-sweep/baton-index.sh:*), Bash(git log:*), Bash(git diff:*), Bash(git show:*), Bash(git branch:*), Bash(git status:*), Bash(git merge-base:*), Bash(git rev-list:*), Bash(git worktree list:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh api:*), Bash(obelisk:*), Read, Edit, Write, Glob, Grep, Agent
---

# Sweep the baton folder

Batons accumulate faster than memory holds them. Several land in a busy week, each written by a session that saw only its own PR; they are picked up a day or a weekend later, and by then the folder is a set of half-remembered names. This skill runs when that has happened, and produces two things: a **refresher** — what each cluster is really about — and a **reconcile** — the batons brought back into agreement with the repo.

**What this sweep owns is the cross-baton view.** A single baton's own drift is already handled: it carries an anchor and opens with a drift check its receiving session runs at pickup. Re-deriving that here would duplicate a mechanism that has a home. What no baton can see is the folder around it — that two of them edit the same seam, that one silently blocks another, what order they should run in. That is the payload.

A folder with one or two batons needs no sweep. Say so and stop.

## 1 — Index

```sh
bash ~/.claude/skills/handoff-sweep/baton-index.sh
```

Each baton's declared fields joined against live git: cluster, anchor, how far the default branch has moved since that anchor, and whether a branch or PR exists for the slug. This is the lookup — read it, never reconstruct it from memory.

Done when every baton in the folder appears in the table.

## 2 — Read every baton whole, yourself

Not delegated, and not skimmed. Step 3's judgements need every baton in one context: a subagent's summary drops the file and path sets that collisions are found by, and reading four of nine produces a confident map of the wrong shape.

Done when every baton has been read end to end.

## 3 — Derive what no single baton knows

- **Clusters.** Group the batons by the workstream they actually serve. Where the folder holds a `_clusters.md`, it carries the vocabulary, what each name covers, and the standing properties that decide order — read it rather than re-inventing names, and weigh its ordering properties against what you now see. A baton the index shows as `(none)` needs a cluster named.
- **Collisions.** Compare the files, packages and paths each baton names. Two batons that touch one seam collide even when neither says so — nobody writing a baton can see this, which is exactly why it is worth a sweep. Check the `collides-with` fields against your own reading rather than trusting them.
- **Order.** Blocked edges plus collisions give the waves: which batons can run beside each other, and which must wait. Say how many can run in parallel and which.
- **Drift with teeth.** For every baton the index shows with non-zero drift, run its own drift query and read the result. Report the instructions the drift makes *moot* — a shipped premise, a merged dependency, a restructured landing site — not only the claims it falsifies.

Done when every baton has a cluster, a place in the order, and either a named drift consequence or "none".

## 4 — Report, then stop

The refresher is the deliverable, and decayed recall is the reason it exists — so write it as prose for someone who wrote these documents and no longer remembers them, not as a table restating the index. Cover: what each cluster is about; per baton, its goal in a sentence or two and its current state; the collisions and the resulting order; and, per baton, the reconcile you propose — **rewrite**, **note**, or **leave**.

Then wait. The human owns which batons change and how ambitious their scope should be.

Done when the human has approved a per-baton plan.

## 5 — Reconcile

Work the approved plan, in the two registers the handoff skill uses — present-register fact for what is now true, forward-register guidance for what the next session should weigh:

- **Rewrite** when the premise died: write the replacement under a forward slug (the handoff skill's naming rule — the branch the next session will work on), carry forward every lesson and dead-end that still holds, and remove the superseded file. Two batons for one goal is the rot this skill exists to clear.
- **Note** when the edges drifted: fold it into the section it bears on, as the case rather than the verdict.
- **Boundary moves** get written into both batons — the one gaining scope and the one losing it — so neither session discovers the move from the other's absence.

- **The folder's own note.** Where a `_clusters.md` exists, amend it when a cluster's meaning shifts, a name is coined or retired, or an ordering property proves wrong — it holds only what the index cannot derive, so membership and state stay in the batons and the table. Where none exists and the folder has grown clusters worth naming, writing it is a reasonable outcome of the sweep; a wave list with dates is not, because the index regenerates that and a page of it goes stale in days.

Then **re-anchor every baton you touched**: today's date and the current default-branch sha, because its claims now rest on the tree you just read. An edited baton left on its old anchor invites the next session to re-run drift you already resolved.

Done when every touched baton carries a fresh anchor, and a second index run shows the folder as you now describe it.

## Escalation — session history

A branch, not a step. When a baton's provenance is genuinely unclear — you cannot tell what it was written from, or the human recalls work that no PR or doc records — the transcripts hold it: read them with the `obelisk` skill, naming the question first. A full dig costs real minutes and a large subagent budget, so it earns its place on one specific unknown, not on a baton that merely reads thin.
