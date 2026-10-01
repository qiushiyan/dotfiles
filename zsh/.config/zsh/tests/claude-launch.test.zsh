#!/usr/bin/env zsh
# What claude.zsh's launchers add on top of headroom: the refusal without
# it, named-launch routing, the per-workspace effort flag, and x-select's cd.
# Topology, environment and `.current` policy are headroom's and tested there
# (~/dev/headroom internal/app, internal/accounts). Everything runs against a
# throwaway $HOME with a recording claude stub — no real account dir or
# vendor tree is touched.
#
#   zsh ~/.config/zsh/tests/claude-launch.test.zsh
#
# Each case pins a specific failure mode found in review; a case that goes
# red again means the fail-closed guarantee it names has regressed.

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
CLAUDE_ZSH="$DOT/zsh/.config/zsh/claude.zsh"
typeset -i PASS=0 FAIL=0

# The launcher tests cross the zsh→exec seam into headroom itself, so they
# must run the binary built from the source under review — whatever headroom
# happens to be installed on PATH can be newer or staler than the wrappers
# being tested. Build once per run; override with HEADROOM_TEST_BIN.
HEADROOM_SRC="${HEADROOM_SRC:-$HOME/dev/headroom}"
if [[ -z "${HEADROOM_TEST_BIN:-}" ]]; then
  if [[ -d "$HEADROOM_SRC" ]] && command -v go >/dev/null 2>&1; then
    HEADROOM_BUILD_DIR=$(mktemp -d "${${TMPDIR:-/tmp}%/}/cl-test-headroom.XXXXXX")
    HEADROOM_TEST_BIN="$HEADROOM_BUILD_DIR/headroom"
    (cd "$HEADROOM_SRC" && go build -o "$HEADROOM_TEST_BIN" ./cmd/headroom) || {
      print -u2 "claude-launch.test: building headroom from $HEADROOM_SRC failed"; exit 1
    }
  else
    print -u2 "claude-launch.test: set HEADROOM_TEST_BIN or provide a buildable checkout at $HEADROOM_SRC"
    exit 1
  fi
fi

