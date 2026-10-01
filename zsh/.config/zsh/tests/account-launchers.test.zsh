#!/usr/bin/env zsh
# Which account each generated launcher reaches, for Claude (x-*, claude.zsh)
# and Codex (cx-*, codex.zsh). The naming rule is the safety property: every
# account gets <p>-<email>; a short <p>-<local-part> exists only while that
# local part is unique, is not the primary's name and is not a utility's
# name; vendor `<dir>.lock` debris is not an account. A short name that
# pointed at the wrong account would start a bypass-permissions session there.
#
#   zsh ~/.config/zsh/tests/account-launchers.test.zsh
#
# Each probe is a `zsh -f` sourcing the working tree's modules in .zshenv's
# order, with a throwaway $HOME holding both accounts roots and a stub
# headroom first on PATH that only logs its arguments. Routing is what the
# launcher hands headroom; headroom's own validation is tested in ~/dev/headroom.

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
MODS="$DOT/zsh/.config/zsh"
ZSH_BIN=$(whence -p zsh)
typeset -i PASS=0 FAIL=0

t() {
  local name="$1"; shift
  local log; log=$(mktemp "${TMPDIR:-/tmp}/al-test-log.XXXXXX")
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

# sandbox <account dir>...: a fresh $HOME whose ~/.claude-accounts and
# ~/.codex-accounts both hold the given dirs, and the logging headroom stub.
# The stub's `accounts add` creates the dir, as the real one does.
sandbox() {
  SB=$(mktemp -d "${${TMPDIR:-/tmp}%/}/al-test.XXXXXX") || return 1
  H="$SB/home"
  mkdir -p "$SB/bin" "$H/.claude-accounts" "$H/.codex-accounts"
  local d
  for d in "$@"; do mkdir -p "$H/.claude-accounts/$d" "$H/.codex-accounts/$d"; done
  cat >"$SB/bin/headroom" <<EOS
#!/bin/sh
printf '%s\n' "\$*" > "$SB/headroom.log"
if [ "\$1 \$2" = "accounts add" ]; then
  root="$H/.claude-accounts"
  case " \$* " in *" --vendor codex "*) root="$H/.codex-accounts" ;; esac
  for a; do last=\$a; done
  mkdir -p "\$root/\$last"
fi
EOS
  chmod +x "$SB/bin/headroom"
}

# probe <script>: the launcher modules, sourced as .zshenv does, then
# <script>, in which `route <fn>...` prints "<fn> => <headroom argv>" or
# "<fn> => absent". Outside tmux and non-interactive, so cx runs headroom
# directly rather than through the pane decoration.
probe() {
  env -u TMUX -u TMUX_PANE HOME="$H" PATH="$SB/bin:/usr/bin:/bin" "$ZSH_BIN" -f -c '
    log=$2/headroom.log
    for f in "$1"/{claude,codex,tmux-utils}.zsh; do source "$f"; done
    route() {
      local fn
      for fn; do
        if (( $+functions[$fn] )); then
          : >| $log; $fn >/dev/null 2>&1
          print -r -- "$fn => $(<$log)"
        else
          print -r -- "$fn => absent"
        fi
      done
    }
    '"$1" zsh "$MODS" "$SB"
}

# expect <output> <fn> <want-pattern>...: each pair must appear as a line.
expect() {
  local out="$1" fn want line bad=0; shift
  local -a lines=("${(@f)out}")
  for fn want in "$@"; do
    line=${(M)lines:#"$fn => "*}
    if [[ "$line" != "$fn => "$~want ]]; then
      print -r -- "$fn: want ${(qqq)want}, got ${(qqq)line}"
      bad=1
    fi
  done
  return bad
}

ACCOUNTS=(yan@a.com dup@a.com dup@b.com qiushi@b.com select@a.com acc@a.com yan@a.com.lock)

test_claude_launcher_names() {
  sandbox $ACCOUNTS || return 1
  local B='-- --dangerously-skip-permissions'
  expect "$(probe 'route x-yan x-yan@a.com x-dup x-dup@a.com x-dup@b.com x-qiushi x-qiushi@b.com x-select x-select@a.com x-acc x-acc@a.com x-yan@a.com.lock')" \
    x-yan             "launch --account yan@a.com $B" \
    x-yan@a.com       "launch --account yan@a.com $B" \
    x-dup             absent \
    x-dup@a.com       "launch --account dup@a.com $B" \
    x-dup@b.com       "launch --account dup@b.com $B" \
    x-qiushi          "launch --account qiushi $B" \
    x-qiushi@b.com    "launch --account qiushi@b.com $B" \
    x-select          "sessions --cd-file * $B" \
    x-select@a.com    "launch --account select@a.com $B" \
    x-acc             "accounts --compact" \
    x-acc@a.com       "launch --account acc@a.com $B" \
    x-yan@a.com.lock  absent
}

test_codex_launcher_names() {
  sandbox $ACCOUNTS || return 1
  local V='launch --vendor codex'
  expect "$(probe 'route cx-yan cx-yan@a.com cx-dup cx-dup@a.com cx-dup@b.com cx-qiushi cx-qiushi@b.com cx-select cx-acc cx-acc@a.com cx-yan@a.com.lock')" \
    cx-yan            "$V --account yan@a.com --" \
    cx-yan@a.com      "$V --account yan@a.com --" \
    cx-dup            absent \
    cx-dup@a.com      "$V --account dup@a.com --" \
    cx-dup@b.com      "$V --account dup@b.com --" \
    cx-qiushi         "$V --account qiushi --" \
    cx-qiushi@b.com   "$V --account qiushi@b.com --" \
    cx-select         "$V --account select@a.com --" \
    cx-acc            "accounts --compact --vendor codex" \
    cx-acc@a.com      "$V --account acc@a.com --" \
    cx-yan@a.com.lock absent
}

# Adding an account that shares a local part retires the short alias in the
# same shell, rather than leaving it on the first account.
test_add_retires_an_ambiguous_alias() {
  sandbox dup@a.com || return 1
  local -a out=("${(@f)$(probe 'route x-dup cx-dup
    claude-account-add dup@b.com >/dev/null; cx-account-add dup@b.com >/dev/null
    route x-dup cx-dup x-dup@b.com cx-dup@b.com')}")
  expect "${(F)out[1,2]}" \
    x-dup        "launch --account dup@a.com -- --dangerously-skip-permissions" \
    cx-dup       "launch --vendor codex --account dup@a.com --" || return 1
  expect "${(F)out[3,-1]}" \
    x-dup        absent \
    cx-dup       absent \
    x-dup@b.com  "launch --account dup@b.com -- --dangerously-skip-permissions" \
    cx-dup@b.com "launch --vendor codex --account dup@b.com --"
}

t "x-* launchers: names and the account each reaches"   test_claude_launcher_names
t "cx-* launchers: names and the account each reaches"  test_codex_launcher_names
t "adding a same-local-part account retires the alias"  test_add_retires_an_ambiguous_alias

rm -rf "${TMPDIR:-/tmp}"/al-test.*(N)
print -r -- "----"
print -r -- "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
