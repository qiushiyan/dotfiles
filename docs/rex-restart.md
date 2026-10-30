# Upgrading and restarting a Rex server with work in it

A Rex server takes every session down with it, and an app update needs a
restart before the new build serves (`docs/rex.md` § Lessons). On the mini
that means a dozen Claude Code sessions, some driven overnight by drive's chat
bots. `rex-upgrade` (`rex/.local/bin/rex-upgrade`, every command in its
header) installs a new build and brings each session back as it was: the same
Rex sessions, tabs, splits and labels, each conversation resumed on its
account, the drive batches still holding their labels, asks and parks, and a
nudge to every session the restart interrupted.

## The upgrade

```bash
rex-upgrade check     # the feed's newest build beside the app and the server
rex-upgrade stage     # download it from the app's own feed, verify it, stage it
rex-upgrade start     # the job below, in launchd; --now skips the wait for quiet
```

Each command runs as well over ssh from the other machine
(`ssh mini ~/.local/bin/rex-upgrade check`). With nothing staged, `start` only
restarts the server, which is what a machine needs once Sparkle has updated
its app. The job:

1. **Waits for quiet:** no Claude Code in Rex busy, no drive step in flight,
   no driven session running a background job, on two looks 20 s apart.
   drive's chat bots send each session its next step soon after a turn ends,
   so a busy batch may never be quiet; `--now` restarts anyway, and the
   interrupted sessions get the continue line.
2. **Snapshots right then,** since busy state, parks and blocks change by the
   minute: each session, its tabs in order, each pane's split, cwd, program
   and flags, each Claude Code's session id, account and busy state, each
   drive label with its state and park, and every screen.
3. **Stops drive's wakes** with `drive watch --stop-all`. A watch that met the
   restart would wake its bot with "gone", and the bot would reopen its
   sessions itself, racing the restore. It prints the `watch --due` each batch
   runs afterwards.
4. **Swaps and restarts:** it quits the app, stops the server, moves the
   staged app into place, and opens the app, which starts the new server from
   its own copy under `RexServer/Versions/<build>` with its own settings, the
   tailnet address included. When the app starts none, the job starts it with
   the old server's tailnet flags. The new server must run the new build,
   serve the tailnet if the old one did, and carry no `NO_COLOR`,
   `FORCE_COLOR`, `TERM=dumb`, `DRIVE_WATCH` or `SSH_CONNECTION`; one that
   fails is stopped and started again, three times.
5. **Restores** (below), runs the `watch --due` lines, and asks the Claude
   Code that ran `start`, if it ran in this Rex, to report.

Each run keeps its snapshot, screens, `job.log`, `restore.log` and the app it
replaced in `~/.local/state/rex-lab/upgrades/<time>/`. When the job gives up,
fix the server by hand and run `rex-upgrade restore --go <run>/snapshot.json`;
without `--go` it prints what it would do.

## What survives and what is rebuilt

Everything a session needs to come back lives outside the server. The
conversation is on disk (`~/.claude/projects`, shared by every account), so
`claude --resume SID` brings it back in the same directory. drive's batch
record is on disk too, and drive itself reopens a label. The restart loses a
pane's scrollback, an unsent line in an input box, every background job and
subagent a session ran, and every Rex id: session, window and block ids all
change.

So the restore rebuilds each kind of pane its own way:

- **A pane nobody drives** opens with the same session label, tab name and
  split, and runs the account's launcher with the session's flags:
  `x-<account> --effort high --resume SID; exec zsh -l`. Only a tab name the
  user gave is set again. rexd numbers every tab and names the rest after
  their pane, and its `~/.local/state/rex-lab/tab-names` file says which names
  it gave. A pane whose directory is gone opens in `~`, where its
  conversation does not resume, since Claude Code files it under that
  directory; the restore names it.
- **A driven label** is reopened by drive: `drive --batch B open LABEL --dir
  DIR --resume SID --account ACCT`. drive refuses to open a label whose block
  still answers. Once the block is gone it records the new block under the
  same label, so the batch, its goals, its asks and the owner's page carry
  on, and it starts the batch's Rex session under its label if none runs.
  Resuming the label's own conversation keeps its park, and a parked label
  gets no wake until its next step.
- **A session that was interrupted** gets one line once it is back: it was
  mid-turn, or idle with a background job or subagent still running. A
  driven label gets it through `drive send`, so the record holds it. The line
  says the jobs are gone, since a bare "continue" leaves a session waiting on
  an agent the restart killed:

  ```text
  Rex restarted and ended this session mid-turn; any background jobs or agents it was waiting on are gone. Continue from where you stopped.
  ```

## Run it from outside Rex

The process that restarts the server must not live in it, and neither must
the shell that starts the new one. A Rex pane dies with the server. A server
started from a pane, a Claude Code tool shell or an ssh login passes that
shell's environment to every pane it runs (`docs/rex.md` § Lessons). So
`start` runs the job as a one-off launchd job in the user's GUI domain
(`com.qiushi.rex-upgrade`, its plist beside the run), which gets the bare
environment the app gives the server it starts, plus the PATH the plist
names. A session that ran `start` from inside Rex dies with the rest; the job
resumes it and asks it to report.

## Checking after

`rex window ls -A` shows every tab, and `drive --driver D status` shows each
label on a live block with its park. Every resumed session has exactly one
live process: count the live `sessions/<pid>.json` per session id across
`~/.claude/sessions` and `~/.claude-accounts/*/sessions`. `rexd status` names
one rexd. The app's screen is the user's to check: whether it shows every
session, and whether the other machine's sidebar has reconnected, which takes
up to 20 seconds.

## Traps

- **Sparkle installs an update only once the old app has quit.** It moves the
  old bundle into
  `~/Library/Caches/com.superlogical.rex/org.sparkle-project.Sparkle/Installation/`
  and the new one into `/Applications` after the app quits. A server started
  in between runs the old build from that cache: `rex server status` keeps
  the old version string, and the app shows a "restart server" toast that is
  right. `lsof -p <server pid>` names the executable it runs. After a Sparkle
  update, `rex-upgrade start` follows the new app's launch.
- **After a stop, any `rex` call starts a server, and the server inherits
  that caller's environment** (`docs/rex.md` § Lessons). One started from a
  bot's Claude Code tool shell gives every pane `NO_COLOR=1 FORCE_COLOR=0`:
  prompts, git and Claude Code lose their colours, and Claude Code's dim
  prompt suggestion reads as typed text, reappearing after every delete, so
  drive calls the input box typed. Only another restart clears it, since each
  running pane already carries the variables. drive passes
  `--autostart=false` on every call, and the job's check refuses such a
  server.
- **A batch that names its Rex session by id loses it on every restart.**
  `rex_session` in a batch's `batch.json` is where `drive open` opens blocks.
  drive records the session's label (`planlab`, `itell`); a batch an older
  drive started may hold an id (`session:…`), which has to be changed to the
  label before any reopen.
- **What a dead session was doing comes from its transcript.** Claude Code
  deletes `sessions/<pid>.json` when its process exits, so the busy flag dies
  with it. The tail of `~/.claude/projects/*/<sid>.jsonl` still shows whether
  the last turn ended (`stop_reason: end_turn`), stopped mid-tool, or ended
  while waiting on an agent. drive's `events.jsonl` shows each label's last
  step and park, and the bots' notes.
