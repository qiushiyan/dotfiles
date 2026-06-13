# Agent-done notifications — design notes

An ambient, in-tmux signal for "a coding agent finished / wants you", tuned for
running several agents at once. **Not** a system notification (too aggressive at
scale) — a status badge you glance at:

- a **`#{@thm_yellow}` dot** on a window's status chip when its agent is done, and
- a **`◷ N` counter** in `status-right` = how many windows in this session are
  waiting on you.

The dot clears when you switch to that window; the counter follows.

## Pieces

| Piece | Where | Role |
|-------|-------|------|
| `@agent_done` | per-window option | the flag; drives the dot (`#{?@agent_done,…}` in `@catppuccin_window_text`) |
| `@agents_ready` | per-session option | the count; drives the `◷ N` badge in `status-right` |
| `tmux-agent-done.sh` | scripts/ | **setter** — agent hook calls it; flags the agent's window |
| `tmux-agent-recount.sh` | scripts/ | **counter** — recomputes `@agents_ready` for every session |
| nav bindings | `tmux.conf` | **clear** — `prefix C-h/C-l/Tab` clear the dot on the window you land on |
| worktree popup | `tmux-worktree.sh` | clears the dot when it switches you to a worktree window |
| Claude `Stop`/`Notification` hooks | `claude/.claude/settings.json` | fire the setter when Claude finishes / wants input |

## The load-bearing idea (read this before changing the clear logic)

**Only the client that pressed the key knows which window you just navigated to.**
This single fact dictates the whole shape:

- The **clear is done inline in the keybinding** (`… \; set -w @agent_done 0 \; …`).
  A keybinding runs in the pressing-client's context, *after* the nav command, so
  the inline `set -w` targets the window you actually landed on.
- The **count is a separate, window-agnostic `run-shell`** (`recount.sh`). It never
  asks "what's the current window" — it just counts flagged windows per session —
  so it runs correctly from anywhere (hook, binding, background).

Conflating those two was the original bug: a `run-shell` child was used to *detect*
the current window, which it cannot do.

## Gotchas / things that cost real time (don't relearn these)

- **A `session-window-changed` hook sees the OLD window.** Inside that hook tmux's
  "current window" is still the one you left, so an inline clear lands on the wrong
  window and a child's `display-message '#{window_id}'` is equally wrong. This is
  why clearing is in the *bindings*, not a hook.
- **`run-shell` children have no client context.** They can't know the current
  window; they connect to the server fresh. Only use them for context-free work
  (the count). That's why `recount.sh` loops *all* sessions instead of taking a
  "current session" — no context to trust.
- **`run-shell` from a hook is hostile to tmux callbacks.** A bare script path with
  `-b` silently doesn't run; without `-b` a script that calls back into `tmux`
  deadlocks the server. Avoided entirely by not clearing from a hook.
- **The dot must use single-hash formats.** catppuccin does NOT pre-expand
  `@catppuccin_window_text` at load (unlike the *separators*, which need `##{…}`),
  so `#{?@agent_done,…}` and `#{@thm_yellow}` are correct as single-hash and expand
  per-window at draw time. The dot resets fg to `@thm_crust` (the chip's text color
  set by the separators), not `default`.
- **You can't test relative nav on a detached server.** `next-window`/`previous`/
  `last-window` need an attached client to have a "current window"; detached they
  no-op and any clear misses. Verify with an attached client (`script -q /dev/null
  tmux attach …`) — detached tests will lie to you here.
- **The setter skips windows you're already watching** (`#{&&:window_active,
  session_attached}`), so an agent finishing on-screen doesn't leave a stuck dot.
- **The Stop hook must exit 0 and stay fast.** A non-zero Stop hook blocks Claude
  from stopping; `done.sh` always `exit 0` and no-ops instantly outside tmux.

## Coverage / known gaps

- Covered nav: `prefix C-h` / `C-l` / `Tab`, and the worktree popup. Prefix
  *number* keys (`prefix 1`–`9`) are not wired to clear — a dot reached that way
  persists until the next C-h/C-l/Tab. (Not in daily use per workflow.md.)
- **Codex is not wired yet.** Codex's single `notify` slot in `config.toml` is
  already used by the Computer Use app; adding ours means wrapping that program
  (call ours, then exec the original). Pending a decision — see `../roadmap.md`.
- Universal fallback (tmux `monitor-silence`) is intentionally not used: it's
  heuristic and would dot any quiet pane. The agent-native hooks are precise.
