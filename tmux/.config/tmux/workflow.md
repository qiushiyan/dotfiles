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
- **`prefix $`** renames the session you're in — do it right after creating an ad-hoc one, so it's findable in `prefix T` later.

At the end of the day, **`prefix d`** detaches — every pane keeps running in the background. Reopen the terminal (or `tmux attach`) and it's exactly as you left it: dev servers still up, agents intact. Done with a project entirely? **`prefix Q`** kills every *other* session, leaving just this one.

## Keeping things findable (renaming)

The picker and status bar are only as useful as your names.

- **`prefix m`** renames the **current window**.
- **`prefix M`** renames the **current pane** in a **popup text field** — same rounded frame as the worktree popup, at eye level instead of down in the status line. Type whatever you want; the label is taken verbatim, and the field starts prefilled with your existing label when the pane has one. `Enter` applies, **`Esc` cancels**, and submitting it **empty** (`C-u` wipes the line) resets the pane. Naming a pane shows the label on its **border** and turns the border on for that window; clearing hands the decision to the reconciler, which keeps the row only while some pane in the window still needs it (another label, or a Claude context chip). Naming also **freezes** the title against the program inside the pane — Claude Code otherwise repaints `✳ …` over your label every render — and clearing hands the title back to the app.
- **`prefix $`** renames the **current session** (tmux's built-in). Do it when a session's default name (`0`, `1`) is meaningless, so `prefix T` reads well — but it's once per session, which is why the custom key went to panes instead.
- For a pane *other* than the current one, use the command prompt: **`prefix :`** then **`rename-pane "label"`** / **`unname-pane`**, which tab-complete like native commands.

The worktree popup names windows after their branch automatically; rename ad-hoc windows (`prefix m`) so browsing with `prefix C-h`/`C-l` makes sense.

## The Claude context chip

A pane running Claude Code shows the session's **account**, that account's **two quota numbers**, the **model** and the session's **context usage** on the **top-right of its border** (`yan 5h:23 Fable:15 opus-5[1m] ✳ 37%`), the context percentage green → yellow (≥50%) → red (≥90%) and everything else muted beside it, independent of whatever title sits top-left. The order is by **scope**: the account and its quotas on the left, the model and the context percentage — this session's own facts — on the right, with the model between them so three numbers never run together.

The model is the id Claude Code reports with its `claude-` prefix dropped — `fable-5`, `opus-5[1m]` — otherwise unprettified, and it tracks a mid-session `/model` switch. The account is which quota lane the session burns (docs/claude-accounts.md): the email local part (the full email when two accounts share one), drawn for **every** lane — an extra is named by the `~/.claude-accounts/` dir in the env headroom built at launch, the primary by the email in `~/.claude.json`, since it launches with no such dir and was otherwise the one account the chip stayed silent about.

**The two quota numbers** are `5h:NN`, the account's 5-hour limit, and `Fable:NN`, its **model-scoped weekly** — no `%` on either, which keeps them distinct from the context percentage. They colour on their own values: muted below 50, yellow from 50, red from 90, so an untroubled border stays untroubled and colour there only ever means "look at this one". The 5-hour figure is free — Claude Code puts it in the payload it hands the statusline on every render. The weekly is not: the payload carries only the *all-models* weekly, which routinely sits far below the scoped one that actually stops work (94% against 54% on one lane the day this shipped), so the scoped figure comes from **headroom** — `claude-quota-refresh.sh`, spawned detached by the statusline when its last attempt has aged past five minutes and no sibling pane holds the lock, leaves it in `~/.cache/claude-ctx/<lane>.quota` for the render path to read with a single shell builtin. Nothing on the render path ever waits for it.

An old weekly reading is still drawn, on purpose: **inside a live window usage only climbs**, so an aged figure understates and is safe. Once its window has *rolled over* the same figure describes a window nobody is spending against — a low number there would read as headroom that may not exist — so it disappears instead, as it does when the refresher could not read a trustworthy number at all. The chip never shows a `0` it isn't sure of.

The chip is **responsive**: as the pane narrows it sheds by priority — the account below 55 columns, the model below 40, the context percentage never. The quota pair goes **first**, below 75, because it is the only part of the chip that is redundant across panes (three panes on one lane draw the same two numbers three times). It is also the only part that can turn urgent, so severity buys it back: a number at ≥50 survives to 40 columns and one at ≥85 draws at any width, each judged on its own value — so a Fable at 94 rides down to a sliver while a calm 5-hour drops out from under it. Widths are tuned to a 221-column client: a half-split (~110) and a third (~73) keep the full chip, a quarter (~55) drops the quota unless it is hot. Pure display — nothing is republished on the way back up.

Claude's statusline script derives all of it on every render and republishes the pane-local options (`@claude_ctx`, `@claude_ctx_model`, `@claude_ctx_account`, `@claude_ctx_5h`, `@claude_ctx_wk`, `@claude_ctx_wk_model`) only when one of them changed; the context percentage alone decides whether the chip exists, so a session that reports no model, or no rate limits at all (API billing), just shows the number. The border row appears when a Claude session goes live in the window and drops when nothing needs it anymore (session ends, pane closes, labels cleared). Cleanup is belt-and-suspenders — Claude's `SessionEnd` hook for normal exits, a zsh `precmd` sweep for hard kills (a `C-z`-suspended claude keeps its chip), a `pane-exited` hook for closed panes, and the break/join/move verbs reconciling after a pane relocation — all funneling through `tmux-claude-ctx.sh`, the single owner of turning borders off. A per-pane tombstone keeps a dying session's last in-flight render from resurrecting a chip that cleanup just removed; it holds only until the same conversation legitimately starts again — resuming keeps the session id, and the `SessionStart` hook discharges the tombstone — so a same-pane resume gets its chip back. Mechanics and format gotchas: the "pane borders" block in `tmux.conf`.

## Starting a new task on its own branch (worktrees)

You want to work on a feature without disturbing `main` or another agent — give it an isolated checkout.

- **`prefix W`** opens the worktree popup for the current repo (`»` marks the one you're in, `*` marks dirty; preview shows each one's git status + recent commits, `ctrl-d`/`ctrl-u` scrolls it).
- Type a branch name and press **`ctrl-n`** → it creates `~/dev/.worktrees/<repo>/<branch>`, opens a window named after the branch, seeds gitignored files (`.env*` …) from the main worktree, and runs the Node install (by lockfile) chained with the post-create command — default `x`, so the agent is already starting when you land. (`@worktree_auto_install off` / `@worktree_post_create_cmd off` to disable.)
- Press **`enter`** on a listed worktree to jump to its window (created if it doesn't exist yet).
- Mark several with **`tab`** (or all with **`ctrl-a`**) and press **`ctrl-x`** to remove them as one confirmed batch — deletion is instant (trash-and-sweep: the `rm -rf` happens in the background), dirty ones need an extra explicit discard, and branch deletion is offered in aggregate.
- Press **`ctrl-g`** to *reap*: batch-remove every clean worktree already merged into the default base — end-of-week cleanup in three keystrokes. (Squash-merged branches don't count as merged; remove those with `ctrl-x`.)
- Press **`ctrl-p`** to pick an open GitHub PR and check it out into a fresh worktree (`ctrl-o` opens it in the browser instead).

One worktree per window keeps parallel agents from stepping on each other. (See `scripts/worktree.md` for the design.)

## Organizing a project's windows (windows = tabs)

Within a project you'll have a few windows — worktrees, a notes window, a long-running process.

- **Create:** `prefix c` (at the end) or **`prefix N`** (right after the current one).
- **Move:** `prefix C-h` / `prefix C-l` for previous/next, **`prefix Tab`** for the last window, **`prefix 1`–`9`** to jump straight to one by number.
- **Reorder:** `Shift-Left` / `Shift-Right` (no prefix) slide the current window left/right.
- **Rename:** `prefix m`. **Close:** `prefix x` (asks to confirm — it's a whole task).

When the terminal narrows past `@window_collapse_width` (default 80 cols), inactive tabs **collapse to just their number badge** so a row of worktrees stops crowding the bar; the current window keeps its full name, and a waiting agent's badge still shows (yellow instead of aqua). They expand again as you widen — it's live, no reload. Tune with `tmux set -g @window_collapse_width <cols>` (`0` disables).

## Seeing tools side by side (panes = splits)

A typical task window: agent on one side, dev server on the other, a scratch shell below.

- **Split:** **`prefix |`** side by side, **`prefix -`** stacked — both open in the current pane's directory.
- **Move between panes:** `prefix h/j/k/l`, or **`Ctrl+h/j/k/l` with no prefix** (these also hop in and out of Neovim splits seamlessly).
- **Focus one:** **`prefix z`** maximizes the pane into a **floating overlay** — the rest of the window stays visible *and live* behind it, so a build or another agent keeps scrolling while you read. `prefix z` again puts it back exactly where it was. (Stock fullscreen zoom moved to `prefix C-z`.)
- **Quick shell:** **`prefix Z`** pops up a **throwaway shell at the current pane's directory** — check `git status` or an `ls` next to a running agent without splitting a pane off. `C-d` closes and disposes of it; it's smaller than the float and rounded-bordered so the two never look alike (in a float, `C-d` would kill your real process).
- **Rearrange:** **`prefix p`** — see below. **Close:** just exit its shell (`C-d`); `prefix X` force-kills a stuck pane.

### Rearranging panes (`prefix p`)

One key instead of five you can't remember. `prefix p` enters a **sticky** mode
— it stays until you leave, so you nudge, look, nudge again — and the row under
the status bar turns into the cheat sheet while you're in it. Any unbound key
drops you out, so you can't get stuck.

The one rule for `h/j/k/l`: **push the pane that way — if something's there,
trade places; if nothing is, become the wall.** So in a stacked split, `l` on
the bottom pane makes it the full-height right-hand column; side by side, `h`
on the right pane swaps the two. Same key, both behaviours, nothing to
remember.

| In pane mode | |
|--|--|
| `h/j/k/l` | push the pane (swap, or move to that edge) |
| `H/J/K/L` | resize · arrow keys move the *cursor* between panes |
| `m` / `M` | mark a pane / move this pane to the mark — works across windows and sessions |
| `u` | undo the last push · `e` spread evenly · `Space` toggle row/column |
| `z` | float it · `b` break it into its own window |
| `Esc` | done |

**Inside a float** only `prefix z` (close) and `prefix d` work — the rest of the
prefix keys are deliberately switched off so a stray `prefix x` can't kill
something behind the overlay.

Design notes and failure handling: `scripts/float-pane.md`.

## Knowing when a background agent is done (agent-done dots)

You've got several Claude/Codex agents running in windows you're not watching.

- When an agent **finishes or wants input** in a background window, a soft **yellow dot** appears on that window's chip and a **`◷ N`** badge in the top-right corner counts how many windows are waiting on you.
- Switch to the window (`prefix C-h`/`C-l`/`Tab`, or the worktree popup) and its dot clears; the badge ticks down.

It's an ambient "unread" badge, not an interrupt — glance at the bar, triage, move on. (Driven by Claude Code's hooks; see `scripts/agent-notify.md`.)

## Reading back & copying output (copy mode)

- Enter with **`prefix [`**; leave with `q` or a quick **double-`Esc`** (a single `Esc` won't exit — see below).
- Scroll: `C-u`/`C-d` (10 lines), `j`/`k` (one line), `gg`/`G` (top/bottom), `/` to search forward.
- Select + copy: `v` start selection, `C-v` rectangle, `H`/`L` to line start/end, `y` to copy and exit.
- Botched a selection? Tap **`Esc`** once — it clears the selection but *stays* in copy mode at the same scroll spot, so you just re-`v`. A lone `Esc` never tears down copy mode and dumps you at the bottom the way stock tmux does. To actually exit via `Esc`, double-tap it within ~0.4s (tunable: the `sleep 0.4` on the binding in `tmux.conf`), since tmux has no native double-tap — the first press arms a flag a background timer clears.

## Browsing past copies (`prefix =`)

Copy-mode `y` puts text in a **tmux paste buffer**, not the macOS clipboard (`set-clipboard` is `external`, so tmux never emits its own OSC 52 — that's why `prefix y` shells out to `pbcopy`). Those buffers stack up to 50 deep, so the last 50 things you copied are all still there — `prefix ]` only ever gives back the newest one.

**`prefix =`** opens the full stack as a zoomed, searchable list:

- **`Enter`** — paste the selected buffer into the current pane.
- **`/`** — search by name *or content*, so you can find a copy by a phrase inside it; `n`/`N` step through matches. (`C-s` does the same, and `f` filters by format instead.)
- **`d`** — delete the selected buffer. Stock tmux's `prefix -` no longer does this; that key is a stacked split here.
- **`e`** — open the buffer in `$EDITOR`. Useful for trimming a long agent response down before pasting it somewhere.
- **`v`** — toggle the preview pane, for when one line of each buffer isn't enough to tell them apart.
- **`q`** — exit.

`prefix #` also lists buffers, but as read-only output you can't act on — `prefix =` is the one worth remembering.

## Jumping to a string on screen (flash-style)

When you can *see* the word you want — a path, a SHA, a function name — `prefix s` gets the cursor there without scrolling or stepping through `/` matches.

- **`prefix s`** dims the pane; start typing the target and every match gets a letter label *live as you type*. Press a label to jump the copy-mode cursor onto that match (it starts a selection, so `y` copies). The nearest match is tinted differently and is also reachable with **`Enter`**. Type more to narrow; **`Esc`** cancels. If your typing leaves a single match, it jumps automatically.
- **`C-s`** does the same from *inside* copy mode, so it composes with `prefix [`.

A vendored, flash.nvim-style tool in `scripts/easyjump/` (see its `DESIGN.md`) — distinct from `prefix u`, which only grabs URLs.

## Quick helpers

- **`prefix u`** — fuzzy-pick any URL from the visible scrollback and open it in the browser. (`Shift+Ctrl+click` opens one directly, bypassing tmux's mouse.)
- **`prefix y`** — copy "this pane's path" to the clipboard: when the pane is running Neovim, the **absolute path of the focused file**; otherwise the pane's **working directory** (read from the foreground process, so it's right even mid-session inside an agent or build — no need to interrupt what's running). **`prefix Y`** is the same but copies the file path **relative to nvim's cwd**. Neovim publishes the paths into pane-scoped `@yank_path`/`@yank_path_rel` options (the `TmuxYankPath` block in nvim's `autocmds.lua`) and withdraws them when the focused buffer isn't a copyable file — dashboards, pickers, terminals, `.git/` edit files, Claude's Ctrl+G prompt files all fall back to the cwd. Over SSH it copies the local path, not the remote one.
- **`prefix g`** — open this pane's repo on **GitHub**: the PR thread when the branch has one, otherwise the branch's file tree (a detached HEAD opens its commit). Same resolution as the `gopen` shell command, and read from the same live cwd `prefix y`'s fallback uses — so a pane sitting in a worktree opens *that* worktree's branch, and it works without interrupting whatever is running in the pane. On a branch GitHub has never seen it asks first, then pushes `-u` and opens the PR-create page.
- **`prefix b`** — **dev-server preview**: prompts for a URL (pre-filled `localhost:3000`; a bare port works) and opens it in a [terminal-browser](https://github.com/zenbu-labs/terminal-browser) pane — real Chromium rendered pixel-accurately in the terminal via the kitty graphics protocol. First press opens a split to the right; pressing again while that browser is open adds the URL as a *tab* in it rather than another split. Close it like any pane, or `terminal-browser shutdown` to kill the shared browser process.
- **`prefix t`** — **theme picker**: pick a terminal theme and it switches everywhere at once — shell colors, prompt, this status bar, and Neovim (Ghostty needs a manual `⌘⇧,` reload on macOS). See `docs/theming.md`.
- **`Ctrl+L`** — clear the screen like normal; if there's a pane to the right with nothing to clear, it jumps there instead. **`prefix C-k`** clears the screen *and* wipes scrollback.
- **`prefix r`** — reload the tmux config after editing it.

## Surviving reboots (resurrect + continuum)

Sessions, windows, panes, and layout auto-save every ~15 min and auto-restore when the tmux server starts — so a reboot doesn't lose your workspace. Manual control: **`prefix C-s`** to save now, **`prefix C-r`** to restore.

Saves go through a small wrapper that first puts any floated pane (`prefix z`) back in its window — a snapshot taken mid-float couldn't be reconnected on restore, since the pane and the window it belongs to would be saved as unrelated things.

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

**Rename** — window `prefix m` · pane `prefix M` popup (`Enter` apply · empty = clear · `Esc` cancel) · session `prefix $`

**Close / remove** — window `prefix x` (confirms) · pane `prefix X` or `C-d` · other sessions `prefix Q` · worktree `prefix W` → `ctrl-x`

**Reorder** — windows `Shift-Left`/`Shift-Right` · panes: float `prefix z` · scratch shell `prefix Z` (stock zoom `prefix C-z`), everything else in **`prefix p`** pane mode (table above)

**Copy mode** — enter `prefix [` · `v` select · `C-v` rectangle · `y` copy · `/` search · `gg`/`G` top/bottom · `Esc` clear selection (stays in copy mode) · `q` or double-`Esc` exit

**Paste buffers** — browse `prefix =` · `Enter` paste · `/` search name/content · `d` delete · `e` edit · `v` preview · `q` exit · newest only `prefix ]`

**Jump (flash-style)** — `prefix s` (or `C-s` in copy mode) → type to search · label to jump · `Enter` nearest · `Esc` cancel

**Misc** — detach `prefix d` · reload `prefix r` · theme picker `prefix t` · clear `Ctrl+L` / `prefix C-k` · URL picker `prefix u` · browser preview `prefix b` · copy path `prefix y`/`Y` · open repo on GitHub `prefix g` · save/restore `prefix C-s`/`prefix C-r`

**From outside tmux**

```bash
tmux ls                        # list sessions
tmux attach -t <name>          # attach to a session
tmux new -s <name>             # new named session
tmux kill-session -t <name>    # kill one session
```
