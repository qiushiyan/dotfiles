#!/usr/bin/env bash
# tmux-worktree.sh — unified git-worktree popup for tmux (bound to prefix W).
#
# Launched from a tmux display-popup. Lists the current repo's worktrees in fzf
# (» marks the worktree you're in, * marks a dirty one, "· merged" marks one the
# reap would take — @worktree_show_merged off to drop it). Rows are built in
# parallel; serially the list was the popup's whole time-to-first-paint.
#   enter        switch to the highlighted worktree's window; if the typed name
#                matches nothing, create that worktree + branch and open its window
#   ctrl-n       force-create a worktree + branch from the TYPED name (even when
#                the query still fuzzy-matches an existing worktree)
#   tab/ctrl-a   mark one / toggle all entries (shift-tab unmarks)
#   ctrl-x       remove the marked worktrees (or the highlighted one if none are
#                marked) as ONE confirmed batch — trash-and-sweep, see below
#   ctrl-g       reap: batch-remove every clean worktree whose branch is already
#                merged into the default base (end-of-week cleanup in 3 keys)
#                — "merged" counts squash and rebase merges, and the base is
#                refreshed first, so a PR you merged in the browser counts too
#   ctrl-p       PR picker: list open GitHub PRs via gh; enter checks one out
#                into a worktree, ctrl-o opens it in the browser, ctrl-r
#                refetches the list (it's memoized for the popup's lifetime)
#   ctrl-d/u     scroll the preview half a page (vim-style)
#
# switch / create / PR-checkout are EXIT operations (you land in the target
# window and the popup closes); remove and reap are IN-POPUP operations (they
# loop back to the refreshed list so you can keep going). A failed create also
# loops back.
#
# REMOVAL IS TRASH-AND-SWEEP: each selected worktree is mv'd into
# ~/dev/.worktrees/.trash/<batch> (a same-filesystem rename — instant no matter
# how big node_modules is), `git worktree prune` drops the metadata, windows
# are killed, branch deletion is offered in aggregate (merged → one [Y/n];
# unmerged → explicit force), and the real rm -rf runs server-side
# in the background via `tmux run-shell -b`, so it survives the popup closing.
# Because mv bypasses `git worktree remove`'s dirty-refusal, THIS script owns
# the dirty check: dirty worktrees are flagged in the confirm list and removed
# only after a second explicit [y/N] (declining keeps them and removes just the
# clean ones). NOTHING IRREVERSIBLE HAPPENS WITHOUT A WAY BACK: a dirty
# worktree's uncommitted work (tracked AND untracked) and a force-deleted
# branch's tip are parked at refs/wt-trash/<batch>/… first, and the ref is
# printed with the command that restores it. Windows are killed by PATH, in
# every session — a window pointing at a deleted directory is broken wherever
# it lives.
#
# New worktrees go under  ~/dev/.worktrees/<repo>/<branch>  for every project
# (no per-repo special-casing). Create makes the worktree, opens its window, then:
#   - copies the gitignored files/dirs a checkout leaves behind (`.env* .npmrc
#     scripts.local .duet docs.local` by default, from the MAIN worktree, at any
#     depth; matched directories are copied whole) into the new tree — configurable
#     via @worktree_copy_globs ("off" to disable);
#   - sends ONE visible, cancellable command line into the new window: the
#     dependency install for a Node project (pnpm/npm/yarn/bun, from the
#     lockfile; @worktree_auto_install off to disable) chained with the
#     post-create command — default "x" (the claude alias), so a fresh worktree
#     lands with the agent already starting. Override or disable it with
#     @worktree_post_create_cmd ("off" to disable).
#
# The fzf UI colors itself from the live tmux palette (the @thm_* options the
# theme files publish), so every terminal theme — including future ones —
# styles this popup with zero per-theme config here.
#
# No args: the session is self-detected via `tmux display-message`, and $PWD is
# the repo (the popup is opened there by `display-popup -d` in the keybinding).
# NB: display-popup does NOT expand #{...} in its command argument, so the
# session must be self-detected, not passed as $1 (it would arrive literally).
#
# Portability note: macOS ships bash 3.2 and there is no brew bash here — keep
# this script array-free (strings of TSV lines instead); empty arrays under
# `set -u` are fatal on 3.2.

