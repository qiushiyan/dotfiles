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

Done when every `owes` line of the check is done or in the report with why it
stayed, and the report carries each `judge` and `waits` line with what you
found or what releases it.

## Start from the check

```bash
python3 ~/.local/share/dotfiles/planlab-skills/pl-closeout/scripts/closeout_check.py <PR>
```

It prints one line per area, with its state and the note beside this file
that holds the procedure. Read a note when a line names it, and rerun the
check before the report. Start each area from what is already recorded,
since a closeout can be started twice. Brief and cleanup commands take the
PR's head branch the check prints, not the branch this session sits on, which
in a review session is another.

## The areas, in order

1. **Ship.** Each surface the merge changed serves it. The deploy or release
   that takes is this session's to run, as the domain note says.
2. **Check in production.** Take each owed read whose condition holds,
   usually one conversation driven on `planlab-dev-qiushi`, and post its
   verdict on the PR. A read whose condition does not hold yet goes in the
   report with the fact that releases it.
3. **Record and tell.** The production records the merge made true, the
   Bench card when the user started one for this work, and the people the
   change is for.
4. **Handoffs.** [handoffs.md](handoffs.md).
5. **Clean up.** [cleanup.md](cleanup.md).

Each domain the merged paths reach has a note in `domains/`, which the
check's lines name; a merge that reaches several takes each.

## What waits for the user

Almost nothing. The brief folder is a git clone, so a revert undoes a
verdict; triage records can be recorded again, a verdict comment edited, a
deploy rolled back. So each is done and reported with its undo. These wait,
each as a ready preview the user answers in one word: a `#loopy` post,
except an internal change's untagged one; a reply to a reporter or a
customer; and a migration that drops or rewrites customer data, with what it
protects and your recommendation. A read only a person can waive is theirs,
with the reason.

## Report

For a reader coming back hours later:

- what merged and where it serves, in a line;
- what this closeout did, area by area, each default with its undo;
- what is still open, each with what releases it, and each held preview
  with its send command;
- what to start next, as [handoffs.md](handoffs.md) says.
