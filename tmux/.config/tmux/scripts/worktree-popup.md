# Worktree popup — UI contract

Satellite of `worktree.md`. Read this when changing fzf output, popup keys,
window selection, copy, or PR checkout. The comments in `tmux-worktree.sh` own
the mechanism; this file keeps the rules a change must not break.

## One surface

```text
enter     → switch highlighted row; create typed name when no row matches
ctrl-y    → copy highlighted path, or marked paths one per line; close
ctrl-n    → force-create typed name
tab       → mark rows
ctrl-x    → remove marked rows, or highlighted row when none are marked
ctrl-g    → reap clean worktrees merged into the trunk
ctrl-p    → open PR picker
esc       → leave current picker
```

Switch, successful creation, and copy close the popup; remove, reap, and any
failure or cancelled PR pick loop back to a refreshed list.

## First paint before probes

The picker opens on bare rows from `git worktree list` and swaps in the probed
rows (dirty marks, merged tags) once `gwt list --json` returns, ~0.3-1s over 25
worktrees. The swap is bound to fzf's `load` event: a reload bound to `start`
discards stdin, so the list would stay empty until the probes finish. `--track`
stays off because with `--id-nth` it blocks typing until the swap completes.
Everything else on the startup path that the list does not need runs in the
background, so listing, switching, and copying work even when gwt fails.

## fzf output is positional

The parser reads fzf's output by line position, so any fzf flag that adds
output must change the parser. Exit `1` can still carry the typed query when no
row matches; treating it as failure would break create-from-query.

## Session, window, and clipboard identity

Window names are presentation, not identity: `feat/x` and `feat-x` collide, and
users can rename windows. Find a worktree window by pane path first and sanitized
name only as fallback, matched exactly (`=session:=name`): a bare tmux target
also matches a name prefix, so removing `reap-me` would kill `reap-me-too`.
Target newly created windows by `#{window_id}`.

A popup has no pane, so copy hands `toclip` the invoking client's active pane;
`toclip` needs only that pane's session to find the client.

## PR checkout

The PR picker fetches `refs/pull/<n>/head` into a local branch and hands it to
normal creation (`worktree.md` § Creation pipeline). An existing local branch
of that name is used as it is, never force-moved.
