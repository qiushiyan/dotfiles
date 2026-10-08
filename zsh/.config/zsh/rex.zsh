# Rex (an experiment, ~/dotfiles/rex/README.md): an interactive shell inside
# Rex makes sure the lab's background watcher, rexd, runs on the server; it
# numbers the tabs. Detached, so startup does not wait for it.
if [[ -o interactive && -n $REX_BLOCK ]] && (( $+commands[rexd] )); then
  rexd &>/dev/null &!
fi
