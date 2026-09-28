# Worktree control — design

`prefix W` opens the tmux worktree popup. This spine owns the shared model and
core boundary; read the satellite for the branch being changed:

```text
popup selection, creation, PR checkout → worktree-popup.md
merged verdict, removal, recovery      → worktree-removal.md
```

The scripts own syntax. These docs own the constraints behind it.

## Shared placement, separate interfaces

`gwt` on PATH (source: `~/dev/gwt`) owns branch resolution,
worktree creation, ignored-file seeding, listing, the trunk, and every merged
verdict. Its callers are the tmux popup,
`brief start`, the `enter-worktree` skill, and the optional `gwtcd` shell helper.

```text
resolution, creation, seeding       → gwt binary
listing, trunk, merged verdicts      → gwt list / merged / trunk
snapshots, recovery refs, trash      → worktree-core.sh
tmux window, popup, send-keys        → tmux-worktree.sh
parent-shell cd                      → gwtcd helper
brief lifecycle diagnosis/resume     → brief CLI
```

The binary prints only the new path on stdout; diagnostics use stderr. It never
changes the caller's directory. `gwt create --non-interactive` accepts the
configured base (HEAD by default) without prompting. `--json` returns the path
and placement result as an object. The binary's `--help` owns its full contract;
`~/dev/gwt/README.md` owns installation, placement, and verdict design. Its
non-interactive `remove` deletes a clean checkout and branch once the branch is
merged into the trunk; the popup's richer cleanup (batches, snapshots, trash,
windows) stays here and asks gwt for the same verdicts.

The shell core retains a forwarding CLI for already-running shells that still
hold the old function. Run `zshreload` to pick up the binary and `gwtcd` helper.

## Mental model

```text
tmux session = project
window       = worktree
pane         = tool
```

Invoke the popup from a repo pane. Worktrees land at
`~/dev/.worktrees/<repo>/<branch>`; `<repo>` is the main checkout's basename.
The popup opens windows in the session that invoked it.

Creation uses the shared `gwt` config: global `~/.config/gwt/config.toml`, then
`gwt.toml` in the shared Git directory. `gwt config show` explains the effective
values. The popup obtains its root with `gwt path`; the path above is the default.
Merge tags, reap, and branch cleanup measure against gwt's trunk (the remote
default branch), never the creation base. Fetch freshness and deadlines come
from `gwt` config.

## Creation pipeline

```text
resolve safe slot
  → git worktree add
  → copy matching ignored prerequisites
  → open/select window
  → send one visible install && post-create command
```

Cheap prerequisites run synchronously before the new window starts work. Slow
dependency installation runs visibly in the destination window so the popup
never blocks and the user can interrupt it.

Package-manager choice comes from the committed lockfile. The post-create
command defaults to `x`; both behaviors are configurable through tmux options.
Delivery is one `send-keys` line targeted by window id, never by the branch-derived
window name.

## Ignored-file seeding

A worktree checkout omits local prerequisites such as `.env*`, token-bearing
`.npmrc`, and `scripts.local/`. The binary copies only ignored matches from the
main worktree, preserving relative path and permissions.

```text
source   → main worktree
universe → git ls-files -oi --exclude-standard --directory
gate     → basename matches configured copy_globs
copy     → cp -pPR to the same relative path, preserving existing targets
```

`--directory` prevents descent into wholly ignored trees such as
`node_modules`. Because a matched directory is copied whole, keep patterns
specific; `*` would copy every ignored directory. Tracked files already arrive
through checkout, and unignored WIP is deliberately excluded.

## Slot safety

`gwt` accepts an absent path or an empty real directory. It refuses a file,
symlink, unreadable or non-empty directory, and symlink parents within the
repository worktree root. Creation deletes nothing.
A stale registration may leave the only copy of work in that slot; every
creator passes through the same guard.

Slashed branches create nested paths. Cleanup may remove empty parents only
inside this repository's worktree root.

## Probes

Dirty state and merge verdicts are one `gwt list --json` call, which runs one
Git process per CPU, keeps Git's order, and probes with `--no-optional-locks`
so it never contends with an agent in the same worktree. The popup never
fans out Git itself; see `worktree-popup.md` § First paint before probes.

## Portability and verification

The scripts remain bash-3.2-safe; under `set -u`, empty arrays are unsafe, so
batch data uses TSV lines.

```text
placement, verdicts: make -C ~/dev/gwt check
snapshots, cleanup:  tmux/.config/tmux/scripts/tests/test-worktree-core.sh
popup, reap, copy:   tmux/.config/tmux/scripts/tests/test-gwt-popup.py
popup path:          detached scratch tmux pane + send-keys + capture-pane
safe test:           set @worktree_post_create_cmd to harmless echo
```

Rebuild the binary with `make -C ~/dev/gwt install`. Script edits are live
through Stow. A binding change in `tmux.conf` needs `prefix r`.
