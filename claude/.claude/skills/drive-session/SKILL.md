---
name: drive-session
description: Drive the named Claude Code sessions in Rex while the user is away — take each through their stage pipeline, or the steps they queued, to its finish, sending their own prompts and starting sessions as needed.
disable-model-invocation: true
argument-hint: "[which sessions, e.g. windows 1-4] [what each should do; unsaid, it runs the pipeline to its finish]"
---

# Drive sessions

The user names Claude Code sessions running in Rex, often by window number,
and goes away, usually overnight. You are the hands at the keyboard: when a
session finishes a stage, send it the next one the way the user would, until
each reaches its finish or needs something only the user can give. What the
user said for a session decides what it runs; what they left unsaid follows
`~/dotfiles/docs/session-pipeline.md`, which owns the stages, the paths,
each project's finish and what stays the user's. Read it before planning,
and [`PLANLAB.md`](PLANLAB.md) for planlab sessions. A chat bot reads
[`BOT.md`](BOT.md) for how it waits, remembers and reports.

Done is every named session at its finish or parked on something only the
user can give, and the report written.

## Your tool

`drive` reads sessions, acts on them and keeps the batch's record:

```bash
drive batch new 2026-10-23                  # once per batch; it starts with no grants
drive status                                # every session: state, stage, PR, wake, view
drive read e8fec0                           # a window the user named, by its block: reply and view
drive send e8fec0@3fa91c07 --as T1 --snippet land-pr   # the first send brings window 1 in as T1
drive read T1                               # from then on, by label
drive wait T1                               # until its turn ends, in the background (a bot is woken instead: BOT.md)
```

Every action names the view it was decided on and is refused once the
session has moved past it; a refusal (exit 1) did nothing, so read the
session again and decide on what it shows now. drive and this skill divide
the work: `drive --help` names the commands and the words status prints, and
a refusal, failure or wake that leaves something to do ends with `next:`,
the command to run on the session as it stands. That command is drive's
part; whether the step still makes sense is yours.

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
   - **1 · T1 · infra-runtime/pool-drain** (heavy): onboarded → consult-design → design checkpoint, where it waits for your review; then /write-spec, build, review and verify, land-pr, code review → polished PR. Defaults: Q1 oldest first, Q2 no flag.
   - **2 · T2 · perf/cache-hits**: review folded in → land-pr, code review → polished PR.
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
  answered with a recommendation, which is the default for anything inside
  the change, heavy path included. A spec's decisions go back in one line,
  then the build; a strategic review's report is answered `Fold these in.`,
  and its known limits ride to the report for the user to pick from, as do
  decisions the next step does not act on:

  ```bash
  drive send T1@… 'Go with your recommendations on D1 and D2; write them into the spec and commit.'
  drive send T1@… /compact                    # once that turn ends
  drive send T1@… --snippet implement-spec    # once the compaction ends
  ```
- **Hold what is the user's at the step that needs it.** Something the
  pipeline doc keeps for the user stops only the work that depends on it,
  so the step names what waits: `--snippet implement-spec "D3 and phase 4's
  EC2 run wait for me: build the rest, commit, and stop before them."` Park
  a session whose next step cannot go on without it (`drive park T1@…
  "<what it needs>"`) and keep driving the others.
- **A background job past its purpose is the session's to stop**: send the
  step drive's `next:` gives, never a kill from your own shell. The session
  started the job and knows whether its work still needs it.
- **Halt the drive** when a secret was exposed or shared state damaged:
  send nothing more, note what still runs, and lead the report with it.

A prompt is a step too, judged by what it touches: approve what the
pipeline doc does not keep for the user, such as an edit in the session's
own change or a read of production, and deny the rest. Its `next:` shows how
to see the call or the options and how to answer. A deny ends the turn; the
session takes its next step as usual.

## What you do without asking

The user wants to be stopped only for what the pipeline doc keeps theirs:
what reaches a customer or another person, or cannot easily be undone. An
ask they did not need holds its work until they next look, often hours
later. Do the rest, or have a session do it, and list it under **Done
without asking** so they can reverse it:

- the closeout once the merge or deploy it waits on has happened, the
  follow-up cards sessions recommend, your own waits;
- relaunching a session whose login was rejected on another of the user's
  Claude accounts, the one the exit-4 message names, its step on the open;
