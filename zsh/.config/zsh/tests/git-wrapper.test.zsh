#!/usr/bin/env zsh
# The working tree's git() wrapper (git.zsh): the stale-base branch guard and
# planlab's push --no-verify, which live in one function.
#
#   zsh ~/.config/zsh/tests/git-wrapper.test.zsh
#
# The case that bought this suite: .zshrc once defined its own git() for the
# planlab push. It replaced this one in every interactive shell, so
# `gitguard on` silently did nothing. portability.test.zsh checks which git()
# an interactive shell ends up with; this suite checks what that git() does.
#
# Every repository is local (a bare origin in the sandbox), so no case needs
# the network.

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
MODULE="$DOT/zsh/.config/zsh/git.zsh"
typeset -i PASS=0 FAIL=0
SB="" H=""

[[ -f "$MODULE" ]] || { print -u2 "git-wrapper.test: no git.zsh at $MODULE"; exit 1 }

# Setup git in this process and every probe: no user or system config (a
# global core.hooksPath or LFS filter would change what the push cases see),
# a fixed identity, and nothing inherited that points git or the wrapper at
# the caller's repositories or guard state.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR PLANLAB_DIR \
  GIT_GUARD_STATE GIT_GUARD_OFF GIT_GUARD_FORCE

# The live guard marker, checked by the last case: `gitguard off` must write
# the sandbox's marker, never this one.
REAL_MARKER="$HOME/.config/git-guard-off"
[[ -e "$REAL_MARKER" ]] && REAL_MARKER_WAS=1 || REAL_MARKER_WAS=0

t() {
  local name="$1"; shift
  local log; log=$(mktemp "${TMPDIR:-/tmp}/gw-test-log.XXXXXX")
  if "$@" >"$log" 2>&1; then
    (( PASS++ )) || true
    print -r -- "PASS $name"
  else
    (( FAIL++ )) || true
    print -r -- "FAIL $name"
    sed 's/^/    /' "$log"
  fi
  rm -f "$log"
}

eq() {  # eq <expected> <actual> <what>
  [[ "$1" == "$2" ]] && return 0
  print -r -- "$3: expected ${(qqq)1}, got ${(qqq)2}"
  return 1
}

# A throwaway $HOME with a bare origin, a planlab clone at the path the
# wrapper keys on by default, and an unrelated clone. Each clone's pre-push
# hook leaves a mark, so a push shows whether git ran it.
sandbox() {
  SB=$(mktemp -d "${${TMPDIR:-/tmp}%/}/gw-test.XXXXXX"); SB=${SB:A}
  H="$SB/home"
  mkdir -p "$H/.config" "$H/dev/planlab"
  command git init -q --bare -b main "$SB/origin.git"
  command git clone -q "$SB/origin.git" "$SB/seed" 2>/dev/null
  command git -C "$SB/seed" commit -q --allow-empty -m initial
  command git -C "$SB/seed" push -q origin main
  command git clone -q "$SB/origin.git" "$H/dev/planlab/main"
  command git clone -q "$SB/origin.git" "$SB/other"
  local repo
  for repo in "$H/dev/planlab/main" "$SB/other"; do
    print -r -- "#!/bin/sh
: > '$SB/hook-ran-${repo:t}'" >"$repo/.git/hooks/pre-push"
    chmod +x "$repo/.git/hooks/pre-push"
  done
}

# One zsh with nothing loaded but the module, run in <dir> against the
# sandbox $HOME. The working tree's git.zsh, never the stowed copy.
probe() {  # probe <dir> <command>
  ( cd "$1" && HOME="$H" command zsh -f -c 'source "$1"; eval "$2"' _ "$MODULE" "$2" )
}

# The sandbox guard. If $HOME did not take, the guard state below is the
# user's live marker and the planlab path is the user's real clone.
test_sandbox_holds() {
  sandbox
  eq "$H $H/.config/git-guard-off" "$(probe "$SB" 'print -r -- $HOME $GIT_GUARD_STATE')" \
    "\$HOME and the guard marker inside the probe"
}

# Leave <repo>'s main one commit behind origin/main, freshly fetched so the
# guard compares without probing the remote again.
make_behind() {
  command git -C "$SB/seed" commit -q --allow-empty -m ahead
  command git -C "$SB/seed" push -q origin main
  command git -C "$1" fetch -q origin
}

