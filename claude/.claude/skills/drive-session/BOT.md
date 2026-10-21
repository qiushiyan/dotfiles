# Driving from a bot

You are a bot outside Claude Code, such as the Grok Bot "Session Driver",
driving the mini's Rex sessions by this skill. SKILL.md, NOTICE.md,
`~/dotfiles/docs/session-pipeline.md` and, for planlab, PLANLAB.md apply
as written, except for the three things this file replaces: background
waits, the scratchpad, and the report going out as chat messages. Re-read
them from the mini at the start of each drive, since they change. Those
three differ because you cannot hold a command open, your context resets,
and the user reads you in a chat, usually on their phone and hours later.

## Waiting

Where SKILL.md starts `wait-turn` or `sleep 300` in the background, start
`notify-driver` on the mini instead. It runs the wait and posts the result
to your webhook routine, which wakes you; `notify-driver --sleep SECS
LABEL` stands in for a sleep. It lives at `~/.local/bin/notify-driver` on
the mini, not yet in the dotfiles repository, so read it there for its
arguments.

- Run each wait inside tmux on the mini, so it outlives the shell that
  started it.
- Keep one wait per session, and stop a session's wait when you park it,
  or it wakes you again and again.
- While a drive runs, keep a watchdog routine that tells the user only
  when a session has gone quiet with no wake. Pause it when the drive
  ends.

## Your memory

Each batch gets a directory on the mini,
`~/.local/state/drive-session/<date the batch started>/`, kept until its
report even across days; the newest is the current batch. It is the
scratchpad SKILL.md names: send files and briefs go there. `checklist.md`
in it holds the authority the user handed over for the batch at its top,
then a line per send and what is parked and why; update it after every
send. Save each session's recap there too, since the report is built from
them. Your long tasks stop after 50 minutes, and your context resets
between wakes. Before sending again, read the checklist and `read-turn ID
--prompts`, as SKILL.md says for a compaction.

## The chat

- **One message per event.** An event is something the user acts on or
  wants to know: a park, a finish, a merge or release, a halt, the plan.
  Say what changed, then the sections SKILL.md § Report gives. An
  acknowledgement followed by "started" and "in motion" is three
  notifications for one event.
- **A choice card** suits a decision with fixed options. Put the
  explanation in the message the card follows, since the card carries
  only the question.
- **A message to a person** goes as a draft the user sends.
