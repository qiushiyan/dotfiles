# Recovery — what protects each kind of state

This repository's files are the live configuration, and the machine holds more
than the repository shows: uncommitted edits, gitignored files, state outside
`~/dotfiles`. Each kind of state has its own protection, and some kinds have
only one. Read this before a destructive change to know what a mistake would
cost, and after a loss to know where each piece comes back from.

## What protects what

- **Committed files:** git and the GitHub remote; a lost checkout is a
  re-clone. An unpushed commit exists only on the machine that made it;
  `twin status` lists those on both machines.
- **Uncommitted edits and gitignored files:** on the mini, Time Machine:
  hourly to an encrypted Samsung T7 left plugged into it, with Time Machine's
  own local snapshots in between (§ Time Machine on the mini). On the laptop,
  which has no backup destination, only the daily local snapshot, so the
  laptop should hold no work that exists nowhere else. GitHub never sees
  them. The gitignored files `twin` carries also exist on the other machine
  (§ A carried copy is not a backup).
- **Credentials:** the password manager, never this tree (§ Credentials in
  1Password). `vpn-private/` stays in `.gitignore` and out of `PACKAGES` so
  that a copy restored into the checkout can be neither committed to this
  public repo nor stowed.
- **Rebuildable state:** the tool that writes it — `prefix I` for tmux
  plugins, `skill-sync` for synced skills, `theme-set` for Ghostty's generated
  theme, `pnpm install` for `node_modules`.
- **Files an agent session wrote or edited:** as a last resort, agent session
  history. The tool calls carry the written content, and obelisk's index keeps
  it after the transcript file is gone; the obelisk skill queries it.
- **The tmux workspace:** continuum's snapshot, saved every 15 minutes, holds
  the windows, layout, each pane's folder and title; Claude's transcripts hold
  the conversations. Nothing holds the running processes (§ A dead tmux
  server).

## Credentials in 1Password

The home-VPN handoff is one Document item, `vpn-private`, in the Private vault
of the Planlab 1Password account. `README.md` is the item's document;
`SECRETS.md` and the Clash configs `nexitally-full.yaml` and
`nexitally-whitelist.yaml` are files in its `add more` section.

Agents reach it through the desktop app's CLI integration: the first `op` call
in a session raises a Touch ID prompt on the user's screen, and the
authorization lasts until 10 idle minutes or 12 hours pass. A service account
would skip the prompt, but it cannot reach a Private vault. `OP_ACCOUNT`, set
in `~/.secrets`, picks the account, because the CLI lists it twice and refuses
to guess.

```bash
d=$(mktemp -d); chmod 700 "$d"
op read "op://Private/vpn-private/SECRETS.md" --out-file "$d/SECRETS.md"            # any of the files
op document edit vpn-private "$d/README.md" --vault Private                           # replace README.md
op item edit vpn-private --vault Private "add more.SECRETS\\.md[file]=$d/SECRETS.md"   # replace a section file
rm -rf "$d"
```

The files are credentials: print nothing from them, and remove the directory
once the upload is done. The escaped dot matters — unescaped, `op` splits the
name into a section and a field, and the upload lands as a stray file named
`md` beside the original.

## A carried copy is not a backup

`twin` reconciles the gitignored files its manifest lists between the laptop
and the mini (`docs/twin.md` § Carried files), so each exists on both. That
covers losing a machine. It does not cover a bad change: an edit, a
truncation included, reaches the other machine at the laptop's next hourly
run. Only a deletion stays put; the other machine keeps its copy and the path
waits for a resolution, which is where a deleted carried file comes back from
(`twin files resolve <target> <path> --keep <the machine that has it>`).

After damage to a carried file, stop the reconciler on the laptop before
restoring, so the damaged copy is not carried over the good one, and resume
it once one machine holds the file whole:

```bash
launchctl bootout gui/$(id -u)/com.qiushi.twin-tick                                        # stop
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.qiushi.twin-tick.plist         # resume
```

A copy that `twin files resolve` replaced or removed is kept under
`~/.local/state/twin/replaced/` on the machine that held it. A bad change
older than that comes back from the mini's Time Machine history.

## Time Machine on the mini

The mini backs up to a Samsung T7 2 TB on one of its own USB-C ports: an
encrypted APFS volume named `T7 Backup`, the whole drive given to Time
Machine, password in 1Password. `~/Library/Caches` and `~/.cache` are
excluded. Time Machine thins on its own (hourly for a day, daily for a
month, weekly until the drive fills, then the oldest weekly goes), so the
drive never needs pruning.

The drive sits in the office beside the mini: it answers a bad change or a
dead mini, not a loss of the office. Work on the mini survives that
only once it is pushed.

