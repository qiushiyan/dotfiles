# Worktree popup — design notes

`prefix W` opens a single tmux popup that **switches, creates, batch-removes,
reaps, and PR-checkouts git worktrees**. Implemented as
`scripts/tmux-worktree.sh`, bound in `tmux.conf`. Keys: `enter` switch/create,
`ctrl-n` create-from-name, `tab`/`ctrl-a` mark rows, `ctrl-x` batch-remove,
`ctrl-g` reap merged, `ctrl-p` PR picker, `ctrl-d`/`ctrl-u` scroll the preview.
This doc is the *why* and the *watch-outs* — the script is the *how*. Don't read
it for syntax; read it before you change behavior.

Four sections carry most of the load-bearing reasoning and are worth reading
before touching anything near them: **Deciding what counts as merged**,
**Everything per-worktree runs in parallel**, **Removal keeps a way back**, and
the gotcha on window identity.

## Three front-ends, one core

The git-worktree logic itself — the `~/dev/.worktrees/<repo>/<branch>` path
convention, base resolution, the `worktree add` new-branch dance (with the
existing-branch fallback), the slot guard, the gitignored-file seeding,
package-manager detection, and reap candidacy (`wt_reap_candidates`) — lives in
**`scripts/worktree-core.sh`**, which is **tmux-free** and sourced by this
popup. Three front-ends wrap it:

- **`tmux-worktree.sh`** (this popup) — the heavyweight surface: an fzf
  switch/create/remove UI that opens each worktree in its **own tmux window** and
  auto-installs deps there.
- **`gwt`** (a zsh function in `zsh/.config/zsh/git.zsh`) — the lightweight
  surface: create a worktree + new branch and **`cd` into it in the current
  pane**. No new window, no dependency install. It runs `worktree-core.sh create`
  (which prints only the new path to stdout) as a subprocess and `cd`s there — the
  `cd` is the whole reason it's a shell function, not a call to the core's CLI.
- **`brief start`** (`~/dev/brief`) — the handoff binary places a worktree for
  a brief's branch through the same CLI: `resolve` first (what the name already
  refers to — local, one remote, several, or nothing), then `create`, passing
  `--new` only on a verdict of nothing so the bounded fetch is paid once. It
  classifies the slot itself beforehand, with context the core lacks (the
  brief, the folder), and refuses with a mend; the core's guard is the last
  line, not the diagnosis.

Keep the split clean: **pure git logic goes in the core; anything that talks to
tmux stays in the popup wrapper.** The popup's `maybe_copy_files` /
`maybe_install_deps` are now thin shims — they call the core for the *what*
(`wt_copy_ignored`, `wt_install_cmd`) and own only the tmux *delivery*
(`display-message`, `send-keys`). `wt_add` keeps git's "Preparing worktree…" /
"HEAD is now at…" chatter off stdout so the core's CLI contract (stdout = the new
path, nothing else) holds for `gwt`.

Two `gwt` behaviors diverge from the popup **on purpose**:

1. **Base branch.** The popup forks from the `origin/HEAD → main → master` chain
   (`wt_default_base`); `gwt` defaults to the **current** branch (you usually
   want to fork from where you stand) behind a `[y/N]` confirm. An explicit base
   arg overrides either.
2. **No install.** `gwt` stays lightweight — it seeds gitignored files but never
   runs `pnpm install`. (The popup still does, in the new window.)

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
   - **`--multi` rides on top.** `tab`/`shift-tab` mark rows, `ctrl-a` toggles
     all, and `ctrl-x` consumes the marked set — or just the highlighted row
     when nothing is marked, so single-delete costs no extra keystrokes. A
     plain `enter` with marks acts on the *first* marked row.
3. **Switch/create exit, remove loops.** The pick-and-dispatch runs in a `while`
   loop. `switch`, `create`, and a successful PR-checkout are *terminal* (you
   want to land in that window, so they `exit` and the `-E` popup closes).
   `remove` (`ctrl-x`) and `reap` (`ctrl-g`) are *in-popup* operations — they
   return to a **refreshed** list (the just-removed entries gone) so you can
   keep going, rather than ejecting you on every delete. A *failed* create and
   a cancelled PR pick also loop back, which is why `create_worktree` and
   `pick_pr` return a real 0/1 status the dispatcher branches on. `esc`/`ctrl-c`
   (fzf exit 130) is the only thing that breaks the loop from the list — keep
   that escape hatch intact or the popup becomes a trap.
