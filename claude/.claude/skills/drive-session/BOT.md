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

Every drive command you write names you as its driver, by your webhook's
name: `session-driver` for Session Driver, `itell` for the iTELL bot. Other
bots drive batches of their own on the mini, and nothing in your shell tells
drive which bot is asking. The examples in these files leave it out, so
add it as you write each one:

```bash
drive --driver itell status     # as the iTELL bot writes `drive status`
```

A command drive prints for you already names its batch: run it as written.

```bash
drive batch new 2026-10-23 --webhook session-driver --rex-session work --tz Europe/London \
  --after-wake 'grokbot-transcript "Session Driver" --archive'                # Session Driver
drive batch new itell-2026-10-23 --webhook itell --rex-session work --tz Europe/London \
  --after-wake 'grokbot-transcript ITELL --archive'                           # the iTELL bot
```

`--webhook` names your own routine's webhook, a file the owner writes, and
wakes it when a session's turn ends; another bot's file wakes that bot, and
a batch started with it is that bot's. `--after-wake` keeps your chat beyond
the app's local window. Start a batch once per drive, never after a reset
(`drive --driver NAME batch` names yours): a new batch starts with no
grants, however recently one was given, and stops the wakes of your last
one. Leave it running when the drive ends, since the user reads it on the
page until your next batch replaces it.

## Waiting

After you send, open or respond, a wake brings you back when that session's
turn ends or it stops on a prompt. A refused command did nothing and brings
no wake: do what its `next:` says instead, which for a session left waiting
is to park it, stopping its wakes until a step is sent to it:

```bash
drive park T3@… "waits for S2's release to finish"
drive timer 300 veto                             # the plan's veto, as a timer wake; once the user answers, it brings nothing to do
```

A park's reason shows on the user's page beside the session, so write it
for them: what the session waits on, in their terms.

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
once, with the lines `watches.log` in the batch's directory (`drive
--driver NAME batch` prints it) has for that session, and record that you
did (`drive record note --session T4 'told the user: …'`). Pause the
watchdog when the drive ends.

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

The user's page, `https://qiushi-mini.tailf7adf1.ts.net:8444`, shows every
driver's batch live: each session's goal, where it stands, its PRs and the
questions waiting on the user. Your messages carry what it cannot: what
changed, why, and what you recommend.

- **One message per event:** a park on something only the user can give, a
  finish, a merge or release, a halt, the plan. Say what changed, then the
  sections SKILL.md § Report gives. Each message buzzes the user's phone, so
  send the result once it exists, never that you have started, are checking
  or will report: on 10-21/22 about a third of your messages were "I'll tell
  you once…" or "Checking…", each a notification with nothing to decide.
- **A stop that needs the user** is written for the user as they read it:
  on the phone, hours later, remembering the product, the customers and the
  people but not the session, its vocabulary, its tickets, its finding
  numbers or what it tried. Here is a stop the bot relayed for the wrong
  reader, which the user had to ask to have explained, and the same stop as
  the bot wrote it once asked:

  <example type="avoid">
  **S1's re-run release gate failed, so it's parked until you answer two questions.** S1 is the summariser release-gate session, with the bench card on QIU-295 and #9539.

  **Rules, A22.** S1 re-judged every summary blind using your definition of a planner rule.
  - **On Haiku:** the branch beats develop on four of the five readings. The one it loses is the since-10-22 window, where invented content rises from 3.42 to 4.08 per summary. Most of that is a skill's own rules being copied in as "hard constraints".
  - **Rules the branch drops but develop keeps:**
    - "Keep the OPC browse focused" was dropped in 2 of 3 replays, after the browse had finished.
    - "Stop at the first failure" was dropped in 1 of 3 replays.
    - A pacing rule held through fold 7, then was dropped at fold 8.
  - **On Sonnet:** it invents less, about one item per summary, but drops three rules in every replay.
  - **The options:**
    - **A (recommended):** carry rules forward in code, and drop one only when the summariser marks it lifted. That fixes rules lost at a later fold, like the pacing rule, but not a rule missed at a thread's first fold.
    - **B:** another prompt pass. The pass just done didn't stop the drops.
  - **A side question:** does "keep the browse focused" still hold once the browse is done? Your definition, "holds while that work runs", suggests it doesn't. If so, dropping it isn't a failure.

  **Commits, A23.** Committed schedules went missing on one long thread, and develop loses them too. A script had trimmed the save output to bare `scheduleId=` lines, so the code can't see those commits. Until session 2's commit receipt (QIU-298) lands, S1 recommends that the strict "no lost commits" rule cover only commits the code can see. Commits it can't see, like those saves, would count only toward the totals. Yes or no?

  **Where S1 is:** it has four new local commits, the last `f85ff0fa1b6`. They're not pushed. All suites pass and the type checks are clean. Codex's third review round fixed two medium defects:
  - an incomplete set of readings could still show the gate as passed;
  - unsaved work could hide a dropped commit.

  There's no PR yet. The comparison pairs are in `scratchpad/gate/pairs2/pairs.html` and the scores in `scratchpad/gate/scores2/gate.txt`, both in S1's scratchpad on the mini.
  </example>

  <example>
  **S1's goal:** decide whether the new summariser is good enough to replace develop's. The summariser keeps a running summary of long Loopy conversations, so the planner remembers what matters after older messages are trimmed.

  **Where it stands:** after your 1B and 2B answers, S1 tightened the prompt on what counts as a planner rule and re-ran the comparison. A blind judge scored every summary from the new version and from develop. The new version still didn't clear the bar, so S1 has stopped. Nothing is pushed and there's no PR yet.

  **What went wrong, in plain terms:**
  - **Dropped instructions:** the new summariser sometimes forgets standing instructions the planner gave, like "stop at the first failure", which develop keeps. A pacing rule survived seven summary updates and was dropped at the eighth.
  - **Made-up rules:** in the newest conversation window, it writes in rules nobody gave. These are mostly a skill's own rules copied in as if the planner had said them.
  - **Sonnet doesn't fix it:** Sonnet makes up less but forgets more.

  **Decision 1, how to stop dropped rules (A22):**
  - **A, recommended:** code carries every rule forward on each update, and a rule is removed only when the summariser explicitly marks it as finished. Rules stop vanishing later in a conversation. A rule the summariser misses the first time it summarises still wouldn't be caught.
  - **B:** another round of prompt tuning. The round just done didn't stop the drops, so it may not work.

  **Decision 1b, a side question:** "keep the OPC browse focused" was dropped after the browse had finished. By your own definition, a rule holds while that work runs. If the rule ends with the browse, that drop is correct and not a failure, and the results look better.

  **Decision 2, lost commits (A23):** the gate has a hard rule that no saved schedule may be lost from the summary. On one long thread, saves went missing in develop too, because a script had trimmed the save output so the code can't see those saves at all. S1 suggests that until the save receipts another session is building land, the hard rule covers only saves the code can see. The invisible ones would still count in the totals but couldn't fail the gate on their own.

  The card from last night has all three. I'd go with A, "the browse rule ends with the browse", and yes on A23.
  </example>
- **A message about one session** states its goal as `drive read` prints
  it, so the chat and the page agree, and links its card by its batch and
  label (`…:8444/#2026-10-23/S1`).
- **A choice card** suits a decision with fixed options. The card carries
  only the question, so the explanation goes in the message before it.
- **A message to a person** goes as a draft the user sends.
- **When the user asks for an outline** of where things stand, send the
  page and add what it cannot show, from `drive status`, the record and the
  sessions: what comes next for each, and anything holding the batch that
  drive does not track, such as a release pause.
