# Restarting a Rex server with work in it

A Rex server takes every session down with it, and an app update needs a
restart before the new build serves (`docs/rex.md` § Lessons). On the mini
that means a dozen Claude Code sessions, some driven overnight by drive's chat
bots. This runbook takes a server down and brings each one back as it was:
the same Rex sessions, tabs, splits and labels, each conversation resumed on
its account, the drive batches still holding their labels, asks and parks,
and a nudge to every session the restart interrupted.

## What survives and what is rebuilt

Everything a session needs to come back lives outside the server. The
conversation is on disk (`~/.claude/projects`, shared by every account), so
`claude --resume SID` brings it back in the same directory. drive's batch
record is on disk too, and drive itself reopens a label. The restart loses a pane's scrollback, an unsent line in an input box,
every background job and subagent a session ran, and every Rex id: session,
window and block ids all change.

So the restore rebuilds each kind of pane its own way:

- **A pane nobody drives** opens with the same session label, tab name and
  split, and runs the account's launcher with the session's flags:
  `x-<account> --effort high --resume SID; exec zsh -l`. Only a tab name the
  user gave is set again. rexd numbers every tab and names the rest after
  their pane, and its `~/.local/state/rex-lab/tab-names` file says which names
  it gave.
- **A driven label** is reopened by drive, with the open its batch's `watch
  --due` and `status` print once its session is gone: `drive --batch B open
  LABEL --dir DIR --resume SID --account ACCT`. drive refuses to open a label
  whose block still answers. Once the block is gone it records the new block
  under the same label, so the batch, its goals, its asks and the owner's
  page carry on, and it starts the batch's Rex session under its label if
  none runs. Resuming the label's own conversation keeps its park, and a
  parked label gets no wake until its next step, so nothing is parked again.
- **A session that was interrupted** gets one line once it is back: it was
  mid-turn, or idle with a background job or subagent still running. A
  driven label gets it through `drive send`, so the record holds it. The line
  says the jobs are gone, since a bare "continue" leaves a session waiting on
  an agent the restart killed:

  ```text
  Rex restarted and ended this session mid-turn; any background jobs or agents it was waiting on are gone. Continue from where you stopped.
  ```

The `~/.local/state/rex-lab/upgrade-2026-10-29/` directory on the mini holds
the tools that did this, each explained in its header:

- **`snapshot.py`:** records each session, its tabs in order, each pane's
  split, cwd, program and flags, each Claude Code's session id, account and
  busy state, and each drive label with its state and park. It also saves
  every screen. It only reads.
- **`restore.py`:** rebuilds from a snapshot, a dry run without `--go`.
- **`restart.py`:** runs the whole sequence as a one-off launchd job.

The tools are machine-local and dated: they name that day's drivers and the
session that ran them. A rerun drops `restore.py`'s re-park and its
`batch.json` edit, which drive's reopen makes redundant.

## Run it from outside Rex

The process that restarts the server must not live in it, and neither must
the shell that starts the new one. A Rex pane dies with the server. A server
started from a pane, a Claude Code tool shell or an ssh login passes that
shell's environment to every pane it runs (`docs/rex.md` § Lessons). The
clean runner is a one-off launchd job in the user's GUI domain. It gets the
same bare environment the app gives the server it starts, plus the PATH its
plist names:

```bash
launchctl bootstrap gui/$(id -u) ~/.local/state/rex-lab/upgrade-2026-10-29/rex-restart.plist   # RunAtLoad, no KeepAlive
launchctl bootout gui/$(id -u)/com.qiushi.rex-restart                                          # once it has reported
```

A session driving the restart from inside Rex dies with the rest. The job
resumes it last and asks it to report.

## The sequence

1. **Pick the moment.** Restart when every Claude Code in Rex is idle, no
   drive step is in flight, and no driven session runs a background job
   (`drive --driver D status --json`, `jobs`). drive's chat bots send each
   session its next step soon after a turn ends, so a busy batch may never
   be quiet. Restarting anyway costs each busy session its running work, and
   the interrupted-session line covers it.
2. **Snapshot right before the stop,** not earlier. Busy state, parks and
   blocks change by the minute, and the restore acts on what the snapshot
   says. A conversation already running elsewhere, such as one you resumed by
   hand, comes out of the snapshot, or it runs twice.
3. **Stop drive's wakes:** `drive watch --stop-all`. A watch that meets the
   restart wakes its bot with "gone", and the bot reopens its sessions itself,
   racing the restore; a watch an older drive started also polls with
   autostart on, so it starts a server in the gap. `--stop-all` stops every
   live batch's session wakes, whichever driver's, records each stop, prints
   the `watch --due` each batch runs once the restore is done. Timers run on.
4. **Stop the server and start the new one at once,** from the clean
   environment, with the mini's tailnet flags:

   ```bash
   rex --autostart=false server stop
   rex server start --tailscale --tailscale-hostname qiushi-mini-rex
   ```

5. **Check the server before anything else uses it.** Its version is the
   bundle's (`rex version` with the bundle's binary). `tailscale: running`
   shows in `rex server status`, and `rex server tailscale on` adds it to a
   running server. `exit-empty` is false. Its environment carries no
   `NO_COLOR`, `FORCE_COLOR`, `TERM=dumb` or `DRIVE_WATCH`:

   ```bash
   ps eww -o command= -p "$(rex --autostart=false server status | awk '/^pid:/{print $2}')" | tr ' ' '\n' | grep -E '^(NO_COLOR|FORCE_COLOR|TERM|DRIVE_WATCH|SSH_CONNECTION)='
   ```

   A server that fails a check is stopped and started again. Something else
   started it in the gap.
6. **Restore, then verify.** Run each batch's `watch --due` from step 3: it
   arms the wakes again and names the open for any label still gone. `rex
   window ls -A` shows every tab, and `drive --driver D status` shows each
   label on a live block with its park. Every resumed session has exactly one
   live process: count the live `sessions/<pid>.json` per session id across
   `~/.claude/sessions` and `~/.claude-accounts/*/sessions`.

## Traps

- **An update is installed only once the old app has quit.** Sparkle moves
  the old bundle into
  `~/Library/Caches/com.superlogical.rex/org.sparkle-project.Sparkle/Installation/`
  and the new one into `/Applications` after the app quits. A server started
  in between runs the old build from that cache: `rex server status` keeps
  the old version string, and the app shows a "restart server" toast that is
  right. `lsof -p <server pid>` names the executable it runs. The restart for
  an update follows the new app's launch, never the old app's quit.
- **After a stop, any `rex` call starts a server, and the server inherits
  that caller's environment** (`docs/rex.md` § Lessons). One started from a
  bot's Claude Code tool shell gives every pane `NO_COLOR=1 FORCE_COLOR=0`:
  prompts, git and Claude Code lose their colours, and Claude Code's dim
  prompt suggestion reads as typed text, reappearing after every delete, so
  drive calls the input box typed. Only another restart clears it, since each
  running pane already carries the variables. drive passes
  `--autostart=false` on every call; a watch an older drive started does not
  (step 3).
- **A batch that names its Rex session by id loses it on every restart.**
  `rex_session` in a batch's `batch.json` is where `drive open` opens blocks.
  drive records the session's label (`planlab`, `itell`), and its open starts
  that session again when none runs; a batch an older drive started may hold
  an id (`session:…`), which has to be changed to the label before any
  reopen.
- **What a dead session was doing comes from its transcript.** Claude Code
  deletes `sessions/<pid>.json` when its process exits, so the busy flag dies
  with it. The tail of `~/.claude/projects/*/<sid>.jsonl` still shows whether
  the last turn ended (`stop_reason: end_turn`), stopped mid-tool, or ended
  while waiting on an agent. drive's `events.jsonl` shows each label's last
  step and park, and the bots' notes.
- **A bot may already be rebuilding its own batch.** Unless the wakes were
  stopped first, each live batch's driver is woken by a "gone" wake whose
  `next:` is the reopen, and runs it. Read each batch's recent events before
  restoring: drive's refusal ("already open as block …") keeps a second open
  harmless, but a bot's open can start the Rex session first, so tabs land in
  the order the bot opened them.
