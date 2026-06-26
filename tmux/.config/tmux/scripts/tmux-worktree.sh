#!/usr/bin/env bash
# tmux-worktree.sh — unified git-worktree popup for tmux (bound to prefix W).
#
# Launched from a tmux display-popup. Lists the current repo's worktrees in fzf:
#   enter    switch to the highlighted worktree's window; if the typed name
#            matches nothing, create that worktree + branch and open its window
#   ctrl-n   force-create a worktree + branch from the TYPED name (even when the
#            query still fuzzy-matches an existing worktree), open its window
#   ctrl-x   remove the selected worktree (refuses if dirty, unless you force it)
#
# switch / create are EXIT operations (you land in the target window and the
# popup closes); remove is an IN-POPUP operation (it loops back to the refreshed
# list so you can remove more or pick again). A failed create also loops back.
#
# New worktrees go under  ~/dev/.worktrees/<repo>/<branch>  for every project
# (no per-repo special-casing). Create makes the worktree, opens its window, then:
#   - copies the gitignored files/dirs a checkout leaves behind (`.env* .npmrc
#     scripts.local .duet docs.local` by default, from the MAIN worktree, at any
#     depth; matched directories are copied whole) into the new tree — configurable
#     via @worktree_copy_globs ("off" to disable);
#   - if it's a Node project, fires a dependency install (pnpm/npm/yarn/bun, from
#     the lockfile) into the new window via send-keys, so the install runs visibly
#     there instead of blocking the popup — @worktree_auto_install off to disable.
#
# No args: the session is self-detected via `tmux display-message`, and $PWD is
# the repo (the popup is opened there by `display-popup -d` in the keybinding).
# NB: display-popup does NOT expand #{...} in its command argument, so the
# session must be self-detected, not passed as $1 (it would arrive literally).

set -u

# Pure git-worktree logic (path convention, base resolution, the worktree-add
# dance, gitignored-file seeding, pkg-manager detection) lives in the tmux-free
# worktree-core.sh, shared with the gwtn shell function. We add only tmux glue.
source "${BASH_SOURCE[0]%/*}/worktree-core.sh"

session="$(tmux display-message -p '#{session_name}' 2>/dev/null)"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "not inside a git repository: $PWD"
  sleep 1.5
  exit 0
fi

# --- repo identity & worktree root -------------------------------------------

# Path convention, main_worktree, and default_base now come from worktree-core.sh
# (wt_worktree_root / wt_main_worktree / wt_default_base). wt_root is resolved once
# here, exactly as before.
wt_root="$(wt_worktree_root)"

# --- list:  "<marker><branch>\t<path>\t<branch>"  (display = field 1) ---------

list_worktrees() {
  git worktree list --porcelain | awk '
    /^worktree /{p = substr($0, 10)}
    /^branch /  {b = $2; sub("refs/heads/", "", b); print b "\t" p}
    /^detached$/{print "(detached)\t" p}
  ' | while IFS=$'\t' read -r branch path; do
    marker="  "
    [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ] && marker="* "
    printf '%s%s\t%s\t%s\n' "$marker" "$branch" "$path" "$branch"
  done
}

# --- actions -----------------------------------------------------------------

win_name() { printf '%s' "$1" | tr '/' '-'; }

# If the new worktree is a Node project, kick off a dependency install VISIBLY in
# its new window via send-keys — NOT inside this script, which would freeze the
# modal popup for the whole install. You land in the window, watch it run, and can
# Ctrl-C it if you didn't want it. The package-manager SELECTION (by lockfile) is
# wt_install_cmd in worktree-core.sh; only the tmux DELIVERY lives here.
# Disable entirely with:  tmux set -g @worktree_auto_install off
maybe_install_deps() {
  local path="$1" target="$2" cmd
  [ -n "$target" ] || return
  case "$(tmux show-option -gqv @worktree_auto_install 2>/dev/null)" in
    off|0|false|no|disabled) return ;;
  esac
  cmd="$(wt_install_cmd "$path")"   # empty if not a Node project
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
  maybe_install_deps "$path" "$winid"
  return 0
}

