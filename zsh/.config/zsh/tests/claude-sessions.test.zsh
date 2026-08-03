#!/usr/bin/env zsh
# Sandbox harness for the permanent surfaces of the shared-sessions toolkit:
# launcher enforcement of the shared-projects topology, migration abort paths,
# obelisk reindex verification, and drift-check verdict classification.
# Everything runs against a throwaway $HOME with stubbed pgrep/lsof/claude/
# obelisk — no real account dir, vendor tree, or index is touched.
#
#   zsh ~/.config/zsh/tests/claude-sessions.test.zsh
#
# Each case pins a specific failure mode found in review; a case that goes
# red again means the fail-closed guarantee it names has regressed.

emulate -L zsh
setopt pipe_fail no_unset

DOT="${0:A:h:h:h:h:h}"
CLAUDE_ZSH="$DOT/zsh/.config/zsh/claude.zsh"
SESSIONS_ZSH="$DOT/zsh/.config/zsh/claude-sessions.zsh"
typeset -i PASS=0 FAIL=0

# The launcher tests cross the zsh→exec seam into headroom itself, so they
# must run the binary built from the source under review — whatever headroom
# happens to be installed on PATH can be newer or staler than the wrappers
# being tested. Build once per run; override with HEADROOM_TEST_BIN.
HEADROOM_SRC="${HEADROOM_SRC:-$HOME/dev/headroom}"
if [[ -z "${HEADROOM_TEST_BIN:-}" ]]; then
  if [[ -d "$HEADROOM_SRC" ]] && command -v go >/dev/null 2>&1; then
    HEADROOM_BUILD_DIR=$(mktemp -d "${${TMPDIR:-/tmp}%/}/cs-test-headroom.XXXXXX")
    HEADROOM_TEST_BIN="$HEADROOM_BUILD_DIR/headroom"
    (cd "$HEADROOM_SRC" && go build -o "$HEADROOM_TEST_BIN" ./cmd/headroom) || {
      print -u2 "claude-sessions.test: building headroom from $HEADROOM_SRC failed"; exit 1
    }
  else
    print -u2 "claude-sessions.test: set HEADROOM_TEST_BIN or provide a buildable checkout at $HEADROOM_SRC"
    exit 1
  fi
fi

