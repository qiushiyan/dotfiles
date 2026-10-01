# Worktree removal — the popup's part

Satellite of `worktree.md`. Read this when changing ctrl-x, reap, branch
prompts, or how removal treats windows. `gwt remove` is the engine: it owns
refusals, the merged verdict, recovery refs, their expiry and the trash
(`~/dev/gwt/README.md` § Removal). The popup owns the prompts and the windows.

## Flow

```text
gwt list --json            → dirty flags, main/current skipped, reap set
confirm batch, then dirty  → declining drops the dirty selections
kill the windows           → per path, every session, plus the exact-name fallback
gwt remove --keep-branch [--discard-dirty] <paths>
gwt merged <branches>      → one [Y/n] for merged, one force [y/N] for the rest
gwt remove <merged>  /  gwt remove --force <unmerged>
```

The `· merged` tag and ctrl-g select the same rows, `.removable and .merged`:
`removable` is the rule `gwt remove` applies, so the tag marks exactly the reap
set. An unreadable status is dirty in gwt's listing, so it is never tagged or
reaped, and ctrl-x keeps it when gwt cannot snapshot it. Print every refusal
and every recovery ref gwt reports; the ref is the only way back.

## Windows

Kill the selected checkouts' windows before calling gwt, for two reasons. gwt
reads a checkout's commit and dirt one last time just before it snapshots and
moves it; a process still writing there (an agent, a dev server) races that
read, and whatever it writes afterwards goes with the checkout unsnapshotted.
And after the rename a pane's cwd reports the new path and no longer matches.
A checkout gwt then refuses stays, without its windows. Search all sessions,
because a deleted cwd is broken wherever its window lives. The name fallback matches
exactly (`=session:=name`), since a bare tmux target also matches a prefix.

## Freshness

The popup starts `gwt trunk --fetch` in the background at launch and waits for
it only when reap or the branch prompts need a verdict; a failed fetch is
announced, not swallowed. A branch gwt cannot judge counts as unmerged and
goes only behind the force prompt.

## Recovery expiry

gwt's `recovery.keep` (default `30d`, `0` keeps refs) replaced the tmux option
`@worktree_backup_days`, which nothing reads any more. Set it in
`~/.config/gwt/config.toml` under `[recovery]`.

## Verification

`make -C ~/dev/gwt check` owns refusals, snapshots, recovery refs, expiry, the
trash sweep and merge styles. `tests/test-gwt-popup.py` drives the popup end to
end: reap's tag and reap set, unmerged, locked and unprobed work left alone,
the exact-name fallback, declined and accepted dirty removal with its printed
snapshot ref, another session's window killed before gwt runs, and a forced
unmerged branch keeping its tip.
