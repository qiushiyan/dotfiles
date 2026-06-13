# Worktree popup — design notes

`prefix W` opens a single tmux popup that **switches, creates, and removes git
worktrees**. Implemented as `scripts/tmux-worktree.sh`, bound in `tmux.conf`.
This doc is the *why* and the *watch-outs* — the script is the *how*. Don't read
it for syntax; read it before you change behavior.

## Use cases

The workflow this serves:

- **Session = project, window = worktree, pane = tool.** Each repo is a tmux
  session; each worktree is a window named after its branch; inside a window are
  the panes you work in (a coding agent, `pnpm dev`, a scratch shell). The popup
  operates the *window* layer — it creates worktree-windows and moves between
  them.
- **Parallel coding agents without collisions.** Running Claude Code and/or
  Codex on the same repo at once means they fight over files, the branch, and
  the dev server. A worktree gives each its own checkout + branch so they run
  truly in parallel. The popup makes spinning one up a few keystrokes instead of
  a multi-command chore.
- **Worktrees for a git beginner.** `git worktree` has sharp edges (where does
  the folder go? how do I remove it safely? what happens to the branch?). The
  popup encodes the safe path and sane conventions so the rough parts are hidden.

## What it assumes (mental model)

- You invoke it **from inside a repo pane** — the popup runs in
  `#{pane_current_path}` and all git operations are relative to that repo.
- New worktrees land at **`~/dev/.worktrees/<repo>/<branch>`**, uniformly for
  every project (`<repo>` is just the basename of the repo's toplevel — no
  per-repo special-casing).
- It opens worktree windows in the **session you launched from**.

## Design guidelines

1. **One key, one surface.** Switch / create / remove all live in the same fzf
   popup (`enter` / `ctrl-n` / `ctrl-x`). A worktree is one mental object; you
   shouldn't memorize three global bindings. When extending, prefer adding a key
   *inside* the popup over adding a new global binding.
2. **fzf is the selection engine; the typed query is the create-name.** Selection
   (switch/remove) needs a list → fzf. Creation needs free text → we reuse fzf's
   own query (`--print-query`) instead of a second prompt, keeping everything on
   one surface. The cost is the output-parsing contract noted below.
3. **Lean on git's built-in safety, then confirm.** `git worktree remove` already
   refuses a dirty worktree; we surface that and only `--force` after an explicit
   second confirm. Don't reimplement safety git already gives you. Destructive
   actions always confirm; the main worktree is never removable.
4. **The script talks back to tmux via the CLI.** Inside the popup it calls
   `tmux new-window / select-window / kill-window`. The session is **self-detected**
   via `tmux display-message` (NOT passed as an arg — `display-popup` doesn't
   expand `#{...}` in its command, so an arg would arrive literally), and `$PWD`
   is the repo because the binding opens the popup there with `-d`.
5. **Create does only the create.** Make the worktree (branch forked from the
   repo's default branch) and open its window — no post-creation commands (no
   `pnpm install`, no `.env` copy). Keep it that way unless asked.

## Gotchas / watch-outs (read before editing)

- **The fzf output is a 3-line contract.** With `--print-query` + `--expect`, the
  script reads line 1 = typed query, line 2 = pressed key (empty for a plain
  `enter`), line 3 = selected row. Adding/removing either flag — or any other
  flag that adds output lines — shifts these and silently breaks dispatch. If you
  touch the fzf invocation, re-check the parser.
- **The popup stays interactive after fzf exits.** fzf uses `/dev/tty`, returns,
  and the script keeps running on the same terminal — that's why the `read`
  confirmations work. `-E` on `display-popup` closes the popup when the *script*
  exits. Don't background the script or redirect its stdin; you'll lose the
  prompts.
- **The session name is passed explicitly on purpose.** A popup is attached to a
  client, but its notion of "current session" is ambiguous; relying on it for
  `new-window` targeting is fragile. The binding passes `#{session_name}` so
  window creation always lands in the right session. Keep doing this.
- **`-d "#{pane_current_path}"` *and* a `cd` fallback.** The binding sets the
  popup's working dir via `-d`, but the same path is also passed as `$2` and the
  script `cd`s to it. Deliberate belt-and-suspenders in case format expansion in
  `-d` behaves differently across tmux versions/setups. Don't drop the fallback.
- **Repo grouping is just the toplevel basename — no special cases.** A repo
  whose main checkout sits in a `main/` subdir (e.g. `~/dev/planlab/main`) groups
  under `~/dev/.worktrees/main/`. Accepted on purpose (simplicity over a prettier
  folder name); if two such repos ever collide on a branch name, create refuses
  with "path already exists" — no data loss.
- **Window matching is by name (`#W`), with `/`→`-`.** Switch/remove locate a
  worktree's window by its sanitized branch name. Two branches that sanitize to
  the same name (`feat/x` vs `feat-x`) collide on one window. Rare, but the
  branch→window mapping is not guaranteed injective.
- **Slashed branches create nested folders.** `feat/login` →
  `~/dev/.worktrees/<repo>/feat/login`. Git is fine with it, but removal leaves
  the empty `feat/` parent behind. Cosmetic.
- **`display-popup` does NOT expand `#{...}` in its shell-command argument** (only
  in `-d`). Passing `'#{session_name}'` as a script arg delivers the literal text
  `#{session_name}`, and `new-window -t '#{session_name}'` then fails with "can't
  find window". That's why the session is self-detected inside the script.
- **Base branch needs `origin/HEAD`.** The default base is the first of
  `origin/HEAD, origin/main, origin/master, main, master` that resolves. A fresh
  clone without `origin/HEAD` set falls through the chain — if a new worktree
  forks from the wrong base, that chain is the first place to look
  (`git remote set-head origin -a` fixes a missing `origin/HEAD`).
- **Create is intentionally bare** — no `pnpm install`, no `.env` copy, no agent
  launch. If you re-add any post-creation step, prefer doing it visibly in the new
  window (`send-keys`) over blocking the popup, and keep it opt-in.
- **Version + reload mechanics.** Needs tmux 3.2+ (`display-popup`); 3.3+ for
  `-e`. Because the script is stow-symlinked, **edits to it are live
  immediately**, but edits to the **binding** in `tmux.conf` need a config reload
  (`prefix r`).
- **You can't drive the popup headlessly.** The interactive popup needs an
  attached client, so it can't run in CI/sandbox. Test the *pieces* instead: git
  logic + the output parser in throwaway repos, and the binding in a scratch
  server (`tmux -L <socket> source-file …`). That's how this was validated.

## Extension points

- **PR picker** → reuse the create path with a branch checked out from a `gh` PR.
- **Agent-done notifications** → attach to the agent pane *inside* a worktree
  window so the alert can name the worktree (see `../roadmap.md`).
- **Richer preview** → the fzf `--preview` already shows `git status -sb` + recent
  log; a per-worktree ahead/behind or PR-status line slots in there.