t() {
  local name="$1"; shift
  local log; log=$(mktemp "${TMPDIR:-/tmp}/cs-test-log.XXXXXX")
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

# Fresh sandbox: fake HOME with tracked dotfiles settings, quiet pgrep/lsof,
# a claude stub that records its invocation *and* the CLAUDE_CONFIG_DIR it
# received — the launcher tests assert routing, and the environment is the
# routing. Sets SB and H, and pins the accounts root to the sandbox — the
# invoking shell's .zshenv may have sourced the real claude.zsh, whose
# typeset -g would otherwise leak the real accounts root into tests that only
# source claude-sessions.zsh.
#
# The launcher tests run the *real* headroom binary (launch routing lives
# there now; stubbing it would test a stub): $HOME re-points its discovery
# and state into the sandbox, and the claude it execs is the recording stub
# on PATH. No real account dir, vendor tree, or Keychain is touched.
sandbox() {
  # No trailing slash in the template: TMPDIR carries one on macOS, and the
  # doubled slash it would put in $H survives zsh string comparison while
  # headroom's Go paths are lexically cleaned — the preflight would then skip
  # every dir it should check.
  SB=$(mktemp -d "${${TMPDIR:-/tmp}%/}/cs-test.XXXXXX")
  H="$SB/home"
  CLAUDE_ACCOUNTS_ROOT="$H/.claude-accounts"
  # The invoking shell may itself carry the leak the launcher tests are
  # about; each test states its own environment.
  unset CLAUDE_CONFIG_DIR
  mkdir -p "$SB/bin" "$H/dotfiles/claude/.claude" "$H/.claude/projects"
  print -r -- '{ "cleanupPeriodDays": 365 }' >"$H/dotfiles/claude/.claude/settings.json"
  print -r -- 'shared config' >"$H/dotfiles/claude/.claude/CLAUDE.md"
  printf '#!/bin/sh\nexit 1\n' >"$SB/bin/pgrep"
  printf '#!/bin/sh\nexit 1\n' >"$SB/bin/lsof"
  printf '#!/bin/sh\necho "cfg=${CLAUDE_CONFIG_DIR-unset} $@" >> %s/claude.log\nexit 0\n' "$SB" >"$SB/bin/claude"
  chmod +x "$SB/bin/pgrep" "$SB/bin/lsof" "$SB/bin/claude"
  # The pinned binary, first on every test's PATH; the missing-headroom test
  # removes this link to state its own environment.
  ln -s "$HEADROOM_TEST_BIN" "$SB/bin/headroom"
}

# An account dir holding one unique transcript and one file identical to a
# canonical one (the dedupe case).
seed_account() {
  local acct="$1"
  mkdir -p "$H/.claude-accounts/$acct/projects/-proj"
  print -r -- '{"turn":"unique-'$acct'"}' >"$H/.claude-accounts/$acct/projects/-proj/1111aaaa-0000-0000-0000-000000000001.jsonl"
  mkdir -p "$H/.claude/projects/-proj"
  print -r -- '{"turn":"shared"}' >"$H/.claude/projects/-proj/2222bbbb-0000-0000-0000-000000000002.jsonl"
  print -r -- '{"turn":"shared"}' >"$H/.claude-accounts/$acct/projects/-proj/2222bbbb-0000-0000-0000-000000000002.jsonl"
}

# A minimal obelisk database with one pre-existing session and one memory.
seed_obelisk_db() {
  mkdir -p "$H/.obelisk"
  sqlite3 "$H/.obelisk/obelisk.sqlite" "
    CREATE TABLE sessions (id TEXT PRIMARY KEY, jsonl_path TEXT, source TEXT DEFAULT 'claude');
    CREATE TABLE memories (id TEXT PRIMARY KEY, summary TEXT);
    INSERT INTO sessions VALUES ('pre-0000-exists', '$H/.claude/projects/-proj/gone.jsonl', 'claude');
    INSERT INTO memories VALUES ('mem-1', 'a durable conclusion');"
}

# --- launcher enforcement ----------------------------------------------------

test_launch_blocks_real_projects_dir() (
  sandbox
  seed_account a@x.com
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$CLAUDE_ZSH"
  local rc=0
  _claude_launch "a@x.com" 2>/dev/null || rc=$?
  [[ $rc -ne 0 ]] || { print "launch proceeded against a real projects dir"; return 1 }
  [[ ! -f "$SB/claude.log" ]] || { print "claude was invoked despite the violation"; return 1 }
)

test_launch_allows_correct_link() (
  sandbox
  mkdir -p "$H/.claude-accounts/a@x.com"
  ln -s "$H/.claude/projects" "$H/.claude-accounts/a@x.com/projects"
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$CLAUDE_ZSH"
  _claude_launch "a@x.com" || { print "launch blocked a correct topology"; return 1 }
  grep -q "cfg=$H/.claude-accounts/a@x.com" "$SB/claude.log" 2>/dev/null \
    || { print "claude did not receive exactly the account's config dir:"; cat "$SB/claude.log" 2>/dev/null; return 1 }
)

# The incident this pins: a tmux server started inside a Claude Code session
# carries that session's CLAUDE_CONFIG_DIR, and a "primary" launch that
# inherits instead of constructing its environment silently runs on the
# wrong account. The managed path must strip it.
test_launch_primary_strips_polluted_env() (
  sandbox
  mkdir -p "$H/.claude-accounts/a@x.com"
  ln -s "$H/.claude/projects" "$H/.claude-accounts/a@x.com/projects"
  export HOME="$H" PATH="$SB/bin:$PATH"
  export CLAUDE_CONFIG_DIR="$H/.claude-accounts/a@x.com"
  source "$CLAUDE_ZSH"
  x || { print "bare x failed"; return 1 }
  grep -q "cfg=unset" "$SB/claude.log" 2>/dev/null \
    || { print "primary launch leaked the inherited CLAUDE_CONFIG_DIR:"; cat "$SB/claude.log" 2>/dev/null; return 1 }
)

# An empty .current is corruption, not a choice: the launch refuses instead
# of silently becoming "primary, permissions bypassed".
test_launch_refuses_empty_current() (
  sandbox
  mkdir -p "$H/.claude-accounts"
  : >| "$H/.claude-accounts/.current"
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$CLAUDE_ZSH"
  local rc=0
  x 2>/dev/null || rc=$?
  [[ $rc -ne 0 ]] || { print "empty .current launched anyway"; return 1 }
  [[ ! -f "$SB/claude.log" ]] || { print "claude was invoked on corrupt routing state"; return 1 }
)

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

# A HEADROOM_* root override must not silently disable the topology
# preflight: which check applies comes from headroom's own classification of
# the target, never from the wrapper prefix-matching its own idea of the
# accounts root against a dir headroom resolved under a different one.
test_launch_preflight_survives_root_override() (
  sandbox
  mkdir -p "$SB/altroot/b@x.com/projects"   # a real dir: topology violation
  export HOME="$H" PATH="$SB/bin:$PATH" HEADROOM_ACCOUNTS_ROOT="$SB/altroot"
  source "$CLAUDE_ZSH"
  local rc=0
  _claude_launch "b@x.com" 2>/dev/null || rc=$?
  [[ $rc -ne 0 ]] || { print "override root skipped the topology preflight"; return 1 }
  [[ ! -f "$SB/claude.log" ]] || { print "claude ran over broken topology"; return 1 }
)

# A generated launcher records its account and routes to it in one step.
test_generated_launcher_remembers_and_routes() (
  sandbox
  mkdir -p "$H/.claude-accounts/a@x.com"
  ln -s "$H/.claude/projects" "$H/.claude-accounts/a@x.com/projects"
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$CLAUDE_ZSH"
  x-a@x.com || { print "generated launcher failed"; return 1 }
  [[ "$(<"$H/.claude-accounts/.current")" == "a@x.com" ]] \
    || { print ".current not recorded: $(cat "$H/.claude-accounts/.current" 2>/dev/null)"; return 1 }
  grep -q "cfg=$H/.claude-accounts/a@x.com" "$SB/claude.log" 2>/dev/null \
    || { print "launcher routed elsewhere:"; cat "$SB/claude.log" 2>/dev/null; return 1 }
)

test_account_add_fails_when_canonical_is_link() (
  sandbox
  mkdir -p "$H/elsewhere"
  rm -rf "$H/.claude/projects"
  ln -s "$H/elsewhere" "$H/.claude/projects"
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$CLAUDE_ZSH"
  local rc=0
  claude-account-add new@x.com >/dev/null 2>&1 || rc=$?
  [[ $rc -ne 0 ]] || { print "claude-account-add reported success over a symlinked canonical store"; return 1 }
)

# --- migration abort paths ---------------------------------------------------

# A writer that slips the process gate and appends to a deduplicated source
# file during the copy window must abort the swap.
test_migrate_aborts_when_dedupe_mutates() (
  sandbox
  seed_account a@x.com
  printf '#!/bin/sh\nif [ ! -f %s/.mutated ]; then touch %s/.mutated; echo extra >> "%s"; fi\nexec /usr/bin/ditto "$@"\n' \
    "$SB" "$SB" "$H/.claude-accounts/a@x.com/projects/-proj/2222bbbb-0000-0000-0000-000000000002.jsonl" >"$SB/bin/ditto"
  chmod +x "$SB/bin/ditto"
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$SESSIONS_ZSH"
  local rc=0
  claude-sessions-migrate >/dev/null 2>&1 || rc=$?
  [[ $rc -ne 0 ]] || { print "migration swapped despite a source file changing mid-run"; return 1 }
  [[ -d "$H/.claude-accounts/a@x.com/projects" && ! -h "$H/.claude-accounts/a@x.com/projects" ]] \
    || { print "source tree was swapped anyway"; return 1 }
)

# A transcript created after the inventory scan must abort the swap.
test_migrate_aborts_on_new_file() (
  sandbox
  seed_account a@x.com
  printf '#!/bin/sh\nif [ ! -f %s/.spawned ]; then touch %s/.spawned; echo late > "%s"; fi\nexec /usr/bin/ditto "$@"\n' \
    "$SB" "$SB" "$H/.claude-accounts/a@x.com/projects/-proj/3333cccc-0000-0000-0000-000000000003.jsonl" >"$SB/bin/ditto"
  chmod +x "$SB/bin/ditto"
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$SESSIONS_ZSH"
  local rc=0
  claude-sessions-migrate >/dev/null 2>&1 || rc=$?
  [[ $rc -ne 0 ]] || { print "migration swapped despite a new source file appearing mid-run"; return 1 }
  [[ -d "$H/.claude-accounts/a@x.com/projects" && ! -h "$H/.claude-accounts/a@x.com/projects" ]] \
    || { print "source tree was swapped anyway"; return 1 }
)

# A mistyped flag must refuse before any filesystem work, not run the cutover.
test_migrate_rejects_unknown_flag() (
  sandbox
  seed_account a@x.com
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$SESSIONS_ZSH"
  local rc=0
  claude-sessions-migrate --dryrun >/dev/null 2>&1 || rc=$?
  [[ $rc -eq 2 ]] || { print "unknown flag returned rc=$rc instead of usage(2)"; return 1 }
  [[ -d "$H/.claude-accounts/a@x.com/projects" && ! -h "$H/.claude-accounts/a@x.com/projects" ]] \
    || { print "the typo executed the real migration"; return 1 }
)

# A rollback failure mid-unwind must not abandon the remaining accounts:
# every restoration is attempted and the residue is named. The mv stub
# breaks b's swap (forcing the unwind) and then breaks a's restore.
test_migrate_unwind_survives_rollback_failure() (
  sandbox
  seed_account a@x.com
  mkdir -p "$H/.claude-accounts/b@x.com/projects/-projb"
  print -r -- '{"turn":"b-only"}' >"$H/.claude-accounts/b@x.com/projects/-projb/5555eeee-0000-0000-0000-000000000005.jsonl"
  printf '#!/bin/sh\ncase "$2" in */b@x.com/projects.pre-share.*) exit 1;; esac\ncase "$1" in */a@x.com/projects.pre-share.*) exit 1;; esac\nexec /bin/mv "$@"\n' >"$SB/bin/mv"
  chmod +x "$SB/bin/mv"
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$SESSIONS_ZSH"
  local rc=0 out
  out=$(claude-sessions-migrate 2>&1) || rc=$?
  [[ $rc -ne 0 ]] || { print "partial swap failure reported success"; return 1 }
  [[ "$out" == *"unwind incomplete"* && "$out" == *a@x.com* ]] \
    || { print "unrestored account not named for manual recovery:"; print -r -- "$out"; return 1 }
  [[ -d "$H/.claude-accounts/b@x.com/projects" && ! -h "$H/.claude-accounts/b@x.com/projects" ]] \
    || { print "b should have been left untouched by its failed swap"; return 1 }
  local -a abk; abk=("$H/.claude-accounts/a@x.com"/projects.pre-share.*(N))
  (( ${#abk} == 1 )) || { print "a's backup missing after failed restore"; return 1 }
)

# A held lock must refuse a second migration outright.
test_migrate_refuses_when_locked() (
  sandbox
  seed_account a@x.com
  mkdir -p "$H/.claude-accounts/.migrate.lock"
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$SESSIONS_ZSH"
  local rc=0
  claude-sessions-migrate >/dev/null 2>&1 || rc=$?
  [[ $rc -ne 0 ]] || { print "migration ran despite a held lock"; return 1 }
  [[ -d "$H/.claude-accounts/a@x.com/projects" && ! -h "$H/.claude-accounts/a@x.com/projects" ]] \
    || { print "locked run still swapped the tree"; return 1 }
)

test_migrate_happy_path() (
  sandbox
  seed_account a@x.com
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$SESSIONS_ZSH"
  claude-sessions-migrate >/dev/null 2>&1 || { print "clean migration failed"; return 1 }
  [[ -h "$H/.claude-accounts/a@x.com/projects" ]] || { print "no symlink installed"; return 1 }
  [[ -f "$H/.claude/projects/-proj/1111aaaa-0000-0000-0000-000000000001.jsonl" ]] \
    || { print "unique transcript not merged"; return 1 }
)

# --- obelisk reindex verification ---------------------------------------------

# An index pass that silently no-ops (skipped build) must fail when a
# migrated, non-empty transcript is absent from the index.
test_reindex_fails_on_noop() (
  sandbox
  seed_obelisk_db
  mkdir -p "$H/.claude/projects/-proj"
  print -r -- '{"turn":"migrated"}' >"$H/.claude/projects/-proj/4444dddd-0000-0000-0000-000000000004.jsonl"
  printf '#!/bin/sh\nexit 0\n' >"$SB/bin/obelisk"; chmod +x "$SB/bin/obelisk"
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$SESSIONS_ZSH"
  local rc=0
  _claude_sessions_reindex test-ts 4444dddd-0000-0000-0000-000000000004 >/dev/null 2>&1 || rc=$?
  [[ $rc -ne 0 ]] || { print "a no-op index pass was reported as success"; return 1 }
)

# An index pass that loses pre-existing sessions (the force-rebuild class)
# must fail the subset assertion.
test_reindex_fails_on_session_loss() (
  sandbox
  seed_obelisk_db
  mkdir -p "$H/.claude/projects/-proj"
  print -r -- '{"turn":"migrated"}' >"$H/.claude/projects/-proj/4444dddd-0000-0000-0000-000000000004.jsonl"
  printf '#!/bin/sh\nsqlite3 "%s" "DELETE FROM sessions WHERE id='"'"'pre-0000-exists'"'"'; INSERT INTO sessions VALUES ('"'"'4444dddd-0000-0000-0000-000000000004'"'"', '"'"'%s'"'"', '"'"'claude'"'"');"\nexit 0\n' \
    "$H/.obelisk/obelisk.sqlite" "$H/.claude/projects/-proj/4444dddd-0000-0000-0000-000000000004.jsonl" >"$SB/bin/obelisk"
  chmod +x "$SB/bin/obelisk"
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$SESSIONS_ZSH"
  local rc=0
  _claude_sessions_reindex test-ts 4444dddd-0000-0000-0000-000000000004 >/dev/null 2>&1 || rc=$?
  [[ $rc -ne 0 ]] || { print "losing a pre-existing indexed session passed verification"; return 1 }
)

# --- drift-check verdicts ------------------------------------------------------

# A canary whose claude invocation fails (login, quota, transport) is
# inability-to-test: INCONCLUSIVE(2), never FAIL(1).
test_canary_request_failure_is_inconclusive() (
  sandbox
  mkdir -p "$H/.claude-accounts/a@x.com"
  ln -s "$H/.claude/projects" "$H/.claude-accounts/a@x.com/projects"
  ln -s "$H/dotfiles/claude/.claude/settings.json" "$H/.claude/settings.json"
  ln -s "$H/dotfiles/claude/.claude/settings.json" "$H/.claude-accounts/a@x.com/settings.json"
  printf '#!/bin/sh\nexit 1\n' >"$SB/bin/claude"; chmod +x "$SB/bin/claude"
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$SESSIONS_ZSH"
  local rc=0
  claude-sessions-check --canary >/dev/null 2>&1 || rc=$?
  [[ $rc -eq 2 ]] || { print "failed canary request returned rc=$rc, expected INCONCLUSIVE(2)"; return 1 }
)

test_check_rejects_unknown_flag() (
  sandbox
  export HOME="$H" PATH="$SB/bin:$PATH"
  source "$SESSIONS_ZSH"
  local rc=0
  claude-sessions-check --canry >/dev/null 2>&1 || rc=$?
  [[ $rc -eq 2 ]] || { print "unknown flag returned rc=$rc instead of usage(2)"; return 1 }
)

# ------------------------------------------------------------------------------

t "launch blocks a real per-account projects dir"        test_launch_blocks_real_projects_dir
t "launch allows the correct shared link"                test_launch_allows_correct_link
t "primary launch strips an inherited CLAUDE_CONFIG_DIR" test_launch_primary_strips_polluted_env
t "empty .current refuses instead of primary fallback"   test_launch_refuses_empty_current
t "missing headroom refuses; no bare-claude fallback"    test_launch_refuses_without_headroom
t "root override cannot skip the topology preflight"     test_launch_preflight_survives_root_override
t "generated launcher remembers and routes in one step"  test_generated_launcher_remembers_and_routes
t "account-add fails closed on symlinked canonical"      test_account_add_fails_when_canonical_is_link
t "migrate aborts when a deduplicated source mutates"    test_migrate_aborts_when_dedupe_mutates
t "migrate aborts when a new source file appears"        test_migrate_aborts_on_new_file
t "migrate rejects a mistyped flag with usage(2)"        test_migrate_rejects_unknown_flag
t "migrate unwind survives a rollback failure"           test_migrate_unwind_survives_rollback_failure
t "migrate refuses to run under a held lock"             test_migrate_refuses_when_locked
t "migrate happy path still merges and links"            test_migrate_happy_path
t "reindex fails when the index pass no-ops"             test_reindex_fails_on_noop
t "reindex fails when pre-existing sessions are lost"    test_reindex_fails_on_session_loss
t "canary request failure is INCONCLUSIVE, not FAIL"     test_canary_request_failure_is_inconclusive
t "check rejects a mistyped flag with usage(2)"          test_check_rejects_unknown_flag

rm -rf "${TMPDIR:-/tmp}"/cs-test.*(N) "${TMPDIR:-/tmp}"/cs-test-headroom.*(N)
print -r -- "----"
print -r -- "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
