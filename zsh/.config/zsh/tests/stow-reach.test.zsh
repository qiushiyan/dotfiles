#!/usr/bin/env zsh
# Red line 2 of CLAUDE.md as a check: nothing in this repo may stow a
# non-empty CLAUDE.md into $HOME. `claude/.claude/CLAUDE.md` stows to
# ~/.claude/CLAUDE.md, the global memory prepended to every request in every
# project, and any <pkg>/CLAUDE.md stows to ~/CLAUDE.md with the same reach —
# unless the package's .stow-local-ignore excludes it (tabtype/ does). The
# same exclusions keep repo-only directories and entry points out of HOME:
# the Makefile's package list and scripts/.stow-local-ignore. Reads the
# working tree; `make list` and a `stow -n` dry run work in scratch
# directories, and nothing is stowed or written outside them.
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

# The Makefile's package list leaves out the top-level directories that are not
# packages, whether or not this checkout has them: docs/ and references/ are
# repo-only reading, node_modules/ is the root package.json's install, and
# vpn-private/ is never stowed. Asked of the real Makefile in a scratch
# directory holding all four beside one real package.
case_list_skips_non_packages() {
  local tmp out rc=0
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/sr-list.XXXXXX") || return 1
  mkdir -p "$tmp"/{docs,references,node_modules,vpn-private,zsh}
  out=$(make -s -f "$DOT/Makefile" -C "$tmp" list 2>&1)
  [[ "$out" == "zsh/" ]] || { print "make -s list in a tree of non-packages and zsh/ said: ${(qqq)out}"; rc=1 }
  [[ -n "$tmp" && -d "$tmp" ]] && rm -rf -- "$tmp"
  return $rc
}

# launchd agents live in one package per machine, and the list names only the
# one ~/.config/machine names: a plist carries its machine's home path, and an
# agent loaded on the wrong machine runs there. With no marker it names
# neither. Asked of the real Makefile in a scratch tree and a scratch HOME.
case_list_names_this_machines_launchd_only() {
  local tmp out rc=0 name want
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/sr-launchd.XXXXXX") || return 1
  mkdir -p "$tmp"/tree/{launchd-mac,launchd-mini,zsh} "$tmp/home/.config"
  for name want in mac "launchd-mac/ zsh/" mini "launchd-mini/ zsh/" "" "zsh/"; do
    if [[ -n "$name" ]]; then print -r -- "  $name  " > "$tmp/home/.config/machine"
    else rm -f "$tmp/home/.config/machine"
    fi
    out=$(HOME="$tmp/home" make -s -f "$DOT/Makefile" -C "$tmp/tree" list 2>&1)
    [[ "$out" == "$want" ]] || { print "marker ${(qqq)name}: make -s list said ${(qqq)out}, want ${(qqq)want}"; rc=1 }
  done
  [[ -n "$tmp" && -d "$tmp" ]] && rm -rf -- "$tmp"
  return $rc
}

# scripts/ holds repo-only entry points run as ./scripts/<name>; its
# .stow-local-ignore keeps them out of HOME. Asked of stow itself, as a dry run
# into a scratch target, so a regex that stopped matching fails here too.
case_scripts_entry_points_stay_repo_local() {
  (( $+commands[stow] )) || { print "stow is not installed"; return 1 }
  local tmp plan rc=0
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/sr-stow.XXXXXX") || return 1
  plan=$(stow -n -v -d "$DOT" -t "$tmp" scripts 2>&1)
  [[ "$plan" == *"LINK: .local "* ]] || { print "stow planned no link for scripts/.local (nothing exercised): $plan"; rc=1 }
  local f
  for f in bootstrap.sh list-secrets.sh; do
    [[ "$plan" == *"LINK: $f "* ]] && { print "stow would link scripts/$f into HOME"; rc=1 }
  done
  [[ -n "$tmp" && -d "$tmp" ]] && rm -rf -- "$tmp"
  return $rc
}

t "claude/.claude/CLAUDE.md is empty"                      case_global_memory_empty
t "no <pkg>/CLAUDE.md stows to ~/CLAUDE.md"                case_no_package_claude_md_reaches_home
t "tabtype package docs stay out of HOME"                  case_tabtype_docs_stay_repo_local
t "make list names no non-package directory"              case_list_skips_non_packages
t "make list names this machine's launchd package only"   case_list_names_this_machines_launchd_only
t "scripts entry points stay out of HOME"                  case_scripts_entry_points_stay_repo_local

print -r -- "stow-reach.test: $PASS passed, $FAIL failed"
(( FAIL == 0 ))
