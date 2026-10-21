# Driving from a bot

You are a bot outside Claude Code, such as the Grok Bot "Session Driver",
driving the mini's Rex sessions by this skill. You cannot hold a command
open, your context resets between wakes, and the user reads you in a chat,
usually on their phone and hours later. So this file replaces three things
in SKILL.md: how you wait, where your scratchpad is, and how the report
reaches the user. Everything else in SKILL.md, NOTICE.md, PLANLAB.md and
`~/dotfiles/docs/session-pipeline.md` applies as written. Re-read them from
the mini at the start of each drive, since they change.

## Waiting

Where SKILL.md runs `wait-turn` or `sleep 300` in the background, run
`notify-driver` on the mini inside tmux, so the wait outlives your shell; it
posts the result to your webhook routine, which wakes you. One wait per
session, named for it, so you can stop it when you park the session:

```bash
tmux new -d -s wait-$ID "notify-driver $ID"          # a turn; arguments as in its header on the mini
tmux new -d -s veto "notify-driver --sleep 300 veto"  # the plan's veto window
tmux kill-session -t wait-$ID                        # parking: a live wait keeps waking you
```

`notify-driver` lives at `~/.local/bin/notify-driver` on the mini, not yet in
the dotfiles repository. While a drive runs, keep a watchdog routine that
tells the user only when a session has gone quiet with no wake, and pause it
when the drive ends.

## Your memory

Each batch gets a directory on the mini,
`~/.local/state/drive-session/<date the batch started>/`, kept until its
report even across days; the newest is the current batch. It is your
scratchpad: send files, briefs and each session's recap go there, and
`checklist.md` holds what SKILL.md's checklist holds. Your long tasks stop
after 50 minutes and your context resets, so before sending again read the
checklist and `read-turn ID --prompts`, as SKILL.md says for a compaction.

## The chat

- **One message per event:** a park, a finish, a merge or release, a halt,
  the plan. Say what changed, then the sections SKILL.md § Report gives. An
  acknowledgement, a "started" and an "in motion" are three notifications
  for one event.
- **A choice card** suits a decision with fixed options. The card carries
  only the question, so the explanation goes in the message it follows.
- **A message to a person** goes as a draft the user sends.
