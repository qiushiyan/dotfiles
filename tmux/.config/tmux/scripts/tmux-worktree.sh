#!/usr/bin/env bash
# tmux-worktree.sh — unified git-worktree popup for tmux (bound to prefix W).
#
# Launched from a tmux display-popup. Lists the current repo's worktrees in fzf
# (» marks the worktree you're in, * marks a dirty one):
#   enter        switch to the highlighted worktree's window; if the typed name
#                matches nothing, create that worktree + branch and open its window
#   ctrl-n       force-create a worktree + branch from the TYPED name (even when
#                the query still fuzzy-matches an existing worktree)
#   tab/ctrl-a   mark one / toggle all entries (shift-tab unmarks)
#   ctrl-x       remove the marked worktrees (or the highlighted one if none are
#                marked) as ONE confirmed batch — trash-and-sweep, see below
#   ctrl-g       reap: batch-remove every clean worktree whose branch is already
#                merged into the default base (end-of-week cleanup in 3 keys)
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
# are killed, branch deletion is offered in aggregate (merged → safe -d behind
# one [Y/n]; unmerged → explicit force), and the real rm -rf runs server-side
# in the background via `tmux run-shell -b`, so it survives the popup closing.
# Because mv bypasses `git worktree remove`'s dirty-refusal, THIS script owns
# the dirty check: dirty worktrees are flagged in the confirm list and their
# changes are only discarded after a second explicit [y/N] (declining keeps
# them and removes just the clean ones).
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

# --- trash (removal staging) --------------------------------------------------

# Batch removal stages worktrees here (same filesystem as wt_root, so mv is a
# rename) and sweeps in the background. Self-heal on startup: sweep whatever a
# crashed/killed popup left behind — but only entries older than 2 minutes, so
# this can never race the sweep another live popup just scheduled.
WT_TRASH="$HOME/dev/.worktrees/.trash"
tmux run-shell -b "find '$WT_TRASH' -mindepth 1 -maxdepth 1 -mmin +2 -exec rm -rf {} + 2>/dev/null; true" 2>/dev/null || true

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
# * (yellow) = dirty. Plain ANSI colors so the terminal theme maps them.
list_worktrees() {
  git worktree list --porcelain | awk '
    /^worktree /{p = substr($0, 10)}
    /^branch /  {b = $2; sub("refs/heads/", "", b); print b "\t" p}
    /^detached$/{print "(detached)\t" p}
  ' | while IFS=$'\t' read -r branch path; do
    here=" "; dirty=" "
    [ "$path" = "$cur_top" ] && here=$'\033[32m»\033[0m'
    [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ] && dirty=$'\033[33m*\033[0m'
    printf '%s%s %s\t%s\t%s\n' "$here" "$dirty" "$branch" "$path" "$branch"
  done
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

switch_worktree() {
  local path branch win
  path="$1"; branch="$2"
  win="$(win_name "$branch")"
  if tmux list-windows -t "$session" -F '#W' 2>/dev/null | grep -qxF "$win"; then
    tmux select-window -t "$session:$win"
  else
    tmux new-window -t "$session" -n "$win" -c "$path"
  fi
  # landing on a worktree window clears its agent-done dot (we know the window
  # by name, so clear it explicitly) and refreshes the ◷ badge.
  tmux set-option -w -t "$session:$win" @agent_done 0 2>/dev/null || true
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
    printf 'DISCARD the uncommitted changes in the %d dirty one(s)? [y/N] ' "$ndirty"; read -r ans
    case "$ans" in
      y|Y) ;;
      *) entries="$(printf '%s' "$entries" | awk -F'\t' '$3 == 0')"
         n=$((n - ndirty))
         if [ "$n" -le 0 ]; then echo "nothing left to remove"; sleep 1.2; return; fi ;;
    esac
  fi

  local trash i=0 removed=0 gone=""
  trash="$WT_TRASH/$(date +%s).$$"
  if ! mkdir -p "$trash"; then echo "cannot create $trash"; sleep 2; return; fi
  while IFS=$'\t' read -r path branch dirty; do
    [ -n "$path" ] || continue
    i=$((i+1))
    if mv "$path" "$trash/$i" 2>/dev/null; then
      removed=$((removed+1))
      gone="$gone$branch"$'\n'
      tmux kill-window -t "$session:$(win_name "$branch")" 2>/dev/null || true
    else
      echo "could not move $branch ($path) — skipped"
    fi
  done <<< "$entries"
  git worktree prune 2>/dev/null || true
  echo "removed $removed worktree(s)"

  # Aggregated branch cleanup (one prompt per kind, not per branch): merged
  # branches default to YES with the safe -d; unmerged ones need an explicit
  # force past a warning, so unmerged work is never silently dropped.
  # `git branch -d/-D` also removes the branch's [branch …] config section.
  local base merged="" unmerged="" nm=0 nu=0 b
  base="$(wt_default_base)"
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    [ "$b" = "(detached)" ] && continue
    git show-ref --verify --quiet "refs/heads/$b" || continue
    if git merge-base --is-ancestor "$b" "$base" 2>/dev/null; then
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
           [ -n "$b" ] && git branch -d "$b" 2>/dev/null
         done <<< "$merged" ;;
    esac
  fi
  if [ "$nu" -gt 0 ]; then
    printf '%d branch(es) NOT merged into %s:\n' "$nu" "$base"
    printf '%s' "$unmerged" | sed 's/^/  /'
    printf 'force-delete them (drops their commits)? [y/N] '; read -r ans
    case "$ans" in
      y|Y) while IFS= read -r b; do
             [ -n "$b" ] && git branch -D "$b" 2>/dev/null
           done <<< "$unmerged" ;;
    esac
  fi

  # sweep this batch's trash server-side (survives the popup closing) and drop
  # the empty parents slashed branches leave behind (feat/x → feat/).
  tmux run-shell -b "rm -rf '$trash'" 2>/dev/null || true
  find "$wt_root" -mindepth 1 -type d -empty -delete 2>/dev/null || true
  sleep 0.8
}

# ctrl-g: reap — batch-remove every clean worktree already merged into the
# default base. Candidacy (linked + clean + merged, squash-merges excluded) is
# wt_reap_candidates in worktree-core.sh; the current worktree is additionally
# excluded by batch_remove's own guard. One confirm, then trash-and-sweep.
reap_merged() {
  local cand
  cand="$(wt_reap_candidates)"
  if [ -z "$cand" ]; then
    echo "nothing to reap — no clean worktree is fully merged into $(wt_default_base)"
    sleep 1.5
    return
  fi
  echo "reap: clean worktrees already merged into $(wt_default_base)"
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
