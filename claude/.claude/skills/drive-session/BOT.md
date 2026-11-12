# Driving from a bot

You are a chat bot, such as the Grok bot "Session Driver", driving Rex
sessions by this skill on the machine `~/.config/machine` names. A command
you run can be held for minutes, not the hour a session's turn can take;
your context resets between runs, several of your runs can act at once, and
the user reads you in a chat on their phone, hours later. So this file
replaces how SKILL.md waits and remembers. Before a run decides or writes
anything, on that machine, read SKILL.md, REPORTING.md, your project's file
(PLANLAB.md or ITELL.md) and `~/dotfiles/docs/session-pipeline.md` § The
stages, § Choosing the path, § Finishes and § Who decides: your context does
not carry over, and the files change. A wake answered by the one command its
`next:` names needs none of them.

Do what drive's `next:` says.

## Your batch

Name yourself on every drive command by your webhook's name:
`session-driver` for Session Driver, `itell` for the iTELL bot. The examples
in these files leave it out. A command drive prints already names its batch,
so run it as written.

```bash
drive --driver itell status     # `drive status`, as the iTELL bot writes it
drive batch new 2026-10-23 --webhook session-driver --rex-session work --tz Europe/London \
  --after-wake 'grokbot-transcript "Session Driver" --archive'                # Session Driver
drive batch new itell-2026-10-23 --webhook itell --rex-session work --tz Europe/London \
  --after-wake 'grokbot-transcript ITELL --archive'                           # the iTELL bot
```

`--webhook` is your own: a batch started with another bot's wakes that bot
and is its batch. Start one batch per drive, never after a reset (`drive
--driver NAME batch` names yours), since a new one drops the grants and your
last batch's wakes. Leave it running when the drive ends: the user reads it
on the page until your next one replaces it.

`drive` is on `PATH` in every shell on that machine: run it bare. If that
machine or these files cannot be read, tell the user once, unless the chat
shows you have, and take no action.

## Waiting

A send, open or respond arms a wake for when that session's turn ends or it
stops on a prompt. A refused command arms none.

```bash
drive park backfill@… "waits for your call on the backfill (A4)"   # shown on the user's page: write it in their terms
drive timer 300 veto                                               # the plan's veto; once the user answers, it brings nothing to do
```

Every run leaves a `drive` command behind it, since a wake with no trace
reads as unheard and comes again.

A wake may act on any session, from what `drive status` and `drive read`
show now. A command your shell cuts short loses nothing: the next send,
respond, park or close on that session settles it from the transcript. Send
the step again only once `drive read search --user` shows it never arrived.

Record what drive cannot see as you decide it (REPORTING.md § The record):
the run the veto timer wakes starts from the record, not the chat.

## Your watchdog

`drive watch --due-all` runs on the machine every five minutes (launchd's
`com.qiushi.drive-watchdog`) with no model run, and posts you only what needs
you, as a `kind: watchdog` wake, each line saying what to do.

A routine of your own adds nothing while that agent runs. A run that
fails for want of usage never reaches you, so drive holds your wakes instead,
losing none. When `drive status` says the driver has not answered, tell the user
once what that held up.

## The chat

Write to the user by REPORTING.md. In the chat:

- **Each message buzzes the user's phone,** so a run's first message is its
  result, once that exists, a reply to the user's own message included.
  While the user is away, a message is for something major.
- **A choice card** holds one decision with fixed options. It carries only
  the question, so the explanation goes in the message before it.
- **A repeat wake that changes nothing** is noise: answer it with a `drive`
  command and no message.

## On the machine

- The default machine is Mini 2: `~/dotfiles/docs/qiushi-mini-2.md` and
  `docs/mini2-pending.md`.
- A process a Shell call starts dies when the call ends: put a long wait in
  a detached tmux session.
