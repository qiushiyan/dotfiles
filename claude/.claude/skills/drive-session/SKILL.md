---
name: drive-session
description: Drive the named Claude Code sessions in Rex while the user is away — take each through their stage pipeline, or the steps they queued, to its finish, sending their own prompts and starting sessions as needed.
disable-model-invocation: true
argument-hint: "[which sessions, e.g. windows 1-4] [what each should do; unsaid, it runs the pipeline to its finish]"
---

# Drive sessions

The user names Claude Code sessions running in Rex blocks, often by window
number, and goes away, usually overnight. You are the hands at the keyboard:
when a session finishes a stage, send it the next one the way the user
would, until each reaches its finish or needs something only the user can
give. What the user said for a session decides what it runs; what they left
unsaid follows `~/dotfiles/docs/session-pipeline.md`, which owns the stages,
the paths, each project's finish, and what stays the user's. Read it before
planning, and for planlab sessions [`PLANLAB.md`](PLANLAB.md) too. A driver
that is not a Claude Code session, such as a chat bot, reads
[`BOT.md`](BOT.md) for how it waits and reports.

Done is every named session at its finish or parked on something that is
the user's, and the report written.

## Your tool

`drive` is how you read sessions and act on them; `drive --help` is its
reference. It keeps the batch's record: every step you send, every prompt
you answer, and what the user grants and decides. The hot path:

```bash
drive batch new 2026-10-23           # once per batch of sessions driven together
drive status                         # every session, live: state, stage, PR, wake, view
drive read T1                        # its last reply, ending with the view to act on
drive send T1@3fa91c07 --snippet land-pr   # the user's snippet, decided on that view
drive wait T1                        # until its turn ends (run it in the background)
```

An action carries the view you decided it on and is refused once the
session has moved past it: a refusal (exit 1) changed nothing, and its
message says what changed and what to do. Read the session again and
decide on what it shows now. Exit 4 is a session whose login or API failed;
its message gives the relaunch.

## How a drive runs