4. **Removal is trash-and-sweep, and the script owns the dirty check.** A batch
   (`ctrl-x` on the marked set) is: one confirm listing every branch with its
   dirty flag → `mv` each worktree into `~/dev/.worktrees/.trash/<batch>` (a
   same-filesystem rename — instant however big node_modules is) → one
   `git worktree prune` → kill the windows → **aggregated** branch deletion
   (merged → one default-yes confirm; unmerged → explicit force past a warning,
   with "merged" defined below) → `tmux run-shell -b "rm -rf …"` sweeps the trash
   server-side, so it survives the popup closing, and empty parent dirs are
   tidied. Parallel `rm -rf`s were considered and rejected: deletion is
   disk-metadata-bound (parallelism buys little on one SSD) and concurrent git
   commands contend on ref locks — hiding the latency beats parallelizing it.
   The price of bypassing `git worktree remove` is that its dirty-refusal never
   fires, so the script re-checks dirtiness itself: discarding uncommitted
   changes takes a *second* explicit `[y/N]`, and declining removes just the
   clean ones. The main worktree and the worktree the popup was launched from
   are never removable. `ctrl-g` (**reap**) feeds this same path with every
   clean worktree already merged into the default base (`wt_reap_candidates`)
   — end-of-week cleanup in three keystrokes.
5. **The script talks back to tmux via the CLI.** Inside the popup it calls
   `tmux new-window / select-window / kill-window`. The session is **self-detected**
   via `tmux display-message` (NOT passed as an arg — `display-popup` doesn't
   expand `#{...}` in its command, so an arg would arrive literally), and `$PWD`
   is the repo because the binding opens the popup there with `-d`.
