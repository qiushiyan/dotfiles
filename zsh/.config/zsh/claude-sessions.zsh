# ~/.config/zsh/claude-sessions.zsh
# Machine-global Claude Code sessions — migration and drift verification.
#
# Session transcripts ($CLAUDE_CONFIG_DIR/projects/<munged-cwd>/<uuid>.jsonl)
# are a property of the project, not the account: they carry no credentials,
# and resume performs no account-ownership check. Every account therefore
# shares one canonical store, ~/.claude/projects, via a per-account symlink
# (seeded by `headroom accounts add`). Any account's resume
# picker then sees every session, and resuming appends to the one canonical
# file — no copies, no forks, so divergent same-UUID histories cannot exist.
#
#   claude-sessions-migrate [--dry-run]   merge per-account projects/ trees
#                                         into the canonical store, then swap
#                                         in the symlinks. One-time; strict.
#   claude-sessions-check [--canary]      drift verification, headroom-style:
#                                         PASS(0) / FAIL(1) / INCONCLUSIVE(2).
#                                         --canary runs a real cross-account
#                                         create-then-resume probe (spends a
#                                         request on two accounts).
#
# Claude Code owns every write to the shared tree after cutover; the
# migration itself is the one bounded exception. sessions-index.json files
# are never merged — Claude Code regenerates its own derived index; the
# originals stay in the per-account *.pre-share.* backups.

_claude_sessions_hash() {
  # sha256 of one file, bare.
  local out
  out=$(shasum -a 256 -- "$1") || return 1
  print -r -- "${out%% *}"
}

