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
