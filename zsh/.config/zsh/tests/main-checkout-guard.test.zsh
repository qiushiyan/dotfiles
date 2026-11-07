#!/usr/bin/env zsh
# Pins git/.config/git/hooks/reference-transaction, the main-checkout guard,
# through the working tree's git/.config/git/dev.gitconfig as an includeIf on
# ~/dev reaches it. Runs in a throwaway HOME with its own global git config and
# twin manifest; nothing here reads or writes the live ones.
#
#   zsh ~/.config/zsh/tests/main-checkout-guard.test.zsh

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
GUARD="$DOT/git/.config/git/hooks/reference-transaction"
[[ -x "$GUARD" ]] || { print -u2 "main-checkout-guard.test: no executable guard at $GUARD"; exit 1 }
typeset -i PASS=0 FAIL=0
SB=$(mktemp -d "${TMPDIR:-/tmp}/main-checkout-guard.XXXXXX") || exit 1
[[ -n "$SB" && -d "$SB" && "$SB" != "/" ]] || exit 1
SB=${SB:A}   # git reports real paths, and the guard matches the top against HOME
trap 'command rm -rf -- "$SB"' EXIT

export HOME=$SB GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=$SB/gitconfig
unset GIT_DIR GIT_WORK_TREE
mkdir -p $SB/.config/git $SB/.config/twin $SB/dev
ln -s "$DOT/git/.config/git/hooks" $SB/.config/git/hooks
ln -s "$DOT/git/.config/git/dev.gitconfig" $SB/.config/git/dev.gitconfig
print -r -- "[user]
	name = t
	email = t@t
[init]
	defaultBranch = main
[includeIf \"gitdir:~/dev/\"]
	path = ~/.config/git/dev.gitconfig" > $GIT_CONFIG_GLOBAL
print -r -- 'path = "~/dev/shared"
path = "~/dev/own-hooks"' > $SB/.config/twin/twin.toml

repo() { mkdir -p "$1" && command git -C "$1" init -q && print x > "$1/f" && command git -C "$1" add f && command git -C "$1" commit -qm init }
repo $SB/dev/shared; repo $SB/dev/unlisted; repo $SB/elsewhere
repo $SB/dev/own-hooks
command git -C $SB/dev/own-hooks config core.hooksPath .githooks
mkdir -p $SB/dev/own-hooks/.githooks
print -r -- '#!/bin/sh
exec "$HOME/.config/git/hooks/reference-transaction" "$@"' > $SB/dev/own-hooks/.githooks/reference-transaction
chmod +x $SB/dev/own-hooks/.githooks/reference-transaction

ok()   { (( PASS++ )) || true; print -r -- "PASS $1" }
bad()  { (( FAIL++ )) || true; print -r -- "FAIL $1"; [[ -n "${2:-}" ]] && print -r -- "$2" | sed 's/^/    /' }
# refused <label> <dir> <branch> <git args...>: exit non-zero, no branch, HEAD still main, message names gwt
refused() {
  local label=$1 dir=$2 b=$3; shift 3
  local err; err=$(cd "$dir" && command git "$@" 2>&1 >/dev/null); local rc=$?
  if (( rc != 0 )) && ! command git -C "$dir" rev-parse -q --verify "refs/heads/$b" >/dev/null \
     && [[ $(command git -C "$dir" branch --show-current) == main && "$err" == *"gwt create -n $b"* ]]; then ok "$label"
  else bad "$label (rc=$rc)" "$err"; fi
}
allowed() {
  local label=$1 dir=$2; shift 2
  local err; err=$(cd "$dir" && command git "$@" 2>&1 >/dev/null) && ok "$label" || bad "$label" "$err"
}

refused "switch -c in a shared main checkout"           $SB/dev/shared a switch -c a
refused "checkout -b in a shared main checkout"         $SB/dev/shared b checkout -b b
refused "a repo with its own hooks path, via the wrapper" $SB/dev/own-hooks c switch -c c
allowed "git branch makes a branch without moving it"   $SB/dev/shared branch d
allowed "worktree add -b, as gwt runs it"               $SB/dev/shared worktree add -q -b e $SB/dev/.worktrees/e
allowed "switch -c inside a linked worktree"            $SB/dev/.worktrees/e switch -q -c f
allowed "switch to an existing branch"                  $SB/dev/shared switch -q d
allowed "commit after it"                               $SB/dev/shared commit -q --allow-empty -m again
allowed "a repo twin does not carry"                    $SB/dev/unlisted switch -q -c g
allowed "a repo outside ~/dev"                          $SB/elsewhere switch -q -c h
allowed "past the guard on purpose"                     $SB/dev/shared -c core.hooksPath=/dev/null switch -q -c i
[[ $(command git -C $SB/dev/shared config --get core.hooksPath) == "~/.config/git/hooks" ]] && ok "dev.gitconfig sets the hooks path under ~/dev" || bad "hooks path under ~/dev"
[[ -z $(command git -C $SB/elsewhere config --get core.hooksPath) ]] && ok "no hooks path outside ~/dev" || bad "hooks path outside ~/dev"

print -- "----"
print -- "main-checkout-guard.test: $PASS passed, $FAIL failed"
(( FAIL == 0 ))