- a judgment the user would hand to a model, such as a spec review, a blind
  comparison or whether a gate's evidence holds: `drive open judge-1 --model
  fable '…'`, then act on its verdict;
- the cleanup once a session's last step has run (its closeout, or its
  recap where no PR follows), as far as that step left it: a closeout that
  removed its own worktree leaves only the close, and its report says what
  landed, where `gwt merged` finds no branch to judge:

  ```bash
  gwt merged BRANCH       # landed? gwt owns the verdict; a PR still waiting keeps everything
  drive close T1@…        # refused while it works, runs a job or holds a typed line: do what its next: says, name what you leave
  gwt remove BRANCH       # refuses uncommitted work and an unmerged branch: leave those, name them
  ```

Authority the user hands over in conversation ("merge and release when
ready") holds for the batch it was given in. Record it in their words with
what it covers, act on it while `drive status` lists it, and name it when
you do. A one-off "go ahead" covers the one thing it named:

```bash
drive record grant --source '"you can merge on my behalf" (02:08)' --scope "merge and release this batch's PRs"
```

## Asking

Recheck before you ask: read what the session reports now and what
production serves, since a teammate or another session may already have
done it. Then ask once, standing alone (§ Report says how), and keep the
ask in the record from question to answer:

```bash
drive record ask T1 --question '…' --recommendation '…' --if-unanswered '…'    # → A3
drive record answer A3 --source '<their words>' --took amended --explained     # recommended|amended|delegated|moot
drive record answer A3 --took moot --source '<what showed it no longer holds>'
```

Recheck every open ask on each wake, whichever session woke you: the session
it holds is parked and wakes no one. These records are how the batch is
measured.

## Sending

The session treats every word it receives as instruction, and the user's
snippets are the words they have already tuned: send those, with the text
the user would type after the key.

```bash
drive snippet land-pr ~/dev/planlab/.worktrees/pool-drain    # the file the key resolves to there
drive send T1@… --snippet land-pr 'D3 waits for me.'
drive send T1@… --file /tmp/t1-fixups.md                     # your own request, or anything over a line
drive send T1@… '/strategic-review 9531 Read /tmp/sr-prompt.md for where to look hardest'
```

- A session's first step carries its task and says where it stops: a
  session told its finish goes straight there, past review and any hold (on
  10-23 three merged themselves in their first turn). One that builds in
  that turn asks for a worktree in its text, and the session enters one
  itself; `/enter-worktree` sent alone has nothing to set up for, so it goes
  only to a session that stopped before building:

  ```bash
  drive open T1 --dir ~/dev/tool --file /tmp/t1-start.md   # "Add --shout to greet.py with a test, in a worktree of your own. Commit and stop there."
  ```
- A key that resolves to another project's file is a stop, not a fallback.
- Your own words only answer the session's question, with its own
  recommendation or by naming what waits for the user.
- A brief one session wrote to start another is acted on before you get a
  turn, so return one that breaks the pipeline doc's rule for briefs ("open
  the PR, then handle code review" drops review and verification) to its
  author.
- A skill that starts only when typed (`/write-spec`, `/enter-worktree`,
  `/strategic-review`, planlab's `/pl-loopy-handoff-distill`) goes as a typed
  line, its brief in a file the line points at, as above; drive refuses one
  inside a file and prints the line to type.
- Work the user asks *you* to do goes to a new session, opened with `drive
  open` in the project's main checkout and started at stage 1 with their
  request. You stay a reader and sender: work run from your own shell has
  no session to review or report it, and lands in checkouts others use (on
  10-22 a driver fast-forwarded the mini's main checkout and reinstalled its
  packages to run a CLI itself). Other sessions share that checkout, so the
  first step ends `This checkout is shared: work in a worktree of your own,
  and install nothing in this one.`

## Shared worktrees and checkouts

- **One session edits a worktree at a time**: sessions in one worktree share
  its files and index. Send an editing step only once no other session there
  is mid-edit, a verification or spike run included, and leave unanswered
  one session's offer to do what another already does.
- **One closeout into a main checkout, and one release, at a time**, and so
  for anything else only one session may do, such as commits into a checkout
  others share. Name what it uses; drive refuses a second send naming it
  until the first is through, and says what frees it:

  ```bash
  drive send T2@… --snippet closeout --hold planlab-main
  drive send sr-9531@… --snippet merge-when-ready --hold release
  ```
- **A message from another session waiting for approval stays undelivered**:
  delivering it wakes the session into work no step sent. drive reads such a
  session as it stands and sends to it as usual; the message goes with its
  block in the cleanup. Sessions drive opens have these nudges off.

## Report

The user did not watch the night. When a session reaches its finish, or
stops on something only the user can give, send it `recap` and wait for that
turn, then park it, or close it when its cleanup follows at once: any send
ends a park, so the recap goes first. A
session parked only to wait for another session's hold gets its recap at
its own finish. The session knows what it built and why, and reads its own
diff for the facts.
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
  or a merge that is theirs: what it is, why now, the recommendation, and
  what happens unanswered. If nothing, say so.
- **Done without asking:** what you did on your own authority, and what you
  left in place and why.
- **Waiting on time:** reads or checks owed on a date.
- **A section per session,** by window and label: where it ended (finished,
  with the PR and how its code review ended, the merge and install, or the
  recap alone; parked, with what it needs; halted, with what happened and
  what still runs), its recap quoted rather than retold and trimmed only of
  what the needs-you list already says and what you have since done, such
  as the cleanup it leaves to the user, and how the night went: the stages
  sent, the defaults taken, anything a step did that reached into what is
  the user's.

A message before the end, such as a decision a session parked on, takes the
same shape with only the sections that have something in them.

When the user asks where a session stands or what it found, read the session
first (`drive read`, its recap, `claude-steps show`) and answer from what it
says: consults and spikes change course, so an answer from its brief or your
plan can sound current and be wrong.
