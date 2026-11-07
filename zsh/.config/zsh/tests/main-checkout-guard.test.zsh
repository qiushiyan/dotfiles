#!/usr/bin/env zsh
# Pins git/.config/git/hooks/reference-transaction, the main-checkout guard,
# and the forwarders beside it, through the working tree's
# git/.config/git/dev.gitconfig as an includeIf on ~/dev reaches it. Runs in a
# throwaway HOME with its own global git config and twin manifest. The last
# section reads two live things and writes none: the working tree's manifest,
# and whether each repository on this machine with its own hooks path still
# runs the guard.
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

REAL_HOME=$HOME
MANIFEST="$DOT/twin/.config/twin/twin.toml"
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
path = "~/dev/own-hooks"
path = "~/dev/self-wrapped"
  path="~/dev/spaced"   # a comment
path = '"'"'~/dev/single'"'"'' > $SB/.config/twin/twin.toml

repo() { mkdir -p "$1" && command git -C "$1" init -q && print x > "$1/f" && command git -C "$1" add f && command git -C "$1" commit -qm init }
repo $SB/dev/shared; repo $SB/dev/unlisted; repo $SB/elsewhere
repo $SB/dev/own-hooks; repo $SB/dev/spaced; repo $SB/dev/single; repo $SB/dev/forwarded; repo $SB/dev/self-wrapped
print -r -- 'path = "~/dev/forwarded"' >> $SB/.config/twin/twin.toml
print -r -- '#!/bin/sh
exit 1' > $SB/dev/forwarded/.git/hooks/pre-commit
print -r -- '#!/bin/sh
cat >> "$HOME/forwarded-refs"' > $SB/dev/forwarded/.git/hooks/reference-transaction
chmod +x $SB/dev/forwarded/.git/hooks/pre-commit $SB/dev/forwarded/.git/hooks/reference-transaction
command git -C $SB/dev/self-wrapped config core.hooksPath .git/hooks
command git -C $SB/dev/own-hooks config core.hooksPath .githooks
mkdir -p $SB/dev/own-hooks/.githooks
print -r -- '#!/bin/sh
exec "$HOME/.config/git/hooks/reference-transaction" "$@"' > $SB/dev/own-hooks/.githooks/reference-transaction
chmod +x $SB/dev/own-hooks/.githooks/reference-transaction
cp $SB/dev/own-hooks/.githooks/reference-transaction $SB/dev/self-wrapped/.git/hooks/reference-transaction

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
refused "a manifest line spaced, quoted or commented"    $SB/dev/spaced j switch -c j
refused "a manifest path in single quotes"              $SB/dev/single k switch -c k
refused "a wrapper that is the repository's own hook"   $SB/dev/self-wrapped l switch -c l
err=$(cd $SB/dev/forwarded && command git commit -q --allow-empty -m blocked 2>&1) \
  && bad "the repository's own pre-commit still runs" "$err" || ok "the repository's own pre-commit still runs"
command git -C $SB/dev/forwarded branch m
grep -q 'refs/heads/m' $SB/forwarded-refs 2>/dev/null && ok "its own reference-transaction gets the ref lines" \
  || bad "its own reference-transaction gets the ref lines" "$(cat $SB/forwarded-refs 2>&1)"
err=$(mkdir -p $SB/dev/fresh && command git -C $SB/dev/fresh init -q 2>&1)
[[ -z $err ]] && ok "git init under ~/dev prints nothing" || bad "git init under ~/dev prints nothing" "$err"
[[ $(command git -C $SB/dev/shared config --get core.hooksPath) == "~/.config/git/hooks" ]] && ok "dev.gitconfig sets the hooks path under ~/dev" || bad "hooks path under ~/dev"
[[ -z $(command git -C $SB/elsewhere config --get core.hooksPath) ]] && ok "no hooks path outside ~/dev" || bad "hooks path outside ~/dev"

# The guard reads the working tree's manifest as twin writes it.
command rm -f $SB/.config/twin/twin.toml; ln -s "$MANIFEST" $SB/.config/twin/twin.toml
repo $SB/dev/gwt
refused "a repository the working tree's manifest lists" $SB/dev/gwt n switch -c n

# Live, read-only: each manifest repository on this machine with its own hooks
# path still runs the guard there. A regenerated hooks directory drops the
# wrapper, and twin carries the deletion, so the guard would go quiet.
for top in ${(f)"$(awk -F= '/^[ \t]*path[ \t]*=/ { gsub(/[ \t"\047]/, "", $2); print $2 }' "$MANIFEST")"}; do
  dir=${top/#\~/$REAL_HOME}
  [[ -d $dir/.git ]] || continue
  own=$(HOME=$REAL_HOME command git -C "$dir" config --local --get core.hooksPath) || continue
  [[ $own == /* ]] || own="$dir/$own"
  if [[ -x $own/reference-transaction ]] && grep -q '.config/git/hooks/reference-transaction' "$own/reference-transaction"; then
    ok "live: ${top} runs the guard from its own hooks path"
  else
    bad "live: ${top} has no guard wrapper in $own (copy one from another such repository, then twin files sync)"
  fi
done

print -- "----"
print -- "main-checkout-guard.test: $PASS passed, $FAIL failed"
(( FAIL == 0 ))
