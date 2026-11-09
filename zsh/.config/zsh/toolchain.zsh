# Shared tool paths for every zsh invocation, on every machine. Add CLI install
# directories here; a directory a machine lacks is a harmless PATH miss.
# .zshrc and .zlogin reapply this after profiles and plugins can reorder PATH.

typeset -U path PATH

# Homebrew's environment, as `brew shellenv` sets it for /opt/homebrew, without
# the fork: 15 ms in every login shell and in every shell started from a bare
# environment. Here, so that it is tracked and the reapplications put Homebrew
# back ahead of /usr/bin after /etc/zprofile's path_helper; a machine's
# ~/.zprofile needs no `brew shellenv` line. No fpath: .zshrc pins the
# completion directory for interactive shells, and an exported FPATH is the
# one thing it must never inherit (docs/zsh.md § Completion dump).
if [[ -x /opt/homebrew/bin/brew ]]; then
  export HOMEBREW_PREFIX=/opt/homebrew HOMEBREW_CELLAR=/opt/homebrew/Cellar HOMEBREW_REPOSITORY=/opt/homebrew
  path=(/opt/homebrew/bin /opt/homebrew/sbin $path)
  [[ -z ${MANPATH-} ]] || export MANPATH=":${MANPATH#:}"
  export INFOPATH="/opt/homebrew/share/info:${${INFOPATH-}#/opt/homebrew/share/info:}"
fi

export PATH="\
$HOME/.bun/bin:\
$HOME/bin:\
$HOME/.local/bin:\
/opt/homebrew/opt/postgresql@18/bin:\
/usr/local/bin:\
$PATH"

_nvm_dir="${NVM_DIR:-$HOME/.nvm}"
_nvm_alias_file="$_nvm_dir/alias/default"
if [[ -r "$_nvm_alias_file" ]]; then
  _nvm_default="${$(<"$_nvm_alias_file")%%[[:space:]]*}"
  _nvm_alias="$_nvm_default"
  for _nvm_alias_depth in 1 2 3; do
    _nvm_alias_file="$_nvm_dir/alias/$_nvm_alias"
    [[ -r "$_nvm_alias_file" ]] || break
    _nvm_alias="${$(<"$_nvm_alias_file")%%[[:space:]]*}"
  done
  _nvm_default="$_nvm_alias"
  _nvm_node_dir=""

  case "$_nvm_default" in
    v*)
      [[ -d "$_nvm_dir/versions/node/$_nvm_default" ]] && _nvm_node_dir="$_nvm_dir/versions/node/$_nvm_default"
      ;;
    [0-9]*)
      _nvm_matches=( "$_nvm_dir"/versions/node/v${_nvm_default}.*(Nn) )
      (( ${#_nvm_matches} )) && _nvm_node_dir="${_nvm_matches[-1]}"
      ;;
    node|stable)
      _nvm_matches=( "$_nvm_dir"/versions/node/v*(Nn) )
      (( ${#_nvm_matches} )) && _nvm_node_dir="${_nvm_matches[-1]}"
      ;;
  esac

  if [[ -n "$_nvm_node_dir" && -d "$_nvm_node_dir/bin" ]]; then
    export NVM_DIR="$_nvm_dir"
    export NVM_BIN="$_nvm_node_dir/bin"
    export NVM_INC="$_nvm_node_dir/include/node"
    path=( "$NVM_BIN" ${path:#$_nvm_dir/versions/node/*/bin} )
    export PATH
  fi
fi
unset _nvm_dir _nvm_alias_file _nvm_default _nvm_alias _nvm_alias_depth _nvm_node_dir _nvm_matches

[ -f "$HOME/google-cloud-sdk/path.zsh.inc" ] && source "$HOME/google-cloud-sdk/path.zsh.inc"

# pnpm global executables (including Obelisk).
export PNPM_HOME="$HOME/Library/pnpm"
path=("$PNPM_HOME/bin" $path)
export PATH
