#!/usr/bin/env bash
# tmux-gopen.sh — prefix g: open the pane's repo on GitHub.
#
# A thin bridge to the `gopen` CLI on PATH (~/dev/gopen; its README owns every
# resolution rule: PR thread > branch tree > commit tree, the per-branch PR
# cache, the SSH-shorthand rewrite, the browser opener). This script adds no
# policy of its own — it supplies the cwd and pane only tmux knows, and turns
# gopen's one interactive moment, the push prompt, into a tmux confirm-before.
#
# The contract with gopen is its stdout and exit code, never its stderr
# wording: on success stdout is the URL it opened; exit 3 means the branch is
# not on origin and nothing was opened. stdin is /dev/null, so gopen never
# prompts here — without a terminal it answers exit 3 instead.
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

command -v gopen >/dev/null 2>&1 ||
  { msg "gopen: not on PATH — (cd ~/dev/gopen && make install)"; exit 0; }

# push: the user confirmed below. -y pushes -u, then opens the PR-create page.
# A plain word, not an array: macOS bash 3.2 calls an empty "${a[@]}" unbound.
yes=
[[ "$mode" == push ]] && yes=-y

err_file=$(mktemp "${TMPDIR:-/tmp}/tmux-gopen.XXXXXX") || exit 0
# run-shell sets no TMUX_PANE. The mini's $BROWSER (browser-clip) picks the
# laptop or the mini's own screen from the clients on this pane's session.
url=$(TMUX_PANE=$pane_id gopen $yes </dev/null 2>"$err_file")
rc=$?
# gopen's own verdict is its last stderr line; git push output comes before it.
err=$(tail -n 1 "$err_file"); rm -f "$err_file"

case "$rc:$mode" in
  0:push) msg "gopen: pushed, opening $url" ;;
  0:*)    msg "gopen: $url" ;;
  3:open)
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
    ;;
  *) msg "${err:-gopen: failed (exit $rc)}" ;;
esac
exit 0
