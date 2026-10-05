#!/usr/bin/env bash
# machine-context.sh — SessionStart hook for this repository: prints which
# machine the session is on, and what differs there, into its context.
#
# The untracked one-word ~/.config/machine names the machine, the key
# .zshenv uses for hosts/<name>.zsh (docs/zsh.md § Machines). The text is
# .claude/machines/<name>.md. Every machine's file is tracked, so the tree is
# the same everywhere and mini-sync has nothing per machine to overwrite; the
# marker lives outside the tree. An unidentified machine is said aloud rather
# than guessed, because the wrong guess on the mini loses edits.
#
# No matcher in settings.json: a resumed session may have moved machines
# (claude-tomini), and a compacted one has lost the text.
set -u

dir="$(cd "$(dirname "$0")/.." && pwd)/machines"
marker="$HOME/.config/machine"
name=""
[[ -r $marker ]] && name=$(tr -d '[:space:]' < "$marker")

if [[ -n $name && -r $dir/$name.md ]]; then
  cat "$dir/$name.md"
  exit 0
fi

if [[ -z $name ]]; then why="~/.config/machine is missing or empty"
else why="~/.config/machine names '$name', which has no .claude/machines/$name.md"
fi
cat <<MSG
This machine is not identified: $why.
On the mini this checkout is a mirror that the mac overwrites, so an edit
made there is lost. Ask the user which machine this is before editing
anything in this repository; the marker holds one word, \`mac\` or \`mini\`.
MSG