set -u

# Pure git-worktree logic (path convention, base resolution, the worktree-add
# dance, gitignored-file seeding, pkg-manager detection, reap candidacy) lives
# in the tmux-free worktree-core.sh, shared with the gwt shell function. We add
# only tmux glue.
source "${BASH_SOURCE[0]%/*}/worktree-core.sh"

session="$(tmux display-message -p '#{session_name}' 2>/dev/null)"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "not inside a git repository: $PWD"
  sleep 1.5
  exit 0
fi

# --- repo identity & worktree root -------------------------------------------

# Path convention, main_worktree, and default_base come from worktree-core.sh
# (wt_worktree_root / wt_main_worktree / wt_default_base).
wt_root="$(wt_worktree_root)"
cur_top="$(git rev-parse --show-toplevel 2>/dev/null)"   # the worktree we're IN
main_top="$(wt_main_worktree)"                           # never removable either

# --- trash (removal staging) --------------------------------------------------

# Batch removal stages worktrees here (same filesystem as wt_root, so mv is a
# rename) and sweeps in the background. Self-heal on startup: sweep whatever a
# crashed/killed popup left behind — but only entries older than 2 minutes, so
# this can never race the sweep another live popup just scheduled.
WT_TRASH="$HOME/dev/.worktrees/.trash"
tmux run-shell -b "find '$WT_TRASH' -mindepth 1 -maxdepth 1 -mmin +2 -exec rm -rf {} + 2>/dev/null; true" 2>/dev/null || true

# The other thing removal leaves behind: the refs/wt-trash snapshots taken before
# discarding uncommitted work or force-deleting a branch. They pin objects, so
# they expire too — same age gate, different store. @worktree_backup_days 0 keeps
# them forever. Cheap enough to run inline (for-each-ref over a tiny namespace).
wt_backup_days="$(tmux show-option -gqv @worktree_backup_days 2>/dev/null)"
wt_prune_backups "${wt_backup_days:-30}"
wt_trim_merged_cache

# --- base freshness (background) ------------------------------------------------

# Every merged/unmerged verdict below is read off the base's remote-tracking ref,
# which is frozen at your last fetch — merge a PR in the browser and its branch
# still reads "NOT merged" here. So refresh it, but never make anyone WATCH a
# fetch: fire it at startup (only when stale — wt_base_is_stale) and await it
# only at the point a verdict is actually needed, by which time browsing the list
# has usually paid for it. Bounded by `timeout` inside wt_fetch_base.
wt_fetch_pid=""
wt_fetch_note=""
if wt_base_is_stale; then
  wt_fetch_base >/dev/null 2>&1 &
  wt_fetch_pid=$!
fi

# Block until the startup fetch lands. A FAILED probe is announced, not
# swallowed: grading against a stale base is exactly the false alarm we're here
# to remove, so the user has to know when we're doing it.
await_base_fetch() {
  [ -n "$wt_fetch_pid" ] || return 0
  kill -0 "$wt_fetch_pid" 2>/dev/null && printf 'refreshing %s…\n' "$(wt_base_display)"
  wait "$wt_fetch_pid" 2>/dev/null || wt_fetch_note="could not refresh $(wt_base_remote) — merge status is as of your last fetch"
  wt_fetch_pid=""
  [ -n "$wt_fetch_note" ] && printf '\033[33m%s\033[0m\n' "$wt_fetch_note"
  return 0
}

# --- fzf theme from the live tmux palette --------------------------------------

