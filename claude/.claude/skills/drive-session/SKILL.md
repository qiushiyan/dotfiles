---
name: drive-session
description: Drive named Rex sessions to their finish while you're away.
disable-model-invocation: true
argument-hint: "[which sessions, e.g. windows 1-4] [what each should do; unsaid, it runs the pipeline to its finish]"
---

# Drive sessions

The user names Claude Code sessions running in Rex, often by window number,
and goes away, usually overnight. You are the hands at the keyboard: when a
session finishes a stage, send it the next one the way the user would, until
each reaches its finish or needs something only the user can give. What the user said for a session decides what it runs; what they left unsaid
follows `~/dotfiles/docs/session-pipeline.md`, which owns the stages, the
paths, each project's finish and who decides what. Read its § The stages, §
Choosing the path, § Finishes and § Who decides before planning,
[`PLANLAB.md`](PLANLAB.md) for planlab sessions and [`ITELL.md`](ITELL.md)
for itell ones. A chat bot reads [`BOT.md`](BOT.md) for how it waits,
remembers and reports.

Done is every named session at its finish or parked on something only the
user can give, and the report written.

## Your tool

`drive` reads sessions, acts on them and keeps the batch's record:

```bash
drive batch new 2026-10-23                  # once per batch
drive status                                # every session: state, stage, PR, wake, view
drive read e8fec0                           # a window the user named, by its block: reply and view
drive send e8fec0@3fa91c07 --as T1 --snippet land-pr   # the first send brings window 1 in as T1
drive read T1                               # from then on, by label
drive wait T1                               # until its turn ends, in the background (a bot is woken instead: BOT.md)
```

`drive --help` and each command's `--help` name the commands, flags and the
words status prints. A refusal, failure or wake that leaves something to do
ends with `next:`, the command to run as things stand; whether that step
still makes sense is yours.

## How a drive runs

