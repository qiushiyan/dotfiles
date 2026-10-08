#!/usr/bin/env zsh
# The working tree's _brief completer (git.zsh): what Tab does with the slugs
# `brief resolve <word>` returns. The binary decides which slugs a word
# reaches, and its own tests pin that; this suite pins the shell half, which
# lives in compstate and can only be seen by pressing Tab in a real line
# editor.
#
#   zsh ~/.config/zsh/tests/brief-completion.test.zsh
#
# The case that bought this suite: `b start sandbox-utf<Tab>` offered nothing
# beside sandbox-textdecoder-utf16le while zsh filtered slugs by its own
# matchers, and handing the binary's answer to compadd -U then erased a typed
# word that no match starts with.
#
# Each case types into an interactive zsh on a pty (script(1)) under a
# throwaway $HOME whose ~/.local/bin/brief is a stub serving fixed answers
# and logging each call, so no case reads a real corpus. A widget bound to
# ^Xd writes $BUFFER to the sandbox. The completion styles are oh-my-zsh's,
# which this config runs: menu select and its case-insensitive matcher-list.

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
MODULE="$DOT/zsh/.config/zsh/git.zsh"
typeset -i PASS=0 FAIL=0
SB="" H=""

[[ -f "$MODULE" ]] || { print -u2 "brief-completion.test: no git.zsh at $MODULE"; exit 1 }

t() {
  local name="$1"; shift
  local log; log=$(mktemp "${TMPDIR:-/tmp}/brief-comp-log.XXXXXX")
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

# The stub answers as the binary does: candidates on stdout at exit 0, a
# reason on stderr at exit 1.
sandbox() {
  SB=$(mktemp -d "${${TMPDIR:-/tmp}%/}/brief-comp-test.XXXXXX")
  H="$SB/home"
  mkdir -p "$H/.local/bin"
  cat >"$H/.local/bin/brief" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$HOME/calls"
case "$*" in
  resolve) printf '%s\n' degraded-platform-wording long-read-wording \
    sandbox-deadline-and-lib-reuse sandbox-textdecoder-utf16le ;;
  'resolve sandbox-utf') echo sandbox-textdecoder-utf16le ;;
  'resolve sandbox') printf '%s\n' sandbox-deadline-and-lib-reuse sandbox-textdecoder-utf16le ;;
  'resolve wording') printf '%s\n' degraded-platform-wording long-read-wording ;;
  *) echo "brief: no brief matching \"${2-}\"" >&2; exit 1 ;;
esac
EOF
  chmod +x "$H/.local/bin/brief"
  : >"$H/calls"
}

# drive <key>...: type each key into a fresh interactive zsh, a pause after
# each so every Tab runs with no input pending, as a person types; prints the
# buffer the line held at the end.
drive() {
  local k
  : >"$H/buffer"
  {
    print -r -- "zmodload zsh/complist; autoload -Uz compinit; compinit -u -D"
    print -r -- "zstyle ':completion:*:*:*:*:*' menu select"
    print -r -- "zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|=*' 'l:|=* r:|=*'"
    print -r -- "source ${(q)MODULE}; compdef _brief brief b"
    print -r -- 'dumpbuf() { print -r -- "$BUFFER" >"$HOME/buffer"; BUFFER=; }; zle -N dumpbuf; bindkey "^Xd" dumpbuf'
    sleep 1
    for k in "$@"; do print -rn -- "$k"; sleep 0.7; done
    print -rn -- $'\x18d'; sleep 0.3
    print -r -- 'exit'
  } | script -q /dev/null env -i HOME="$H" TERM=xterm USER="${USER:-}" \
      TMPDIR="${TMPDIR:-/tmp}" PATH=/usr/bin:/bin:/usr/sbin:/sbin zsh -f -i >/dev/null 2>&1
  print -r -- "$(<"$H/buffer")"
}

calls() { print -r -- "$(<"$H/calls")"; }

# The sandbox guard: the stub, not a real brief, answered, and the line editor
# ran the widget. Without both, every case below graded nothing.
test_sandbox_holds() {
  sandbox
  eq "b start sandbox-textdecoder-utf16le " "$(drive 'b start sandbox-utf' $'\t')" "buffer" || return 1
  eq "resolve sandbox-utf" "$(calls)" "calls to the stub"
}

# A word no slug starts with completes to the one slug the binary returns:
# zsh's matchers would have filtered it out.
test_gapped_word_completes() {
  sandbox
  eq "brief start sandbox-textdecoder-utf16le " "$(drive 'brief start sandbox-utf' $'\t')" "buffer"
}

# Matches that do not all start with the word keep it on the first Tab, where
# zsh would replace it with their empty common prefix; the second Tab starts
# the menu on the first match.
test_unprefixed_matches_keep_the_word() {
  sandbox
  eq "brief start wording" "$(drive 'brief start wording' $'\t')" "after one Tab" || return 1
  eq "brief start degraded-platform-wording " "$(drive 'brief start wording' $'\t' $'\t')" "after two Tabs"
}

# Matches that all start with the word still extend it to their common prefix.
test_common_prefix_still_inserts() {
  sandbox
  eq "brief start sandbox-" "$(drive 'brief start sandbox' $'\t')" "buffer"
}

# A miss leaves the word and asks the binary once, not once per matcher in
# matcher-list, since its answer does not depend on zsh's matcher.
test_miss_asks_once() {
  sandbox
  eq "brief start utf-sandbox" "$(drive 'brief start utf-sandbox' $'\t')" "buffer" || return 1
  eq "resolve utf-sandbox" "$(calls)" "calls to the stub"
}

# An empty word asks for every live slug, never with an empty argument, which
# the binary refuses.
test_empty_word_asks_bare() {
  sandbox
  drive 'brief start ' $'\t' >/dev/null
  eq "resolve" "$(calls)" "calls to the stub"
}

t "the stub answers, not a real brief (else everything below is void)" test_sandbox_holds
t "a gapped word completes to the slug the binary returns"             test_gapped_word_completes
t "matches the word does not prefix keep it; the next Tab cycles"      test_unprefixed_matches_keep_the_word
t "matches sharing the word as a prefix still extend it"               test_common_prefix_still_inserts
t "a miss keeps the word and asks the binary once"                     test_miss_asks_once
t "an empty word asks for every live slug"                             test_empty_word_asks_bare

rm -rf "${TMPDIR:-/tmp}"/brief-comp-test.*(N)
print -r -- "----"
print -r -- "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