# The active terminal theme publishes its palette as @thm_* tmux options
# (tmux.conf force-loads the palette file on start and on every theme switch),
# so the popup reads its colors from tmux at launch instead of keeping
# per-theme tables — a new theme styles this UI with no change here.
fzf_colors="fg+:-1"
_wt_theme() {
  local accent muted dim surface green red
  accent="$(tmux show -gqv @thm_mauve 2>/dev/null)"
  [ -n "$accent" ] || return 0            # no palette loaded — fzf defaults
  muted="$(tmux show -gqv @thm_overlay_2 2>/dev/null)"
  dim="$(tmux show -gqv @thm_overlay_0 2>/dev/null)"
  surface="$(tmux show -gqv @thm_surface_0 2>/dev/null)"
  green="$(tmux show -gqv @thm_green 2>/dev/null)"
  red="$(tmux show -gqv @thm_red 2>/dev/null)"
  fzf_colors="hl:$red,hl+:$red,fg+:-1,bg+:$surface,gutter:-1,query:-1,pointer:$accent,prompt:$accent,spinner:$accent,marker:$green,info:$muted,header:$muted,label:$muted,border:$dim,preview-border:$dim"
}
_wt_theme

# --- list:  "<markers> <branch>\t<path>\t<branch>"  (display = field 1) --------

# Marker column: » (green) = the worktree the popup was launched from,
# * (yellow) = dirty. Plain ANSI colors so the terminal theme maps them. A clean
# worktree whose branch has already landed also gets a dim "· merged" tag — now
# that merged-ness counts squash and rebase merges it is worth trusting, and
# seeing the reap set BEFORE pressing ctrl-g is the difference between a cleanup
# and a surprise. Disable with @worktree_show_merged off.
#
# One row = one `git status` (+ the merge test), so rows are built in PARALLEL
# via wt_fanout — serially this was the popup's whole time-to-first-paint.
row_for() {
  local path="$1" branch="$2" base="$3" show_merged="$4" here=" " dirty=" " tag=""
  [ "$path" = "$cur_top" ] && here=$'\033[32m»\033[0m'
  if [ -n "$(git --no-optional-locks -C "$path" status --porcelain 2>/dev/null)" ]; then
    dirty=$'\033[33m*\033[0m'
  elif [ -n "$show_merged" ] && [ "$path" != "$main_top" ] && [ "$path" != "$cur_top" ] \
       && [ "$branch" != "(detached)" ] && wt_merged_into "$branch" "$base"; then
    # only where it's actionable: the main worktree and the one you're in can
    # never be removed, and a dirty worktree can never be reaped.
    tag=$'\033[32m · merged\033[0m'
  fi
  printf '%s%s %s%s\t%s\t%s\n' "$here" "$dirty" "$branch" "$tag" "$path" "$branch"
}

list_worktrees() {
  local base="" show_merged=""
  case "$(tmux show-option -gqv @worktree_show_merged 2>/dev/null)" in
    off|0|false|no|disabled) ;;
    *) show_merged=1; base="$(wt_default_base)" ;;
  esac
  # Detached entries have no branch to test, but still belong in the list.
  git worktree list --porcelain | awk '
    /^worktree /{p = substr($0, 10)}
    /^branch /  {b = $2; sub("refs/heads/", "", b); print p "\t" b}
    /^detached$/{print p "\t(detached)"}
  ' | wt_fanout row_for "$base" "$show_merged"
}

# --- create / switch -----------------------------------------------------------

win_name() { printf '%s' "$1" | tr '/' '-'; }

# Post-creation work runs VISIBLY in the new window via send-keys — NOT inside
# this script, which would freeze the modal popup. ONE chained command line:
#   <install> && <post-create cmd>
# The install half (Node projects only; package-manager SELECTION by lockfile
# is wt_install_cmd in worktree-core.sh) is toggled by @worktree_auto_install.
# The post-create half defaults to "x" (the claude alias — a fresh worktree
# lands with the agent already starting) and is overridden or disabled via
# @worktree_post_create_cmd. You land in the window, watch it run, and can
# Ctrl-C either half. send-keys types into the window's interactive zsh, which
# is what lets an alias like "x" resolve at all.
maybe_post_create() {
  local path="$1" target="$2" inst="" post cmd=""
  [ -n "$target" ] || return
  case "$(tmux show-option -gqv @worktree_auto_install 2>/dev/null)" in
    off|0|false|no|disabled) ;;
    *) inst="$(wt_install_cmd "$path")" ;;   # empty if not a Node project
  esac
  post="$(tmux show-option -gqv @worktree_post_create_cmd 2>/dev/null)"
  [ -n "$post" ] || post="x"
  case "$post" in off|0|false|no|disabled|none) post="" ;; esac
  if [ -n "$inst" ] && [ -n "$post" ]; then
    cmd="$inst && $post"
  else
    cmd="$inst$post"                         # at most one is non-empty here
  fi
  [ -n "$cmd" ] || return
  # target by window-id (not name): new-window can make duplicate names.
  tmux send-keys -t "$target" "$cmd" Enter
}

