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

- **Wait in the background, not by polling.** `wait-turn` under
  `run_in_background` wakes you once the session's turn has ended and stayed
  ended.
- **An ended turn is not yet the trigger.** Read its last reply
  (`read-turn ID`) before acting: a turn also ends while a background
  subagent works, on a question to the user, or partway through a sequence.
  If the reply is not the state the user named, arm the wait again.
- **Send the user's words as written.** The session treats every word as
  instruction, so a qualifier you add changes the work it does. A request of
  your own, something you need from the session, goes as a brief file.
- **Conditional steps get a full read.** For "if the plan is sound and
  nothing needs my decision", read the whole report. When something does
  need the user, stop there and leave the decision summarised; otherwise
  send.
- **A permission prompt is yours to judge.** `wait-turn` returns `blocked` on
  one. Read the whole command (`read-turn ID --pending`; the screen cuts it
  off), approve with `enter` what stays inside the session's own task and
  scratch space, otherwise let it auto-deny, and name either in the report.

## Rex

The scripts are in `~/.agents/skills/drive-session/scripts/`; each prints its
usage when run bare.

```bash
rex block ls; rex block call -b ID title    # the title is the session's; your own block is $REX_BLOCK
wait-turn ID [QUIET_SECS]                   # run_in_background: status, transcript path, screen tail (quiet 60 s)
read-turn ID [--last|--pending|--user]      # its last reply · the call a permission prompt waits on · the prompt it got
send-turn ID 'one short line'               # types, submits, confirms from the transcript that it arrived whole
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

Start a session without taking the user's focus; `x` is their Claude
launcher, a zsh function. It prints the new block's id; send once the input
box shows on screen:

```bash
rex run -s "$REX_SESSION" -c DIR --label NAME --focus=false --shell none --json -- /bin/zsh -lic 'x; exec zsh -l'
```

## Report

Lead with where the sequence stands: each step sent, what its session
produced, and anything that needs the user, with the block ids so they can
find each window.
