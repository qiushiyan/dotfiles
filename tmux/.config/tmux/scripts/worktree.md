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
   - **`enter` switches *or* creates.** It accepts the highlighted row, but if the
     typed query matched **nothing** (fzf returns exit 1 with an empty selection
     but still echoes the query), `enter` falls through to create-from-query — so
     typing a brand-new name and pressing enter Just Works. We deliberately do
     *not* override fzf's highlight: when the query still fuzzy-matches an existing
     worktree (e.g. `min` matches `main`), `enter` switches to that match and
     `ctrl-n` is the **force-create** escape hatch that ignores the highlight.
     This keeps `enter` predictable — it always honors what's visibly selected.
3. **Switch/create exit, remove loops.** The pick-and-dispatch runs in a `while`
   loop. `switch` and `create` are *terminal* (you want to land in that window, so
   they `exit` and the `-E` popup closes). `remove` (`ctrl-x`) is an *in-popup*
   operation — it returns to a **refreshed** list (the just-removed entry gone) so
   you can remove more or pick again, rather than ejecting you on every delete. A
   *failed* create also loops back (showing its error) instead of closing, which
   is why `create_worktree` returns a real 0/1 status the dispatcher branches on.
   `esc`/`ctrl-c` (fzf exit 130) is the only thing that breaks the loop from the
   list — keep that escape hatch intact or the popup becomes a trap.
4. **Lean on git's built-in safety, then confirm.** `git worktree remove` already
   refuses a dirty worktree; we surface that and only `--force` after an explicit
   second confirm. Don't reimplement safety git already gives you. Destructive
   actions always confirm; the main worktree is never removable.
5. **The script talks back to tmux via the CLI.** Inside the popup it calls
   `tmux new-window / select-window / kill-window`. The session is **self-detected**
   via `tmux display-message` (NOT passed as an arg — `display-popup` doesn't
   expand `#{...}` in its command, so an arg would arrive literally), and `$PWD`
   is the repo because the binding opens the popup there with `-d`.
6. **Post-creation work runs in the new window, never in the popup.** Create
   makes the worktree (branch forked from the repo's default branch), opens its
   window, and — for a Node project — kicks off a dependency install. The install
   is sent into the **new window** with `send-keys` (targeted by `#{window_id}`,
   not name), so it runs *visibly* where you land and you can `Ctrl-C` it; it does
   **not** run inside the script, which would freeze the modal popup for the whole
   install. The package manager is read from the committed lockfile
   (`pnpm-lock.yaml`/`package-lock.json`/`yarn.lock`/`bun.lock*`) so we never
   clobber an npm repo with a pnpm lockfile, defaulting to `pnpm` (repo
   convention) when there's none. On by default; disable with
   `tmux set -g @worktree_auto_install off`.
   - **Sync vs async split.** The rule above is about *slow* work: a multi-minute
     install must not block the popup, so it goes async into the window. *Fast,
     must-happen-first* work — the gitignored-file seed (guideline 7) — runs
     **synchronously in the script** instead, so those files are on disk before
     the install (which may need `.npmrc`/`.env`) starts. Match the mechanism to
     the cost: cheap+prerequisite → sync in script; slow → async via `send-keys`.
7. **Seed gitignored files _and dirs_ from the main worktree.** A fresh checkout
   omits ignored paths (`.env*`, `scripts.local/`, …), so create copies them in
   from the **main** worktree (`maybe_copy_files`). Key choices:
   - **Pattern list** is `@worktree_copy_globs` (space/newline-separated; default
     `.env* .npmrc scripts.local`; `off`/`none` to disable). Patterns match an
     entry's **basename**, so `.env*` catches env files at *any depth*
     (`application/.env.development.local`) and `scripts.local` matches that ignored
     directory; each match is recreated at the same relative path — a **matched
     directory is copied whole** (`cp -pR`). Depth-independence is the whole point,
     since these often live in a subdir, not the repo root.
     `.npmrc` is in the default because the ignored-only scope makes it free: a
     *tracked* `.npmrc` (the common case — registry config) already rides the
     checkout and is never touched here, so it only acts on a *gitignored*,
     token-bearing `.npmrc`, which is exactly the one a fresh worktree's install
     would otherwise miss. (Auth tokens kept in `~/.npmrc` are global and need no
     copy either way.)
   - **Scope is git-IGNORED paths only** (`git ls-files -oi --exclude-standard`).
     That's deliberately exactly "what `worktree add` left behind": never tracked
     paths (already checked out) nor untracked-but-unignored WIP. Consequence: a
     pattern that targets a *non-ignored* untracked file won't copy it — fine for
     env/secret files and local script dirs, which are gitignored.
   - **`--directory` is load-bearing, and the PATTERN is now the only gate.**
     Without `--directory`, `ls-files -oi` descends into `node_modules/` and lists
     every `.env` inside it (dependencies ship them) — a copy explosion.
     `--directory` collapses each wholly-ignored dir to one `dir/` entry; we strip
     the trailing slash, match its basename, and `cp -pR` it **only if it matches**.
     That's why `scripts.local` gets copied but `node_modules`/`dist` don't — they
     simply don't match. There is no longer a `[ -f ]` safety net excluding all
     dirs, so **keep the default patterns specific**: a broad glob (e.g. `*`) would
     now drag in whole ignored directories. Don't remove `--directory`.
   - **Source = main worktree, always**, even if you launched the popup from a
     linked worktree — the main checkout is the canonical home for these files.
     Perms are preserved (`cp -pR`; env files are often mode 600, scripts +x).

## Gotchas / watch-outs (read before editing)

- **The fzf output is a 3-line contract.** With `--print-query` + `--expect`, the
  script reads line 1 = typed query, line 2 = pressed key (empty for a plain
  `enter`), line 3 = selected row. Adding/removing either flag — or any other
  flag that adds output lines — shifts these and silently breaks dispatch. If you
  touch the fzf invocation, re-check the parser.
- **Only exit 130 is special; exit 1 is normal here.** fzf returns **1** ("no
  match") when you press `enter`/`ctrl-n` on a query that filtered the list to
  empty — but it *still* prints the query on line 1, which is exactly what the
  create-on-`enter` path needs. So the script gates *only* on `130` (esc/ctrl-c →
  close popup) and treats every other code as "parse and dispatch". Don't add an
  `exit` on code 1 — it would kill create-from-a-new-name. (Verified on fzf 0.73.)
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
- **Create's only post-creation step is the dependency install** (Node projects;
  see guideline 6) — still no `.env` copy, no agent launch. The install is fired
  with `send-keys` into the new window, *after* `new-window` returns its
  `#{window_id}` — so a slow `pnpm install` never blocks the popup, and the
  command lands in the right window even if two branches sanitize to the same
  name. There's a small inherent race (keys are sent the instant the window's
  shell spawns); tmux buffers them to the pane's pty, so they run once the shell's
  line editor is ready — don't "fix" it with a blocking `sleep` in the script.
  Any new post-creation step should follow the same pattern (visible, non-blocking,
  toggleable).
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
