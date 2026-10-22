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

## How a drive runs

1. **Survey every named session before asking anything.** Find its block,
   then read where it stands and what it has been told:

   ```bash
   S=~/.agents/skills/drive-session/scripts
   $S/find-session                        # window, block, state, session id, cwd, title
   claude-steps show SESSION_ID           # which stages ran, commits since each, its PR
   $S/read-turn ID --prompts 10           # what it was told; open any brief a prompt points at
   $S/read-turn ID                        # where its last turn ended
   ```

   Settle for each: its project's finish, its path, the stage it is in and
   whether that stage is finished, what it waits on, and which sessions share
   a worktree or will close out into the same main checkout. Something the
   session was told ("pause before phase 5 until I name the workspaces")
   outranks the pipeline.
2. **Plan in one message, and give the user five minutes to veto it.** A
   line per session — where it is → the stages you will send → its finish —
   then the defaults you will take and what waits for the user. Ask only what
   blocks a session, a fact or permission only the user holds, and hold that
   session only at the step that needs the answer. Start a `sleep 300` under
   `run_in_background` and end your turn with the message; nothing goes to
   any session before the sleep wakes you. A later answer counts from then
   on, and the report names what ran on the default.

   <example>
   - **1 · a1b2c3 · infra-runtime/pool-drain** (heavy): onboarded → consult-design, /write-spec, build, review and verify, land-pr, code review → polished PR. Defaults: Q1 oldest first, Q2 no flag.
   - **2 · d4e5f6 · perf/cache-hits**: review folded in → land-pr, code review → polished PR.
   - **3 · 778899 · dotfiles zsh-faster**: built → review-then-closeout → merged and synced.

   **Needs you:** window 1's experiment wants workspaces loopy-drain-a and loopy-drain-b; it builds and reviews without them and stops before the experiment.
   Sending starts in 5 minutes; reply to change any of this.
   </example>
3. **Drive** each session as its turns end (§ Each step), keeping a
   checklist in your scratchpad: one line per send with the time, block,
   what was sent and whether it arrived. It becomes the report, and after
   your own context is compacted or restarted, read `read-turn ID --prompts`
   against it before sending again.
4. **Report** (§ Report).

## Each step

`wait-turn` under `run_in_background` wakes you once a session's turn has
ended and stayed ended. A wait can vanish silently: while any session works
keep a `sleep 1800` fallback under `run_in_background`, and on each wake
re-arm a wait for every working session missing from the armed waits,
which `pgrep -lf 'wait-turn|notify-driver'` lists by block.

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
  review to the finish. A strategic review's report is answered `Fold these
  in.`: that builds its findings and settles its investigate list, and its
  known limits are the user's to pick from, so they ride to the report
  unbuilt. Decisions the next step does not act on ride to the report.
- **Hold what is the user's at the step that needs it.** Something on the
  pipeline doc's list of what stays the user's stops only the work that
  depends on it. Send the step with a tail that names what waits, as in
  `implement-spec` followed by `D3 and phase 4's EC2 run wait for me: build
  the rest, commit, and stop before them.` Park the session when its next
  step cannot proceed without it, or when it went past the step you were
  about to send. Send a parked session nothing more, note what it needs, and
  keep driving the others.
- **Halt the drive** when a secret was exposed or shared state damaged:
  send nothing more to any session, note what is still running, and lead
  the report with it.

A permission prompt is a step too: `wait-turn` returns `blocked`, and
`read-turn ID --pending` shows the whole call. Judge it by what it touches,
wherever it runs: approve with `enter` what the pipeline doc does not keep
for the user, such as an edit in the session's own change or a read of
production, and let the rest auto-deny. Name either in the report.

## What you do without asking

The user wants to be stopped only for what the pipeline doc keeps theirs:
what reaches a customer or another person, or cannot easily be undone. An
ask they did not need holds its work until they next look, often hours
later. Everything else the drive needs, do or have the session do, and list
it under **Done without asking** (§ Report) so they can reverse it: the
closeout once the merge or deploy it waits on has happened, the follow-up
cards sessions recommend, your own waits and watchdogs, and the cleanup
once a session's last step has run (its closeout, or its recap where there
is no PR):

```bash
gwt merged BRANCH           # landed? gwt owns the verdict; a PR still waiting for its merge keeps everything
rex capture -b ID           # an unsent line in the input box or a running job: leave the block and name it
rex block close ID          # close the session before its checkout goes
gwt remove BRANCH           # without flags it refuses uncommitted work and an unmerged branch: leave those and name them
```

Authority the user hands over in conversation, such as "merge and release
when ready", holds for the rest of the batch it was given in: the sessions
they asked you to drive together, from your plan to its report. Write it at
the top of your checklist, so it survives a reset of your context and ends
with the batch.

## Sending

The session treats every word it receives as instruction, and the user's
snippets are the words they have already tuned, so send those rather than a
paraphrase:

```bash
# SESSION_DIR is the session's cwd from find-session. Each send gets its own file in your
# scratchpad, left in place: a busy session reads it only when it takes the prompt.
F=<scratchpad>/$ID-1.md          # your first send to this session carries the notice
$S/snippet consult-then-build "$SESSION_DIR" "Take your recommendations on Q1 and Q2." > $F   # TEXT lands where the user types after it
cat ~/.agents/skills/drive-session/NOTICE.md $F > $F.first && $S/send-turn ID --file $F.first

F=<scratchpad>/$ID-4.md
$S/snippet loopy-review-verify "$SESSION_DIR" > $F    # stderr names the file the key came from
$S/send-turn ID --file $F