# One-time migration of per-account session trees into ~/.claude/projects.
claude-sessions-migrate() {
  emulate -L zsh
  setopt local_options pipe_fail err_return no_unset
  local canon="$HOME/.claude/projects"
  local root="${CLAUDE_ACCOUNTS_ROOT:-$HOME/.claude-accounts}"
  local dry=0
  if (( $# > 1 )) || [[ -n "${1:-}" && "$1" != --dry-run ]]; then
    print -u2 -r -- "usage: claude-sessions-migrate [--dry-run]"
    return 2
  fi
  [[ "${1:-}" == --dry-run ]] && dry=1

  # One migration at a time: two interleaved runs can each classify and
  # verify, then race the sequential swaps into a topology one of them
  # reports as success. mkdir is the atomic take; a crash leaves the dir
  # behind, and the refusal says exactly what to remove.
  setopt local_traps
  local lockdir=""
  if (( ! dry )); then
    command mkdir -p -- "$root"
    if ! command mkdir -- "$root/.migrate.lock" 2>/dev/null; then
      print -u2 -r -- "FAIL another migration appears to be running — if none is, remove $root/.migrate.lock and re-run"
      return 1
    fi
    lockdir="$root/.migrate.lock"
  fi
  local work; work=$(mktemp -d "${TMPDIR:-/tmp}/claude-sessions-migrate.XXXXXX")
  # Values are baked into the trap at set time — at fire time the
  # function's locals are already out of scope.
  local cleanup="command rm -rf -- ${(q)work}"
  [[ -n "$lockdir" ]] && cleanup+="; command rmdir -- ${(q)lockdir} 2>/dev/null"
  trap "${cleanup}; :" EXIT
  local inventory="$work/inventory"   # hash|action|account-dir|relpath, action: copy|dedupe
  : >"$inventory"

  local -a sources link_only
  local d p
  for d in "$root"/*(/N); do
    p="$d/projects"
    if [[ -h "$p" ]]; then
      if [[ "$p" -ef "$canon" ]]; then
        print -r -- "already shared: $d"
      else
        print -u2 -r -- "FAIL $p is a symlink but does not resolve to $canon — fix by hand first"
        return 1
      fi
    elif [[ -d "$p" ]]; then
      sources+=("$d")
    elif [[ -e "$p" ]]; then
      print -u2 -r -- "FAIL $p exists but is neither a directory nor a symlink"
      return 1
    else
      link_only+=("$d")
    fi
  done

  if (( ! ${#sources} && ! ${#link_only} )); then
    print -r -- "nothing to do: every account already shares $canon"
    return 0
  fi

  # Quiescence: a live session can append to a source transcript after we
  # copied it — the canonical file would silently miss those turns. Refuse
  # while any claude process runs; lsof on the source trees as backstop.
  if (( ! dry )); then
    local live
    if live=$(pgrep -lx claude 2>/dev/null); then
      print -u2 -r -- "FAIL live claude process(es) — quit every session first (this one included):"
      print -u2 -r -- "$live"
      return 1
    fi
    for d in "${sources[@]}"; do
      if lsof +D "$d/projects" >/dev/null 2>&1; then
        print -u2 -r -- "FAIL open files under $d/projects — something is still using it"
        return 1
      fi
    done
  fi

  # Scan + conflict detection. Collisions must be byte-identical — across
  # sources, and against the canonical tree — for every relative path, not
  # just top-level transcripts (a session's closure includes its <uuid>/
  # subdir and project memory/ files). Anything divergent aborts the run.
  # Every file lands in the inventory, dedupes included: the inventory is
  # the complete pre-copy truth the pre-swap rescan verifies against.
  local -A seen          # relpath -> "hash|account-dir"
  local -a conflicts uuids
  local f rel h ch prev n_copy=0 n_dedupe=0 n_index=0
  for d in "${sources[@]}"; do
    local src="$d/projects"
    for f in "$src"/**/*(.DN); do
      rel="${f#$src/}"
      if [[ "${rel:t}" == sessions-index.json ]]; then
        (( n_index++ )) || true
        continue
      fi
      h=$(_claude_sessions_hash "$f")
      if [[ -n "${seen[$rel]:-}" ]]; then
        prev="${seen[$rel]%%|*}"
        if [[ "$prev" == "$h" ]]; then
          print -r -- "$h|dedupe|$d|$rel" >>"$inventory"
          (( n_dedupe++ )) || true
        else
          conflicts+=("$rel: ${seen[$rel]#*|} vs $d")
        fi
        continue
      fi
      seen[$rel]="$h|$d"
      if [[ -e "$canon/$rel" ]]; then
        ch=$(_claude_sessions_hash "$canon/$rel")
        if [[ "$ch" == "$h" ]]; then
          print -r -- "$h|dedupe|$d|$rel" >>"$inventory"
          (( n_dedupe++ )) || true
        else
          conflicts+=("$rel: $d vs canonical")
        fi
        continue
      fi
      print -r -- "$h|copy|$d|$rel" >>"$inventory"
      (( n_copy++ )) || true
      if [[ "$rel" == */*.jsonl && "${rel:h}" != */* ]]; then
        uuids+=("${${rel:t}%.jsonl}")
      fi
    done
  done

  if (( ${#conflicts} )); then
    print -u2 -r -- "FAIL ${#conflicts} divergent path(s) — same relative path, different bytes; resolve by hand:"
    printf '  %s\n' "${conflicts[@]}" >&2
    return 1
  fi

  print -r -- "plan: ${#sources} account tree(s) to merge, $n_copy file(s) to copy, $n_dedupe identical duplicate(s) skipped, $n_index sessions-index.json left for Claude Code to regenerate, ${#link_only} account(s) need only the symlink"
  if (( dry )); then
    print -r -- "dry run — nothing written"
    return 0
  fi

  # Copy (ditto preserves permissions, times, xattrs). Abort anywhere up to
  # the swap and nothing is lost: sources untouched, canonical merely holds
  # verified copies.
  mkdir -p "$canon"
  local act acct
  while IFS='|' read -r h act acct rel; do
    [[ "$act" == copy ]] || continue
    mkdir -p "$canon/${rel:h}"
    ditto "$acct/projects/$rel" "$canon/$rel"
  done <"$inventory"

  # Re-walk every source in full against the inventory — dedupes included.
  # A file that changed, appeared, or vanished since the scan is a writer
  # the process gate missed; the swap would strand its turns in the backup.
  local -A want found
  local key
  while IFS='|' read -r h act acct rel; do
    key="$acct|$rel"
    want[$key]="$h"
  done <"$inventory"
  for d in "${sources[@]}"; do
    local src2="$d/projects"
    for f in "$src2"/**/*(.DN); do
      rel="${f#$src2/}"
      [[ "${rel:t}" == sessions-index.json ]] && continue
      key="$d|$rel"
      found[$key]=1
      if [[ -z "${want[$key]:-}" ]]; then
        print -u2 -r -- "FAIL new file appeared during migration: $f — a session was live; nothing swapped, re-run when quiet"
        return 1
      fi
      if [[ "$(_claude_sessions_hash "$f")" != "${want[$key]}" ]]; then
        print -u2 -r -- "FAIL $f changed during migration — a session was live; nothing swapped, re-run when quiet"
        return 1
      fi
    done
  done
  for key in "${(k)want[@]}"; do
    if [[ -z "${found[$key]:-}" ]]; then
      print -u2 -r -- "FAIL ${key%%|*}/projects/${key#*|} vanished during migration — nothing swapped"
      return 1
    fi
  done
  while IFS='|' read -r h act acct rel; do
    [[ "$act" == copy ]] || continue
    if [[ "$(_claude_sessions_hash "$canon/$rel")" != "$h" ]]; then
      print -u2 -r -- "FAIL canonical copy of $rel does not match its source — nothing swapped"
      return 1
    fi
  done <"$inventory"

  # Cross-directory renames cannot be atomic as a set, so all-or-nothing is
  # provided by unwinding every completed swap if any later one fails.
  local ts; ts=$(date +%Y%m%d-%H%M%S)
  local -a swapped linked
  local swap_err=""
  for d in "${sources[@]}"; do
    if mv "$d/projects" "$d/projects.pre-share.$ts" && ln -s "$canon" "$d/projects"; then
      swapped+=("$d")
    else
      swap_err="$d"
      break
    fi
  done
  if [[ -z "$swap_err" ]]; then
    for d in "${link_only[@]}"; do
      if ln -s "$canon" "$d/projects"; then
        linked+=("$d")
      else
        swap_err="$d"
        break
      fi
    done
  fi
  if [[ -n "$swap_err" ]]; then
    # Rollback must run to completion no matter what fails: err_return is
    # switched off for this block (zsh triggers it inside brace groups on
    # the left of || when the function itself is called in a tested
    # context), every step uses plain `if !`, and whatever could not be
    # restored is named for manual recovery from its backup. This branch
    # always ends in return 1.
    unsetopt err_return
    print -u2 -r -- "FAIL swapping $swap_err — restoring every account to its pre-migration state"
    local -a unrestored
    if [[ -e "$swap_err/projects.pre-share.$ts" && ! -e "$swap_err/projects" && ! -h "$swap_err/projects" ]]; then
      if ! command mv "$swap_err/projects.pre-share.$ts" "$swap_err/projects" 2>/dev/null; then
        unrestored+=("$swap_err")
      fi
    fi
    for d in "${linked[@]}"; do
      if ! command rm -f "$d/projects" 2>/dev/null; then
        unrestored+=("$d")
      fi
    done
    for d in "${swapped[@]}"; do
      if ! command rm -f "$d/projects" 2>/dev/null; then
        unrestored+=("$d")
        continue
      fi
      if ! command mv "$d/projects.pre-share.$ts" "$d/projects" 2>/dev/null; then
        unrestored+=("$d")
      fi
    done
    if (( ${#unrestored} )); then
      print -u2 -r -- "FAIL unwind incomplete — restore these by hand from their projects.pre-share.$ts backups: ${unrestored[*]}"
    fi
    return 1
  fi
  for d in "${swapped[@]}"; do
    print -r -- "shared: $d (backup: $d/projects.pre-share.$ts)"
  done
  for d in "${linked[@]}"; do
    print -r -- "shared: $d (no sessions to migrate)"
  done

  if ! _claude_sessions_reindex "$ts" "${uuids[@]}"; then
    print -u2 -r -- "obelisk verification failed — the topology swap itself is complete; fix obelisk, then re-run claude-sessions-check"
    return 1
  fi

  print -r -- "done — verify with: claude-sessions-check --canary"
  print -r -- "backups can be deleted once the check passes and the picker shows the migrated sessions"
}

# Fold the now-shared tree into obelisk's index and verify it directly —
# the CLI's own output is not trusted: no session may point into the old
# per-account roots, migrated sessions must be present, and the memories
# layer untouched (count + content checksum, not count alone).
_claude_sessions_reindex() {
  emulate -L zsh
  setopt local_options local_traps pipe_fail err_return no_unset
  local ts="$1"; shift
  local -a uuids; uuids=("$@")
  local db="$HOME/.obelisk/obelisk.sqlite"
  local canon="$HOME/.claude/projects"

  if [[ ! -f "$db" ]] || ! command -v obelisk >/dev/null || ! command -v sqlite3 >/dev/null; then
    print -r -- "obelisk: not set up here — skipping reindex"
    return 0
  fi

  local work; work=$(mktemp -d "${TMPDIR:-/tmp}/claude-sessions-reindex.XXXXXX")
  trap "rm -rf ${(q)work}" EXIT

  # Snapshot through SQLite itself — a raw cp of a WAL-mode database can
  # capture a torn copy mid-transaction.
  sqlite3 "$db" ".backup '$db.pre-share.$ts'"

  # The full pre-state, because the assertions below must prove nothing was
  # LOST, not merely that the expected additions arrived — for every
  # transcript retention already pruned, the index row is the last record
  # in existence (a lossy one: obelisk truncates each message at 10,000
  # characters, so it is a search index and never an archive).
  sqlite3 "$db" "SELECT id FROM sessions ORDER BY id;" >"$work/pre-ids"
  local mem_before mem_after
  mem_before=$(sqlite3 "$db" "SELECT COUNT(*) FROM memories;")$'\n'$(sqlite3 "$db" "SELECT * FROM memories ORDER BY 1;" | shasum -a 256)

  # Incremental on purpose — never `obelisk --build`: a force rebuild
  # mirrors only the files on disk. The probe's exit status proves nothing
  # (a skipped build still exits 0); the assertions below are the evidence
  # that indexing actually happened.
  if ! obelisk --search "__claude_sessions_migrate__" >/dev/null; then
    print -u2 -r -- "obelisk: incremental index failed — snapshot kept at $db.pre-share.$ts"
    return 1
  fi

  sqlite3 "$db" "SELECT id FROM sessions ORDER BY id;" >"$work/post-ids"
  local lost
  lost=$(comm -23 "$work/pre-ids" "$work/post-ids")
  if [[ -n "$lost" ]]; then
    print -u2 -r -- "obelisk: FAIL $(print -r -- "$lost" | wc -l | tr -d ' ') pre-existing session(s) vanished from the index — restore $db.pre-share.$ts and investigate"
    return 1
  fi

  mem_after=$(sqlite3 "$db" "SELECT COUNT(*) FROM memories;")$'\n'$(sqlite3 "$db" "SELECT * FROM memories ORDER BY 1;" | shasum -a 256)
  if [[ "$mem_before" != "$mem_after" ]]; then
    print -u2 -r -- "obelisk: FAIL memories changed across reindex — restore from $db.pre-share.$ts and investigate"
    return 1
  fi

  local stale
  stale=$(sqlite3 "$db" "SELECT COUNT(*) FROM sessions WHERE jsonl_path LIKE '%.claude-accounts%';")
  if [[ "$stale" != 0 ]]; then
    print -u2 -r -- "obelisk: FAIL $stale session(s) still point into ~/.claude-accounts after reindex"
    return 1
  fi

  # Every migrated transcript with content must now be indexed; absence
  # means the index pass silently no-opped (skipped build, live daemon) —
  # only genuinely empty transcripts may be skipped.
  local u n_empty=0 bad=0
  local -a hit
  for u in "${uuids[@]}"; do
    if [[ "$(sqlite3 "$db" "SELECT COUNT(*) FROM sessions WHERE id='$u';")" == 0 ]]; then
      hit=("$canon"/**/"$u.jsonl"(N))
      if (( ${#hit} )) && [[ -s "${hit[1]}" ]]; then
        print -u2 -r -- "obelisk: FAIL migrated session $u has content but is not indexed — the index pass did not run"
        (( bad++ )) || true
      else
        (( n_empty++ )) || true
      fi
    fi
  done
  (( bad == 0 )) || return 1
  print -r -- "obelisk: reindexed — nothing lost, memories intact, no stale paths, $(( ${#uuids} - n_empty ))/${#uuids} migrated sessions indexed"
}

# Drift verification for the shared-sessions topology. Exit: 0 PASS,
# 1 FAIL, 2 INCONCLUSIVE (topology holds but cross-account behavior was
# not exercised — run --canary after a Claude Code update to prove it).
claude-sessions-check() {
  emulate -L zsh
  setopt local_options pipe_fail no_unset
  local canon="$HOME/.claude/projects"
  local root="${CLAUDE_ACCOUNTS_ROOT:-$HOME/.claude-accounts}"
  local tracked="$HOME/dotfiles/claude/.claude/settings.json"
  local expected_cleanup=365
  local canary=0 fails=0
  if (( $# > 1 )) || [[ -n "${1:-}" && "$1" != --canary ]]; then
    print -u2 -r -- "usage: claude-sessions-check [--canary]"
    return 2
  fi
  [[ "${1:-}" == --canary ]] && canary=1

  _cs_fail() { print -r -- "FAIL $1"; (( fails++ )) || true }
  _cs_pass() { print -r -- "PASS $1" }

  # Topology: identity by inode, never by readlink text.
  if [[ -d "$canon" && ! -h "$canon" ]]; then
    _cs_pass "canonical $canon is a real directory"
  else
    _cs_fail "canonical $canon must be a real directory, not a symlink"
  fi

  local d p n_accounts=0
  for d in "$root"/*(/N); do
    (( n_accounts++ )) || true
    p="$d/projects"
    if [[ -h "$p" && "$p" -ef "$canon" ]]; then
      _cs_pass "${d:t}: projects -> canonical"
    elif [[ -h "$p" ]]; then
      _cs_fail "${d:t}: projects is a symlink but resolves elsewhere (dangling or wrong target)"
    elif [[ -d "$p" ]]; then
      _cs_fail "${d:t}: projects is a real directory — unmigrated, sessions are fragmenting again"
    else
      _cs_fail "${d:t}: projects missing entirely"
    fi
    local -a leftovers; leftovers=("$d"/projects.pre-share.*(N))
    (( ${#leftovers} )) && print -r -- "note ${d:t}: migration backup still present (${#leftovers}) — delete once satisfied"
  done
  (( n_accounts )) || print -r -- "note: no secondary accounts under $root"

  # Retention: the pin must hold in the one file every account resolves. It is
  # the floor, kept generous on purpose — the actual policy is ccclean's
  # (~/dev/ccclean), which judges sessions by human turns rather than age.
  for d in "$HOME/.claude" "$root"/*(/N); do
    if [[ ! "$d/settings.json" -ef "$tracked" ]]; then
      _cs_fail "${d:t:-primary}: settings.json does not resolve to the tracked shared file"
    fi
  done
  local cleanup
  cleanup=$(python3 -c "import json;print(json.load(open('$tracked')).get('cleanupPeriodDays'))" 2>/dev/null)
  if [[ "$cleanup" == "$expected_cleanup" ]]; then
    _cs_pass "cleanupPeriodDays = $expected_cleanup in shared settings"
  else
    _cs_fail "cleanupPeriodDays is '$cleanup', expected $expected_cleanup (0 would disable persistence, absence means 30-day pruning of the shared tree)"
  fi

  if (( fails )); then
    print -r -- "verdict: FAIL ($fails)"
    return 1
  fi

  if (( ! canary )); then
    print -r -- "verdict: INCONCLUSIVE — topology holds; run 'claude-sessions-check --canary' to prove cross-account resume (spends one request on two accounts)"
    return 2
  fi

  # Behavioral canary: create under a secondary account, then resume the
  # same UUID under the primary — the one canonical file must grow. This is
  # the actual contract sharing exists for.
  local -a accts; accts=("$root"/*(/N))
  if (( ! ${#accts} )); then
    print -r -- "verdict: INCONCLUSIVE — no secondary account to run the canary against"
    return 2
  fi
  local acct="${accts[1]}"
  local cwd; cwd=$(mktemp -d "${TMPDIR:-/tmp}/claude-canary.XXXXXX")
  local uuid; uuid=$(uuidgen | tr '[:upper:]' '[:lower:]')

  print -r -- "canary: creating session $uuid under ${acct:t} in $cwd"
  # A failed claude invocation is inability to test — login, quota, or
  # transport — never evidence of drift: INCONCLUSIVE, not FAIL.
  if ! ( cd "$cwd" && CLAUDE_CONFIG_DIR="$acct" command claude -p --session-id "$uuid" "Reply with exactly: canary-one" >/dev/null ); then
    print -r -- "canary: create request failed (login/quota/transport — could not test)"
    print -r -- "verdict: INCONCLUSIVE"
    return 2
  fi

  local -a hits; hits=("$canon"/**/"$uuid.jsonl"(N))
  if (( ${#hits} != 1 )); then
    _cs_fail "canary transcript not in canonical tree (found ${#hits}, expected 1)"
    print -r -- "verdict: FAIL ($fails)"
    return 1
  fi
  local file="${hits[1]}" size1 size2
  size1=$(stat -f %z "$file")

  print -r -- "canary: resuming $uuid under the primary account"
  if ! ( cd "$cwd" && command claude -p --resume "$uuid" "Reply with exactly: canary-two" >/dev/null ); then
    print -r -- "canary: resume request failed (login/quota/transport — could not test)"
    print -r -- "verdict: INCONCLUSIVE"
    return 2
  fi

  size2=$(stat -f %z "$file")
  local -a strays; strays=("$root"/*/projects.pre-share.*/**/"$uuid.jsonl"(N))
  if (( size2 > size1 )) && grep -q "canary-two" "$file" && (( ${#strays} == 0 )); then
    _cs_pass "cross-account resume appended to the one canonical transcript ($size1 -> $size2 bytes)"
    print -r -- "verdict: PASS"
    return 0
  fi
  _cs_fail "canary resume did not grow the canonical transcript as expected (before=$size1 after=$size2, strays=${#strays})"
  print -r -- "verdict: FAIL ($fails)"
  return 1
}
