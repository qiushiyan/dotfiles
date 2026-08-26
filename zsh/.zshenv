
# Keep $PATH free of duplicates regardless of how config is (re)loaded.
typeset -U path PATH

. "$HOME/.cargo/env"

# Homebrew (Apple Silicon) — make /opt/homebrew/bin available to ALL zsh
# invocations, including non-interactive SSH sessions. /etc/zprofile only
# loads for login shells, so `ssh host cmd` (e.g. mosh spawning mosh-server)
# would otherwise miss it. Idempotent.
if [[ -x /opt/homebrew/bin/brew && ":$PATH:" != *":/opt/homebrew/bin:"* ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

[ -f "$HOME/.config/zsh/toolchain.zsh" ] && source "$HOME/.config/zsh/toolchain.zsh"

# Default locale for non-interactive shells (e.g., SSH command execution).
# mosh-server refuses to start without a UTF-8 locale, and macOS doesn't set
# one in non-login non-interactive shells.
: "${LANG:=en_US.UTF-8}"
: "${LC_ALL:=en_US.UTF-8}"
export LANG LC_ALL

# Custom functions (sourced here so they're available in all zsh invocations)
# Stub compdef to suppress errors; remove it after so compinit can define the real one
(( $+functions[compdef] )) || { compdef() { : }; _compdef_stub=1 }
for f in ~/.config/zsh/*.zsh(N); do
  [[ "$f:t" == "toolchain.zsh" ]] && continue
  source "$f"
done
if (( _compdef_stub )); then
  unfunction compdef
  unset _compdef_stub
fi

# ── EQUALS off ────────────────────────────────────────────  docs/zsh.md
# zsh expands a leading-`=` word to that command's path (`=ls` → /bin/ls),
# on assignment right-hand sides too (`x==ls`). Nothing here uses it, and it
# is fatal to agent-authored one-liners: `cat a; echo ====; cat b` becomes a
# lookup for a command named `===`, which aborts the eval'd line — so `cat b`
# silently never runs and only the trailing error says so. Here rather than
# in .zshrc because the shells that hit it are non-interactive.
unsetopt EQUALS