$S/send-turn ID '/write-spec Go with your recommendations on the open decisions.'   # a skill only the user can start: typed
$S/send-turn ID '        /pl-loopy-handoff-distill merged and deployed'   # resent padded after typing lost its head
```

- **Check the `from:` line.** A project can give a key another meaning; a
  key that resolves to the wrong project's file is a stop, not a fallback.
- **Write no notes;** they are the user's, and `claude-steps` already shows a
  file's snippet as `pasted <key>  in a file`.
- **Your own words** only answer the session's question, with its own
  recommendation or by naming what waits for the user, as the snippet's tail
  or one line. A request of your own goes as a brief file.
- **Check a brief's stages before sending it.** The new session acts on a
  brief before you get a turn, so return one that breaks the pipeline doc's
  rule for briefs — "open the PR, then handle code review" drops review and
  verification — to the session that wrote it.
- **Typed or from a file.** A file the session reads can start a skill the
  model may call, such as `/review` or `/pl-loopy-handoff`. A skill whose
  `SKILL.md` sets `disable-model-invocation: true` starts only when typed,
  as one line: `/write-spec`, `/enter-worktree` and `/spike` among the global
  ones, and planlab's `/pl-loopy-handoff-distill`, the whole of its
  `closeout` key.
- **Pad a typed skill command whose head was lost.** Eight leading spaces
  absorb the first characters typing sometimes drops. The model then starts
  the skill from the words, a typed-only one included, and `claude-steps`
  shows `you: "/…" → skill …`. `/compact` stays unpadded: padded, it is
  only words.
- **The notice goes before the first step you send a session.** Sessions run
  with permissions bypassed, so the limits reach one only through what it
  reads. Before a typed first step, send the notice as a file on its own and
  wait for its turn.
- **Work the user asks you to do goes to a new session**, which you open
  with `x` (§ Rex) in the project's main checkout and start at stage 1 with
  the user's request; you stay a reader and sender, apart from the cleanup
  in § What you do without asking. Other sessions run from
  that checkout, so the first step ends with `This checkout is shared:
  install nothing here. If the work needs an install, stop and say so.`
  Type `/enter-worktree` when it stops there or reaches the build.

## Shared worktrees and checkouts

- **One session edits a worktree at a time.** Sessions in one worktree share
  its files and git index. Send a step that edits only once no other session
  there is mid-edit, a verification or spike run included, and leave
  unanswered one session's offer to do what another is already doing.
- **One closeout into a main checkout at a time.** Personal-tool branches
  merge in their main checkout and planlab handoffs write one briefs
  repository, so serialize those steps across sessions.
- **A held message from another session stays undelivered.** `blocked` can
  also mean one waits for approval (the screen says so), and delivering it
  wakes the session into work no step sent. Deny it when your next step
  goes to that session, unless the plan wants what it asks; a finished
  session's message goes with its block in the cleanup. Name it once under
  **Done without asking**.

## Rex

```bash
# read-turn, send-turn, wait-turn and snippet print their usage when run bare
find-session [DIR]                     # each Claude session: window, block, state, session id, cwd, title; yours is $REX_BLOCK
wait-turn ID [QUIET_SECS] [BG_SECS]    # run_in_background: status, transcript path, screen tail (quiet 60 s; through background jobs 600 s)
wait-turn ID 60 3600                   # planlab's /pl-handle-code-review loops for up to an hour; report how it ended
read-turn ID [--last|--pending|--user|--prompts N]   # last reply · the call a permission prompt waits on · newest prompt · what it was told
send-turn ID 'one short line'          # types, submits, confirms from the transcript that it arrived whole; a slash command too
send-turn ID --file brief.md           # anything longer: typing drops a long prompt's head
snippet KEY [DIR] [TEXT] | snippet --list [DIR]
rex send-key -b ID enter               # approve a permission prompt
rex block close ID                     # close a session's block once its last step has run (§ What you do without asking)
```

A prompt sent while the session works is queued whole and taken mid-turn;
`send-turn` says so and exits 0. When it exits 1, something else arrived and
the session is working on it. Take it back:

```bash
rex send-key -b ID ctrl+c      # once, while it works: interrupts the turn; a second press quits Claude Code
read-turn ID --user            # "[Request interrupted by user…]" once it took; Rex reads `working` until the next turn
rex send-key -b ID ctrl+u      # repeat until the box is empty, if the prompt came back into it
send-turn ID --file brief.md
```

Start or resume a session without taking the user's focus, always through
`x`, the user's Claude launcher, which places it on the least-loaded
account. `rex run` prints the new block's id; send once the input box shows:

```bash
rex run -s "$REX_SESSION" -c DIR --label NAME --focus=false --shell none --json -- /bin/zsh -lic 'x; exec zsh -l'
rex run … -- /bin/zsh -lic 'x --resume SESSION_ID; exec zsh -l'    # resume one, in its own DIR
```

## Report

The user did not watch the night. When a session reaches its finish or
parks, send it `recap` and wait for that turn: the session knows what it
built and why, and reads its own diff for the facts. Build the report from
those recaps. The user meets every id in it cold, and an item they cannot
decide from costs a round trip, so each item stands on its own:

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
- **A section per session,** by window and block:
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
session first (`read-turn`, its recap, `claude-steps show`) and answer from
what it says. A brief or your plan says what the session set out to do;
consults and spikes change course, so an answer from the brief can sound
current and be wrong.
