#!/usr/bin/env zsh
# Real shell helpers and installed gwt; every checkout/config stays in a temporary home.
emulate -L zsh
setopt err_exit pipe_fail
module="${0:A:h:h}/git.zsh"
core="${0:A:h:h:h:h:h}/tmux/.config/tmux/scripts/worktree-core.sh"
binary="$(whence -p gwt)" || { print -u2 'gwt.test: install gwt on PATH first'; exit 1; }
sandbox="$(mktemp -d)"; sandbox="${sandbox:A}"
trap 'cd /; command rm -rf "$sandbox"' EXIT
export HOME="$sandbox" XDG_CONFIG_HOME="$sandbox/config"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset GWT_CONFIG GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
mkdir -p "$sandbox/bin" "$XDG_CONFIG_HOME/gwt"
cp "$binary" "$sandbox/bin/gwt"
# At a terminal gwt copies each new path; this stub keeps the real clipboard out.
print -r -- '#!/bin/sh
cat > "$HOME/clipboard"' > "$sandbox/bin/toclip"
chmod +x "$sandbox/bin/toclip"
export PATH="$sandbox/bin:$PATH"
source "$module"
# Capture completion specifications; no terminal or completion widget needed.
_arguments() { print -rl -- "$@"; }
# The command words _gwt offers in the first position, ahead of the branches.
offered() { local line="${(@M)${(@f)"$(_gwt)"}:#1:*}"; line="${line#1:*:\(}"; print -r -- "${line%%\$\(*}"; }
# _gwt_commands is the binary's subcommand list: gwt offers exactly it, gwtcd none.
binary_commands=(${(f)"$(command gwt --help | sed -nE '/^Usage:/,/^$/s/^(Usage:)? +gwt \[?([a-z]+)\]? .*/\2/p')"})
[[ "${(o)binary_commands}" == "${(o)_gwt_commands}" ]] || {
  print -u2 "_gwt_commands ($_gwt_commands) differs from gwt --help ($binary_commands)"; exit 1
}
words=(gwt ''); CURRENT=2
[[ "${(o)${=$(offered)}}" == "${(o)_gwt_commands}" ]]
words=(gwtcd ''); CURRENT=2
[[ -z "${$(offered)//[[:space:]]/}" ]] || { print -u2 'gwtcd completion offers commands'; exit 1; }
# Custom root and a caller branch different from the main checkout's branch.
print 'worktree_root = "~/custom trees"' > "$XDG_CONFIG_HOME/gwt/config.toml"
command git init -q -b main "$sandbox/repo"
cd "$sandbox/repo"
command git config user.name Test
command git config user.email test@example.invalid
command git commit --allow-empty -qm initial
command git worktree add -qb topic "$sandbox/topic"
cd "$sandbox/topic"
command git commit --allow-empty -qm topic
expected="$(command git rev-parse HEAD)"
gwtcd --non-interactive feat/helper
[[ "$PWD" == "$sandbox/custom trees/repo/feat/helper" ]]
cd "$sandbox/topic"
path_from_shim="$(bash "$core" create feat/shim)"
[[ "$path_from_shim" == "$sandbox/custom trees/repo/feat/shim" ]]
[[ "$(command git -C "$path_from_shim" rev-parse HEAD)" == "$expected" ]]
# A refused creation must fail and leave the parent shell in its original directory.
rc=0; gwtcd --non-interactive feat/helper 2>/dev/null || rc=$?
[[ $rc == 1 && "$PWD" == "$sandbox/topic" ]]
# gwt --cd enters the checkout; without it the function is a passthrough.
gwt --cd -n feat/flag
[[ "$PWD" == "$sandbox/custom trees/repo/feat/flag" ]]
cd "$sandbox/topic"
gwt create feat/plain --cd --non-interactive
[[ "$PWD" == "$sandbox/custom trees/repo/feat/plain" ]]
cd "$sandbox/topic"
[[ "$(gwt path feat/flag)" == "$sandbox/custom trees/repo/feat/flag" ]]
[[ "$PWD" == "$sandbox/topic" ]]
rc=0; gwt --cd remove feat/flag 2>/dev/null || rc=$?
[[ $rc == 2 && -d "$sandbox/custom trees/repo/feat/flag" ]]
# Every other subcommand refuses --cd too; a stale list made this `gwt create list`.
rc=0; gwt --cd list -n 2>/dev/null || rc=$?
[[ $rc == 2 && "$PWD" == "$sandbox/topic" && ! -e "$sandbox/custom trees/repo/list" ]]
rc=0; gwt --cd --json -n feat/json 2>/dev/null || rc=$?
[[ $rc == 2 && ! -e "$sandbox/custom trees/repo/feat/json" ]]
[[ "$(gwt --cd --help)" == *'--cd'* ]]
words=(gwt ''); CURRENT=2
[[ "$(_gwt)" == *'--cd['* && "$(_gwt)" == *'--no-clipboard['* ]]
words=(gwtcd ''); CURRENT=2
[[ "$(_gwt)" != *'--cd['* ]]
print 'PASS: completion and subcommand list, configured placement, failure cwd, compatibility shim, and gwt --cd'
