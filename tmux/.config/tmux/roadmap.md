# tmux: features not yet built

A backlog of tmux improvements worth building. Open items follow this route to
the current design and dormant reference docs:

```
scripts/worktree.md      the worktree popup (prefix W) + the gh PR picker
scripts/agent-notify.md  dormant agent-done reference
scripts/float-pane.md    floating zoom and restore
scripts/pane-mode.md     pane mode (prefix p)
workflow.md              how all of it is meant to be used
```

---

## Hint copy (tmux-fingers)

**What:** press a key and every file path / git SHA / URL / `line:col` on screen
gets a letter label; type it to copy. A generalization of the existing `prefix u`
URL picker. (Distinct from `easyjump.tmux` on `prefix s`, which labels matches of
a *typed search string* to move the cursor — flash.nvim-style. Hint-copy labels
*pattern tokens* with no search and is copy-, not navigation-, oriented.)

**Why:** grab paths, SHAs, and error locations out of agent/test output without
the mouse.

**Mechanism:** evaluate the maintained hint-copy plugins when implementing, then
configure match regexes and keys through TPM. Popularity and activity snapshots
are evidence to re-check, not design to cache here.

**Effort:** small (install + config).

## Preserve easyjump syntax colour

**What:** keep captured ANSI foreground colours while dimming the easyjump
backdrop. The current overlay intentionally repaints it as one grey.

**Design constraint:** labels and the current match must retain fixed contrast
on both light and dark themes. Parse `capture-pane -e`; transform foregrounds;
leave label, match, and current attributes owned by `scripts/easyjump/easyjump.py`.

**Effort:** medium; ANSI state and wide-character offsets need focused tests.

## Persistent floating scratch terminal

**What:** one key toggles a *persistent* floating shell (history + cwd preserved)
for quick `git` / `gh` / `ls`; another dismisses it. Your layout never moves.

**What already covers part of it:** the **ephemeral** scratch popup shipped as
`prefix Z` (`scripts/float-pane.md`, "The scratch popup") — a disposable
shell at the current pane's cwd, gone on exit. tmux 3.7's native floating panes
(`prefix *` → `new-pane`) also give a non-modal floating shell. What neither
gives is **persistence** across toggles, which was the point of the original
item — this entry is now only that remainder.

**Mechanism:** point the shipped scratch presentation at a persistent scratch
session (a nested attach) instead of a fresh shell. Share only the presentation
— the holder state machine exists to relocate a tiled pane and restore a source
layout, and a scratch terminal has neither. NB: a persistent session brings
back naming and idle-GC questions the ephemeral variant deliberately avoids,
and a nested attach means the key-table staging questions too — decide before
building.

**Effort:** small.

---

## Notes

- Items that extend the worktree popup should follow its design guidelines
  (`scripts/worktree.md`): one surface per concept and built-in safety first.
  `display-popup -d` supplies the repo path; the script self-detects the session
  because formats do not expand in the popup command argument.
- For pane-driving automation, `tmux-scripting.md` documents `send-keys` /
  `capture-pane` / `tmux-wait-for-text`.
