#!/usr/bin/env zsh
# Red line 2 of CLAUDE.md as a check: nothing in this repo may stow a
# non-empty CLAUDE.md into $HOME. `claude/.claude/CLAUDE.md` stows to
# ~/.claude/CLAUDE.md, the global memory prepended to every request in every
# project, and any <pkg>/CLAUDE.md stows to ~/CLAUDE.md with the same reach —
# unless the package's .stow-local-ignore excludes it (tabtype/ does). Also:
# every package `make list` stows is tracked, so an untracked top-level dir
# (node_modules/ from the root package.json) can't become one. Reads the
# working tree only; nothing is stowed, sourced, or written.
#
#   zsh ~/.config/zsh/tests/stow-reach.test.zsh
#
# The case that bought this suite: a session working on Claude config wrote
# guidance into claude/.claude/CLAUDE.md, reading it as package-local
# (session 5915c97e, 2026-08-02). The rule was in CLAUDE.md at the time.

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
typeset -i PASS=0 FAIL=0

[[ -f "$DOT/Makefile" ]] || { print -u2 "stow-reach.test: no Makefile at $DOT"; exit 1 }

t() {
  local name="$1"; shift
  local log; log=$(mktemp "${TMPDIR:-/tmp}/sr-test-log.XXXXXX")
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

# ignored <pkg> <relpath>: true when the package's .stow-local-ignore lists the
# file's basename (stow matches the regex against each path segment).
ignored() {
  local ign="$DOT/$1/.stow-local-ignore" base="${2:t}"
  [[ -f "$ign" ]] || return 1
  local re
  while IFS= read -r re; do
    [[ -z "$re" || "$re" == \#* ]] && continue
    [[ "$base" =~ "^${re}$" ]] && return 0
  done < "$ign"
  return 1
}

# Stowed packages, asked of the Makefile itself so the two can't drift. An
# empty answer fails rather than letting every case pass over nothing.
packages() {
  local -a pkgs=(${=$(make -s -C "$DOT" list)})
  (( $#pkgs )) || { print "make -s list named no packages"; return 1 }
  print -rl -- ${pkgs%/}
}

case_global_memory_empty() {
  local f="$DOT/claude/.claude/CLAUDE.md"
  [[ -f "$f" ]] || { print "claude/.claude/CLAUDE.md is missing (it should exist, empty)"; return 1 }
  [[ -s "$f" ]] && { print "claude/.claude/CLAUDE.md is non-empty: it stows to ~/.claude/CLAUDE.md, the global memory"; return 1 }
  return 0
}

case_no_package_claude_md_reaches_home() {
  local pkg rc=0
  local -a pkgs
  pkgs=($(packages)) || { print -l $pkgs; return 1 }
  for pkg in $pkgs; do
    local f="$DOT/$pkg/CLAUDE.md"
    [[ -f "$f" ]] || continue
    if ! ignored "$pkg" "CLAUDE.md"; then
      print "$pkg/CLAUDE.md would stow to ~/CLAUDE.md; add it to $pkg/.stow-local-ignore or move it to docs/"
      rc=1
    fi
  done
  return $rc
}

# The package rule is a deny list over every top-level dir, so anything on
# disk qualifies: node_modules/ stowed ~/.pnpm and ~/@pierre for two months
# before anyone noticed. A real package has tracked files.
case_every_package_is_tracked() {
  local pkg rc=0
  local -a pkgs
  pkgs=($(packages)) || { print -l $pkgs; return 1 }
  for pkg in $pkgs; do
    [[ -n "$(git -C "$DOT" ls-files -- "$pkg" | head -1)" ]] && continue
    print "$pkg/ has no tracked files but make would stow it; add it to the Makefile's filter-out"
    rc=1
  done
  return $rc
}

case_tabtype_docs_stay_repo_local() {
  local doc
  for doc in CLAUDE.md WORKFLOW.md DESIGN.md; do
    ignored tabtype "$doc" || {
      print "tabtype/.stow-local-ignore no longer excludes $doc"
      return 1
    }
  done
  return 0
}

t "claude/.claude/CLAUDE.md is empty"                      case_global_memory_empty
t "no <pkg>/CLAUDE.md stows to ~/CLAUDE.md"                case_no_package_claude_md_reaches_home
t "tabtype package docs stay out of HOME"                  case_tabtype_docs_stay_repo_local
t "every package make stows is tracked"                    case_every_package_is_tracked

print -r -- "stow-reach.test: $PASS passed, $FAIL failed"
(( FAIL == 0 ))
