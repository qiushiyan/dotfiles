# Worktree control — design

`prefix W` opens the tmux worktree popup. This spine owns the shared model and
core boundary; read the satellite for the branch being changed:

```text
popup selection, creation, PR checkout → worktree-popup.md
merged verdict, removal, recovery      → worktree-removal.md
```

The scripts own syntax. These docs own the constraints behind it.

## Three front-ends, one core

`scripts/worktree-core.sh` is tmux-free git logic shared by:

- `tmux-worktree.sh` — fzf UI; opens each worktree in its own tmux window and
  delivers post-create work there;
- `gwt` in `zsh/.config/zsh/git.zsh` — creates, seeds ignored files, then changes
  the current shell's directory; it does not install dependencies;
- `brief start` in `~/dev/brief` — resolves the branch first, then creates only
  when resolution proves the name absent.

```text
git/path/base/slot/seed/merge verdict → worktree-core.sh
tmux window, popup, send-keys          → tmux-worktree.sh
parent-shell cd                        → gwt wrapper
brief lifecycle diagnosis             → brief CLI
```

The core CLI prints only the new path on stdout. Git progress goes elsewhere so
`gwt` can consume the result without parsing prose.

## Mental model

```text
tmux session = project
window       = worktree
pane         = tool
```

Invoke the popup from a repo pane. Worktrees land at
`~/dev/.worktrees/<repo>/<branch>`; `<repo>` is the main checkout's basename.
The popup opens windows in the session that invoked it.

The popup forks from the default-base chain. `gwt` defaults to the current
branch behind confirmation because its purpose is to continue from where the
shell stands. An explicit base overrides either.

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
`.npmrc`, and `scripts.local/`. The core copies only ignored matches from the
main worktree, preserving relative path and permissions.

```text
source   → main worktree
universe → git ls-files -oi --exclude-standard --directory
gate     → basename matches @worktree_copy_globs
copy     → cp -pR to the same relative path
```

`--directory` prevents descent into wholly ignored trees such as
`node_modules`. Because a matched directory is copied whole, keep patterns
specific; `*` would copy every ignored directory. Tracked files already arrive
through checkout, and unignored WIP is deliberately excluded.

## Slot safety

`wt_slot_free` accepts an absent path or an empty real directory. It refuses a
file, symlink, unreadable directory, or non-empty directory and deletes nothing.
A stale registration may leave the only copy of work in that slot; every
creator passes through the same guard.

Slashed branches create nested paths. Cleanup may remove empty parents only
inside this repository's worktree root.

## Parallel probes

List rendering fans out read-only git questions such as dirty state and merge
status. `wt_fanout` preserves input order with zero-padded result files; finish
order never reshuffles the UI.

Run its wait loop in an explicit subshell. A bare `wait` in the caller could
adopt the background base fetch and turn list rendering back into a network
wait. Probes use `git --no-optional-locks` so they do not contend with agents in
the same worktrees.

## Portability and verification

The scripts remain bash-3.2-safe; under `set -u`, empty arrays are unsafe, so
batch data uses TSV lines.

```text
core tests:  tmux/.config/tmux/scripts/tests/test-worktree-core.sh
popup path:  detached scratch tmux pane + send-keys + capture-pane
safe test:   set @worktree_post_create_cmd to harmless echo
```

Script edits are live through Stow. A binding change in `tmux.conf` needs
`prefix r`.
