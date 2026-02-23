
. "$HOME/.cargo/env"

# Custom functions (sourced here so they're available in all zsh invocations)
# Stub compdef to suppress errors; remove it after so compinit can define the real one
(( $+functions[compdef] )) || { compdef() { : }; _compdef_stub=1 }
for f in ~/.config/zsh/*.zsh(N); do
  source "$f"
done
(( _compdef_stub )) && unfunction compdef && unset _compdef_stub
