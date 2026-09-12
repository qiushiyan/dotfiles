# Shared tool paths for every zsh invocation. Add CLI install directories here.
# .zshrc and .zlogin reapply this after profiles and plugins can reorder PATH.

typeset -U path PATH
export PATH="\
$HOME/.config/tmux/plugins/tmuxifier/bin:\
$HOME/.wasmtime/bin:\
$HOME/.bun/bin:\
$HOME/bin:\
$HOME/bin/elixir-ls:\
$HOME/.local/bin:\
$HOME/.mix/escripts:\
/opt/homebrew/opt/postgresql@16/bin:\
/opt/homebrew/opt/openjdk@11/bin:\
/usr/local/bin:\
$HOME/Library/Android/sdk/platform-tools:\
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
