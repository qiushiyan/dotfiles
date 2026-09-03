# Worktree popup — UI contract

Satellite of `worktree.md`. Read this when changing fzf output, popup keys,
window selection, PR checkout, or post-create delivery.

## One surface

```text
enter     → switch highlighted row; create typed name when no row matches
ctrl-n    → force-create typed name
tab       → mark rows
ctrl-x    → remove marked rows, or highlighted row when none are marked
ctrl-g    → reap clean worktrees merged into the default base
ctrl-p    → open PR picker
esc       → leave current picker
```

Switch and successful creation exit into the destination window. Remove and
reap loop back to a refreshed list. Failed creation and a cancelled PR picker
also return to the list.

## fzf is a positional protocol

The main picker combines `--print-query`, `--expect`, and `--multi`:

```text
line 1     typed query
line 2     pressed key; empty means enter
line 3..N  selected rows
```

The PR picker omits `--print-query`, so its first line is the key and its second
is the row. Any fzf flag that adds output must change the corresponding parser.

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