# After a worktree is gone, offer to delete its branch too — called from BOTH the
# normal and force-removal paths so a branch (and its [branch …] config section,
# which `git branch -d/-D` removes with it) never leaks. Merged branches default to
# YES and use the safe `git branch -d`; unmerged branches default to NO and need an
# explicit force (`-D`) past a warning, so you can't silently drop unmerged work.
maybe_delete_branch() {
  local branch="$1" base ans
  [ -n "$branch" ] && [ "$branch" != "(detached)" ] || return
  base="$(wt_default_base)"
  if git merge-base --is-ancestor "$branch" "$base" 2>/dev/null; then
    printf 'delete merged branch "%s"? [Y/n] ' "$branch"; read -r ans
    case "$ans" in n|N) ;; *) git branch -d "$branch" 2>/dev/null || true ;; esac
  else
    printf 'branch "%s" is NOT merged into %s — force-delete it? [y/N] ' "$branch" "$base"; read -r ans
    case "$ans" in y|Y) git branch -D "$branch" 2>/dev/null || true ;; esac
  fi
}

remove_worktree() {
  local path branch win main ans err tmp
  path="$1"; branch="$2"
  [ -z "$path" ] && return
  main="$(wt_main_worktree)"
  if [ "$path" = "$main" ]; then echo "refusing to remove the main worktree"; sleep 1.5; return; fi
  printf 'remove worktree "%s"\n  %s ? [y/N] ' "$branch" "$path"; read -r ans
  case "$ans" in y|Y) ;; *) return ;; esac
  win="$(win_name "$branch")"
  tmp="$(mktemp)"
  if git worktree remove "$path" 2>"$tmp"; then
    tmux kill-window -t "$session:$win" 2>/dev/null || true
    maybe_delete_branch "$branch"
  else
    err="$(cat "$tmp")"
    echo "could not remove: $err"
    printf 'force-remove (DISCARDS uncommitted changes)? [y/N] '; read -r ans
    case "$ans" in
      y|Y)
        if git worktree remove --force "$path"; then
          tmux kill-window -t "$session:$win" 2>/dev/null || true
          maybe_delete_branch "$branch"
        fi ;;
    esac
  fi
  rm -f "$tmp"
}

# --- pick & dispatch ---------------------------------------------------------

# Looped so remove (ctrl-x) can return to a refreshed list. switch / create
# break the loop with `exit`; remove and a failed create fall through and re-run
# fzf. esc / ctrl-c (fzf exit 130) closes the whole popup.
while true; do
  out="$(list_worktrees | fzf \
    --ansi \
    --delimiter='\t' --with-nth=1 \
    --prompt='worktree> ' \
    --header='enter: switch / create if new    ctrl-n: force-new from name    ctrl-x: remove' \
    --print-query \
    --expect=ctrl-n,ctrl-x \
    --preview='git -C {2} -c color.status=always status -sb 2>/dev/null; echo; git -C {2} log --oneline -8 2>/dev/null' \
    --preview-window='right,55%,wrap')"
  code=$?
  [ "$code" -eq 130 ] && exit 0   # esc / ctrl-c

  query="$(printf '%s\n' "$out" | sed -n '1p')"
  key="$(printf '%s\n'   "$out" | sed -n '2p')"
  choice="$(printf '%s\n' "$out" | sed -n '3p')"
  sel_path="$(printf '%s' "$choice" | cut -f2)"
  sel_branch="$(printf '%s' "$choice" | cut -f3)"

  case "$key" in
    # force-create from the typed name; on failure, loop back to the list.
    ctrl-n) create_worktree "$query" && exit 0 ;;
    # remove always returns to the refreshed list (confirmed, cancelled, or failed).
    ctrl-x) remove_worktree "$sel_path" "$sel_branch" ;;
    # plain enter: switch to the highlighted row; if nothing matched the typed
    # query, treat enter as "create it". Both exit the popup on success.
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