# The guard on a stale base: it names the gap, and answering "no" aborts the
# creation. GIT_GUARD_FORCE stands in for the terminal a person would have.
test_guard_fires_on_stale_base() {
  sandbox
  make_behind "$SB/other"
  local err rc
  err=$(probe "$SB/other" 'GIT_GUARD_FORCE=1 git switch -c feat <<<n' 2>&1 >/dev/null) && rc=0 || rc=$?
  [[ $err == *"git-guard: 'main' is 1 commit(s) behind origin/main"* ]] || {
    print -r -- "no guard warning on stderr: ${(qqq)err}"; return 1
  }
  eq "1" "$rc" "exit status after answering no" || return 1
  command git -C "$SB/other" rev-parse -q --verify refs/heads/feat >/dev/null && {
    print -r -- "branch feat exists although the guard was answered no"; return 1
  }
  return 0
}

# `gitguard off` writes the sandbox marker and the creation goes through
# without a prompt; `gitguard on` removes it and the guard fires again.
test_gitguard_toggle() {
  sandbox
  make_behind "$SB/other"
  local err
  err=$(probe "$SB/other" 'gitguard off >/dev/null; GIT_GUARD_FORCE=1 git switch -q -c off-branch </dev/null' 2>&1) || {
    print -r -- "creation failed with the guard off: ${(qqq)err}"; return 1
  }
  eq "" "$err" "output of a creation with the guard off" || return 1
  [[ -e "$H/.config/git-guard-off" ]] || { print -r -- "gitguard off wrote no marker in the sandbox"; return 1 }
  command git -C "$SB/other" switch -q main
  err=$(probe "$SB/other" 'gitguard on >/dev/null; GIT_GUARD_FORCE=1 git switch -c on-branch <<<n' 2>&1 >/dev/null)
  [[ ! -e "$H/.config/git-guard-off" ]] || { print -r -- "gitguard on left the marker"; return 1 }
  [[ $err == *"git-guard: 'main' is 1 commit(s) behind"* ]] || {
    print -r -- "guard silent after gitguard on: ${(qqq)err}"; return 1
  }
}

# A push from the planlab clone and from one of its worktrees lands without
# running the pre-push hook, and says so.
test_planlab_push_skips_hook() {
  sandbox
  local clone="$H/dev/planlab/main" err
  command git -C "$clone" commit -q --allow-empty -m from-clone
  err=$(probe "$clone" 'git push -q origin HEAD:refs/heads/from-clone' 2>&1 >/dev/null) || {
    print -r -- "push from the clone failed: ${(qqq)err}"; return 1
  }
  [[ $err == *"push --no-verify"* ]] || { print -r -- "no --no-verify note: ${(qqq)err}"; return 1 }
  command git -C "$clone" worktree add -q -b wt "$SB/wt"
  command git -C "$SB/wt" commit -q --allow-empty -m from-worktree
  probe "$SB/wt" 'git push -q origin HEAD:refs/heads/from-worktree' >/dev/null 2>&1 || {
    print -r -- "push from the worktree failed"; return 1
  }
  [[ ! -e "$SB/hook-ran-main" ]] || { print -r -- "the planlab pre-push hook ran"; return 1 }
  eq "2" "$(command git -C "$SB/origin.git" for-each-ref refs/heads/from-clone refs/heads/from-worktree | wc -l | tr -d ' ')" \
    "branches the two pushes created on origin"
}

# Anywhere else a push is plain: the hook runs and nothing is announced. And
# in the planlab clone, anything but push passes through untouched.
test_other_push_runs_hook() {
  sandbox
  local err
  command git -C "$SB/other" commit -q --allow-empty -m other
  err=$(probe "$SB/other" 'git push -q origin HEAD:refs/heads/other' 2>&1 >/dev/null) || {
    print -r -- "push failed: ${(qqq)err}"; return 1
  }
  [[ -e "$SB/hook-ran-other" ]] || { print -r -- "the other repo's pre-push hook did not run"; return 1 }
  eq "" "$err" "stderr of a plain push" || return 1
  eq "" "$(probe "$H/dev/planlab/main" 'git status --short' 2>&1)" "git status in the planlab clone"
}

# The live marker is exactly as the suite found it.
test_live_marker_untouched() {
  local now; [[ -e "$REAL_MARKER" ]] && now=1 || now=0
  eq "$REAL_MARKER_WAS" "$now" "existence of $REAL_MARKER"
}

t "throwaway \$HOME holds (else everything below is void)"  test_sandbox_holds
t "the guard fires on a stale base and aborts on no"       test_guard_fires_on_stale_base
t "gitguard off silences the guard, on restores it"        test_gitguard_toggle
t "planlab pushes (clone and worktree) skip the hook"      test_planlab_push_skips_hook
t "other pushes run the hook; other commands untouched"    test_other_push_runs_hook
t "the live guard marker is untouched"                     test_live_marker_untouched

rm -rf "${TMPDIR:-/tmp}"/gw-test.*(N)
print -r -- "----"
print -r -- "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