The laptop is not backed up to it. Network Time Machine from home to the
mini over the tailnet would be slow to seed and fragile; the laptop stays
free of unique work instead.

```bash
tmutil destinationinfo                       # the destination, on the mini
tmutil status                                # a backup in progress
tmutil listbackups                           # backups on the drive (needs Full Disk Access)
tmutil isexcluded <path>                     # whether a path is backed up
```

## Local snapshots

`snapshot` takes an APFS snapshot of the whole Data volume — every file on the
machine, not only this repository — in seconds and without sudo; its header
has usage and the restore commands. A snapshot shares the disk it protects, so
it answers a delete, never a lost or dead Mac. Snapshots are taken:

- **Before a destructive operation**, by hand, or by Codex following its
  global `AGENTS.md`. A plain run replaces the previous plain run's snapshot,
  so exactly one stands and a session can take one before every risky step.
  Claude's copy of the rule, `claude/.claude/rules/snapshots.md`, is disabled
  because it fired on routine worktree work; restore it with
  `git checkout ebc580f -- claude/.claude/rules/snapshots.md`.
- **Daily**, on each machine, from the LaunchAgent `com.qiushi.snapshot` at
  13:00, keeping 7 days, while Time Machine has no destination; once it has one, the run does
  nothing, because Time Machine snapshots hourly itself. The window matters
  more than the frequency: the files only a snapshot protects change rarely,
  and their loss is noticed late, so a week of dailies beats a day of hourlies.

The daily job is paused by disabling it, because launchd loads every plist in
`~/Library/LaunchAgents` again at login and an unload alone lasts until then:

```bash
launchctl bootout gui/$(id -u)/com.qiushi.snapshot; launchctl disable gui/$(id -u)/com.qiushi.snapshot   # pause
launchctl enable gui/$(id -u)/com.qiushi.snapshot; launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.qiushi.snapshot.plist   # resume
launchctl print-disabled gui/$(id -u) | grep snapshot                                                  # which it is
for d in $(snapshot --list); do tmutil deletelocalsnapshots "$d"; done                                 # delete them all
```

## After a loss

1. Stop the writers: pause the reconciler when a carried file is involved
   (§ A carried copy is not a backup), and run nothing that writes into the
   damaged tree.
2. Committed files: `git restore` in place if `.git` survived, otherwise
   re-clone.
3. Uncommitted and ignored files: on the mini, open Time Machine from the
   menu bar (or Finder in the affected folder) and restore from the newest
   backup before the loss; a dead mini is rebuilt from the T7 with Migration
   Assistant. On the laptop, pick the newest snapshot taken before the loss
   (`snapshot --list`), mount it read-only and copy out.
4. What no snapshot holds: rebuild with the tools above, pull credentials from
   the password manager, and search agent history for files a session wrote.
5. Resume the reconciler once the carried files are whole on one machine.

## A dead tmux server

The terminal shows the last frame tmux drew, `[server exited unexpectedly]`
spliced into a pane, and a bare shell prompt below it; `tmux ls` finds no
server. Every program in every pane died with it: shells, Claude sessions, and
what those sessions ran in the background, such as `envoy` jobs, which record
`interrupted` with SIGTERM.

The snapshot brings back windows, layout, folders and pane titles, and the
transcripts bring back the conversations, but nothing restarts the agents.
Their link is the pane title: Claude sets it to its session's title, resurrect
saves it, and the transcript records the same title (an `ai-title` or
`custom-title` line), so each pane maps to its own session. `claude --continue`
does not: it opens a folder's newest conversation, which is the wrong one
wherever panes share a folder or a background `claude -p` run wrote there
since.

1. **Copy the snapshots aside** before starting a server:
   `cp -p ~/.local/share/tmux/resurrect/tmux_resurrect_*.txt <a scratch dir>`.
   A server that restores wrong autosaves the wrong state over `last` within
   15 minutes.
2. **Map Claude panes to sessions** from the snapshot, before resumed sessions
   start writing transcripts again. The block prints
   `session:window.pane  session-id  how  title`; `how` is `title`, or
   `newest-in-folder` for an untitled session, which is the guess to check.
   A pane whose transcript stopped before the server died (compare its
   modification time with the others) had already exited and stays a shell.

   ```bash
   python3 -I - "$HOME/.local/share/tmux/resurrect/last" <<'PY'
   import glob, json, os, re, sys
   save = sys.argv[1]
   since = os.path.getmtime(save) - 86400
   projects = os.path.expanduser("~/.claude/projects")
   for row in open(save):
       f = row.rstrip("\n").split("\t")
       if f[0] != "pane" or not f[10].startswith(":claude"):
           continue
       title, cwd = f[6].split(" ", 1)[-1], f[7].lstrip(":")
       found = []
       for t in glob.glob(f"{projects}/*/*.jsonl"):
           if os.path.getmtime(t) < since:
               continue
           for line in open(t, errors="replace"):
               if '-title"' in line:
                   d = json.loads(line)
                   if title in (d.get("aiTitle"), d.get("customTitle")) and d.get("cwd", cwd) == cwd:
                       found.append((os.path.getmtime(t), d["sessionId"], "title"))
                       break
       if not found:
           for t in glob.glob(f"{projects}/{re.sub(r'[^A-Za-z0-9]', '-', cwd)}/*.jsonl"):
               found.append((os.path.getmtime(t), os.path.basename(t)[:-6], "newest-in-folder"))
       m, sid, how = max(found) if found else (0, "?", "none")
       print(f"{f[1]}:{f[2]}.{f[5]}", sid, how, title, sep="\t")
   PY
   ```

