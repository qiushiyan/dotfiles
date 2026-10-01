# tmux: features not yet built

A backlog of tmux improvements worth building. The current design starts at
`workflow.md`, whose sections name each feature's design doc.

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

**Gap:** `prefix Z` (`scripts/float-pane.md` § The scratch popup) and tmux
3.7's native floating panes (`prefix *`) both give a floating shell; neither
keeps history and cwd across toggles.

**Mechanism:** point the scratch presentation at a persistent scratch
session (a nested attach) instead of a fresh shell, sharing only the
presentation (`scripts/float-pane.md` § The container adapter). NB: a
persistent session brings back naming and idle-GC questions the ephemeral
variant deliberately avoids, and a nested attach means the key-table staging
questions too — decide before building.

**Effort:** small.

---

## Notes

- Items that extend the worktree popup should follow its design guidelines
  (`scripts/worktree.md`): one surface per concept and built-in safety first.
- For pane-driving automation, `tmux-scripting.md` documents `send-keys` /
  `capture-pane` / `tmux-wait-for-text`.