1. **Survey every named session before asking anything**, by its block until
   it joins the batch: `drive read e8fec0 --prompts 10` shows what it was
   told (open any brief a prompt points at), `drive read e8fec0` where it
   stopped, `claude-steps show SESSION_ID` its stages, commits and PR.
   Settle each one's finish, path and stage, whether that stage is done,
   what it waits on, and which sessions share a worktree or close out into
   the same main checkout. What a session was told ("pause
   before phase 5 until I name the workspaces") outranks the pipeline.
2. **Plan in one message, and give the user five minutes to veto it.** A
   line per session, the defaults you take, what waits for them. Ask only
   what blocks a session, and hold that session only at the step that needs
   the answer. Record the plan (`drive record note 'plan: …'`), so a run
   after a compaction or reset reads it, post it, then wait five minutes in
   the background (`sleep 300`; a bot arms BOT.md's veto timer) with nothing
   sent. A later answer counts from then on, and the report names what ran
   on a default.

   <example>
   - **1 · T1 · infra-runtime/pool-drain** (heavy): onboarded → consult-design → design checkpoint, where it waits for your review; then /write-spec, build, review and verify, land-pr, code review, strategic review → merged and released. Defaults: Q1 oldest first, Q2 no flag.
   - **2 · T2 · perf/cache-hits**: review folded in → land-pr, code review, strategic review → merged and released.
   - **3 · T3 · dotfiles zsh-faster**: built → review-then-closeout → merged and synced.

   **Needs you:** window 1's experiment wants workspaces loopy-drain-a and loopy-drain-b; it builds and reviews without them and stops before the experiment.
   Sending starts in 5 minutes; reply to change any of this.
   </example>
3. **Drive** each session as its turns end (§ Each step). After a compaction
   or reset, `drive status` and `drive log` are your memory: what you sent,
   what is in flight, what the user granted. Decide from them and from the
   sessions, never from what you remember.
4. **Report** (§ Report).

## Each step

Read the whole reply first: a turn also ends while a background job runs, on
a question, or partway through a sequence. Advance on finished work: a
dispatched review is not folded in, and a spec with open decisions is not
ready to build.

- **Continue** when the stage is done, or the session ended on a question it
  answered with a recommendation: take it for anything inside the change,
  heavy path included. A spec's decisions go back in one line, then the
  build. Decisions the next step does not act on, and a strategic review's
  known limits, ride to the report for the user to pick from:

  ```bash
  drive send T1@… 'Go with your recommendations on D1 and D2; write them into the spec and commit.'
  drive send T1@… /compact                    # once that turn ends
  drive send T1@… --snippet implement-spec    # once the compaction ends
  ```
- **Hold what is the user's at the step that needs it.** Something the
  pipeline doc's § Who decides asks the user stops only the work that depends on it,
  so the step names what waits: `--snippet implement-spec "D3 and phase 4's
  EC2 run wait for me: build the rest, commit, and stop before them."` Park
  a session whose next step cannot go on without it (`drive park T1@…
  "<what it needs>"`) and keep driving the others.
- **A background job past its purpose is the session's to stop**: send the
  step drive's `next:` gives, never a kill from your own shell. The session
  started the job and knows whether its work still needs it.
- **A session back from a Rex restart** lost every background job and agent
  it ran, and a turn the restart cut short wakes `interrupted`. Its next
  step says so: `Rex restarted and ended this session mid-turn; any
  background jobs or agents it was waiting on are gone. Continue from where
  you stopped.`
- **A check that comes back blocked or inconclusive**, from a session or the
  Browser Test bot, goes back once with what passing looks like exactly (the
  click path, the expected value) before it reaches the user as a failure.
- **Halt the drive** when a secret was exposed or shared state damaged:
  send nothing more, note what still runs, and lead the report with it.

## Acting and asking

The user is stopped only for the pipeline doc's two asks, design questions
at the checkpoint and mutations of production data, and for what only they
can do. What its § Who decides hands over is yours or a session's, cleanup,
a gate's evidence and a strategic review included, and what it puts out of
reach stays there. An ask they did not need holds its work until they next
look, often hours later. Do the rest and list it under **Done without
asking** so they can reverse it:

- the closeout once the merge or deploy it waits on has happened, the
  follow-up cards sessions recommend, your own waits;
- relaunching a session whose login was rejected, or reopening one a Rex
  restart ended, as drive's `next:` says;
- a judgment the user would hand to a model, from a fresh session: `drive
  open judge-1 --model fable --goal '…' '…'`, then act on its verdict;
- the merge and release, by your project file's § After the PR (a personal
  tool's is its closeout);
- the cleanup once a session's last step has run, as far as that step left
  it. A closeout that removed its own worktree leaves only the close, and
  its report, not `gwt merged`, says what landed:

  ```bash
  gwt merged BRANCH       # landed? a PR still waiting keeps everything
  drive close T1@…        # refused while it works: do what its next: says, name what you leave
  gwt remove BRANCH       # refuses uncommitted work and an unmerged branch: leave those, name them
  ```

A prompt is a step too: approve what the pipeline doc's § Who decides hands
to sessions, such as an edit in the session's own change or a read of
production, and deny the rest. A deny ends the turn, so its next step is
yours to send.

Authority the user hands over beyond the pipeline doc's § Who decides ("run
the backfill on Acme's workspace") holds while `drive status` lists it:
record it in their words with what it covers, and name it when you act on
it. A one-off "go ahead" covers the one thing it named. A rule for every
batch ("from now on…") also goes to the user as the line for the file it
changes: these files, not your memory, reach the next batch.

```bash
drive record grant --source '"run the backfill on Acme" (02:08)' --scope "the backfill's --commit on Acme's workspace"
```

To ask, recheck first, since a teammate or another session may already have
done it. Then ask once, standing alone (§ Report), and keep the ask in the
record from question to answer. Recheck every open ask on each wake,
whichever session woke you: the session it holds is parked and wakes no one.

```bash
drive record ask T1 --question '…' --recommendation '…' --if-unanswered '…'    # → A3
drive record answer A3 --source '<their words>' --took amended --explained
drive record answer A3 --took moot --source '<what showed it no longer holds>'
```

## Sending

The session treats every word it receives as instruction. Send the user's
snippets, the words they have tuned, with what they would type after the
key. Write anything else as the user would type it: first person, their
words where they gave them and nothing they did not say, beyond the
session's own recommendation or what waits for the user. The notice told
the session that someone else sends its steps, so a step names nothing
of you, the chat or the batch's record:

<example type="avoid">
Qiushi's answers to the design checkpoint (A2): he agrees with all your recommendations.
</example>

<example>
I agree with your recommendations. I don't understand this area deeply, but it reads as a valid proposal. Write the spec.
</example>

```bash
drive snippet land-pr ~/dev/planlab/.worktrees/pool-drain    # the file the key resolves to there
drive send T1@… --snippet land-pr 'D3 waits for me.'
drive send T1@… --file /tmp/t1-fixups.md                     # your own request, or anything over a line
drive send T1@… '/strategic-review 9531 @/tmp/sr-prompt.md'                 # @ attaches the file, as the user's would
```

- A session's first step carries its task and says where it stops: a session
  told its finish goes straight there, past review and any hold. One that
  builds in that turn asks for a worktree in its text; `/enter-worktree`
  alone goes only to a session that stopped before building. Every session
  carries a `--goal`: what it sets out to solve, for a user who remembers
  the product but not the session; record it again only when its purpose or
  scope changes.

  ```bash
  drive open S1 --dir ~/dev/planlab/main --goal "Make Loopy's running summary of long chats keep the decisions it already settled, instead of dropping them each time it is redone (QIU-295)." --file /tmp/s1-start.md   # "… Build it in a worktree of your own; commit and stop before the PR."
  drive record goal P0 '…'   # a session that joined on a send, or one drive status names as having none
  ```
- A key that resolves to another project's file is a stop, not a fallback.
- A brief one session wrote to start another is acted on before you get a
  turn, so return one that drops a stage (the pipeline doc's rule for
  briefs) to its author.
- A skill that starts only when typed (`/write-spec`, `/enter-worktree`,
  `/strategic-review`, planlab's `/pl-loopy-handoff-distill`) goes as a typed
  line with its brief attached, as above.
- Work the user asks *you* to do goes to a new session, opened with `drive
  open` in the project's main checkout and started at stage 1 with their
  request. You stay a reader and sender: work run from your own shell has no
  session to review or report it, and lands in checkouts others use. Other
  sessions share that checkout, so the first step ends `This checkout is
  shared: work in a worktree of your own, and install nothing in this one.`

## Shared worktrees and checkouts

- **One session edits a worktree at a time**: sessions in one worktree share
  its files and index. Send an editing step only once no other session there
  is mid-edit, a verification or spike run included, and leave unanswered
  one session's offer to do what another already does.
- **One closeout into a main checkout, and one release, at a time**, and so
  for anything else only one session may do, such as commits into a checkout
  others share. Name what it uses with `--hold`:

  ```bash
  drive send T2@… --snippet closeout --hold planlab-main
  drive send sr-9531@… --snippet merge-when-ready --hold release
  ```
- **A message from another session waiting for approval stays undelivered**:
  delivering it wakes the session into work no step sent.

## Report

When a session reaches its finish, or stops on something only the user can
give, send it `recap` and wait for that turn, then park it, or close it when
its cleanup follows at once: any send ends a park, so the recap goes first.
A session parked only to wait for another session's hold gets its recap at
its own finish.
Build the report from the recaps and the record (`drive log`, `drive
metrics`). The user meets every id in it cold, and an item they cannot
decide from costs a round trip, so each item stands alone:

<example>
**Needs you**
- **Take down the remote-workers lab host after the 31 Oct read?** It is the one `planlab-prod` EC2 host (about $277 a month) running the experiment for `qiushi-lab`; no customer uses it. #9251 recommends taking it down once that read is in. Unanswered, it keeps running.

**Done without asking**
- Closed #9254's block and removed its worktree `run-state/adoption-and-parks`.
- Filed QIU-280, a backlog card: importPlan charges each edit row a flat 1 KiB, about a third of its real size.
- Left the `qiu-272` block open: its input box holds an unsent line.

**Waiting on time**
- Thu 22 Oct: #9255's production read of the lane ceiling.
</example>

- **Needs you:** what waits for the user across every session, a decision
  or a merge the user held: what it is, why now, who using the product
  would notice each option, or that nobody would, the recommendation, and
  what happens unanswered. If nothing, say so.
- **Done without asking:** what you did on your own authority, and what you
  left in place and why.
- **Waiting on time:** reads or checks owed on a date.
- **A section per session,** by window and label:
  - where it ended: finished (the PR, how its code review ended, the merge
    and install, or the recap alone), parked (on what), or halted (what
    happened, what still runs);
  - its recap quoted, cut only of what Needs you says and what you have
    since done, such as the cleanup it leaves to the user;
  - the stages sent, the defaults taken, and any step that reached into
    what is the user's.

A message before the end, such as a decision a session parked on, takes the
same shape with only the sections that have something in them.

When the user asks where a session stands or what it found, read the session
first (`drive read`, its recap, `claude-steps show`) and answer from what it
says: consults and spikes change course, so an answer from its brief or your
plan can sound current and be wrong.
