---
name: pl-closeout
description: "(Planlab) Close out a merged PR: ship it, check production, record and announce it, settle its briefs, clean up. Use once a PR merges, or when told one merged."
---

# Close out a merged PR

A PR merged. Leave nothing behind it: the change serves wherever it runs,
production has shown what its tests could not, the records and the people it
is for know, the briefs say what is left, and what the branch started is gone.
This is the merging session's own next step, taken without asking; the user
reads the report, often hours later.

Done when no line of the check reads `owes`, and the report carries each
`judge` and `waits` line with what you found or what releases it.

## Start from the check

```bash
python3 ~/.local/share/dotfiles/planlab-skills/pl-closeout/scripts/closeout_check.py <PR>
```

It reads where the merge stands and prints one line per area, with a state
(`done`, `owes`, `judge`, `waits`) and the note beside this file that holds
the procedure. Read a note when a line names it. Start each area from what
is already recorded, since a closeout can be started twice. Rerun the check
after each area and once more before the report. The PR's head
branch it prints is the branch every brief and cleanup command takes, also
when this session sits on another branch, as a review session does.

## The areas, in order

1. **Ship.** Each surface the merge changed serves it. Whoever closes out
   ships: the domain note says how, and the deploy or release the merge
   needs is this session's to run. A merge step that stopped on a gate the
   user must answer, such as a migration over customer data, stays stopped,
   and so does the closeout.
2. **Check in production.** Take each owed read whose condition holds,
   usually one conversation driven on `planlab-dev-qiushi`, and post its
   verdict on the PR. A read whose condition does not hold yet goes in the
   report with the fact that releases it.
3. **Record and tell.** The production records the merge made true, the
   Bench card when the user started one for this work, and the people the
   change is for.
4. **Handoffs.** [handoffs.md](handoffs.md).
5. **Clean up.** [cleanup.md](cleanup.md). Removing the worktree is the
   closeout's last tool call.

A merge that reaches no deployed surface (docs, skills, snippets) owes 4
and 5, and the one real use [domains/tooling.md](domains/tooling.md) names
when its verification left one owed.

## Domains

The check's lines name each domain the merged paths reach and its note in
`domains/` (Loopy, the main app, Taodesk, Bench, Steward, tooling); a merge
that reaches several takes each. `--domains` prints which paths make which.

## What waits for the user

Almost nothing here waits. The brief folder is a git clone, so a revert
undoes a verdict; triage records can be recorded again, a verdict comment can
be edited, and a deploy rolls back. Each is done and reported as a default
with its undo. What reaches people waits, each as a ready preview the user
answers in one word: a `#loopy` post, except an internal change's untagged
one, and a reply to a reporter or a customer. A migration that drops or
rewrites customer data waits too, with what it protects and your
recommendation. A read only a person can waive is theirs, with the
reason.

## Report

For a reader coming back hours later:

- what merged and where it serves, in a line;
- what this closeout did, area by area, each default with its undo;
- what is still open, each with what releases it, and each held preview
  with its send command;
- what to start next, as [handoffs.md](handoffs.md) says.
