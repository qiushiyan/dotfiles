# tmux: high-value features not yet built

A backlog of tmux improvements we've discussed and agreed are worth building,
with enough notes to pick any one up later. Two buckets: features that **extend
the worktree popup**, and **standalone** one-offs.

Already in place (for context): the **worktree popup** (`prefix W`, see
`scripts/worktree.md`) and **sesh** session switching (`prefix T`). The
"worktree sessionizer" idea from early brainstorming merged into the worktree
popup — it is not a separate item.

---

## A. Builds on the worktree popup

### ✅ Agent-done notifications  (built — Claude wired, Codex pending)

**Status:** the in-tmux UI (window dot + `◷ N` badge) and the Claude Code
`Stop`/`Notification` hooks are implemented and verified — see
`scripts/agent-notify.md`. Still open: wiring **Codex** (its single `notify` slot
in `config.toml` is occupied by the Computer Use app, so adding ours means a
wrapper that calls ours then execs the original — needs a decision before doing).

**What:** be told when a coding-agent pane (Claude Code / Codex) finishes or is
waiting for input, instead of tabbing between panes to check.

**Why:** the #1 friction when running 3–4 agents in parallel — you stop
babysitting and only look when a pane actually wants you.

**Mechanism — two layers:**

- *Universal, heuristic.* tmux `monitor-silence` flags a window when its active
  pane produces no output for N seconds; bridge the flag to a macOS notification
  via `set-hook -g alert-silence '…'` calling `terminal-notifier`/`osascript`
  (or the `tmux-notify` plugin). Works for any long task (builds, tests, agents)
  with zero per-agent setup — but can't distinguish "done" from "paused".
- *Agent-native, precise.* Hook the agent's own completion event:
  - **Claude Code** — a `Stop` hook (agent finished) and `Notification` hook
    (needs attention / waiting) in `settings.json`; each runs a shell command.
  - **Codex** — `notify` in `config.toml`, an external program invoked on
    `agent-turn-complete` with a JSON payload.
  - Different per agent, but exact.

**Ties to worktree:** fires on the agent pane inside a worktree window, so the
alert can name *which* worktree wants attention.

**Effort:** small (universal silence flag) → medium (agent-native hooks + routing
which worktree/window the alert refers to).

### gh PR picker

**What:** a popup listing open PRs (`gh pr list`) with a preview; pick one to open
in the browser or **check it out into a fresh worktree**.

**Why:** you live in git/gh; reviewing a PR is currently several manual commands.

**Mechanism:** fzf popup over `gh pr list`, `--preview 'gh pr view {}'`; on select
either `gh pr view --web` or reuse the worktree create path with the PR's branch.

**Depends on:** the worktree popup (for the checkout action).

**Effort:** small once the worktree popup exists.

---

## B. Standalone one-offs

### Hint copy (tmux-fingers)

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

**Depends on:** nothing.

**Effort:** small (install + config).

### Floating scratch terminal

**What:** one key toggles a *persistent* floating shell (history + cwd preserved)
for quick `git` / `gh` / `ls`; another dismisses it. Your layout never moves.

**Why:** the ad-hoc "5th pane" becomes a popup — less clutter, no layout churn.

**Mechanism:** `display-popup` attached to a dedicated hidden session so it
survives toggles (hand-rolled, ~10 lines, or the `omerxx/tmux-floax` plugin).

**Depends on:** nothing.

**Effort:** tiny.

---

## Notes

- Items in **A** should follow the worktree popup's design guidelines
  (`scripts/worktree.md`): one surface per concept, lean on built-in safety, pass
  tmux context (session, path) in as args rather than inferring it.
- For **B** and any pane-driving automation, `tmux-scripting.md` already documents
  `send-keys` / `capture-pane` / `tmux-wait-for-text`.
