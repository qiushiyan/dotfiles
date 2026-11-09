# The second office mini, the office workstation (docs/qiushi-mini-2.md), where
# ~/.config/machine says `mini2`. .zshenv sources this last, in every shell.
# Only what is about being this machine belongs here; a tool's setup goes in
# the shared files behind a check for the tool.

# Machine badge: the shared oh-my-posh prompt and tmux status bar read it.
export PROMPT_MACHINE=mini2

# The login ~/.claude holds here; the primary answers to its local part
# (claude.zsh, _claude_primary).
(( $+functions[_claude_primary] )) && _claude_primary qiushi@planlab.ai   # x-qiushi too

# A batch runs four or five planlab sessions here, and a multi-file vitest run
# sizes its pool to the machine (cores minus one, 14 here), so their test runs
# oversubscribe the 15 cores and tests time out under load. vitest reads this
# after its config and flags, so it caps every run however it was typed; CI
# never sees it. planlab docs/devpool/qiushi/README.md, M2.
export VITEST_MAX_WORKERS=3

# Reached from the laptop over ssh as the mini is, so the same two fixes
# (hosts/mini.zsh says why): OSC 8 links over sshd, and URLs that follow the
# screen last typed at.
[[ -n $SSH_CONNECTION ]] && export FORCE_HYPERLINK=1
export BROWSER="$HOME/.local/bin/browser-clip"

# aws sso login's default flow redirects to a localhost listener here, which a
# browser on the laptop can't reach; the device-code flow works from any
# browser, at the desk or over ssh.
aws() {
  if [[ $1 == sso && $2 == login && " $* " != *" --use-device-code "* ]]; then
    command aws "$@" --use-device-code
  else
    command aws "$@"
  fi
}

alias v=nvim
