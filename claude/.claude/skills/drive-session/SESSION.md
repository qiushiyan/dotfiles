# Driving from a Claude Code session

You are a Claude Code session the user started in Rex to drive their
sessions by this skill, and they talk to you in this terminal. This file
replaces how SKILL.md waits and remembers; write to the user by
REPORTING.md. After a compaction, read SKILL.md, this file and REPORTING.md
again before you decide anything.

## Your batch

`drive batch new NAME` run from this session makes the batch yours: every
drive command you run then acts in it without `--batch` or `--driver`. It is
driver `claude`'s; name another with `--driver` only when another Claude
Code session drives a batch now (`drive batch list`). Start one per drive;
after a compaction, `drive batch` names the one you have.

## The listener

Each wake waits in the batch until your listener takes it, so a turn of
yours is done when its message is written and one listener runs in the
background (the Bash tool's `run_in_background`):

```bash
drive listen    # ends once a session needs you, printing each woken session with what to run
```

Claude Code starts your next turn when it ends. Do what its lines say, and
start it again before that turn ends. Anything you wait for goes through it
too: `drive timer 300 veto` for the plan's veto, `drive park … --until` for
a session to look at later.

**A line in your input starting `[drive]`** is drive's watchdog, not the
user: wakes waited while no listener ran. Start one and act on what it
prints.

## The user

What the user types here is their word: record an answer or a grant first
(`drive record answer`, `drive record grant`), then act on it. They read
your turn's last message when they come back, often hours later, and the
page in the meantime. So a stop goes on record as an ask the moment you
decide it, and a turn that leaves them something ends on it, in SKILL.md §
Report's shape. Put every question in that message and on record: a
question tool waits for an answer nobody is there to give.
