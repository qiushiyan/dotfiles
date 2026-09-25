# The office mini (docs/qiushi-mini.md), where ~/.config/machine says `mini`.
# .zshenv sources this last, in every shell. Only what is about being this
# machine belongs here; a tool's setup goes in the shared files behind a check
# for the tool.

# Machine badge: the shared oh-my-posh prompt and tmux status bar read it.
export PROMPT_MACHINE=mini

# sshd does not forward TERM_PROGRAM, so Claude Code decides the terminal lacks
# OSC 8 support and prints URLs as plain text (no Ctrl-click). The laptop
# client (Ghostty -> tmux with the hyperlinks feature) passes OSC 8 through.
[[ -n $SSH_CONNECTION ]] && export FORCE_HYPERLINK=1
# A URL "opened" here (Claude Code Ctrl-click, gh --web, ...) goes to the
# laptop clipboard via OSC 52, not the mini's Safari.
[[ -n $SSH_CONNECTION ]] && export BROWSER="$HOME/.local/bin/browser-clip"

# aws sso login defaults to a browser flow that redirects to a localhost
# listener on this machine, which a laptop browser (ssh, BROWSER=browser-clip)
# can't reach. The device-code flow works from any browser: the URL carries
# the code, so paste it on the laptop and approve.
aws() {
  if [[ $1 == sso && $2 == login && " $* " != *" --use-device-code "* ]]; then
    command aws "$@" --use-device-code
  else
    command aws "$@"
  fi
}

alias v=nvim
