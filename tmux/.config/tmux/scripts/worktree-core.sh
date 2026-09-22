#!/usr/bin/env bash
# tmux worktree support: merge verdicts, listing, snapshots, and removal.
# Creation and branch resolution live in ~/dev/gwt, installed by make install into ~/.local/bin; resolved through PATH.
# The CLI shim at the bottom keeps already-running shells usable after migration.

# --- repo identity & worktree root -------------------------------------------

# Read placement from gwt so changing worktree_root also changes cleanup's bounds.
wt_worktree_root() {
  gwt path
}

# Configuration is read once per popup; helper-only callers load it on demand.
WT_CONFIG_LOADED=0
wt_load_config() {
  local cfg
  cfg="$(gwt config show --json)" || return 1
  WT_BASE_MAX_AGE_SECONDS="$(printf '%s' "$cfg" | jq -er '.fetch.max_age')" || return 1
  WT_FETCH_TIMEOUT="$(printf '%s' "$cfg" | jq -er '.fetch.timeout')" || return 1
  WT_CONFIG_LOADED=1
}

# After moving a worktree away, remove only its empty branch-name parents.
# Paths come from Git's absolute worktree list. Never scan sibling checkouts:
# even an empty-directory find walks all their dependency trees.
wt_remove_empty_parents() {
  local root="$1" parent="${2%/*}"
  while true; do
    case "$parent" in "$root"/*) ;; *) break ;; esac
    rmdir "$parent" 2>/dev/null || break
    parent="${parent%/*}"
  done
  return 0
}

# The main (first) worktree — canonical home for gitignored files we seed from.
wt_main_worktree() {
  git worktree list --porcelain | awk '/^worktree /{print substr($0,10); exit}'
}

# Merge/reap base: the first of these refs that resolves. Creation uses gwt
# config independently. A clone without origin/HEAD falls through the chain.
wt_default_base() {
  local b
  for b in origin/HEAD origin/main origin/master main master; do
    if git rev-parse --verify --quiet "$b" >/dev/null 2>&1; then echo "$b"; return; fi
  done
  git rev-parse --abbrev-ref HEAD
}

# What to CALL the base in a message. wt_default_base usually returns the symref
# "origin/HEAD", which tells a human nothing — "not merged into origin/HEAD"
# reads like an internal error. Resolve it to the branch it points at
# (origin/develop, origin/main, …) for anything the user reads.
wt_base_display() {
  local base="${1:-$(wt_default_base)}"
  git rev-parse --abbrev-ref "$base" 2>/dev/null || printf '%s\n' "$base"
}

# --- base freshness ------------------------------------------------------------

# Merged-ness is only as honest as the base ref, and NOTHING in this machinery
# used to fetch: origin/HEAD sat frozen at your last pull, so a PR merged on
# GitHub ten minutes ago was invisible and its branch was reported "NOT merged".
# Same shape of guard as the branch-creation wrapper in git.zsh: skip the network
# when a fetch happened recently, and bound the probe with `timeout` so a dead
# network can't hang a caller.

# The remote whose refs the base lives on ("origin"), or nothing when the base is
# a local branch (the main/master tail of wt_default_base's chain) — there's
# nothing to refresh in that case. Derived from the FULL ref name so a local
# branch called `feat/x` can't masquerade as remote `feat`.
wt_base_remote() {
  local full
  full="$(git rev-parse --symbolic-full-name "$(wt_default_base)" 2>/dev/null)"
  case "$full" in
    refs/remotes/*) full="${full#refs/remotes/}"; printf '%s\n' "${full%%/*}" ;;
  esac
}

# True when no fetch has happened within the configured freshness window.
# The nonempty-file check is load-bearing: a fetch killed mid-flight truncates FETCH_HEAD to
# empty with a FRESH mtime, and that has to read as stale (same lesson as the
# `-s` test in git.zsh). --git-common-dir, not --git-dir: FETCH_HEAD lives in the
# main checkout's .git even when we're called from a linked worktree.
wt_base_is_stale() {
  [ "$WT_CONFIG_LOADED" = 1 ] || wt_load_config || return 0
  local common modified
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  [ -n "$common" ] && [ -s "$common/FETCH_HEAD" ] || return 0
  modified="$(stat -f %m "$common/FETCH_HEAD" 2>/dev/null)" ||
    modified="$(stat -c %Y "$common/FETCH_HEAD" 2>/dev/null)" || return 0
  awk -v now="$(date +%s)" -v modified="$modified" -v age="$WT_BASE_MAX_AGE_SECONDS" \
    'BEGIN { exit !(now - modified < age) }' && return 1
  return 0
}

# Refresh the remote-tracking refs the merged-check reads. Returns non-zero when
# the probe failed or timed out — callers must SAY so rather than quietly
# grading against last week's base.
wt_fetch_base() {
  [ "$WT_CONFIG_LOADED" = 1 ] || wt_load_config || return 1
  local remote
  remote="$(wt_base_remote)"
  [ -n "$remote" ] || return 0
  if command -v timeout >/dev/null 2>&1; then
    timeout "$WT_FETCH_TIMEOUT" git fetch --quiet "$remote"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$WT_FETCH_TIMEOUT" git fetch --quiet "$remote"
  else
    git fetch --quiet "$remote"
  fi
}

# --- merged-ness ---------------------------------------------------------------

# Is <branch>'s work already contained in <base>? THE one place that decides,
# because getting it wrong is either a lost branch or a false alarm that trains
# you to force-delete past warnings. Three ways work lands on a base, and only
# the first is visible in the commit graph:
#
#   1. merge commit / fast-forward → the branch's commits ARE ancestors.
#   2. GitHub "Squash and merge"   → base gets ONE brand-new commit that shares
#      no history with the branch. `merge-base --is-ancestor` says "not merged"
#      about work that is demonstrably shipped — the false alarm this exists to
#      kill. Detect it by PATCH IDENTITY: collapse the branch to a single
#      dangling commit (its tip's tree, parented on the merge base) and ask
#      `git cherry` whether the base already carries that patch ("-" = applied).
#   3. GitHub "Rebase and merge"   → base gets the commits re-authored, new SHAs,
#      same patches. Per-commit `git cherry`: merged iff EVERY commit reads "-".
# Both patch paths also require a clean merge leaving the base tree unchanged,
# because patch IDs ignore whitespace that can change code semantics.
#
# Cost order is deliberate — (1) is a graph query, (2) and (3) each scan the
# patch-ids of merge-base..base (~0.1–0.4s here), so only a branch that is
# genuinely unmerged pays for both. The dangling commit-tree object is
# unreachable and gets swept by the next `git gc`.
#
# The answer is MEMOIZED (below) because it is a pure function of two commit
# shas. Callers can treat it as cheap.

# Where the memo lives. Without it, drawing the "merged" tag in the popup list
# costs a patch-id scan per worktree on EVERY open (~0.6s parallel on a
# 7-worktree repo) to recompute an answer that only changes when a branch or the
# base actually moves; with it, the first open after a fetch pays and the rest
# are free. Lines are "<branch-sha> <base-sha> <0|1>". Nothing needs
# invalidating for ref movement; the filename versions the verdict policy. Appends are
# short enough to be O_APPEND-atomic, which is what makes it safe under the
# fan-out's concurrent writers.
wt_merged_cache_file() {
  local common
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  [ -n "$common" ] || return 1
  printf '%s/wt-merged-cache-v3\n' "$common"
}

# Keep the memo from growing without bound; called at front-end startup, not per
# lookup. Cheap: the file is one short line per (branch, base) pair ever seen.
wt_trim_merged_cache() {
  local cache max="${1:-2000}" tmp
  cache="$(wt_merged_cache_file)" || return 0
  [ -f "$cache" ] || return 0
  [ "$(wc -l < "$cache" 2>/dev/null || echo 0)" -gt "$max" ] || return 0
  tmp="$cache.$$"
  tail -n "$((max / 2))" "$cache" > "$tmp" 2>/dev/null && mv -f "$tmp" "$cache" 2>/dev/null
  rm -f "$tmp" 2>/dev/null
  return 0
}

wt_merged_into() {
  local branch="$1" base="$2" shas bsha tsha cache rc
  shas="$(git rev-parse -q "$branch^{commit}" "$base^{commit}" 2>/dev/null)"
  bsha="${shas%%$'\n'*}"; tsha="${shas##*$'\n'}"
  case "$bsha$tsha" in
    ''|*[!0-9a-f]*) bsha="" ;;          # rev-parse echoes the raw arg when a ref is missing
  esac
  if [ -n "$bsha" ] && [ "$bsha" != "$tsha" ]; then
    cache="$(wt_merged_cache_file)" || cache=""
    if [ -n "$cache" ] && [ -f "$cache" ]; then
      case "$(grep -m1 "^$bsha $tsha " "$cache" 2>/dev/null)" in
        *' 1') return 0 ;;
        *' 0') return 1 ;;
      esac
    fi
    _wt_merged_compute "$branch" "$base"; rc=$?
    [ -n "$cache" ] && printf '%s %s %d\n' "$bsha" "$tsha" "$((1 - rc))" >> "$cache" 2>/dev/null
    return $rc
  fi
  _wt_merged_compute "$branch" "$base"
}

# The uncached verdict — the three checks described above, in cost order.
_wt_merged_compute() {
  local branch="$1" base="$2" mb tree out merges
  git merge-base --is-ancestor "$branch" "$base" 2>/dev/null && return 0

  mb="$(git merge-base "$base" "$branch" 2>/dev/null)" || return 1
  [ -n "$mb" ] || return 1
  tree="$(git rev-parse -q --verify "$branch^{tree}" 2>/dev/null)" || return 1
  # A branch whose net diff against the merge base is empty has nothing to match
  # on; call it unmerged rather than let an empty patch decide.
  [ "$(git rev-parse -q --verify "$mb^{tree}" 2>/dev/null)" = "$tree" ] && return 1

  case "$(git cherry "$base" "$(git commit-tree "$tree" -p "$mb" -m _ 2>/dev/null)" 2>/dev/null)" in
    -*) _wt_merge_leaves_base_unchanged "$branch" "$base"; return $? ;;
  esac

  # git cherry omits merge commits, including edits made during the merge.
  merges="$(git rev-list --merges "$base..$branch" 2>/dev/null)" || return 1
  [ -z "$merges" ] || return 1

  out="$(git cherry "$base" "$branch" 2>/dev/null)"
  [ -n "$out" ] || return 1
  # Merged iff no line is "+ <sha>" (unapplied). Tested as a string, not piped
  # into grep: `printf | grep -q` can die of SIGPIPE the moment grep matches, and
  # under `set -o pipefail` that turns the match into a nonzero status — which
  # here would invert the verdict and force-delete an unmerged branch.
  case $'\n'"$out" in
    *$'\n'+*) return 1 ;;
  esac
  _wt_merge_leaves_base_unchanged "$branch" "$base"
}

# Patch IDs ignore whitespace, including significant Python/YAML indentation.
# Accept a patch match only when merging leaves the base's exact contents intact.
_wt_merge_leaves_base_unchanged() {
  local tree base_tree
  tree="$(git merge-tree --write-tree "$2" "$1" 2>/dev/null)" || return 1
  base_tree="$(git rev-parse --verify "$2^{tree}" 2>/dev/null)" || return 1
  [ "$tree" = "$base_tree" ]
}

# Pick the dependency-install command for a Node project from its committed
# lockfile (so we never clobber an npm repo with a pnpm lockfile), defaulting to
# pnpm (repo convention). Prints the command; prints nothing if not a Node project.
# Pure selection only — DELIVERY (popup: send-keys into the new window) is the
# front-end's job. (gwt does not install at all.)
wt_install_cmd() {
  local path="$1"
  [ -f "$path/package.json" ] || return 0
  if   [ -f "$path/pnpm-lock.yaml" ];    then echo "pnpm install"
  elif [ -f "$path/yarn.lock" ];         then echo "yarn"
  elif [ -f "$path/package-lock.json" ]; then echo "npm install"
  elif [ -f "$path/bun.lockb" ] || [ -f "$path/bun.lock" ]; then echo "bun install"
  else echo "pnpm install"; fi
}

# --- parallel fan-out ----------------------------------------------------------

# wt_fanout <fn> [args…] — run <fn> once per "<f1>\t<f2>" line on stdin, all at
# once, and print the results IN INPUT ORDER. Each job gets the line's fields
# followed by [args…].
#
# Exists because every per-worktree question here is a git process (status, and
# now the patch-id merge test), and asking them serially made the cost of the
# popup scale with how many worktrees you keep: 7 worktrees measured 2.6s cold
# / 0.30s warm serially, 0.03s fanned out. Two things are load-bearing:
#
#   - Order comes from zero-padded FILENAMES, not from completion order.
#   - The whole loop runs in an explicit ( … ) subshell so its bare `wait`
#     cannot adopt a caller's background job. The popup keeps a base fetch in
#     flight while this runs; a `wait` that swallowed it would block the list on
#     the network, which is the exact thing that fetch is backgrounded to avoid.
wt_fanout() {
  local fn="$1"; shift
  local tmpd i=0 f1 f2
  tmpd="$(mktemp -d "${TMPDIR:-/tmp}/wt-fanout.XXXXXX")" || return 1
  (
    while IFS=$'\t' read -r f1 f2; do
      [ -n "$f1" ] || continue
      i=$((i + 1))
      "$fn" "$f1" "$f2" "$@" > "$tmpd/$(printf '%05d' "$i")" 2>/dev/null &
    done
    wait
  )
  cat "$tmpd"/* 2>/dev/null
  rm -rf "$tmpd"
  return 0
}

# The worktree list as "<path>\t<branch>" lines, detached entries dropped (they
# emit no `branch` record in the porcelain output). The fan-out's input shape.
wt_list_tsv() {
  git worktree list --porcelain | awk '
    /^worktree /{p = substr($0, 10)}
    /^branch /  {b = $2; sub("refs/heads/", "", b); print p "\t" b}
  '
}

# --- pre-deletion safety net ---------------------------------------------------

# Where snapshots taken before something irreversible are parked. Plain refs, so
# the objects stay reachable and survive `git gc`; outside refs/heads, so they
# never appear in `git branch`, in a worktree list, or in a completion. Expired
# by wt_prune_backups — a safety net nobody prunes is just a disk leak.
WT_BACKUP_NS="refs/wt-trash"

# Snapshot a worktree's ENTIRE working state as one commit; prints its sha.
# Taken before a dirty worktree is discarded, where the only record of the work
# used to be the directory about to be rm -rf'd — one mistyped `y` and it was
# gone with no undo, since the trash sweep for that batch fires immediately.
#
# Why not `git stash create`: it captures tracked modifications only, and the
# dirt in an agent's worktree is usually new UNTRACKED files. So we build the
# tree ourselves in a SCRATCH index (GIT_INDEX_FILE) — the worktree's own index
# is untouched, nothing lands on the shared stash list, and `add -A` still obeys
# .gitignore so node_modules doesn't get committed. Parented on HEAD, so
# `git diff HEAD <ref>` reads as the changes that were pending.
wt_snapshot_worktree() {
  local path="$1" msg="${2:-worktree snapshot}" idx tree parent
  idx="$(mktemp "${TMPDIR:-/tmp}/wt-index.XXXXXX")" || return 1
  rm -f "$idx"                      # git creates the index itself; an empty file is not a valid one
  parent="$(git -C "$path" rev-parse -q --verify HEAD 2>/dev/null)"
  GIT_INDEX_FILE="$idx" git -C "$path" read-tree HEAD 2>/dev/null || true
  GIT_INDEX_FILE="$idx" git -C "$path" add -A 2>/dev/null || { rm -f "$idx"; return 1; }
  tree="$(GIT_INDEX_FILE="$idx" git -C "$path" write-tree 2>/dev/null)"
  rm -f "$idx"
  [ -n "$tree" ] || return 1
  if [ -n "$parent" ]; then
    git -C "$path" commit-tree "$tree" -p "$parent" -m "$msg" 2>/dev/null
  else
    git -C "$path" commit-tree "$tree" -m "$msg" 2>/dev/null
  fi
}

# Park <sha> under WT_BACKUP_NS and print the ref. <slot> must be unique within
# the batch, because <name> alone is not enough: two branches named `feat` and
# `feat/x` flatten differently but a ref store still can't hold both
# `…/feat` and `…/feat/x` (directory/file conflict), and a plain overwrite would
# silently drop one of the two things we just promised to keep.
wt_backup_ref() {
  local batch="$1" slot="$2" name="$3" sha="$4" ref
  [ -n "$sha" ] || return 1
  ref="$WT_BACKUP_NS/$batch/$slot-$(printf '%s' "$name" | tr '/' '-')"
  git update-ref "$ref" "$sha" 2>/dev/null || return 1
  printf '%s\n' "$ref"
}

# Drop backup refs older than <days>. The batch id is an epoch, so the age is in
# the ref name — same age-gated shape as the trash-directory sweep, and for the
# same reason: without it, every branch ever force-deleted stays pinned in the
# object store forever.
wt_prune_backups() {
  local days="${1:-30}" cutoff ref batch
  case "$days" in ''|*[!0-9]*) return 0 ;; esac
  [ "$days" -gt 0 ] || return 0
  cutoff=$(( $(date +%s) - days * 86400 ))
  git for-each-ref --format='%(refname)' "$WT_BACKUP_NS" 2>/dev/null | while IFS= read -r ref; do
    batch="${ref#"$WT_BACKUP_NS"/}"; batch="${batch%%/*}"; batch="${batch%%.*}"
    case "$batch" in ''|*[!0-9]*) continue ;; esac
    [ "$batch" -lt "$cutoff" ] && git update-ref -d "$ref" 2>/dev/null
  done
  return 0
}

# --- reap candidacy ------------------------------------------------------------

# Worktrees that are safe to batch-remove ("reap"): linked (never the main
# worktree), on a real branch (detached entries emit no `branch` line in the
# porcelain output, so they drop out in awk), clean (no uncommitted changes),
# and already merged into the default base. Prints "path<TAB>branch" lines;
# prints nothing when there's nothing to reap. Merged-ness is wt_merged_into, so
# squash- and rebase-merged branches DO count — reaping them is the common case
# on a GitHub repo, and they used to be invisible here. Callers that care about
# a fresh answer should wt_fetch_base first; the popup front-end additionally
# excludes the worktree it was launched from.
wt_reap_candidates() {
  local main base
  main="$(wt_main_worktree)"
  base="$(wt_default_base)"
  # Fanned out: candidacy costs a `git status` plus a merge test that can run to
  # ~0.4s on a patch-id scan, so serially this grew with the worktree count.
  wt_list_tsv | wt_fanout _wt_reap_one "$main" "$base"
}

# One candidacy verdict, run as a fan-out job: prints the row or nothing.
# --no-optional-locks so a probe can't contend with an agent working in that
# worktree for index.lock — nothing here needs to write.
_wt_reap_one() {
  local path="$1" branch="$2" main="$3" base="$4"
  [ "$path" = "$main" ] && return 0
  [ -n "$(git --no-optional-locks -C "$path" status --porcelain 2>/dev/null)" ] && return 0
  wt_merged_into "$branch" "$base" || return 0
  printf '%s\t%s\n' "$path" "$branch"
}

# --- CLI (only when EXECUTED directly, not when sourced) ----------------------

_wt_core_create() {
  gwt create --non-interactive "$@"
}

_wt_core_resolve() {
  gwt resolve "$@"
}

# Compatibility for shells and brief binaries loaded before the migration.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  sub="${1:-}"; [ $# -gt 0 ] && shift
  case "$sub" in
    create) _wt_core_create "$@" ;;
    resolve) _wt_core_resolve "$@" ;;
    *) printf 'worktree-core.sh: use gwt create or gwt resolve\n' >&2; exit 2 ;;
  esac
fi