3. **Start a server.** At the terminal, `tmux` starts one attached, and
   continuum restores the snapshot about a second later. Detached,
   `tmux new-session -d` does the same; wait until `tmux ls` lists the
   restored sessions. The restore removes the unnamed starter session `0`
   itself; a starter given a name stays, and killing it before the restore
   lands leaves no session, so the server exits first. An agent starting the
   server passes only the terminal's environment (`env -i` with `HOME`,
   `USER`, `SHELL`, `TERM`, `TERMINFO`, `LANG`, `SSH_AUTH_SOCK`, `TMPDIR` and
   the `GHOSTTY_*` variables): every pane inherits the environment of the
   process that started the server, and its own `CLAUDE_*` variables would
   reach every Claude launched there.
4. **Resume each session in its pane**, through `x` so the folder's effort
   and the permission flags come back with it:
   `tmux send-keys -t work:4.2 "x --resume <session-id>" Enter`.
5. **Re-dispatch background work** the sessions owned: `envoy pending` lists
   the interrupted jobs.

### Finding when and why

- **The watcher's record comes first.** The `com.qiushi.tmux-exit-watch`
  agent, on both machines, holds every tmux server's pid with the kernel and
  appends one line per exit to `~/.local/state/tmux-exit/exits.jsonl`: the
  time to the millisecond, the socket, and `kind` — `clean` (exit 0: the last
  session closed, `kill-server`, SIGTERM), `error-exit` (a non-zero code;
  tmux's own `fatal` exits 1) or `signaled` (with the signal) — plus
  `detail` `memory` when macOS killed it for memory. Any exit but a clean one
  names a process table saved beside it at that moment, which shows what ran
  beside the server, and for how long. It does not name a signal's sender.
  `~/Library/Logs/tmux-exit-watch.log` shows which servers it is watching;
  it picks up a restarted server by itself (`scripts/.local/bin/tmux-exit-watch`).
- **When, from everything else:** every transcript that was live at the time
  stops at the same second (file modification time); an `envoy` job's
  `meta.json` records its `terminationRequestedAt` to the millisecond; the
  snapshot's time bounds it from below. zsh writes a history entry when a
  command starts, so `~/.zsh_history` shows what was typed in that second.
- **The client's last line names the kind of exit.** `[server exited]` is a
  graceful shutdown: `kill-server`, or SIGTERM. `[server exited unexpectedly]`
  means the connection broke before that: SIGKILL, tmux's own `fatal` (an
  `exit(1)` whose reason goes only to a `-v` log), a crash, or an IPC failure.
  SIGHUP does not stop the server.
- **A crash or a memory kill** usually leaves a report: a `tmux-*.ips` in
  `~/Library/Logs/DiagnosticReports`, or a `JetsamEvent-*.ips` in
  `/Library/Logs/DiagnosticReports` whose killed process carries a `reason`.
  No report narrows the cause without excluding a crash.
- **tmux keeps no log** unless the server was started with `-v` or sent
  SIGUSR2, which toggles the log on and off (`kill -USR2 <server pid>`;
  the file is `tmux-server-<pid>.log` in the server's working directory).
  It is no way to wait for a rare fatal: attached to a busy session it
  writes about half a megabyte a second, a line per keystroke and redraw,
  synchronously, which makes typing and scrollback visibly sluggish, and the
  file holds everything typed. Use it for a bounded reproduction, then
  delete the file.
- **A suspected trigger is tested on its own server**, `tmux -L <name>` from a
  scratch directory with a config that does not load tpm: continuum on a
  second server autosaves over the real snapshots. Attach a client and
  confirm it with `tmux -L <name> list-clients`, since a detached server never
  draws to a terminal, and type the command into an interactive shell there:
  every command start runs zsh's `preexec` hooks, and cout's calls
  `tmux set-option` before the command itself runs (`zsh/.config/zsh/cout.zsh`).
