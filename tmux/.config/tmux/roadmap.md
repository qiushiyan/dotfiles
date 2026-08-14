# tmux: features not yet built

A backlog of tmux improvements worth building, with enough notes to pick any one
up later. Shipped items live in the docs that own them, not here — this file is
only what is still open:

```
scripts/worktree.md      the worktree popup (prefix W) + the gh PR picker
scripts/agent-notify.md  agent-done dots and the ◷ badge
scripts/float-pane.md    floating zoom (prefix z) + pane mode (prefix p)
workflow.md              how all of it is meant to be used
```

---

## Codex agent-done wiring

**What:** the agent-done dot and `◷ N` badge fire for Claude Code but not Codex,
so a Codex pane finishing goes unnoticed.

**Why it is still open:** Codex has a single `notify` slot in `config.toml` and
it is already occupied by the Computer Use app. Wiring ours means a wrapper that
calls ours then execs the original — that needs a decision before doing, not just
implementation time.

**Mechanism:** Codex invokes `notify` on `agent-turn-complete` with a JSON
payload; the receiving end already exists (`scripts/tmux-agent-done.sh`).

**Effort:** small, once the wrapper question is settled.

## Hint copy (tmux-fingers)

**What:** press a key and every file path / git SHA / URL / `line:col` on screen
gets a letter label; type it to copy. A generalization of the existing `prefix u`
URL picker. (Distinct from `easyjump.tmux` on `prefix s`, which labels matches of
a *typed search string* to move the cursor — flash.nvim-style. Hint-copy labels
*pattern tokens* with no search and is copy-, not navigation-, oriented.)

**Why:** grab paths, SHAs, and error locations out of agent/test output without
the mouse.

**Mechanism:** install `Morantron/tmux-fingers` (Crystal) via TPM; configure match
regexes and keys. (Chosen over the once-default `fcsonline/tmux-thumbs`: as of
2026-06 fingers leads on stars (1.4k vs 1.1k), was updated this month vs ~2yr
stale, and carries 8 open issues vs 48 — the "thumbs = the modern Rust rewrite"
framing has inverted.)

**Effort:** small (install + config).

## Persistent floating scratch terminal

**What:** one key toggles a *persistent* floating shell (history + cwd preserved)
for quick `git` / `gh` / `ls`; another dismisses it. Your layout never moves.

**What already covers part of it:** the **ephemeral** scratch popup shipped as
`prefix C-z` (`scripts/float-pane.md`, "The scratch popup") — a disposable
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
  (`scripts/worktree.md`): one surface per concept, lean on built-in safety, pass
  tmux context (session, path) in as args rather than inferring it.
- For pane-driving automation, `tmux-scripting.md` documents `send-keys` /
  `capture-pane` / `tmux-wait-for-text`.
