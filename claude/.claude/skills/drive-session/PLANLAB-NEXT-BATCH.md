# Deciding planlab's next batch

The user asked what the next batch should work on. Sessions that change no
code work it out, the user picks once, and every session of the batch opens
from a start note. Done is those sessions open and working, and the planning
sessions closed.

**What a brief, a card or an earlier report says is a lead.** It describes
the day it was written; PRs have merged and customers have moved since.
Every item that enters the batch rests on production data read today or a
spike run today, or is marked as judged by eye. The snippets ask each
session for that, so your steps need not.

**The commands below are examples to reason from.** Each shows a shape and
one batch's words. The labels, the goals and the text after a key are yours
to write, from what the user said and what the sessions found.

## 1. Gather, in two sessions

One session per source of work: what arrived, and what was planned. The user
asked for them, so open both at once, in the batch you drive now, since a
new batch stops the wakes of the sessions still waiting in this one. With no
batch live, start one as BOT.md does; step 4 then opens its sessions there.

```bash
# what arrived; the window and what the user keeps for themselves are this batch's, in their words
drive open slack-triage --dir ~/dev/planlab/main --goal 'Find what reached us since 6 Nov that the next batch should fix: Slack asks, bug reports and follow-up cards.' \
  --snippet loopy-slack-triage 'The window starts 6 Nov. Dev pool and changeability are mine already: leave them out.'
# domain based initiatives check, user may ask for domains to skip or emphasize
drive open initiatives-review --dir ~/dev/planlab/main --goal 'Find which milestones, owed reads and waiting briefs are worth starting now, and which briefs no longer hold.' \
  --snippet loopy-initiatives-review 'Dev pool and changeability are mine already: leave them out.'
```

- **After the key** also go the follow-ups the last batch's record names.
  A window the user did not give starts the day the last batch did (`drive
  batch list`). When a step inside the snippet has to change, send an
  adapted copy with `--file`, starting from the text `drive snippet
  loopy-slack-triage ~/dev/planlab/main` prints.
- **A source goes to one session.** Two sessions clustering the same items
  return two batches that disagree.
- **A report that ranks on a lead goes back once,** naming what it left
  unmeasured, such as `drive send slack-triage@… 'Measure these before you
  rank them: the wiki links and the js-exec faults.'`
- **When the user names one source, or already knows most of the work,** one
  session gathers, by the snippet for that source, and its report goes
  straight to step 3.

This step is done when each report names its file and every item it ranks
is measured or marked. Send the user the headlines of both in one message,
as information: their pick comes in step 3.

## 2. Review both reports fresh

A third session, which wrote neither report, turns the proposals into one
batch. Open it as soon as step 1 is done; what the user says after that
goes to it as a step, in their words:

```bash
# after the key: where the reports are, and whatever the user has said about them so far
drive open batch-review --dir ~/dev/planlab/main --goal 'Turn both reports into one batch: fewer, sharper sessions, each set up to get its problem right.' \
  --snippet loopy-batch-review 'The reports: <path> and <path>. Dev pool and changeability are mine already.'
```

Its report is the batch: a table in start order with each session's label
and goal, which the ask and the opens are built from. The session plans;
opening and driving stay yours.

## 3. The start notes, and the one pick

The session that holds the batch, the review or step 1's one gathering
session, writes a start note per session while the user reads:

```bash
# one question for the whole batch, worded from the review's table; the folder is named for the day the notes are written
drive record ask batch-review --question 'Start this batch of nine sessions? …' --recommendation '…' --if-unanswered 'The start notes are written meanwhile; nothing opens.'
drive send batch-review@… --snippet loopy-batch-notes 'The folder is ~/dev/.handoffs/planlab-main/_batches/2026-11-12/.'
```

- **The ask carries** the sessions in start order with a line each, what
  the review merged, split or dropped, and what the batch would later need
  from the user: each customer write and message to a person. A yes starts
  the batch, and each of those is asked again at its own step (PLANLAB.md §
  Who can be hurt). It also lists the briefs and cards the reports would
  retire or close, which wait for this yes because the pick can bring one
  back.
- **The folder is in the handoffs clone,** `_batches/<today's date>/`: a
  session opens from its note days later, on any machine. The snippet has
  Fable and Astra review the notes before it publishes them, a round an
  adapted copy keeps.
- **An answer that amends the batch** goes to the same session in the
  user's words, to fold into the notes.

This step is done when the session's report says the notes are published
and the user has answered. Notes it could not publish go back to it.

## 4. Open the batch, then close the planning sessions

In this order, on the user's yes:

1. **Retirements.** Send each session that proposed them its own, and wait
   for those turns, in words such as `drive send initiatives-review@… 'Yes
   to the batch. Retire the briefs you listed, except any the batch now
   takes, and publish. Say what you retired.'`
2. **What the last batch still holds** (`drive status`), since the new
   batch stops its wakes and takes it off the user's page. A session parked
   on a date gets a `drive timer` in the new batch, its note naming the
   session and what to read, and joins on its next step, sent by its block
   with `--as`. An open ask is recorded again.
3. **The new batch and its sessions:**

   ```bash
   drive batch new 2026-11-12 …        # yours, as BOT.md starts one
   # one open per session; its label, goal and path come from its note
   drive open skill-page-titles --dir ~/dev/planlab/main --goal '…' '/pl-loopy-onboarding Start from ~/dev/.handoffs/planlab-main/_batches/2026-11-12/skill-page-titles.md. This checkout is shared: work in a worktree of your own, and install nothing in this one.'
   ```

   Every session opens from its note, a bug included, since onboarding
   hands an incident's ids to `pl-loopy-debug` first. Its `--goal` is the
   note's goal in a sentence. The folder's `README.md` gives the start
   order; sessions it keeps apart open one after the other's merge. A start
   note sets up the work and you send its stages, so SKILL.md's rule for a
   brief that drops a stage leaves it alone.
4. **The planning sessions, last:** `drive --batch 2026-11-09 close
   batch-review@…` for each, once every session that can start has: until
   then a note may be questioned, and its evidence sits with the session
   that gathered it. Their reports and the notes are their recap, so close
   them without one.
