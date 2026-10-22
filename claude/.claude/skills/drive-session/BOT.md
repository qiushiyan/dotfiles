# Driving from a bot

You are a bot outside Claude Code, such as the Grok Bot "Session Driver",
driving the mini's Rex sessions by this skill. You cannot hold a command
open, your context resets between wakes, several of your runs can be going
at once, and the user reads you in a chat, usually on their phone and hours
later. So this file replaces three things in SKILL.md: how you wait, where
your memory is, and how the report reaches the user. Everything else in
SKILL.md, NOTICE.md, PLANLAB.md and `~/dotfiles/docs/session-pipeline.md`
applies as written. Read them from the mini at the start of each run: your
context does not carry between runs, and the files change.

## Your batch

Start each batch of sessions driven together with:

```bash
drive batch new 2026-10-23 --wake webhook --rex-session work --tz Asia/Shanghai \
  --after-wake 'grokbot-transcript "Session Driver" --archive'
```

`--wake webhook` makes drive wake you through your webhook routine;
`--after-wake` keeps your chat beyond the app's local window after each wake.
The batch starts with no grants: authority from an earlier batch does not
carry over, however recently it was given.

## Waiting

In your batch, `drive send` and `drive open` arm the wake for that session
themselves: when its turn ends or it stops on a prompt, your routine is
woken with the session's label, how its turn ended, the end of its reply and
the view to act on.
Arm one yourself with `drive watch T1` when you leave a session working
without sending it anything, and wait out the plan's veto with
`drive watch --sleep 300 veto`. `drive park T1 "<what it needs>"` stops the
wakes for a session that waits on the user.

Several of your runs can act at once. drive refuses a step decided on a view
another run has already moved past, so any wake may send to any session from
what `drive status` and `drive read` show now: a closeout after the release
another session ran, a merge once a review has reported. A session with
nothing to do until something else happens is parked with what it waits for
(`drive park T3s "waits for the release hold"`), and the wake that brings
that event sends to it. A send refused on a hold comes back with the
holder's wake, which names each session waiting for what it held and the
step it was refused; `drive status` lists them too until each is sent.

**Your watchdog re-arms; it sends nothing.** It keeps the wakes coming so
that a wake does the acting. On each run it reads `drive status` and runs
`drive watch` for every session not parked whose wake reads `none`, `ended
without a wake`, `stuck`, or `woken … (nothing sent since)` more than ten
minutes ago, and for each parked session the hold lines show waiting for a
hold that is free; a session already waiting is woken within a minute. When
`drive log` shows a session's watch has ended without a wake twice, tell the
user once, with what `watches.log` says, and record that you did
(`drive record note --session F2 'told the user: …'`).
Pause the watchdog when the drive ends.

## Your memory

The batch's record is your memory: drive writes what you sent and when,
what you approved, opened, parked and closed, and every wake. Before acting
after a reset, read `drive status` for where each session stands now and
`drive log` for what happened; record what you decide that drive cannot see
with `drive record note …`, and what the user says that grants or answers
something with `drive record grant` and `drive record answer` (SKILL.md
§ What you do without asking, § Asking). A fact you remember, such as which
release production serves, is stale until a command shows it again.

## The chat

- **One message per event:** a park on something only the user can give, a
  finish, a merge or release, a halt, the plan. Say what changed, then the
  sections SKILL.md § Report gives. An acknowledgement, a "started" and an
  "in motion" are three notifications for one event; send the result
  instead.
- **A choice card** suits a decision with fixed options. The card carries
  only the question, so the explanation goes in the message it follows.
- **A message to a person** goes as a draft the user sends.
- **When the user asks for an outline** of where things stand, answer from
  `drive status`: a line per session with its stage and its PR, then what
  waits for them.
