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

# If the new worktree is a Node project, kick off a dependency install VISIBLY in
# its new window via send-keys — NOT inside this script, which would freeze the
# modal popup for the whole install. You land in the window, watch it run, and
# can Ctrl-C it if you didn't want it. The package manager is chosen from the
# committed lockfile (so we never clobber an npm repo with a pnpm lockfile),
# defaulting to pnpm (this repo's convention) when none is present.
# Disable entirely with:  tmux set -g @worktree_auto_install off
maybe_install_deps() {
  local path="$1" target="$2" cmd
  [ -n "$target" ] || return
  case "$(tmux show-option -gqv @worktree_auto_install 2>/dev/null)" in
    off|0|false|no|disabled) return ;;
  esac
  [ -f "$path/package.json" ] || return
  if   [ -f "$path/pnpm-lock.yaml" ];    then cmd="pnpm install"
  elif [ -f "$path/yarn.lock" ];         then cmd="yarn"
  elif [ -f "$path/package-lock.json" ]; then cmd="npm install"
  elif [ -f "$path/bun.lockb" ] || [ -f "$path/bun.lock" ]; then cmd="bun install"
  else cmd="pnpm install"; fi
  # target by window-id (not name): new-window can make duplicate names.
  tmux send-keys -t "$target" "$cmd" Enter
}

# Seed the new worktree with the gitignored files/dirs a fresh checkout leaves
# behind (`.env*`, `.npmrc`, `scripts.local/` …), copied from the MAIN worktree.
# The pattern list lives in @worktree_copy_globs (space/newline-separated; default
# ".env* .npmrc scripts.local .duet docs.local"; set to "off" to disable). Each pattern matches an
# entry's BASENAME, so ".env*" catches env files at *any depth* (e.g.
# application/.env.development.local) and "scripts.local" matches that ignored
# directory; every match is recreated at the same relative path in the new tree,
# directories copied whole (-R). (.npmrc is only ever copied when it's gitignored
# — a tracked one already rides the checkout; see scope below.)
#
# Why `git ls-files -oi --exclude-standard --directory`:
#   -oi --exclude-standard  → only paths git is IGNORING (exactly what `worktree
#                             add` didn't bring over; never tracked paths, which
#                             already exist, nor random untracked WIP)
#   --directory             → collapses a wholly-ignored dir to ONE entry ("dir/")
#                             instead of every file under it (e.g. the hundreds of
#                             .env files dependencies ship inside node_modules/).
#                             We then copy that one entry recursively IF it matches
#                             a pattern — so the PATTERN is the only gate: node_
#                             modules/ & dist/ are excluded purely by not matching.
#                             Keep default patterns specific; a broad glob like "*"
#                             would now pull whole ignored dirs.
# Source is the main worktree (canonical home for these files) regardless of which
# worktree you launched the popup from. Perms are preserved (-pR) — env files are
# often mode 600, scripts often +x.
maybe_copy_files() {
  local newdir="$1" main globs rel relstripped src dst base pat copied=0
  main="$(main_worktree)"
  [ -n "$main" ] && [ "$main" != "$newdir" ] || return
  globs="$(tmux show-option -gqv @worktree_copy_globs 2>/dev/null)"
  case "$globs" in off|none|no|0|false|disabled) return ;; esac
  [ -z "$globs" ] && globs=".env* .npmrc scripts.local .duet docs.local"
  set -f; set -- $globs; set +f          # split patterns; never pathname-expand them
  while IFS= read -r -d '' rel; do
    relstripped="${rel%/}"                # --directory yields ignored dirs as "dir/"
    src="$main/$relstripped"
    [ -e "$src" ] || continue
    base="${relstripped##*/}"
    for pat in "$@"; do
      case "$base" in
        $pat)
          dst="$newdir/$relstripped"
          mkdir -p "$(dirname "$dst")"
          # -R copies a matched directory's whole tree (e.g. scripts.local/);
          # harmless on a plain file. Pattern is the only gate now, so node_modules/
          # & dist/ are excluded by NOT matching — keep the default patterns specific.
          cp -pR "$src" "$dst" 2>/dev/null && copied=$((copied + 1))
          break ;;
      esac
    done
  done < <(git -C "$main" ls-files -oi --exclude-standard --directory -z)
  [ "$copied" -gt 0 ] && tmux display-message "worktree: copied $copied item(s) from main" || true
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
  local name path win base tmp winid
  name="$(printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [ -z "$name" ]; then
    echo "type a name first"; sleep 1.5; return 1
  fi
  path="$wt_root/$name"
  win="$(win_name "$name")"
  if [ -e "$path" ]; then echo "path already exists: $path"; sleep 1.5; return 1; fi
  base="$(default_base)"
  tmp="$(mktemp)"
  mkdir -p "$(dirname "$path")"
  if git worktree add -b "$name" "$path" "$base" 2>"$tmp"; then
    :
  elif git worktree add "$path" "$name" 2>>"$tmp"; then
    :  # branch already existed — checked it out into the worktree instead
  else
    echo "git worktree add failed:"; cat "$tmp"; rm -f "$tmp"; sleep 2.5; return 1
  fi
  rm -f "$tmp"
  winid="$(tmux new-window -t "$session" -n "$win" -c "$path" -P -F '#{window_id}')"
  maybe_copy_files "$path"               # seed .env* etc. BEFORE install may need them
  maybe_install_deps "$path" "$winid"
  return 0
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
