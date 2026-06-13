#!/usr/bin/env bash
# tmux-worktree.sh — unified git-worktree popup for tmux (bound to prefix W).
#
# Launched from a tmux display-popup. Lists the current repo's worktrees in fzf:
#   enter    switch to (or create) that worktree's window in the current session
#   ctrl-n   create a new worktree + branch from the TYPED name, open its window
#   ctrl-x   remove the selected worktree (refuses if dirty, unless you force it)
#
# New worktrees go under  ~/dev/.worktrees/<repo>/<branch>  for every project
# (no per-repo special-casing). Create does only that — make the worktree and
# open its window in the current session; no post-creation commands.
#
# No args: the session is self-detected via `tmux display-message`, and $PWD is
# the repo (the popup is opened there by `display-popup -d` in the keybinding).
# NB: display-popup does NOT expand #{...} in its command argument, so the
# session must be self-detected, not passed as $1 (it would arrive literally).

set -u

session="$(tmux display-message -p '#{session_name}' 2>/dev/null)"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "not inside a git repository: $PWD"
  sleep 1.5
  exit 0
fi

# --- repo identity & worktree root -------------------------------------------

# every project's worktrees live under one root, grouped by repo dir name.
wt_root="$HOME/dev/.worktrees/$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"

main_worktree() {
  git worktree list --porcelain | awk '/^worktree /{print substr($0,10); exit}'
}

default_base() {
  local b
  for b in origin/HEAD origin/main origin/master main master; do
    if git rev-parse --verify --quiet "$b" >/dev/null 2>&1; then echo "$b"; return; fi
  done
  git rev-parse --abbrev-ref HEAD
}

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

create_worktree() {
  local name path win base tmp
  name="$(printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [ -z "$name" ]; then
    echo "type a branch name first, then press ctrl-n"; sleep 1.5; return
  fi
  path="$wt_root/$name"
  win="$(win_name "$name")"
  if [ -e "$path" ]; then echo "path already exists: $path"; sleep 1.5; return; fi
  base="$(default_base)"
  tmp="$(mktemp)"
  mkdir -p "$(dirname "$path")"
  if git worktree add -b "$name" "$path" "$base" 2>"$tmp"; then
    :
  elif git worktree add "$path" "$name" 2>>"$tmp"; then
    :  # branch already existed — checked it out into the worktree instead
  else
    echo "git worktree add failed:"; cat "$tmp"; rm -f "$tmp"; sleep 2.5; return
  fi
  rm -f "$tmp"
  tmux new-window -t "$session" -n "$win" -c "$path"
}

remove_worktree() {
  local path branch win main ans err tmp
  path="$1"; branch="$2"
  [ -z "$path" ] && return
  main="$(main_worktree)"
  if [ "$path" = "$main" ]; then echo "refusing to remove the main worktree"; sleep 1.5; return; fi
  printf 'remove worktree "%s"\n  %s ? [y/N] ' "$branch" "$path"; read -r ans
  case "$ans" in y|Y) ;; *) return ;; esac
  win="$(win_name "$branch")"
  tmp="$(mktemp)"
  if git worktree remove "$path" 2>"$tmp"; then
    tmux kill-window -t "$session:$win" 2>/dev/null || true
    printf 'also delete branch "%s"? [y/N] ' "$branch"; read -r ans
    case "$ans" in y|Y) git branch -D "$branch" 2>/dev/null || true ;; esac
  else
    err="$(cat "$tmp")"
    echo "could not remove: $err"
    printf 'force-remove (DISCARDS uncommitted changes)? [y/N] '; read -r ans
    case "$ans" in
      y|Y) git worktree remove --force "$path" && tmux kill-window -t "$session:$win" 2>/dev/null || true ;;
    esac
  fi
  rm -f "$tmp"
}

# --- pick & dispatch ---------------------------------------------------------

out="$(list_worktrees | fzf \
  --ansi \
  --delimiter='\t' --with-nth=1 \
  --prompt='worktree> ' \
  --header='enter: switch    ctrl-n: new (type a name)    ctrl-x: remove' \
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
  ctrl-n) create_worktree "$query" ;;
  ctrl-x) remove_worktree "$sel_path" "$sel_branch" ;;
  *)      [ -n "$sel_path" ] && switch_worktree "$sel_path" "$sel_branch" ;;
esac
