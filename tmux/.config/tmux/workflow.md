# tmux workflow guide

How this setup is meant to be *used*, organized around everyday scenarios rather
than a wall of keys. A grouped cheat sheet lives at the very bottom for quick
lookup once the workflows are familiar.

**Prefix = `C-a`** (or `C-b`). "`prefix X`" means press the prefix, release, then `X`.

## The mental model (read this first)

Everything is three nested levels, and most of what you do is moving between them:

- **Session = a project.** It survives closing the terminal; you attach/detach to it.
- **Window = a task within the project** (often one git worktree). Like a tab — you see one at a time; the status bar lists them.
- **Pane = a tool inside the task** — a coding agent, a `pnpm dev` server, a scratch shell — all visible at once via splits.

So: *which project?* → session. *which task/branch?* → window. *which tool?* → pane.

---

## Sitting down: jump into a project (sessions)

You open the terminal and want to get into something.

- **`prefix T`** opens the **sesh** picker — fuzzy-find a project, recent dir, or config and jump straight in (creating the session if needed). Inside the picker: `C-a` all · `C-t` tmux sessions · `C-g` configs · `C-x` zoxide dirs · `C-f` find dirs under `~` · `C-d` kill the highlighted session · `Tab`/`S-Tab` move.
- **`prefix BTab`** flips to the **last session** — the fast toggle between, say, work and a personal project.
- **`prefix C-f`** jumps to a session by name; **`prefix C-c`** starts a fresh empty one.

At the end of the day, **`prefix d`** detaches — every pane keeps running in the background. Reopen the terminal (or `tmux attach`) and it's exactly as you left it: dev servers still up, agents intact. Done with a project entirely? **`prefix Q`** kills every *other* session, leaving just this one.

## Keeping things findable (renaming)

The picker and status bar are only as useful as your names.

- **`prefix M`** renames the **current session** — do this when a session's default name (`0`, `1`) is meaningless, so `prefix T` reads well.
- **`prefix m`** renames the **current window**.

The worktree popup names windows after their branch automatically; rename ad-hoc windows (`prefix m`) so browsing with `prefix C-h`/`C-l` makes sense.

## Starting a new task on its own branch (worktrees)

You want to work on a feature without disturbing `main` or another agent — give it an isolated checkout.

