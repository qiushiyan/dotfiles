# Driving from a bot

You are a bot outside Claude Code, such as the Grok Bot "Session Driver",
driving the mini's Rex sessions by this skill. A command you run can be
held for minutes, not the hour a session's turn can take; your context
resets between runs, several of your runs can act at once, and the user
reads you in a chat on their phone, hours later. So this
file replaces how SKILL.md waits, remembers and reports; the rest of
SKILL.md, NOTICE.md, PLANLAB.md and `~/dotfiles/docs/session-pipeline.md`
applies as written. Read them from the mini at the start of every run: your
context does not carry over, and the files change.

## Your batch

```bash
drive batch new 2026-10-23 --webhook session-driver --rex-session work --tz Asia/Shanghai \
  --after-wake 'grokbot-transcript "Session Driver" --archive'
```

`--webhook` names your own routine's webhook, a file the owner writes, and
wakes it when a session's turn ends; another bot's file wakes that bot.
`--after-wake` keeps your chat beyond the app's local window. Start a batch
once per drive, never after a reset (`drive batch` names the current one):
a new batch starts with no grants, however recently one was given, and
stops the last batch's wakes.

## Waiting

After you send, open or respond, a wake brings you back when that session's
turn ends or it stops on a prompt. A refused command did nothing and brings
no wake: do what its `next:` says instead, which for a session left waiting
is to park it, stopping its wakes until a step is sent to it:

```bash
drive park T3@… "waits for the release hold"
drive watch --sleep 300 veto                     # the plan's veto, as a timer wake; once the user answers, it brings nothing to do
```

Any wake may act on any session, from what `drive status` and `drive read`
show now: drive keeps two runs off one session, and refuses a step decided
on a view another run has moved past.

A command your shell cuts short loses nothing: the next send, respond, park
or close on that session settles it from the transcript. Send the step again only once
`drive read T1 --user` shows it never arrived; `drive log` has it in full.

## Your watchdog

Your watchdog routine runs on a schedule. It sends and answers nothing; it
keeps the wakes coming, so that a wake does the acting. A wake no run acted
on is posted once more by `--due`, and that wake's run acts. Each run:

```bash
drive watch --due    # arms every session whose wakes stopped coming, and says why
drive status         # the open asks: recheck each, as SKILL.md § Asking says
```

When `--due` says a watch has ended without a wake twice, tell the user
once, with the lines `watches.log` in the batch's directory (`drive batch`
prints it) has for that session, and record that you did (`drive record
note --session T4 'told the user: …'`). Pause the watchdog when the drive
ends.

## Your memory

The batch's record is your memory: drive writes what you sent, approved,
opened, parked and closed, and every wake. After a reset, read `drive
status` for where each session stands and `drive log` for what happened.
Record what drive cannot see as you decide it, your plan first, since the
run the veto timer wakes starts from the record, not the chat:

```bash
drive record note 'plan: T1 consult-design → checkpoint; T2 land-pr → code review; T3 review-then-closeout'
drive record grant --source '"merge when green" (02:08)' --scope 'merge #9531 once its checks pass'
```

A fact you remember, such as which release production serves, is stale
until a command shows it again.

## The chat

- **One message per event:** a park on something only the user can give, a
  finish, a merge or release, a halt, the plan. Say what changed, then the
  sections SKILL.md § Report gives. Each message buzzes the user's phone, so
  send the result once it exists, never that you have started, are checking
  or will report: on 10-21/22 about a third of your messages were "I'll tell
  you once…" or "Checking…", each a notification with nothing to decide.
- **A choice card** suits a decision with fixed options. The card carries
  only the question, so the explanation goes in the message before it.
- **A message to a person** goes as a draft the user sends.
- **When the user asks for an outline** of where things stand, answer from
  `drive status`: a line per session with its stage and PR, then what waits
  for them.