6. **Post-creation work runs in the new window, never in the popup.** Create
   makes the worktree (branch forked from the repo's default branch), opens its
   window, and sends **one chained command line** into it with `send-keys`
   (targeted by `#{window_id}`, not name): the dependency install `&&` the
   post-create command. It runs *visibly* where you land and you can `Ctrl-C`
   either half; it does **not** run inside the script, which would freeze the
   modal popup. The install half (Node projects only) reads the package manager
   from the committed lockfile
   (`pnpm-lock.yaml`/`package-lock.json`/`yarn.lock`/`bun.lock*`) so we never
   clobber an npm repo with a pnpm lockfile, defaulting to `pnpm` (repo
   convention) when there's none; disable with
   `tmux set -g @worktree_auto_install off`. The post-create half defaults to
   **`x` (the claude alias)** — a fresh worktree lands with the agent already
   starting, which is the whole parallel-agents workflow in one keystroke less;
   override or disable with `tmux set -g @worktree_post_create_cmd <cmd|off>`.
   It *must* be delivered via send-keys into the window's interactive zsh —
   that's what lets an alias like `x` resolve at all.
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
8. **The PR picker reuses the create path.** `ctrl-p` opens a second fzf screen
   (still one popup — guideline 1) over `gh pr list`, previewing with
   `gh pr view`. `enter` fetches `refs/pull/<n>/head` into a local branch named
   after the PR's head branch — that ref exists for fork PRs too — and then
   calls the normal `create_worktree`: `wt_add`'s existing-branch fallback
   checks it out, and the window / file seed / install+agent chain runs as for
   any create. An existing local branch of the same name is used **as-is**
   (never force-moved — it may hold local commits). `ctrl-o` opens the PR in
   the browser instead; `esc` returns to the worktree list, not out of the
   popup. The PR list is **memoized for the popup's lifetime**: esc + re-enter
   skips the loading screen, `ctrl-r` inside the picker forces a refetch, and
   a freshly opened popup always fetches anew — the cache is just a variable,
   so there are no files or TTLs to invalidate. A stale row is harmless for
   checkout (enter fetches the PR's *live* head ref), and an empty result is
   deliberately not memoized so "no open PRs" keeps re-checking.
9. **The UI is themed by tmux, not by the script.** fzf colors are read at
   launch from the `@thm_*` options the active palette file publishes (the
   same options the status bar uses), and the popup border is the global
   `popup-border-lines rounded` + `popup-border-style` in `tmux.conf` — so a
   new terminal theme styles this popup with zero per-theme config here. The
   list markers (`»` = the worktree you're in, `*` = dirty) use plain ANSI
   colors for the same reason.

## Deciding what counts as merged

`wt_merged_into <branch> <base>` in the core is the single answer to "is this
branch's work already on the base", used by both reap candidacy and the
branch-deletion prompt. It was `git merge-base --is-ancestor` in two places,
and that is wrong in a way that is worse than it looks: **on a squash-merging
repo, every shipped branch reports "NOT merged"**, so the batch-remove flow
asks you to force-delete "dropping their commits" on work that is demonstrably
on main. A warning that cries wolf on every removal is worse than no warning —
you stop reading it, and the one time a branch really was unmerged you force
past that too.

Three ways work lands on a base; only the first is visible in the graph.

| how it landed | what the base gets | how we detect it |
| --- | --- | --- |
| merge commit / fast-forward | the branch's own commits | `merge-base --is-ancestor` |
| GitHub **Squash and merge** | one new commit, no shared history | collapse the branch to a dangling `commit-tree` (tip's tree, parented on the merge base) and ask `git cherry` if the base already carries that patch |
| GitHub **Rebase and merge** | the commits re-authored, new SHAs | per-commit `git cherry`; merged iff every line is `-` |

Checks run in that order because it is also cheapest-first: the graph query is
microseconds, each patch-id scan is ~0.1–0.4 s, so only a branch that really is
unmerged pays for both. Two consequences worth keeping in mind:

- **`git branch -d` disagrees with us on purpose.** Git's own "fully merged"
  test is the graph-only one, so `-d` *refuses* a squash-merged branch. Having
  independently established containment by patch identity, `delete_merged_branch`
  falls back to `-D` — and reports a deletion that still fails instead of
  swallowing it, which is what the old `2>/dev/null` did.
- **A verdict is only as fresh as the base ref**, and nothing here used to
  fetch. Merge a PR in the browser and its branch stayed "unmerged" until you
  next pulled — the second half of the same false alarm. The popup now fires
  `wt_fetch_base` in the **background at startup** (only when `wt_base_is_stale`
  — no fetch in the last 5 min) and `await_base_fetch`s it at the moment a
  verdict is needed, so browsing the list pays for the network. Same shape as
  the branch-creation guard in `git.zsh`: `FETCH_HEAD` mtime for freshness
  (`-size +0c` too — a killed fetch truncates it with a *fresh* mtime), a
  `timeout`-bounded probe, and a failed probe that **says so** rather than
  quietly grading against last week's base.

What it still can't see: a branch merged into something other than the default
base, and a branch whose diff was applied by hand with edits (no patch matches).
Both correctly fall through to the force prompt.

The verdict is **memoized** on `(branch sha, base sha)` in
`<git-common-dir>/wt-merged-cache`, which is what makes it cheap enough to draw
in the list on every popup open (measured on a 7-worktree repo: 0.8 s cold,
0.2 s on memo hits). It is a pure function of those two shas, so there is
nothing to invalidate — a ref that moves is simply a different key, and that
key is the safety property: a memo keyed on the branch alone would keep
answering "merged" after the base moved, and a stale "merged" is how a branch
gets deleted. `wt_trim_merged_cache` caps the file at popup startup.

Tests: `tests/test-worktree-core.sh` (W1–W5 are one case per merge style plus the
must-stay-NO case; W10 pins the truncated-`FETCH_HEAD` trap; W22/W23 poison the
memo to prove it is really read, and really keyed on both shas; W30–W35 are the
slot guard, W35 the unreadable directory that must not read as empty).

## Everything per-worktree runs in parallel

Every question the popup asks about a worktree is a git process — `git status`
for the dirty marker, the merge test for the tag — so asking them in a loop made
the popup's time-to-first-paint scale with how many worktrees you keep. Measured
on a 7-worktree repo: **2.6 s cold / 0.30 s warm serially, 0.03 s fanned out**
for the status pass alone.

`wt_fanout <fn>` in the core takes `"<f1>\t<f2>"` lines on stdin, runs one job
per line, and prints the results **in input order**. Two things are load-bearing:

- **Order comes from zero-padded filenames**, not from completion order. A list
  that reshuffles itself between openings is one you can't build muscle memory
  on.
- **The loop runs inside an explicit `( … )` subshell**, so its bare `wait`
  cannot adopt a caller's background job. The popup keeps a base fetch in flight
  the whole time this runs; a `wait` that swallowed it would block the list on
  the network — precisely what backgrounding that fetch exists to prevent. If
  you add another `wait` anywhere in this script, check it against that.

Probes use `git --no-optional-locks`: nothing here writes, and this workflow has
agents running git in those same worktrees, so a probe must never contend for
`index.lock`.

## Removal keeps a way back

Removal used to have two points of no return, both one keystroke deep:
discarding a dirty worktree (the batch's trash is swept *immediately*, so a
mistyped `y` was final) and force-deleting an unmerged branch (`git branch -D`
takes the branch's reflog with it, leaving `git fsck --lost-found` as the
recovery route). Both now snapshot first, into `refs/wt-trash/<batch>/<slot>-<branch>`:

- **A dirty worktree** is captured by `wt_snapshot_worktree` as one commit
  parented on HEAD, so `git diff HEAD <ref>` reads as the changes that were
  pending. Not `git stash create` — that captures *tracked* modifications only,
  and the dirt in an agent's worktree is mostly new untracked files. The tree is
  built in a scratch `GIT_INDEX_FILE`, so the worktree's own index is untouched
  and nothing lands on the shared stash list; `add -A` still obeys `.gitignore`,
  which is what keeps `node_modules` out of it. **A worktree that cannot be
  snapshotted is not removed** — "discard" must never quietly mean "lost".
- **An unmerged branch tip** is parked at a ref before `-D`.

The ref name is printed with the command that undoes it. `<slot>` is an index,
not just the branch name, because two branches in one batch can collide —
`feat` and `feat/x` can't both exist in the ref store (directory/file conflict),
and a silent overwrite would drop one of the two things we just promised to
keep. These refs pin objects, so they expire on the same age-gate principle as
the trash directory (`wt_prune_backups`, `@worktree_backup_days`, default 30;
`0` keeps them forever).

## Gotchas / watch-outs (read before editing)

- **The fzf output is a positional contract.** With `--print-query` +
  `--expect` + `--multi`, the script reads line 1 = typed query, line 2 =
  pressed key (empty for a plain `enter`), lines 3..N = the selected rows (the
  marked ones, or just the highlighted row when nothing is marked). The PR
  picker's inner fzf has a *different*, two-line contract (`--expect` without
  `--print-query`): line 1 = key, line 2 = row. Adding/removing any of these
  flags — or any flag that adds output lines — shifts the parse and silently
  breaks dispatch. If you touch an fzf invocation, re-check its parser.
- **`ctrl-a`/`ctrl-d`/`ctrl-u` are rebound inside the list.** `ctrl-a` =
  toggle-all, `ctrl-d`/`ctrl-u` = preview half-page scroll (vim feel). Stock
  fzf `ctrl-u` (clear query) is deliberately traded away.
- **"Merged" is patch identity, not just ancestry — and the base is refreshed
  first.** Both are corrections to a false alarm that used to fire constantly:
  every squash-merged branch was reported "NOT merged into origin/HEAD… drops
  their commits", which is how you train someone to force past the one warning
  that was real. See "Deciding what counts as merged" below before touching
  `wt_merged_into`.
- **The trash sweep is age-gated on purpose.** Startup schedules a background
  sweep of `~/dev/.worktrees/.trash` entries **older than 2 minutes** (crash
  self-healing); each batch sweeps only its own uniquely-named dir. The age
  gate is what makes the startup sweep unable to race a sweep another live
  popup just scheduled — don't "simplify" it to `rm -rf` of the whole root.
- **The script must stay bash-3.2-safe.** macOS ships bash 3.2 and there is no
  brew bash on this machine; under `set -u`, expanding an *empty* array is
  fatal on 3.2 — which is why the batch machinery passes TSV-line strings
  around instead of arrays. Keep it array-free.
- **The fzf theme is read once at popup launch.** Switching the terminal theme
  while the popup is open keeps the old colors until you reopen. Trivial, by
  design.
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
  folder name); if two such repos ever collide on a branch name, the slot guard
  refuses — no data loss.
- **The slot guard (`wt_slot_free`) deletes nothing.** A slot is free when it is
  absent or an empty real directory (`git worktree add` accepts that); a file, a
  symlink, an unreadable directory, or anything non-empty is refused, because a
  directory left behind by a pruned registration may hold a session's only copy
  of its work. Every creator — `create`, `gwt`, the popup — passes through it.
- **Windows are found by PATH first, name second — and removal reaches into
  other sessions.** A window's name is the branch with `/`→`-`, which is neither
  injective (`feat/x` and `feat-x` produce the same name, so switching to one
  could land you in the other) nor stable (rename the window and the mapping is
  gone). So `windows_for_path` matches on `#{pane_current_path}` — a pane in the
  worktree, or in a subdirectory of it — and the name match survives only as the
  fallback for a window whose pane has since `cd`'d elsewhere. Two consequences:
  - **Removal kills matching windows in *every* session** (`list-panes -a`), not
    just the popup's. A window pointing at a deleted directory is broken wherever
    it lives. If such a window is the **last** one in another session, tmux ends
    that session — expected, but it is a session disappearing out of view.
  - **The window ids must be collected _before_ the `mv`.** A process whose cwd
    is renamed under it reports the *new* path, so after staging into the trash
    nothing matches any more and every window survives its worktree.
- **Slashed branches create nested folders.** `feat/login` →
  `~/dev/.worktrees/<repo>/feat/login`. Git is fine with it, and batch removal
  now tidies the empty `feat/` parent afterwards (`find -mindepth 1 -type d
  -empty -delete`, scoped to this repo's worktree root — keep that scoping).
- **`display-popup` does NOT expand `#{...}` in its shell-command argument** (only
  in `-d`). Passing `'#{session_name}'` as a script arg delivers the literal text
  `#{session_name}`, and `new-window -t '#{session_name}'` then fails with "can't
  find window". That's why the session is self-detected inside the script.
- **Base branch needs `origin/HEAD`.** The default base is the first of
  `origin/HEAD, origin/main, origin/master, main, master` that resolves. A fresh
  clone without `origin/HEAD` set falls through the chain — if a new worktree
  forks from the wrong base, that chain is the first place to look
  (`git remote set-head origin -a` fixes a missing `origin/HEAD`).
- **Create's post-creation step is ONE chained send-keys line** — install `&&`
  post-create command (guideline 6). It's fired into the new window *after*
  `new-window` returns its `#{window_id}` — so a slow `pnpm install` never
  blocks the popup, and the command lands in the right window even if two
  branches sanitize to the same name. There's a small inherent race (keys are
  sent the instant the window's shell spawns); tmux buffers them to the pane's
  pty, so they run once the shell's line editor is ready — don't "fix" it with
  a blocking `sleep` in the script. Any new post-creation step should follow
  the same pattern (visible, non-blocking, toggleable) and join the chain
  rather than adding a second send-keys.
- **Reload mechanics.** Because the script is stow-symlinked, **edits to it are
  live immediately**, but edits to the **binding** in `tmux.conf` need a config
  reload (`prefix r`). (The repo's tmux version is pinned once, in `CLAUDE.md`.)
- **The *popup* can't run headlessly, but the script can.** `display-popup`
  needs an attached client — but the script itself runs fine in a pane of a
  *detached* scratch server (`tmux -L <socket>`): a pane has a pty regardless
  of attachment, so fzf renders and the `read` confirms work, driven by
  `send-keys` and asserted with `capture-pane`. That's how the reap / batch /
  create / guard flows were validated end-to-end; only the binding itself needs
  a real client. NB: when testing, set `@worktree_post_create_cmd` to a
  harmless `echo` on the scratch server first, or every test create launches a
  real claude.

## Extension points

- **Agent-done notifications** → attach to the agent pane *inside* a worktree
  window so the alert can name the worktree (see `../roadmap.md`); the popup
  list could then also mark which worktree's agent is waiting (`@agent_done`
  is per-window and the branch→window mapping is already here).
- **Richer preview** → the fzf `--preview` already shows `git status -sb` + recent
  log; a per-worktree ahead/behind or PR-status line slots in there.
- (The PR picker from this list is built — `ctrl-p`, guideline 8.)
