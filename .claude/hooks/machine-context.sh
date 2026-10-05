#!/usr/bin/env bash
# machine-context.sh — SessionStart hook for this repository: prints which
# machine the session is on, and what differs there, into its context.
#
# The untracked one-word ~/.config/machine names the machine, the key
# .zshenv uses for hosts/<name>.zsh (docs/zsh.md § Machines). The text is
# .claude/machines/<name>.md. Every machine's file is tracked, so the tree is
# the same in both clones; the marker lives outside the tree. An unidentified
# machine is said aloud rather than guessed: the marker also picks the launchd
# package and the Codex fragment, and a wrong guess activates the other
# machine's.
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
  # What this checkout has unsent or behind, on both machines, from twin's
  # recorded observations: --recorded asks neither the network nor the other
  # machine. A twin that is absent, or slower than the limit, adds nothing.
  if command -v twin >/dev/null 2>&1; then
    state=$(perl -e 'alarm shift; exec @ARGV' "${TWIN_HOOK_LIMIT:-4}" twin status dotfiles --recorded 2>/dev/null)
    rc=$?
    if (( rc <= 2 )) && [[ -n $state ]]; then
      printf '\n`twin status dotfiles --recorded`, as this session started:\n\n%s\n' "$state"
    fi
  fi
  exit 0
fi

if [[ -z $name ]]; then why="~/.config/machine is missing or empty"
else why="~/.config/machine names '$name', which has no .claude/machines/$name.md"
fi
cat <<MSG
This machine is not identified: $why.
The marker picks this machine's launchd agents and Codex settings, and twin
refuses to run without it, so nothing machine-specific is stowed or rendered
until it exists. Ask the user which machine this is before running
\`make restow\` or \`twin\` here; the marker holds one word, \`mac\` or \`mini\`.
MSG
