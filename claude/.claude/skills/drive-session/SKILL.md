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

- **Wait in the background, not by polling.** Run
  `~/.agents/skills/drive-session/scripts/wait-turn BLOCK [QUIET_SECS]` with
  `run_in_background`; you are woken when the session's turn has ended and
  stayed ended for the quiet window (60 s default). It prints the status
  record, the transcript path and the screen's tail. Exit 2 means no Claude
  session runs in that block.
- **An ended turn is not yet the trigger.** Read the session's last message
  in its transcript before acting; the screen shows only a tail. A turn ends
  while a background subagent works, on a question to the user, or partway
  through a sequence. If the message is not the state the user named, arm
  the wait again.
- **Send the user's words as written.** The session treats every word as
  instruction, so a qualifier you add changes the work it does.
- **Conditional steps get a full read.** For "if the plan is sound and
  nothing needs my decision", read the whole report. When something does
  need the user, stop there and leave the decision summarised; otherwise
  send.

## Rex

- **Find the target:** `rex block ls`, then
  `rex block call -b ID title` for each block: the title is the Claude
  session's, and the owner pid is its process. Your own block is
  `$REX_BLOCK`.
- **Send a prompt:** `rex send -b ID 'text'`, check with
  `rex capture -b ID --trim --unwrap | tail` that it sits alone in the
  input box (typed text joins whatever is already there), then
  `rex send-key -b ID enter`. A few seconds later
  `rex block call -b ID program_status` should show the `claude` record
  `working`.
- **Start a session:**
  `rex run -s "$REX_SESSION" -c DIR --label NAME --focus=false --shell none --json -- /bin/zsh -lic 'x; exec zsh -l'`
  opens a new window without taking the user's focus and prints its block
  id. `x` is the user's Claude launcher, a zsh function, hence the
  interactive shell. Wait for the empty input box on screen before sending.

## Report

Lead with where the sequence stands: each step sent, what its session
produced, and anything that needs the user, with the block ids so they can
find each window.
