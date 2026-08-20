#!/usr/bin/env bash
# tmux-gopen.sh — prefix g: open the pane's repo on GitHub.
#
# A thin bridge to the `gopen` zsh function (zsh/.config/zsh/git.zsh), which owns
# every resolution rule: PR thread > branch tree > commit tree, the per-branch PR
# cache, the SSH-shorthand rewrite. This script adds no policy of its own — it
# supplies the cwd only tmux knows, and turns gopen's two interactive moments
# (the browser hand-off, the push prompt) into tmux gestures.
#
# git.zsh is sourced by a *non-interactive* zsh, not `zsh -ic`: the file is
# self-contained, so this skips the full interactive rc (~60ms vs ~400ms) and the
# `can't change option: zle` noise that comes with faking interactivity.
#
# Only the pane id and client name cross the binding boundary; the path is looked
# up here, so a quote or $ in a directory name never reaches a command line. That
# path comes from the pane's *foreground* process group, so it is right even
# while nvim or claude is running, and it is the worktree's own path when the
# pane sits in a worktree — which is what makes a worktree open its own branch.
#
# Always exits 0: a keybinding must never leave a run-shell error popup behind.

set -u

mode=${1:-open}
pane_id=${2:-}
client=${3:-}

msg() { tmux display-message -t "$pane_id" "$1" 2>/dev/null; }

pane_path=$(tmux display-message -p -t "$pane_id" '#{pane_current_path}' 2>/dev/null)
[[ -d "$pane_path" ]] || { msg "gopen: can't resolve this pane's path"; exit 0; }
cd "$pane_path" || exit 0

# gopen -y: push -u, then open the PR-create page. -y answers the prompt so no
# tty is needed, and gopen opens the browser itself — nothing left to do here.
if [[ "$mode" == push ]]; then
  if err=$(zsh -c 'source "$HOME/.config/zsh/git.zsh"; gopen -y' 2>&1 >/dev/null); then
    msg "gopen: pushed, opening the PR page"
  else
    msg "${err:-gopen: push failed}"
  fi
  exit 0
fi

# Resolve first: -n prints the URL, never pushes, never opens. That buys the URL
# for the status message and catches the unpushed case before anything happens.
err_file=$(mktemp)
url=$(zsh -c 'source "$HOME/.config/zsh/git.zsh"; gopen -n' 2>"$err_file")
rc=$?
warn=$(cat "$err_file"); rm -f "$err_file"

if (( rc != 0 )) || [[ -z "$url" ]]; then
  msg "${warn:-gopen: failed}"
  exit 0
fi

# The one case -n declines to handle: a branch GitHub has never seen. gopen falls
# back to the repo home and says so on stderr, and that sentence is the seam
# between the two halves — keep them in step if either side is reworded.
if [[ "$warn" == *"is not on origin"* ]]; then
  branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null)
  prompt="gopen: '$branch' isn't on origin. Push and open a PR? (y/n)"
  cmd="run-shell -b \"bash '$HOME/.config/tmux/scripts/tmux-gopen.sh' push '$pane_id' '$client'\""
  # -t "$client" is load-bearing. This script runs under `run-shell -b`, which
  # drops the client context the binding had, so an untargeted confirm-before
  # finds no client to prompt on and silently does nothing. The client name is
  # threaded in from the binding and back out into the recursive push call.
  if [[ -n "$client" ]]; then
    tmux confirm-before -t "$client" -p "$prompt" "$cmd" 2>/dev/null
  else
    tmux confirm-before -p "$prompt" "$cmd" 2>/dev/null
  fi
  exit 0
fi

zsh -c 'source "$HOME/.config/zsh/git.zsh"; _gopen_browser "$1"' _ "$url" 2>/dev/null
msg "gopen: $url"
exit 0