# Seed the new worktree with gitignored files/dirs from the main worktree. The
# copy itself is wt_copy_ignored in worktree-core.sh (where the @worktree_copy_globs
# patterns, the --directory mechanics, and the "keep patterns specific" warning are
# documented). Here we only pass the tmux-configured globs in and surface the
# core's summary via display-message.
maybe_copy_files() {
  local globs msg
  globs="$(tmux show-option -gqv @worktree_copy_globs 2>/dev/null)"
  msg="$(wt_copy_ignored "$1" "$globs")"
  [ -n "$msg" ] && tmux display-message "$msg" || true
}

# Window ids (one per line) whose PANES live in <path>, across every session.
# Identity by path, not by name: the window name is the branch with "/"→"-",
# which is not injective (feat/x and feat-x produce the same name, so switching
# to one could land you in the other) and goes stale the moment a window is
# renamed. <scope> is "-s <session>" to look in one session or "-a" for all.
windows_for_path() {
  local path="$1"; shift
  tmux list-panes "$@" -F '#{window_id}'$'\t''#{pane_current_path}' 2>/dev/null \
  | while IFS=$'\t' read -r wid p; do
      case "$p" in "$path"|"$path"/*) printf '%s\n' "$wid" ;; esac
    done | awk '!seen[$0]++'
}

switch_worktree() {
  local path branch win wid
  path="$1"; branch="$2"
  win="$(win_name "$branch")"
  # path → name → create. The name fallback still matters: a window opened for
  # this worktree whose pane has since cd'd elsewhere is findable only by name.
  wid="$(windows_for_path "$path" -s -t "$session" | sed -n '1p')"
  [ -n "$wid" ] || wid="$(tmux list-windows -t "$session" -F '#{window_id}'$'\t''#W' 2>/dev/null \
                          | awk -F'\t' -v n="$win" '$2 == n {print $1; exit}')"
  [ -n "$wid" ] || wid="$(tmux new-window -t "$session" -n "$win" -c "$path" -P -F '#{window_id}')"
  tmux select-window -t "$wid" 2>/dev/null || true
  # landing on a worktree window clears its agent-done dot (by window id, so a
  # duplicate name can't send it to the wrong window) and refreshes the ◷ badge.
  tmux set-option -w -t "$wid" @agent_done 0 2>/dev/null || true
  [ -f "$HOME/.config/tmux/scripts/tmux-agent-recount.sh" ] && \
    bash "$HOME/.config/tmux/scripts/tmux-agent-recount.sh" 2>/dev/null || true
}

# returns 0 on success (worktree created, window opened → caller exits popup);
# returns 1 on any failure (caller loops back to the list so you can retry).
create_worktree() {
  local name path win base winid
  name="$(printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [ -z "$name" ]; then
    echo "type a name first"; sleep 1.5; return 1
  fi
  path="$wt_root/$name"
  win="$(win_name "$name")"
  if [ -e "$path" ]; then echo "path already exists: $path"; sleep 1.5; return 1; fi
  base="$(wt_default_base)"
  mkdir -p "$(dirname "$path")"
  # wt_add forks a new branch (falls back to checking out an existing one); on
  # failure it prints git's error to stderr — pause so it's readable before the loop refreshes.
  if ! wt_add "$name" "$base" "$path"; then sleep 2.5; return 1; fi
  winid="$(tmux new-window -t "$session" -n "$win" -c "$path" -P -F '#{window_id}')"
  maybe_copy_files "$path"               # seed .env* etc. BEFORE install may need them
  maybe_post_create "$path" "$winid"
  return 0
}

# --- removal: trash-and-sweep ---------------------------------------------------

# Delete a branch we have ALREADY established is contained in the base.
# `git branch -d` refuses a squash- or rebase-merged branch, because git's own
# "fully merged" test is the graph-only one — so the safe -d silently left
# exactly the branches this cleanup is most often about. We verified containment
# by patch identity, so fall back to -D. A deletion that still fails (branch
# checked out elsewhere, ref locked) is REPORTED, never swallowed: the old
# `2>/dev/null` made a no-op look identical to success.
delete_merged_branch() {
  local b="$1" err
  git branch -d "$b" >/dev/null 2>&1 && return 0
  err="$(git branch -D "$b" 2>&1)" && return 0
  printf '  could not delete %s: %s\n' "$b" "$err"
  return 1
}

# batch_remove "<path>\t<branch> lines" — confirm once, stage every worktree
# into a fresh trash dir (mv = same-fs rename, instant), prune the git
# metadata, kill their windows, offer AGGREGATED branch deletion, then sweep
# the trash in the background and tidy the empty parent dirs slashed branches
# leave behind. Always returns to the refreshed list.
#
# Safety model: mv bypasses `git worktree remove`'s dirty-refusal, so we own
# the dirty check here — dirty entries are flagged in the confirm list, and
# their uncommitted changes are discarded only after a second explicit [y/N]
# (declining drops the dirty ones from the batch and removes just the clean).
# The main worktree and the worktree the popup runs in are never removed.
batch_remove() {
  local main entries="" path branch dirty n=0 ndirty=0 ans
  main="$(wt_main_worktree)"
  while IFS=$'\t' read -r path branch; do
    [ -n "$path" ] || continue
    if [ "$path" = "$main" ];    then echo "skipping the main worktree ($branch)"; continue; fi
    if [ "$path" = "$cur_top" ]; then echo "skipping the worktree you're in ($branch)"; continue; fi
    dirty=0
    [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ] && { dirty=1; ndirty=$((ndirty+1)); }
    entries="$entries$path"$'\t'"$branch"$'\t'"$dirty"$'\n'
    n=$((n+1))
  done <<< "$1"
  if [ "$n" -eq 0 ]; then sleep 1.2; return; fi

  echo "remove $n worktree(s):"
  while IFS=$'\t' read -r path branch dirty; do
    [ -n "$path" ] || continue
    if [ "$dirty" = 1 ]; then
      printf '  %s  \033[33m(dirty — has uncommitted changes)\033[0m\n' "$branch"
    else
      printf '  %s\n' "$branch"
    fi
  done <<< "$entries"
  printf 'proceed? [y/N] '; read -r ans
  case "$ans" in y|Y) ;; *) return ;; esac

  if [ "$ndirty" -gt 0 ]; then
    printf 'also remove the %d dirty one(s)? their changes are snapshotted first [y/N] ' "$ndirty"; read -r ans
    case "$ans" in
      y|Y) ;;
      *) entries="$(printf '%s' "$entries" | awk -F'\t' '$3 == 0')"
         n=$((n - ndirty))
         if [ "$n" -le 0 ]; then echo "nothing left to remove"; sleep 1.2; return; fi ;;
    esac
  fi

  local trash batch i=0 removed=0 gone="" saved="" snap ref wins w
  batch="$(date +%s).$$"
  trash="$WT_TRASH/$batch"
  if ! mkdir -p "$trash"; then echo "cannot create $trash"; sleep 2; return; fi
  while IFS=$'\t' read -r path branch dirty; do
    [ -n "$path" ] || continue
    i=$((i+1))
    # Snapshot the dirt BEFORE anything destructive, and refuse to remove a
    # worktree we couldn't snapshot: this batch's trash is swept immediately, so
    # "yes" to the prompt above used to mean the changes were unrecoverable the
    # moment it was answered.
    if [ "$dirty" = 1 ]; then
      snap="$(wt_snapshot_worktree "$path" "wt-trash: $branch")"
      if [ -z "$snap" ]; then echo "could not snapshot $branch — keeping it"; continue; fi
      ref="$(wt_backup_ref "$batch" "$(printf '%03d' "$i")" "$branch" "$snap")" \
        && saved="$saved$ref"$'\n'
    fi
    # Collect the windows BEFORE the mv: a pane whose cwd is renamed out from
    # under it reports the NEW path, so afterwards nothing matches any more.
    wins="$(windows_for_path "$path" -a)"
    if mv "$path" "$trash/$i" 2>/dev/null; then
      removed=$((removed+1))
      gone="$gone$branch"$'\n'
      # every session, not just this one — a window left pointing at a deleted
      # directory is broken wherever it lives. Name match stays as the fallback
      # for a window whose pane has cd'd elsewhere.
      while IFS= read -r w; do
        [ -n "$w" ] && tmux kill-window -t "$w" 2>/dev/null
      done <<< "$wins"
      tmux kill-window -t "$session:$(win_name "$branch")" 2>/dev/null || true
    else
      echo "could not move $branch ($path) — skipped"
    fi
  done <<< "$entries"
  git worktree prune 2>/dev/null || true
  echo "removed $removed worktree(s)"
  if [ -n "$saved" ]; then
    printf 'uncommitted changes saved — recover with \033[36mgit switch -c <name> <ref>\033[0m:\n'
    printf '%s' "$saved" | sed 's/^/  /'
  fi

  # Aggregated branch cleanup (one prompt per kind, not per branch): merged
  # branches default to YES; unmerged ones need an explicit force past a
  # warning, so unmerged work is never silently dropped.
  # `git branch -d/-D` also removes the branch's [branch …] config section.
  #
  # "Merged" is wt_merged_into, against a base refreshed a moment ago — it counts
  # squash- and rebase-merges, which the plain ancestor test cannot see. That
  # matters here more than anywhere: a shipped branch landing in the "NOT merged"
  # list is a warning you learn to ignore, and the next time it's real you force
  # past it out of habit.
  local base merged="" unmerged="" nm=0 nu=0 b
  await_base_fetch
  base="$(wt_default_base)"
  [ "$removed" -gt 0 ] && printf 'checking branches against %s…\n' "$(wt_base_display "$base")"
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    [ "$b" = "(detached)" ] && continue
    git show-ref --verify --quiet "refs/heads/$b" || continue
    if wt_merged_into "$b" "$base"; then
      merged="$merged$b"$'\n'; nm=$((nm+1))
    else
      unmerged="$unmerged$b"$'\n'; nu=$((nu+1))
    fi
  done <<< "$gone"
  if [ "$nm" -gt 0 ]; then
    printf 'delete %d merged branch(es)? [Y/n] ' "$nm"; read -r ans
    case "$ans" in
      n|N) ;;
      *) while IFS= read -r b; do
           [ -n "$b" ] && delete_merged_branch "$b"
         done <<< "$merged" ;;
    esac
  fi
  if [ "$nu" -gt 0 ]; then
    printf '%d branch(es) NOT merged into %s:\n' "$nu" "$(wt_base_display "$base")"
    printf '%s' "$unmerged" | sed 's/^/  /'
    printf 'force-delete them? their tips are kept as refs first [y/N] '; read -r ans
    case "$ans" in
      y|Y) local k=0 tip
           saved=""
           while IFS= read -r b; do
             [ -n "$b" ] || continue
             k=$((k+1))
             # `git branch -D` leaves the commits reachable only from the branch
             # reflog, which the branch deletion takes with it — recovery then
             # means `git fsck --lost-found`. A ref costs nothing and keeps the
             # tip addressable until wt_prune_backups expires it.
             tip="$(git rev-parse -q --verify "refs/heads/$b" 2>/dev/null)"
             ref="$(wt_backup_ref "$batch" "b$(printf '%03d' "$k")" "$b" "$tip")" \
               && saved="$saved$ref"$'\n'
             git branch -D "$b" >/dev/null 2>&1 || printf '  could not delete %s\n' "$b"
           done <<< "$unmerged"
           if [ -n "$saved" ]; then
             printf 'tips kept — restore with \033[36mgit branch <name> <ref>\033[0m:\n'
             printf '%s' "$saved" | sed 's/^/  /'
           fi ;;
    esac
  fi

  # sweep this batch's trash server-side (survives the popup closing) and drop
  # the empty parents slashed branches leave behind (feat/x → feat/).
  tmux run-shell -b "rm -rf '$trash'" 2>/dev/null || true
  find "$wt_root" -mindepth 1 -type d -empty -delete 2>/dev/null || true
  sleep 0.8
}

# ctrl-g: reap — batch-remove every clean worktree already merged into the
# default base. Candidacy (linked + clean + merged incl. squash/rebase merges) is
# wt_reap_candidates in worktree-core.sh; the current worktree is additionally
# excluded by batch_remove's own guard. One confirm, then trash-and-sweep.
# The base is refreshed first (await_base_fetch) — reap's whole value is that it
# knows what has landed, and it knew nothing newer than your last fetch.
reap_merged() {
  local cand base
  await_base_fetch
  base="$(wt_base_display)"
  echo "checking which worktrees are merged into $base…"
  cand="$(wt_reap_candidates)"
  if [ -z "$cand" ]; then
    echo "nothing to reap — no clean worktree is fully merged into $base"
    sleep 1.5
    return
  fi
  echo "reap: clean worktrees already merged into $base"
  batch_remove "$cand"
}

# --- PR picker ------------------------------------------------------------------

# ctrl-p: open GitHub PRs via gh; enter fetches the PR head into a local branch
# (refs/pull/<n>/head exists for fork PRs too) and reuses the normal create
# path — wt_add's existing-branch fallback checks it out, then window, file
# seed, install + agent as usual. ctrl-o opens the PR in the browser instead;
# esc returns to the worktree list.
# Output contract HERE is two lines (--expect without --print-query): line 1 =
# pressed key, line 2 = selected row.
# Returns 0 only when a worktree was created (the caller then exits the popup).
#
# The PR list is memoized for the POPUP's lifetime (pr_cache): esc-ing out of
# the picker and re-entering skips the loading screen. ctrl-r inside the picker
# clears the memo and refetches; a fresh popup always fetches anew (the cache
# dies with the process — no files, no TTL, no invalidation to get wrong).
# A stale row is harmless for checkout: enter fetches the PR's LIVE head ref.
# An empty result is deliberately NOT memoized, so "no open PRs" re-checks.
pr_cache=""

pick_pr() {
  local prs out key row branch num
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI not found"; sleep 1.5; return 1
  fi
  while true; do
    if [ -n "$pr_cache" ]; then
      prs="$pr_cache"
    else
      echo "fetching open PRs…"
      if ! prs="$(gh pr list --limit 50 --json number,title,headRefName,author \
          --template '{{range .}}#{{.number}} {{.title}} — {{.author.login}}{{"\t"}}{{.headRefName}}{{"\t"}}{{.number}}{{"\n"}}{{end}}' 2>&1)"; then
        printf '%s\n' "$prs"; sleep 2.5; return 1
      fi
      if [ -z "$prs" ]; then echo "no open PRs"; sleep 1.5; return 1; fi
      pr_cache="$prs"
    fi
    out="$(printf '%s\n' "$prs" | fzf \
      --ansi --cycle --layout=reverse \
      --delimiter='\t' --with-nth=1 \
      --padding=1,2 \
      --prompt='pr ❯ ' --pointer='▌' --info=inline-right \
      --header='enter: checkout into a worktree   ctrl-o: browser   ctrl-r: refresh   esc: back' \
      --expect=ctrl-o,ctrl-r \
      --bind 'ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up' \
      --color="$fzf_colors" \
      --preview='GH_FORCE_TTY=$FZF_PREVIEW_COLUMNS gh pr view {3} 2>/dev/null' \
      --preview-label=' pr ' \
      --preview-window='right,55%,wrap')" || return 1   # esc / no pick → back
    key="$(printf '%s\n' "$out" | sed -n '1p')"
    row="$(printf '%s\n' "$out" | sed -n '2p')"
    if [ "$key" = "ctrl-r" ]; then pr_cache=""; continue; fi
    break
  done
  branch="$(printf '%s' "$row" | cut -f2)"
  num="$(printf '%s' "$row" | cut -f3)"
  [ -n "$branch" ] || return 1
  if [ "$key" = "ctrl-o" ]; then
    gh pr view --web "$num" >/dev/null 2>&1 || true
    return 1
  fi
  # An existing local branch is used as-is (likely this PR's, from an earlier
  # checkout; never force-move a local branch — it may hold local commits).
  # Otherwise fetch the PR head into a new local branch of the same name.
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "using existing local branch $branch"
  elif ! git fetch origin "pull/$num/head:$branch"; then
    sleep 2.5; return 1
  fi
  create_worktree "$branch"
}

# --- pick & dispatch ------------------------------------------------------------

# Looped so remove (ctrl-x) and reap (ctrl-g) can return to a refreshed list.
# switch / create / PR-checkout break the loop with `exit`; remove, reap, a
# cancelled PR pick, and a failed create fall through and re-run fzf.
# esc / ctrl-c (fzf exit 130) closes the whole popup.
while true; do
  out="$(list_worktrees | fzf \
    --ansi --multi --cycle --layout=reverse \
    --delimiter='\t' --with-nth=1 \
    --padding=1,2 \
    --prompt='❯ ' --pointer='▌' --marker='✓' --info=inline-right \
    --ghost='filter, or type a new branch name' \
    --header=$'enter switch/create   ctrl-n new-from-name   tab/ctrl-a mark\nctrl-x remove   ctrl-g reap merged   ctrl-p PRs   ctrl-d/u preview' \
    --print-query \
    --expect=ctrl-n,ctrl-x,ctrl-g,ctrl-p \
    --bind 'ctrl-a:toggle-all,ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up' \
    --color="$fzf_colors" \
    --preview='git -C {2} -c color.status=always status -sb 2>/dev/null; echo; git -C {2} log --color=always --oneline -8 2>/dev/null' \
    --preview-label=' status · log ' \
    --preview-window='right,55%,wrap')"
  code=$?
  [ "$code" -eq 130 ] && exit 0   # esc / ctrl-c

  query="$(printf '%s\n' "$out" | sed -n '1p')"
  key="$(printf '%s\n'   "$out" | sed -n '2p')"
  # with --multi, everything from line 3 on is a selected row (the marked ones,
  # or just the highlighted row when nothing is marked)
  selections="$(printf '%s\n' "$out" | sed -n '3,$p')"
  choice="$(printf '%s\n' "$selections" | sed -n '1p')"
  sel_path="$(printf '%s' "$choice" | cut -f2)"
  sel_branch="$(printf '%s' "$choice" | cut -f3)"

  case "$key" in
    # force-create from the typed name; on failure, loop back to the list.
    ctrl-n) create_worktree "$query" && exit 0 ;;
    # batch-remove the marked rows (or the highlighted one); always loops back.
    ctrl-x) batch_remove "$(printf '%s\n' "$selections" | cut -f2,3)" ;;
    # reap merged+clean worktrees; always loops back.
    ctrl-g) reap_merged ;;
    # PR picker: exits the popup only when a worktree was actually created.
    ctrl-p) pick_pr && exit 0 ;;
    # plain enter: switch to the (first) selected row; if nothing matched the
    # typed query, treat enter as "create it". Both exit the popup on success.
    *)
      if [ -n "$sel_path" ]; then
        switch_worktree "$sel_path" "$sel_branch"; exit 0
      elif [ -n "$query" ]; then
        create_worktree "$query" && exit 0
      else
        exit 0   # empty query, nothing highlighted — nothing to do
      fi
      ;;
  esac
done
