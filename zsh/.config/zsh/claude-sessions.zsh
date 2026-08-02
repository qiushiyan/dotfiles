# ~/.config/zsh/claude-sessions.zsh
# Machine-global Claude Code sessions — migration and drift verification.
#
# Session transcripts ($CLAUDE_CONFIG_DIR/projects/<munged-cwd>/<uuid>.jsonl)
# are a property of the project, not the account: they carry no credentials,
# and resume performs no account-ownership check. Every account therefore
# shares one canonical store, ~/.claude/projects, via a per-account symlink
# (seeded by _claude_link_projects in claude.zsh). Any account's resume
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
  [[ "${1:-}" == --dry-run ]] && dry=1

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

  mkdir -p "$canon"
  local work; work=$(mktemp -d "${TMPDIR:-/tmp}/claude-sessions-migrate.XXXXXX")
  local manifest="$work/manifest"   # lines: hash|account-dir|relpath
  : >"$manifest"

  # Scan + conflict detection. Collisions must be byte-identical — across
  # sources, and against the canonical tree — for every relative path, not
  # just top-level transcripts (a session's closure includes its <uuid>/
  # subdir and project memory/ files). Anything divergent aborts the run.
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
          (( n_dedupe++ )) || true
        else
          conflicts+=("$rel: $d vs canonical")
        fi
        continue
      fi
      print -r -- "$h|$d|$rel" >>"$manifest"
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

  # Copy (ditto preserves permissions, times, xattrs), then prove no source
  # moved underneath us and the canonical bytes match the manifest before
  # any symlink swap. Abort here and nothing is lost: sources untouched,
  # canonical merely holds verified copies.
  local acct
  while IFS='|' read -r h acct rel; do
    mkdir -p "$canon/${rel:h}"
    ditto "$acct/projects/$rel" "$canon/$rel"
  done <"$manifest"

  while IFS='|' read -r h acct rel; do
    if [[ "$(_claude_sessions_hash "$acct/projects/$rel")" != "$h" ]]; then
      print -u2 -r -- "FAIL $acct/projects/$rel changed during migration — a session was live; nothing swapped, re-run when quiet"
      return 1
    fi
    if [[ "$(_claude_sessions_hash "$canon/$rel")" != "$h" ]]; then
      print -u2 -r -- "FAIL canonical copy of $rel does not match its source — nothing swapped"
      return 1
    fi
  done <"$manifest"

  local ts; ts=$(date +%Y%m%d-%H%M%S)
  for d in "${sources[@]}"; do
    mv "$d/projects" "$d/projects.pre-share.$ts"
    ln -s "$canon" "$d/projects"
    print -r -- "shared: $d (backup: $d/projects.pre-share.$ts)"
  done
  for d in "${link_only[@]}"; do
    ln -s "$canon" "$d/projects"
    print -r -- "shared: $d (no sessions to migrate)"
  done

  _claude_sessions_reindex "$ts" "${uuids[@]}"

  print -r -- "done — verify with: claude-sessions-check --canary"
  print -r -- "backups can be deleted once the check passes and the picker shows the migrated sessions"
}

# Fold the now-shared tree into obelisk's index and verify it directly —
# the CLI's own output is not trusted: no session may point into the old
# per-account roots, migrated sessions must be present, and the memories
# layer untouched (count + content checksum, not count alone).
_claude_sessions_reindex() {
  emulate -L zsh
  setopt local_options pipe_fail no_unset
  local ts="$1"; shift
  local -a uuids; uuids=("$@")
  local db="$HOME/.obelisk/obelisk.sqlite"

  if [[ ! -f "$db" ]] || ! command -v obelisk >/dev/null || ! command -v sqlite3 >/dev/null; then
    print -r -- "obelisk: not set up here — skipping reindex"
    return 0
  fi

  cp "$db" "$db.pre-share.$ts"
  local mem_before mem_after
  mem_before=$(sqlite3 "$db" "SELECT COUNT(*) FROM memories;")$'\n'$(sqlite3 "$db" "SELECT * FROM memories ORDER BY 1;" | shasum -a 256)

  # Incremental on purpose — never `obelisk --build`: a force rebuild mirrors
  # only the files that exist right now, and for every transcript retention
  # already pruned, the index row is the last record there is. Any ordinary
  # obelisk command picks up new files incrementally and keeps those rows.
  if ! obelisk --search "__claude_sessions_migrate__" >/dev/null; then
    print -u2 -r -- "obelisk: incremental index failed — snapshot kept at $db.pre-share.$ts"
    return 1
  fi

  mem_after=$(sqlite3 "$db" "SELECT COUNT(*) FROM memories;")$'\n'$(sqlite3 "$db" "SELECT * FROM memories ORDER BY 1;" | shasum -a 256)
  if [[ "$mem_before" != "$mem_after" ]]; then
    print -u2 -r -- "obelisk: FAIL memories changed across rebuild — restore from $db.pre-share.$ts and investigate"
    return 1
  fi

  local stale
  stale=$(sqlite3 "$db" "SELECT COUNT(*) FROM sessions WHERE jsonl_path LIKE '%.claude-accounts%';")
  if [[ "$stale" != 0 ]]; then
    print -u2 -r -- "obelisk: FAIL $stale session(s) still point into ~/.claude-accounts after rebuild"
    return 1
  fi

  local u missing=0
  for u in "${uuids[@]}"; do
    if [[ "$(sqlite3 "$db" "SELECT COUNT(*) FROM sessions WHERE id='$u';")" == 0 ]]; then
      print -r -- "obelisk: note — migrated session $u not in index (empty/unparseable transcripts are skipped by design)"
      (( missing++ )) || true
    fi
  done
  print -r -- "obelisk: reindexed — memories intact, no stale paths, $(( ${#uuids} - missing ))/${#uuids} migrated sessions indexed"
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

  # Retention: the pin must hold in the one file every account resolves.
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
  ( cd "$cwd" && CLAUDE_CONFIG_DIR="$acct" command claude -p --session-id "$uuid" "Reply with exactly: canary-one" >/dev/null )

  local -a hits; hits=("$canon"/**/"$uuid.jsonl"(N))
  if (( ${#hits} != 1 )); then
    _cs_fail "canary transcript not in canonical tree (found ${#hits}, expected 1)"
    print -r -- "verdict: FAIL ($fails)"
    return 1
  fi
  local file="${hits[1]}" size1 size2
  size1=$(stat -f %z "$file")

  print -r -- "canary: resuming $uuid under the primary account"
  ( cd "$cwd" && command claude -p --resume "$uuid" "Reply with exactly: canary-two" >/dev/null )

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