t() {
  local name="$1"; shift
  local log; log=$(mktemp "${TMPDIR:-/tmp}/cl-test-log.XXXXXX")
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

# Fresh sandbox: a fake HOME holding the canonical session store and a
# dotfiles tree for the effort table, and a claude stub that records its
# invocation *and* the CLAUDE_CONFIG_DIR it received — the tests assert
# routing, and the environment is the routing. Sets SB and H.
#
# The launcher tests run the *real* headroom binary (launch routing lives
# there now; stubbing it would test a stub): $HOME re-points its discovery
# and state into the sandbox, and the claude it execs is the recording stub
# on PATH. No real account dir, vendor tree, or Keychain is touched.
sandbox() {
  # No trailing slash in the template: TMPDIR carries one on macOS, and the
  # doubled slash it would put in $H survives zsh string comparison while
  # headroom's Go paths are lexically cleaned — its topology check would then
  # skip every dir it should check.
  SB=$(mktemp -d "${${TMPDIR:-/tmp}%/}/cl-test.XXXXXX")
  H="$SB/home"
  # The invoking shell may itself carry the leak the launcher tests are
  # about; each test states its own environment.
  unset CLAUDE_CONFIG_DIR
  mkdir -p "$SB/bin" "$H/dotfiles/claude/.claude" "$H/.claude/projects"
  printf '#!/bin/sh\necho "cfg=${CLAUDE_CONFIG_DIR-unset} $@" >> %s/claude.log\nexit 0\n' "$SB" >"$SB/bin/claude"
  chmod +x "$SB/bin/claude"
  # The pinned binary, first on every test's PATH; the missing-headroom test
  # removes this link to state its own environment.
  ln -s "$HEADROOM_TEST_BIN" "$SB/bin/headroom"
}

# --- launchers: what the wrapper adds to headroom ---------------------------

# No headroom, no launch: falling back to bare `claude` would recreate the
# inherited-environment misroute in exactly the shells most likely to have it.
test_launch_refuses_without_headroom() (
  sandbox
  rm -f "$SB/bin/headroom"
  export HOME="$H" PATH="$SB/bin:/usr/bin:/bin"
  source "$CLAUDE_ZSH"
  local rc=0
  x 2>/dev/null || rc=$?
  [[ $rc -eq 127 ]] || { print "missing headroom returned rc=$rc, expected 127"; return 1 }
  [[ ! -f "$SB/claude.log" ]] || { print "claude ran without the managed path"; return 1 }
)

# A named launch is scoped: it routes to its account and leaves .current
# alone — only the board's enter moves where bare `x` goes. The pin as a
# launcher side effect is what let a two-minute hop to another account
# silently retarget every later bare `x`.
test_generated_launcher_routes_without_repinning() (
  sandbox
  mkdir -p "$H/.claude-accounts/a@x.com"
  ln -s "$H/.claude/projects" "$H/.claude-accounts/a@x.com/projects"
  print -rn -- b@x.com >"$H/.claude-accounts/.current"
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$CLAUDE_ZSH"
  x-a@x.com || { print "generated launcher failed"; return 1 }
  grep -q "cfg=$H/.claude-accounts/a@x.com" "$SB/claude.log" 2>/dev/null \
    || { print "launcher routed elsewhere:"; cat "$SB/claude.log" 2>/dev/null; return 1 }
  [[ "$(<"$H/.claude-accounts/.current")" == "b@x.com" ]] \
    || { print "named launcher moved .current: $(cat "$H/.claude-accounts/.current" 2>/dev/null)"; return 1 }
)

# Workspace effort rides into claude as a launch flag: inside a listed dir
# (a subdir, or a symlink to it) the session gets `--effort <level>`;
# outside — including a lookalike prefix — it gets none, so settings.json's
# default stands.
test_effort_follows_workspace() (
  sandbox
  mkdir -p "$H/wiki/notes" "$H/dotfiles-old"
  ln -s "$H/wiki" "$SB/wiki-link"
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$CLAUDE_ZSH"
  local d
  for d in "$H/dotfiles" "$H/wiki/notes" "$SB/wiki-link" "$H/dotfiles-old" "$H"; do
    ( cd "$d" && x ) || { print "x failed in $d"; return 1 }
  done
  local -a got=("${(@f)$(<"$SB/claude.log")}")
  local want=(high high high none none) i
  for i in {1..5}; do
    if [[ "$want[i]" == none ]]; then
      [[ "$got[i]" != *--effort* ]] || { print "launch $i got an effort it should not: $got[i]"; return 1 }
    else
      [[ "$got[i]" == *"--effort $want[i] "* ]] || { print "launch $i: expected --effort $want[i], got: $got[i]"; return 1 }
    fi
  done
)

# The most specific dir wins whatever the table's order, and an explicit
# --effort on the command line beats the table instead of doubling up.
test_effort_specific_dir_and_explicit_flag_win() (
  sandbox
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$CLAUDE_ZSH"
  CLAUDE_X_EFFORT=("$H/dotfiles" high "$H/dotfiles/claude" medium)
  ( cd "$H/dotfiles/claude/.claude" && x ) || { print "x failed"; return 1 }
  ( cd "$H/dotfiles" && x --effort=max ) || { print "x --effort=max failed"; return 1 }
  local -a got=("${(@f)$(<"$SB/claude.log")}")
  [[ "$got[1]" == *"--effort medium "* ]] || { print "subdir entry lost to its parent: $got[1]"; return 1 }
  [[ "$got[2]" != *"--effort "* && "$got[2]" == *--effort=max* ]] \
    || { print "explicit flag did not replace the table's: $got[2]"; return 1 }
)

# --- x-select: the wrapper's whole job is the cd afterwards -------------------

# The advisory cd-file contract, wrapper side: non-empty and absolute means
# headroom entered that dir, and the cd sticks regardless of how the session
# exited; the exit status passes through untouched. The stub stands in for
# headroom because the picker needs a terminal — the binary's own side of the
# contract is pinned in headroom's pty harness.
test_x_select_cds_from_advice() (
  sandbox
  mkdir -p "$H/proj"
  rm -f "$SB/bin/headroom" # a symlink to the real binary — never write through it
  cat >"$SB/bin/headroom" <<EOS
#!/bin/sh
[ "\$1" = sessions ] && [ "\$2" = --cd-file ] || exit 9
printf '%s' "$H/proj" > "\$3"
exit 7
EOS
  chmod +x "$SB/bin/headroom"
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$CLAUDE_ZSH"
  cd "$H"
  local rc=0
  x-select || rc=$?
  [[ $rc -eq 7 ]] || { print "exit status not passed through: rc=$rc, want 7"; return 1 }
  [[ "$PWD" == "$H/proj" ]] || { print "did not cd to the advised dir: $PWD"; return 1 }
)

# Empty advice means no launch was committed — cancel or refusal — and the
# wrapper must stay put.
test_x_select_stays_put_on_empty_advice() (
  sandbox
  rm -f "$SB/bin/headroom"
  cat >"$SB/bin/headroom" <<'EOS'
#!/bin/sh
[ "$1" = sessions ] && [ "$2" = --cd-file ] || exit 9
: > "$3"
exit 1
EOS
  chmod +x "$SB/bin/headroom"
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$CLAUDE_ZSH"
  cd "$H"
  local rc=0
  x-select || rc=$?
  [[ $rc -eq 1 ]] || { print "exit status not passed through: rc=$rc, want 1"; return 1 }
  [[ "$PWD" == "$H" ]] || { print "cd'd on empty advice: $PWD"; return 1 }
)

# ------------------------------------------------------------------------------

t "missing headroom refuses; no bare-claude fallback"    test_launch_refuses_without_headroom
t "generated launcher routes without repinning bare x"   test_generated_launcher_routes_without_repinning
t "workspace effort applies inside listed dirs only"     test_effort_follows_workspace
t "specific dir and explicit --effort win"               test_effort_specific_dir_and_explicit_flag_win
t "x-select cds from non-empty advice, status through"   test_x_select_cds_from_advice
t "x-select stays put on empty advice"                   test_x_select_stays_put_on_empty_advice

rm -rf "${TMPDIR:-/tmp}"/cl-test.*(N) "${TMPDIR:-/tmp}"/cl-test-headroom.*(N)
print -r -- "----"
print -r -- "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
