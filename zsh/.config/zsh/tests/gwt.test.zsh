#!/usr/bin/env zsh
# Real shell helpers and installed gwt; every checkout/config stays in a temporary home.
emulate -L zsh
setopt err_exit pipe_fail
module="${0:A:h:h}/git.zsh"
core="${0:A:h:h:h:h:h}/tmux/.config/tmux/scripts/worktree-core.sh"
binary="$(command -v gwt)" || { print -u2 'gwt.test: install gwt on PATH first'; exit 1; }
sandbox="$(mktemp -d)"; sandbox="${sandbox:A}"
trap 'cd /; command rm -rf "$sandbox"' EXIT
export HOME="$sandbox" XDG_CONFIG_HOME="$sandbox/config"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset GWT_CONFIG GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
mkdir -p "$sandbox/bin" "$XDG_CONFIG_HOME/gwt"
cp "$binary" "$sandbox/bin/gwt"
export PATH="$sandbox/bin:$PATH"
source "$module"
# Capture completion specifications; no terminal or completion widget needed.
_arguments() { print -rl -- "$@"; }
words=(gwtcd ''); CURRENT=2
spec="$(_gwt)"
[[ "$spec" != *'create resolve path remove config'* ]] || {
  print -u2 'gwtcd completion offers non-creation commands'; exit 1
}
# Custom root and a caller branch different from the main checkout's branch.
print 'worktree_root = "~/custom trees"' > "$XDG_CONFIG_HOME/gwt/config.toml"
command git init -q -b main "$sandbox/repo"
cd "$sandbox/repo"
command git config user.name Test
command git config user.email test@example.invalid
print '.env' > .gitignore
command git add .gitignore
command git commit -qm initial
command git worktree add -qb topic "$sandbox/topic"
print prerequisite > .env
cd "$sandbox/topic"
command git commit --allow-empty -qm topic
expected="$(command git rev-parse HEAD)"
gwtcd --non-interactive feat/helper
[[ "$PWD" == "$sandbox/custom trees/repo/feat/helper" ]]
[[ "$(command git rev-parse HEAD)" == "$expected" && "$(<.env)" == prerequisite ]]
cd "$sandbox/topic"
path_from_shim="$(bash "$core" create feat/shim)"
[[ "$path_from_shim" == "$sandbox/custom trees/repo/feat/shim" ]]
[[ "$(command git -C "$path_from_shim" rev-parse HEAD)" == "$expected" ]]
# A refused creation must leave the parent shell in its original directory.
if gwtcd --non-interactive feat/helper 2>/dev/null; then
  print -u2 'occupied path unexpectedly succeeded'; exit 1
fi
[[ "$PWD" == "$sandbox/topic" ]]
print 'PASS: gwtcd completion, configured placement, caller HEAD, main seeding, failure cwd, and compatibility shim'