- **`prefix W`** opens the worktree popup for the current repo (preview shows each one's git status + recent commits).
- Type a branch name and press **`ctrl-n`** → it creates `~/dev/.worktrees/<repo>/<branch>`, opens a window named after the branch, and drops you in. That's all it does — no install or setup commands.
- Press **`enter`** on a listed worktree to jump to its window (created if it doesn't exist yet).
- Press **`ctrl-x`** to remove a finished worktree — it refuses if the worktree is dirty (offers `--force`), and can delete the branch too.

One worktree per window keeps parallel agents from stepping on each other. (See `scripts/worktree.md` for the design.)

## Organizing a project's windows (windows = tabs)

Within a project you'll have a few windows — worktrees, a notes window, a long-running process.

- **Create:** `prefix c` (at the end) or **`prefix N`** (right after the current one).
- **Move:** `prefix C-h` / `prefix C-l` for previous/next, **`prefix Tab`** for the last window, **`prefix 1`–`9`** to jump straight to one by number.
- **Reorder:** `Shift-Left` / `Shift-Right` (no prefix) slide the current window left/right.
- **Rename:** `prefix m`. **Close:** `prefix x` (asks to confirm — it's a whole task).

## Seeing tools side by side (panes = splits)

A typical task window: agent on one side, dev server on the other, a scratch shell below.

- **Split:** **`prefix |`** side by side, **`prefix -`** stacked — both open in the current pane's directory.
- **Move between panes:** `prefix h/j/k/l`, or **`Ctrl+h/j/k/l` with no prefix** (these also hop in and out of Neovim splits seamlessly).
- **Focus one:** **`prefix z`** zooms the current pane fullscreen; `prefix z` again restores the layout.
- **Resize:** `prefix H/J/K/L`. **Swap:** `prefix >` / `prefix <`.
- **Reshape:** `prefix !` breaks a pane out into its own (hidden) window; `prefix @` joins that hidden pane back. **Close:** just exit its shell (`C-d`); `prefix X` force-kills a stuck pane.

## Knowing when a background agent is done (agent-done dots)

You've got several Claude/Codex agents running in windows you're not watching.

- When an agent **finishes or wants input** in a background window, a soft **yellow dot** appears on that window's chip and a **`◷ N`** badge in the top-right corner counts how many windows are waiting on you.
- Switch to the window (`prefix C-h`/`C-l`/`Tab`, or the worktree popup) and its dot clears; the badge ticks down.

It's an ambient "unread" badge, not an interrupt — glance at the bar, triage, move on. (Driven by Claude Code's hooks; see `scripts/agent-notify.md`.)

## Reading back & copying output (copy mode)

- Enter with **`prefix [`** (leave with `q` or `Esc`).
- Scroll: `C-u`/`C-d` (10 lines), `j`/`k` (one line), `gg`/`G` (top/bottom), `/` to search forward.
- Select + copy: `v` start selection, `C-v` rectangle, `H`/`L` to line start/end, `y` to copy and exit.

## Quick helpers

- **`prefix u`** — fuzzy-pick any URL from the visible scrollback and open it in the browser. (`Shift+Ctrl+click` opens one directly, bypassing tmux's mouse.)
- **`prefix t`** — **theme picker**: pick a terminal theme and it switches everywhere at once — shell colors, prompt, this status bar, and Neovim (Ghostty needs a manual `⌘⇧,` reload on macOS). See `docs/theming.md`.
- **`Ctrl+L`** — clear the screen like normal; if there's a pane to the right with nothing to clear, it jumps there instead. **`prefix C-k`** clears the screen *and* wipes scrollback.
- **`prefix r`** — reload the tmux config after editing it.

## Surviving reboots (resurrect + continuum)

Sessions, windows, panes, and layout auto-save every ~15 min and auto-restore when the tmux server starts — so a reboot doesn't lose your workspace. Manual control: **`prefix C-s`** to save now, **`prefix C-r`** to restore.

---

## Cheat sheet (by operation)

**Switch / navigate**

| | Key |
|--|--|
| project (session) | `prefix T` picker · `prefix BTab` last · `prefix C-f` by name |
| window | `prefix C-h`/`C-l` prev/next · `prefix Tab` last · `prefix 1`–`9` by number |
| pane | `prefix h/j/k/l` · `Ctrl+h/j/k/l` (no prefix, vim-aware) |

**Create**

| | Key |
|--|--|
| session | `prefix C-c` |
| window | `prefix c` (end) · `prefix N` (after current) |
| split | `prefix \|` side-by-side · `prefix -` stacked |
| worktree | `prefix W` → type name → `ctrl-n` |

**Rename** — session `prefix M` · window `prefix m`

**Close / remove** — window `prefix x` (confirms) · pane `prefix X` or `C-d` · other sessions `prefix Q` · worktree `prefix W` → `ctrl-x` · break/join pane `prefix !` / `prefix @`

**Reorder / resize / zoom** — windows `Shift-Left`/`Shift-Right` · panes `prefix >`/`prefix <` · resize `prefix H/J/K/L` · zoom `prefix z`

**Copy mode** — enter `prefix [` · `v` select · `C-v` rectangle · `y` copy · `/` search · `gg`/`G` top/bottom

**Misc** — detach `prefix d` · reload `prefix r` · theme picker `prefix t` · clear `Ctrl+L` / `prefix C-k` · URL picker `prefix u` · save/restore `prefix C-s`/`prefix C-r`

**From outside tmux**

```bash
tmux ls                        # list sessions
tmux attach -t <name>          # attach to a session
tmux new -s <name>             # new named session
tmux kill-session -t <name>    # kill one session
```
