# Worktree popup — UI contract

Satellite of `worktree.md`. Read this when changing fzf output, popup keys,
window selection, PR checkout, or post-create delivery.

## One surface

```text
enter     → switch highlighted row; create typed name when no row matches
ctrl-y    → copy highlighted path, or marked paths one per line; close
ctrl-n    → force-create typed name
tab       → mark rows
ctrl-x    → remove marked rows, or highlighted row when none are marked
ctrl-g    → reap clean worktrees merged into the default base
ctrl-p    → open PR picker
esc       → leave current picker
```

Switch and successful creation exit into the destination window; copy exits
with a status-line report, like `prefix y`. Remove and reap loop back to a
refreshed list. Failed creation or copy and a cancelled PR picker also return
to the list.

A popup has no pane, so copy hands `toclip` the invoking client's active pane;
`toclip` needs only that pane's session to find the client. `toclip` resolves
through PATH, which is how the popup test substitutes a stub.

## First paint before probes

Dirty marks and merged tags come from `gwt list --json`: a status and a merge
verdict per worktree, ~0.3-1s over 25 worktrees depending on load and on
whether a moved trunk emptied gwt's memo. The picker therefore opens on bare
rows from `git worktree list`, with the probed columns blank, and swaps in the
probed rows once:

```text
bare_rows | fzf --id-nth=2 --bind 'load:unbind(load)+reload-sync:<script> --rows'
```

- `load`, not `start`: a reload bound to `start` discards stdin, so the list
  would stay empty until the probes finish.
- `reload-sync` keeps the bare list live, so typing and moving never wait.
- `--id-nth=2` (the path) carries marks across the swap. The cursor keeps its
  index because gwt lists the same worktrees in Git's order: bare repositories
  skipped, detached and prunable checkouts kept, as `bare_rows` does.
- No `--track`: with `--id-nth` it blocks input until a `reload-sync` completes.

Startup work the list does not need runs in the background: trash sweep, backup
pruning, and `gwt trunk --fetch`. Listing, switching, and copying therefore work
even if gwt fails; the probed rows then fall back to the bare ones. Removal
resolves the gwt root when it runs.

## fzf is a positional protocol

The main picker combines `--print-query`, `--expect`, and `--multi`:

```text
line 1     typed query
line 2     pressed key; empty means enter
line 3..N  selected rows
```

The PR picker omits `--print-query`, so its first line is the key and its second
is the row. Any fzf flag that adds output must change the corresponding parser.

Rows are `<markers> <branch>\t<path>\t<branch>`; bare and probed rows share the
layout, so a key pressed before the swap parses the same.

Exit `130` is cancellation. Exit `1` can still carry the typed query when no row
matches; treating it as failure would break create-from-query. fzf uses
`/dev/tty`, then returns to the script, which is why confirmation prompts remain
interactive.

## Session and window identity

`display-popup` expands formats in `-d`, not in its shell-command argument.
`tmux-worktree.sh` therefore self-detects the attached client's session with
`tmux display-message`; passing `#{session_name}` would pass the literal text.

The binding sets the repo cwd with `-d`, and the script retains a `cd` fallback.

Window names are presentation, not identity: `feat/x` and `feat-x` collide, and
users can rename windows. Find a worktree window by pane path first and sanitized
name only as fallback. Target newly created windows by `#{window_id}`.

## Create and PR checkout

Creation opens the window before delivering dependency installation and the
post-create command. The two commands share one `&&` chain so prerequisites
finish before the agent starts, while the popup remains unblocked.

The PR picker lists through `gh`, previews through `gh pr view`, and fetches
`refs/pull/<n>/head` before calling normal creation. Existing local branches are
never force-moved. Its list is cached only for the popup lifetime; `ctrl-r`
refreshes, and an empty result is not cached.

## Theme and headless checks

fzf reads the active `@thm_*` palette at launch; reopening picks up a theme
change. Popup borders remain owned by `tmux.conf`.

`display-popup` needs an attached client, but the script can be driven inside a
pane on a detached scratch server. Use `send-keys` and `capture-pane`; replace
the post-create command before any create test.
