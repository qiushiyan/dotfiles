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
would, until each session reaches its finish or needs something only the
user can give. What the user said for a session decides what it runs; what
they left unsaid follows `~/dotfiles/docs/session-pipeline.md`, which owns
the stages, the light and heavy paths, each project's finish, and what stays
the user's. Read it before planning.

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
2. **Plan in one message, then give the user a few minutes to veto it.** A
   line per session: where it is → the stages you will send → its finish.
   Then the defaults you will take and the sessions you will park, each with
   what it needs. Ask only what blocks a session: a fact or permission only
   the user holds, such as the finish of a project the pipeline does not
   cover or a workspace to create. Start a `sleep 300` under
   `run_in_background`, send the message, and send nothing to any session
   until the sleep ends. A question still unanswered then holds its session
   only at the step that needs the answer, and you drive it up to there. An
   answer arriving later counts from then on, and the report names what
   already ran on the default.
3. **Drive** each session as its turns end (§ Each step), keeping a
   checklist in your scratchpad: one line per send with the time, block,
   what was sent and whether it arrived. The checklist carries the drive
   through a compaction of your own context and becomes the report.
4. **Report** (§ Report).

## Each step

`wait-turn` under `run_in_background` wakes you once a session's turn has
ended and stayed ended. Read the reply in full before acting: a turn also
ends while a background job runs, on a question, or partway through a
sequence. Advance on finished work, not recorded activity. A review that
was dispatched has not been folded in, and a spec with open decisions is not
ready to build. Then take one of three actions:

- **Continue.** The stage is done, or the session ended on a question it
  answered with a recommendation. Send the next stage. The session's
  recommendation is the default for anything inside the change, on the heavy
  path too. A spec's decisions are answered in one line that has them
  written into the spec, `Go with your recommendations on D1 and D2; write
  them into the spec and commit.`, then `/compact`, then `implement-spec`,
  then on through review to the finish. Decisions the next step does not act
  on ride to the report.
- **Hold what is the user's at the step that needs it.** Something on the
  pipeline doc's list of what stays the user's — a hard-to-undo decision with
  no recommendation, a workspace to create, an AWS profile that is not logged
  in — stops only the work that depends on it. Send the step with a tail that
  names what waits, as in `implement-spec` followed by `D3 and phase 4's EC2
  run wait for me: build the rest, commit, and stop before them.` Park the
  session when its next step cannot proceed without it, or when the session
  went past the step you were about to send, which makes that step stale.
  Send a parked session nothing more, note what it needs, and keep driving
  the others.
- **Halt the drive.** A secret was exposed, or shared state was damaged.
  Send nothing more to any session, note what is still running, and lead the
  report with it.

A permission prompt is a step too. `wait-turn` returns `blocked`; read the
whole call (`read-turn ID --pending`, since the screen cuts it off). Judge
it by what it touches, not by the directory it runs in. Approve with `enter`
what stays within the session's own change and scratch space; otherwise let
it auto-deny. Name either in the report.

## Sending

The session treats every word it receives as instruction, and the user's
snippets are the words they have already tuned, so send those rather than a
paraphrase:

```bash
# SESSION_DIR: the session's cwd from find-session
# F: a new file in your scratchpad for each send, left in place: a busy session reads it later
F=<scratchpad>/$ID-3.md
$S/snippet loopy-review-verify "$SESSION_DIR" > $F    # the key as TabType expands it there; stderr names the file
$S/snippet consult-then-build "$SESSION_DIR" "Take your recommendations on Q1 and Q2." > $F   # text the user would type after it
$S/send-turn ID --file $F
cat ~/.agents/skills/drive-session/NOTICE.md $F > $F.first && $S/send-turn ID --file $F.first   # your first send to a session
$S/send-turn ID '/write-spec Go with your recommendations on the open decisions.'                # a user-invoked skill, typed
claude-steps note SESSION_ID "drive: sent loopy-review-verify"
```