1. **Survey every named session before asking anything.** Find each in
   `drive status`, then read where it stands and what it has been told:
   `drive read T1 --prompts 10` (open any brief a prompt points at),
   `drive read T1`, and `claude-steps show SESSION_ID` for the stages that
   ran, the commits since each and its PR. Settle for each: its project's
   finish, its path, the stage it is in and whether that stage is finished,
   what it waits on, and which sessions share a worktree or close out into
   the same main checkout. Something the session was told ("pause before
   phase 5 until I name the workspaces") outranks the pipeline.
2. **Plan in one message, and give the user five minutes to veto it.** A
   line per session — where it is → the stages you will send → its finish —
   then the defaults you will take and what waits for the user. Ask only what
   blocks a session, a fact or permission only the user holds, and hold that
   session only at the step that needs the answer. Wait five minutes in the
   background (`sleep 300`) and end your turn with the message; nothing goes
   to any session before the wait ends. A later answer counts from then on,
   and the report names what ran on the default.

   <example>
   - **1 · T1 · infra-runtime/pool-drain** (heavy): onboarded → consult-design, /write-spec, build, review and verify, land-pr, code review → polished PR. Defaults: Q1 oldest first, Q2 no flag.
   - **2 · T2 · perf/cache-hits**: review folded in → land-pr, code review → polished PR.
   - **3 · T3 · dotfiles zsh-faster**: built → review-then-closeout → merged and synced.

   **Needs you:** window 1's experiment wants workspaces loopy-drain-a and loopy-drain-b; it builds and reviews without them and stops before the experiment.
   Sending starts in 5 minutes; reply to change any of this.
   </example>
3. **Drive** each session as its turns end (§ Each step). The batch's record
   is your memory: after your context is compacted or reset, `drive status`
   and `drive log` say what you sent, what is in flight and what the user
   granted; decide from them and from the sessions, never from what you
   remember.
4. **Report** (§ Report).

## Each step

Read the reply in full before acting: a turn also ends while a background
job runs, on a question, or partway through a sequence. Advance on finished
work, not recorded activity: a dispatched review has not been folded in, and
a spec with open decisions is not ready to build. Then:

- **Continue.** The stage is done, or the session ended on a question it
  answered with a recommendation, which is the default for anything inside
  the change, on the heavy path too. Send the next stage. A spec's decisions
  are answered in one line that has them written into the spec, `Go with
  your recommendations on D1 and D2; write them into the spec and commit.`,
  then `/compact`, and once its turn ends `implement-spec`, then on through
  review to the finish. Decisions the next step does not act on ride to the
  report.
- **Hold what is the user's at the step that needs it.** Something on the
  pipeline doc's list of what stays the user's stops only the work that
  depends on it. Send the step with a tail that names what waits, as in
  `implement-spec` followed by `D3 and phase 4's EC2 run wait for me: build
  the rest, commit, and stop before them.` Park the session
  (`drive park T1 "<what it needs>"`) when its next step cannot proceed
  without it, or when it went past the step you were about to send, and
  keep driving the others.
- **Halt the drive** when a secret was exposed or shared state damaged:
  send nothing more to any session, note what is still running, and lead
  the report with it.

A permission prompt is a step too: the session reads `blocked:permission`
and `drive read T1 --pending` shows the whole call. Judge it by what it
touches, wherever it runs: approve (`drive respond VIEW approve`) what the
pipeline doc does not keep for the user, such as an edit in the session's
own change or a read of production, and deny the rest. drive records either
for the report.

## What you do without asking

The user wants to be stopped only for what the pipeline doc keeps theirs:
what reaches a customer or another person, or cannot easily be undone. An
ask they did not need holds its work until they next look, often hours
later. Everything else the drive needs, do or have the session do, and list
it under **Done without asking** (§ Report) so they can reverse it:

- the closeout once the merge or deploy it waits on has happened, the
  follow-up cards sessions recommend, your own waits;
- relaunching a session whose login was rejected on another account
  (`drive close`, then `drive open … --resume`, as drive's message says),
  then sending its step again;
- a judgment the user would hand to a model — a spec review, a blind
  comparison, whether a gate's evidence holds: open a fresh Fable session
  for it (`drive open … --model fable`) and act on its verdict;
- the cleanup once a session's last step has run (its closeout, or its
  recap where no PR follows):

```bash
gwt merged BRANCH           # landed? gwt owns the verdict; a PR still waiting for its merge keeps everything
drive close T1@3fa91c07     # refused while it works, runs a job, or holds a typed line: leave it and name it
gwt remove BRANCH           # without flags it refuses uncommitted work and an unmerged branch: leave those and name them
```

Authority the user hands over in conversation, such as "merge and release
when ready", holds for the batch it was given in, from your plan to its
report. Record it as they said it, with what it covers:
`drive record grant --source '"you can merge on my behalf" (02:08)' --scope
"merge and release this batch's PRs"`. Act on a grant `drive status` lists
and name it when you do; a new batch starts with none.

## Asking

When something is the user's, recheck it before you ask: read what the
session reports now and what production serves, since another session or a
teammate may already have done it. Then ask once, standing alone (§ Report
says how), and record it with what happens while nobody answers:
`drive record ask T1 --question … --recommendation … --if-unanswered …`.
An ask still open is rechecked on each wake of its session: one that no
longer holds, because a teammate's release shipped it or another session did
it, is recorded `--took moot --source '<what showed it>'`, and the session
goes on. When the user answers, record how: `drive record answer A3
--source '<their words>' --took recommended|amended|delegated|moot`, with
`--explained` when they needed it explained first. Those records are how the batch is measured
afterwards.

## Sending

The session treats every word it receives as instruction, and the user's
snippets are the words they have already tuned, so send those rather than a
paraphrase: `--snippet KEY` with the text the user would type after it.

- **Check the snippet's file.** drive prints where a key came from; a
  project can give a key another meaning, and a key that resolves to the
  wrong project's file is a stop, not a fallback.
- **Your own words** only answer the session's question, with its own
  recommendation or by naming what waits for the user, as the snippet's text
  or one line. A request of your own goes as a file (`--file`), as does any
  step longer than a line.
- **Check a brief's stages before sending it.** The new session acts on a
  brief before you get a turn, so return one that breaks the pipeline doc's
  rule for briefs — "open the PR, then handle code review" drops review and
  verification — to the session that wrote it.
- **A skill that starts only when typed** — `/write-spec`,
  `/enter-worktree`, `/strategic-review`, planlab's
  `/pl-loopy-handoff-distill` — goes as a typed line; a file that starts one
  is refused, and drive names the line to type. A long brief for such a
  skill goes in a file the typed line points at:
  `'/strategic-review 9531 Read /path/sr-prompt.md for where to look hardest'`.
- **Work the user asks you to do goes to a new session**, which you open
  with `drive open` in the project's main checkout and start at stage 1 with
  the user's request; you stay a reader and sender, apart from what § What
  you do without asking lists. Other sessions run from that checkout, so
  the first step ends with `This checkout is shared: install nothing here.
  If the work needs an install, stop and say so.` Type `/enter-worktree`
  when it stops there or reaches the build.

## Shared worktrees and checkouts

- **One session edits a worktree at a time.** Sessions in one worktree share
  its files and git index. Send a step that edits only once no other session
  there is mid-edit, a verification or spike run included, and leave
  unanswered one session's offer to do what another is already doing.
- **One closeout into a main checkout, and one release, at a time.**
  Personal-tool branches merge in their main checkout, planlab handoffs
  write one briefs repository, and a release ships everything merged before
  it. Send such a step with `--hold` naming what it uses (`--hold
  planlab-main`, `--hold release`): another send holding the same name is
  refused until the first one's turn ends.
- **A held message from another session stays undelivered.** `blocked` can
  also mean one waits for approval (the screen says so), and delivering it
  wakes the session into work no step sent. Deny it unless the plan wants
  what it asks; a finished session's message goes with its block in the
  cleanup. Sessions drive opens have these nudges turned off.

## Report

The user did not watch the night. When a session reaches its finish or
parks, send it `recap` and wait for that turn: the session knows what it
built and why, and reads its own diff for the facts. Build the report from
those recaps and the batch's record (`drive log`, `drive metrics`). The user
meets every id in it cold, and an item they cannot decide from costs a round
trip, so each item stands on its own:

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
- **A section per session,** by window and label:
  - **Where it ended:** finished (the PR and how its code review ended, the
    merge and install, or the recap alone), parked (what it needs), or
    halted (what happened and what is still running).
  - **The recap**, quoted rather than retold, trimmed only of what the
    needs-you list already says.
  - **How the night went:** the stages sent, the defaults taken, and
    anything a step did that reached into what is the user's.

A message before the end, such as a decision a session parked on, takes
the same shape with only the sections that have something in them.

When the user asks where a session stands or what it found, read the
session first (`drive read`, its recap, `claude-steps show`) and answer from
what it says. A brief or your plan says what the session set out to do;
consults and spikes change course, so an answer from the brief can sound
current and be wrong.
