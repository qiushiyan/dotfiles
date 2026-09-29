# Recovery — what protects each kind of state

This repository's files are the live configuration, and the machine holds more
than the repository shows: uncommitted edits, gitignored files, state outside
`~/dotfiles`. Each kind of state has its own protection, and some kinds have
only one. Read this before a destructive change to know what a mistake would
cost, and after a loss to know where each piece comes back from.

## What protects what

- **Committed files:** git and the GitHub remote; a lost checkout is a
  re-clone. Unpushed commits exist only on the laptop, and in the mini's
  mirror up to its last sync.
- **Uncommitted edits and gitignored files:** a local snapshot, and a Time
  Machine backup once the laptop has a backup destination. Nothing else holds
  a copy: GitHub never sees them, and the mini's mirror excludes every ignored
  path.
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

## The mini's mirror is not a backup

`mini-sync` runs `rsync --delete` one way, so a deletion on the laptop reaches
the mini on the next hourly run, and ignored paths never travel. After a loss,
pause the job before restoring anything, and re-enable it once the laptop tree
is whole (`docs/qiushi-mini.md` § Sync owns the job):

```bash
launchctl bootout gui/$(id -u)/com.qiushi.mini-sync
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.qiushi.mini-sync.plist
```

## Local snapshots

`snapshot` takes an APFS snapshot of the whole Data volume — every file on the
machine, not only this repository — in seconds and without sudo; its header
has usage and the restore commands. A snapshot shares the disk it protects, so
it answers a delete, never a lost or dead Mac. Snapshots are taken:

- **Before a destructive operation**, by hand or by an agent following the
  global rule `claude/.claude/rules/snapshots.md` (mirrored into Codex's
  `AGENTS.md`). A plain run replaces the previous plain run's snapshot, so
  exactly one stands and a session can take one before every risky step.
- **Daily**, from the LaunchAgent `com.qiushi.snapshot` at 13:00, keeping
  7 days, while Time Machine has no destination; once it has one, the run does
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

1. Stop the writers: pause `mini-sync`, and run nothing that writes into the
   damaged tree.
2. Committed files: `git restore` in place if `.git` survived, otherwise
   re-clone.
3. Uncommitted and ignored files: pick the newest snapshot taken before the
   loss (`snapshot --list`), mount it read-only and copy out.
4. What no snapshot holds: rebuild with the tools above, pull credentials from
   the password manager, and search agent history for files a session wrote.
5. Re-enable `mini-sync` once the laptop tree is whole.
