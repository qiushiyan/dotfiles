---
name: drive-session
description: Watch another Claude Code session in Rex and act when it reaches a trigger — send it the next prompt, or start a new session and hand it one — so a queued sequence keeps running while you are away.
disable-model-invocation: true
argument-hint: "[which session] when [trigger], [send this / start a session and run this]; then …"
---

# Drive a session

The user has queued work for another Claude Code session running in a Rex
block, usually before stepping away: when it reaches a trigger, send it the
next prompt, or open a new session and give that one a prompt. You are the
hands at the keyboard. Done is every queued step sent and its turn finished,
or a step that needs the user's decision; then report.

## Judgment

- **Keep a checklist when the plan spans sessions.** One line per queued
  step in your scratchpad: its block, what was sent, and where it stands.
  Update it as each step lands. Your context may be compacted on a long
  drive, and the checklist carries the plan through and becomes the report.
- **Wait in the background, not by polling.** `wait-turn` under
  `run_in_background` wakes you once the session's turn has ended and stayed
  ended. A turn that ended while its background jobs run wakes you after
  ten quiet minutes with a `background jobs:` line, since the reply may be a
  question rather than "I'll report when they finish".
- **An ended turn is not yet the trigger.** Read its last reply
  (`read-turn ID`) before acting: a turn also ends while a background
  subagent works, on a question to the user, or partway through a sequence.
  If the reply is not the state the user named, arm the wait again.
- **Check the next step still fits.** A session can go past what it was
  sent: run another review round, push a fix, answer a question the next
  step was meant to ask. When the reply makes the next queued step stale or
  redundant, that is a decision for the user.
- **Send the user's words as written.** The session treats every word as
  instruction, so a qualifier you add changes the work it does. A request of
  your own, something you need from the session, goes as a brief file.
- **Stop only where the next step needs the user.** Sessions end steps with
  decisions for the user. One the next step does not act on rides to the
  report, and you send. For a conditional step ("if the plan is sound and
  nothing needs my decision"), read the whole report; when something there
  needs the user, stop and leave the decision summarised. A step can still
  reach into what a session marked as the user's, such as a docs sync
  rewriting an entry they own: the report names it.
- **One session edits a worktree at a time.** Sessions sharing a worktree
  share its files and its git index. Send a step that edits only once no
  other session there is mid-edit, a verification or spike run included.
  When one session offers to do what another is already doing, leave the
  offer unanswered.
- **A permission prompt is yours to judge.** `wait-turn` returns `blocked` on
  one. Read the whole command (`read-turn ID --pending`; the screen cuts it
  off), approve with `enter` what stays inside the session's own task and
  scratch space, otherwise let it auto-deny, and name either in the report.
- **A held message from another session is the user's.** `blocked` also
  means a message from another session waits for approval; the screen says
  so. Delivering it wakes the session, which may start work no step sent, so
  leave it and name it in the report. When your next step goes to that
  session, read the held message on screen and deny it unless the plan
  wants what it asks.

## Rex

The scripts are in `~/.agents/skills/drive-session/scripts/`; each of the
`-turn` ones prints its usage when run bare.

```bash
find-session [DIR]                          # each Claude session: block, state, session id, cwd, title; DIR keeps those in it or below; yours is $REX_BLOCK
wait-turn ID [QUIET_SECS]                   # run_in_background: status, transcript path, screen tail (quiet 60 s)
read-turn ID [--last|--pending|--user]      # its last reply · the call a permission prompt waits on · the prompt it got
send-turn ID 'one short line'               # types, submits, confirms from the transcript that it arrived whole; a slash command too
send-turn ID --file brief.md                # anything longer than one short line: typing drops a long prompt's head
rex send-key -b ID enter                    # approve a permission prompt
```

A prompt sent while the session works is queued whole and taken mid-turn;
`send-turn` says so and exits 0. When it exits 1, something else arrived and
the session is working on it. Take it back:

```bash
rex send-key -b ID ctrl+c      # once, while it works: interrupts the turn; a second press quits Claude Code
read-turn ID --user            # "[Request interrupted by user…]" once it took; Rex reads `working` until the next turn
rex send-key -b ID ctrl+u      # repeat until the box is empty, if the prompt came back into it
send-turn ID --file brief.md
```

Start or resume a session without taking the user's focus, always through
`x`, their Claude launcher (a zsh function): it lets headroom place the
session on the least-loaded account. It prints the new block's id; send once
the input box shows on screen:

```bash
rex run -s "$REX_SESSION" -c DIR --label NAME --focus=false --shell none --json -- /bin/zsh -lic 'x; exec zsh -l'
rex run … -- /bin/zsh -lic 'x --resume SESSION_ID; exec zsh -l'    # resume one, in its own DIR
```

## Report

Lead with where the sequence stands: each step sent, what its session
produced, and anything that needs the user, with the block ids so they can
find each window.