- **Check the `from:` line.** A project can give a key another meaning. A
  key that resolves to the wrong project's file is a stop, not a fallback.
- **Your own words** only answer the session's question, with its own
  recommendation or by naming what waits for the user, as the snippet's tail
  or one line. A request of your own goes as a brief file.
- **Typed or from a file.** A file the session reads can start a skill the
  model may call (`/review`, `/consult`, `/update-docs`, planlab's
  handoff, verify and code-review skills). One only the user can start
  (`/write-spec`, `/enter-worktree`, `/spike`, itell's `/onboarding`) is
  sent typed, as one line.
- **The notice goes before the first step you send a session.** Sessions run
  with permissions bypassed, and you act only between their turns. The
  limits reach a session only through what it reads. When that first step
  is typed, send the notice as a file on its own and wait for its turn to
  end.
- **`/compact` waits for its own turn.** Send it once the spec carries the
  accepted decisions, wait for the turn to end, then send `implement-spec`.
- **Long waits get a longer background cap.** A planlab PR's code review,
  `/pl-handle-code-review`, loops for up to an hour. Wait on it with a
  `BG_SECS` of 3600, then report how the loop ended.
- **Work the user asks you to do goes to a new session.** Open it with `x`
  (§ Rex) in the project's main checkout and start it at stage 1 with the
  user's request: the project's onboarding command with the request as its
  argument, or `think-holistic` with the request as its tail where the
  project has none. Then drive it like the others; the pipeline moves it to
  a branch before the build. Your own session stays a reader and sender, so
  every edit falls under the same rules.

## Shared worktrees and checkouts

- **One session edits a worktree at a time.** Sessions in one worktree share
  its files and its git index. Send a step that edits only once no other
  session there is mid-edit, a verification or spike run included. When one
  session offers to do what another is already doing, leave the offer
  unanswered.
- **One closeout into a main checkout at a time.** Two personal-tool
  branches merge in the same main checkout, and planlab handoffs write one
  briefs repository. Serialize those steps across sessions.
- **A held message from another session is the user's.** `blocked` also
  means a message from another session waits for approval; the screen says
  so. Delivering it wakes the session, which may start work no step sent, so
  leave it and name it in the report. When your next step goes to that
  session, read the held message and deny it unless the plan wants what it
  asks.
- **After your own context is compacted or restarted,** read
  `read-turn ID --prompts` against the checklist before sending anything
  again.

## Rex

Each script prints its usage when run bare.

```bash
find-session [DIR]                     # each Claude session: window, block, state, session id, cwd, title; yours is $REX_BLOCK
wait-turn ID [QUIET_SECS] [BG_SECS]    # run_in_background: status, transcript path, screen tail (quiet 60 s; through background jobs 600 s)
read-turn ID [--last|--pending|--user|--prompts N]   # last reply · the call a permission prompt waits on · newest prompt · what it was told
send-turn ID 'one short line'          # types, submits, confirms from the transcript that it arrived whole; a slash command too
send-turn ID --file brief.md           # anything longer: typing drops a long prompt's head
snippet KEY [DIR] [TEXT] | snippet --list [DIR]
rex send-key -b ID enter               # approve a permission prompt
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
`x`, their Claude launcher (a zsh function). It lets headroom place the
session on the least-loaded account. `rex run` prints the new block's id;
send once the input box shows on screen:

```bash
rex run -s "$REX_SESSION" -c DIR --label NAME --focus=false --shell none --json -- /bin/zsh -lic 'x; exec zsh -l'
rex run … -- /bin/zsh -lic 'x --resume SESSION_ID; exec zsh -l'    # resume one, in its own DIR
```

## Report

The user did not watch the night. Lead with each session's state, by window
and block:

- **Finished:** what it reached and what is left for the user, such as the
  merge.
- **Parked:** what it needs, explained so the user can decide from your
  words alone.
- **Halted:** what happened and what is still running.

Then, per session: the stages sent, the defaults taken, how the PR's code
review ended, and anything a step did that reached into what is the user's.
