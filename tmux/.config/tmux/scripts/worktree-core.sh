#!/usr/bin/env bash
# worktree-core.sh — the tmux-free heart of the git-worktree machinery.
#
# This file holds the pure logic (no tmux calls, no window/pane awareness) shared
# by two front-ends:
#   - tmux-worktree.sh  — the `prefix W` fzf popup; SOURCES this file and wraps the
#                         functions below with tmux glue (new-window, send-keys,
#                         display-message).
#   - gwtn (git.zsh)    — a lightweight shell function that creates a worktree +
#                         branch and `cd`s into it in the CURRENT pane (no new
#                         window); INVOKES this file as a CLI: `worktree-core.sh
#                         create <branch> <base>` and reads the printed path.
#
# Dual nature: when SOURCED it only defines wt_* functions (the executable guard at
# the bottom is false). When EXECUTED directly it dispatches a subcommand.
#
# CLI stdout contract (load-bearing — gwtn captures it):
#   `create` prints ONLY the final worktree path to stdout. Every human-facing
#   message (the verb it chose, the copy summary, errors) goes to STDERR, so the
#   caller can do `path="$(worktree-core.sh create ...)"` and get a clean path
#   while the messages still stream to the terminal.
#   `resolve` prints ONLY the verdict line (see wt_resolve_branch) to stdout.
#
# New worktrees land at  ~/dev/.worktrees/<repo>/<branch>  for every project
# (repo = the toplevel's basename; no per-repo special-casing).

# --- repo identity & worktree root -------------------------------------------

# Every project's worktrees live under one root, grouped by repo dir name.
# Root the group on the MAIN checkout, never on `pwd`: run from a linked
# worktree, --show-toplevel is the branch directory, which would nest the next
# worktree under a sibling branch's name instead of the project's. Same reason
# `brief`'s folder scheme resolves the project through --git-common-dir.
wt_worktree_root() {
  printf '%s\n' "$HOME/dev/.worktrees/$(basename "$(wt_main_worktree 2>/dev/null)")"
}

# The main (first) worktree — canonical home for gitignored files we seed from.
wt_main_worktree() {
  git worktree list --porcelain | awk '/^worktree /{print substr($0,10); exit}'
}

# Default base ref for a brand-new branch: the first of these that resolves. A
# fresh clone without origin/HEAD set falls through the chain (fix with
# `git remote set-head origin -a`). NB: the gwtn shell function deliberately does
# NOT use this — it defaults to the *current* branch — but the popup does.
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
: "${WT_BASE_MAX_AGE_MIN:=5}"   # minutes a previous fetch counts as fresh
: "${WT_FETCH_TIMEOUT:=8}"      # seconds to wait for the network probe

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

# True when no fetch has happened in the last WT_BASE_MAX_AGE_MIN minutes.
# `-size +0c` is load-bearing: a fetch killed mid-flight truncates FETCH_HEAD to
# empty with a FRESH mtime, and that has to read as stale (same lesson as the
# `-s` test in git.zsh). --git-common-dir, not --git-dir: FETCH_HEAD lives in the
# main checkout's .git even when we're called from a linked worktree.
wt_base_is_stale() {
  local common
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  [ -n "$common" ] || return 0
  [ -n "$(find "$common/FETCH_HEAD" -size +0c -mmin "-$WT_BASE_MAX_AGE_MIN" 2>/dev/null)" ] && return 1
  return 0
}

# Refresh the remote-tracking refs the merged-check reads. Returns non-zero when
# the probe failed or timed out — callers must SAY so rather than quietly
# grading against last week's base.
wt_fetch_base() {
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
# invalidating — a moved ref is simply a different key — and the appends are
# short enough to be O_APPEND-atomic, which is what makes it safe under the
# fan-out's concurrent writers.
wt_merged_cache_file() {
  local common
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  [ -n "$common" ] || return 1
  printf '%s/wt-merged-cache\n' "$common"
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
  local branch="$1" base="$2" mb tree out
  git merge-base --is-ancestor "$branch" "$base" 2>/dev/null && return 0

  mb="$(git merge-base "$base" "$branch" 2>/dev/null)" || return 1
  [ -n "$mb" ] || return 1
  tree="$(git rev-parse -q --verify "$branch^{tree}" 2>/dev/null)" || return 1
  # A branch whose net diff against the merge base is empty has nothing to match
  # on; call it unmerged rather than let an empty patch decide.
  [ "$(git rev-parse -q --verify "$mb^{tree}" 2>/dev/null)" = "$tree" ] && return 1

  case "$(git cherry "$base" "$(git commit-tree "$tree" -p "$mb" -m _ 2>/dev/null)" 2>/dev/null)" in
    -*) return 0 ;;
  esac

  out="$(git cherry "$base" "$branch" 2>/dev/null)"
  [ -n "$out" ] || return 1
  # Merged iff no line is "+ <sha>" (unapplied). Tested as a string, not piped
  # into grep: `printf | grep -q` can die of SIGPIPE the moment grep matches, and
  # under `set -o pipefail` that turns the match into a nonzero status — which
  # here would invert the verdict and force-delete an unmerged branch.
  case $'\n'"$out" in
    *$'\n'+*) return 1 ;;
  esac
  return 0
}

# --- branch resolution --------------------------------------------------------

# What does <branch> ALREADY refer to? This is the decision that picks wt_add's
# verb, and it exists because the obvious ordering is wrong. `worktree add -b` is
# a CREATION, and a creation succeeds whenever no LOCAL branch exists — so trying
# it first let "create" win every tie, including the tie against a branch that
# exists only on a remote. That produced a brand-new empty branch quietly
# shadowing the remote one, which is the worst available outcome: same name, none
# of the commits, no error. Resolve the name FIRST, then choose the verb.
#
# Prints exactly one line:
#   local                a local branch of that name exists
#   remote <ref>         no local branch; exactly one refs/remotes/*/<branch>
#   ambiguous <ref>…     no local branch; several remotes carry the name
#   absent               nothing, anywhere
#
# In a for-each-ref pattern `*` fills the remote-name slot only — it does not
# cross `/`, so a slashed branch (skill/foo/bar) resolves correctly. But the
# pattern DOES match a longer ref at a component boundary: `…/*/feat/x` also
# matches `…/origin/feat/x/y`. The exact-suffix filter drops those, so a `remote`
# verdict always names a ref that really is <branch>.
wt_resolve_branch() {
  local branch="$1" ref n=0 all=""
  git show-ref --verify --quiet "refs/heads/$branch" && { printf 'local\n'; return 0; }
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    case "$ref" in
      */"$branch") n=$((n + 1)); all="${all:+$all }$ref" ;;
    esac
  done <<EOF
$(git for-each-ref --format='%(refname)' "refs/remotes/*/$branch" 2>/dev/null)
EOF
  case "$n" in
    0) printf 'absent\n' ;;
    1) printf 'remote %s\n' "$all" ;;
    *) printf 'ambiguous %s\n' "$all" ;;
  esac
}

# The same verdict, but with ONE bounded network probe when the answer would be
# "absent" — the only verdict that is dangerous to get wrong from a stale cache.
# Remote-tracking refs are a local cache: a branch pushed since your last fetch
# reads as absent, and absent means "create a new branch off the base" — the same
# silent-shadow bug, just rarer. The probe costs nothing on a hit, and a miss is
# precisely the moment you were about to create a branch and wanted fresh refs
# anyway (gwt otherwise never fetches, so this is also its only guard against
# forking off a stale base). Staleness gate and timeout are the ones from the
# base-freshness section above.
wt_resolve_branch_fresh() {
  local branch="$1" verdict
  verdict="$(wt_resolve_branch "$branch")"
  [ "$verdict" = absent ] || { printf '%s\n' "$verdict"; return 0; }
  wt_base_is_stale || { printf 'absent\n'; return 0; }
  printf 'wt: no branch "%s" here or on a remote — refreshing remote refs…\n' "$branch" >&2
  wt_fetch_base || printf 'wt: fetch failed or timed out — resolving against the last-fetched state\n' >&2
  wt_resolve_branch "$branch"
}

# --- create ------------------------------------------------------------------

# Put <branch> in a worktree at <path>, forking from <base> ONLY if the branch
# does not already exist somewhere. The verb comes from the resolution above:
#
#   local      → check the existing branch out. <base> unused.
#   remote     → `git worktree add <path> <branch>`, whose DWIM creates the local
#                branch at <remote>/<branch> AND sets it as upstream ("branch 'x'
#                set up to track 'origin/x'"). <base> unused.
#   absent     → `--no-track -b` off <base>: a genuinely new branch.
#   ambiguous  → refuse, naming the candidates. git's own error here is a bare
#                "fatal: invalid reference: <branch>", which tells you nothing.
#
# <force_new> (4th arg, default 0) forces the `absent` verb — the escape hatch for
# "I want a new branch that happens to share a name with a remote one". It is the
# inverse of the flag you might expect: the dangerous case is the one where you
# DON'T know the name is taken, so the safe reading has to be the default.
#
# The chosen verb is always announced on stderr. The bug this replaced was bad
# specifically because it was silent, so the fix must not be.
#
# Returns 0/1; on failure prints git's own error (under a header) to stderr so
# either front-end can surface it.
wt_add() {
  local branch="$1" base="$2" path="$3" force_new="${4:-0}"
  local verdict kind tmp rc ref short

  if [ "$force_new" = 1 ]; then verdict="absent"; else verdict="$(wt_resolve_branch_fresh "$branch")"; fi
  kind="${verdict%% *}"

  if [ "$kind" = ambiguous ]; then
    printf 'wt: "%s" exists on more than one remote:\n' "$branch" >&2
    # Unquoted on purpose: one line per ref. Refnames cannot contain whitespace
    # or glob characters, so word-splitting is exactly the right tool here.
    # shellcheck disable=SC2086
    set -- ${verdict#ambiguous }
    for ref in "$@"; do printf '      %s\n' "${ref#refs/remotes/}" >&2; done
    printf '    disambiguate by creating the local branch yourself first, e.g.\n' >&2
    printf '      git branch --track %s <remote>/%s\n' "$branch" "$branch" >&2
    return 1
  fi

  tmp="$(mktemp)"
  # Capture BOTH git streams to $tmp: git prints "Preparing worktree…" (stderr) and
  # "HEAD is now at…" (stdout), and we must not let either leak to OUR stdout — the
  # CLI's stdout is the worktree path alone. Silent on success; on failure the
  # captured output is replayed to stderr.
  case "$kind" in
    local)
      printf 'wt: "%s" already exists locally — checking it out (base not used)\n' "$branch" >&2
      git worktree add "$path" "$branch" >"$tmp" 2>&1
      ;;
    remote)
      # "refs/remotes/origin/feat/x" → short "origin/feat/x", remote "origin".
      short="${verdict#remote refs/remotes/}"
      printf 'wt: "%s" exists only on %s — checking out %s as a tracking branch (base not used)\n' \
        "$branch" "${short%/$branch}" "$short" >&2
      git worktree add "$path" "$branch" >"$tmp" 2>&1
      ;;
    *)
      printf 'wt: creating new branch "%s" off "%s"\n' "$branch" "$(wt_base_display "$base")" >&2
      git worktree add --no-track -b "$branch" "$path" "$base" >"$tmp" 2>&1
      ;;
  esac
  rc=$?

  [ "$rc" -eq 0 ] && { rm -f "$tmp"; return 0; }
  printf 'git worktree add failed:\n' >&2; cat "$tmp" >&2; rm -f "$tmp"
  return 1
}

# Seed the new worktree with the gitignored files/dirs a fresh checkout leaves
# behind (`.env*`, `.npmrc`, `scripts.local/` …), copied from the MAIN worktree.
#
# Patterns: arg $2 if given, else $WORKTREE_COPY_GLOBS, else the default below
# (space/newline-separated; "off"/"none"/… disables). Each pattern matches an
# entry's BASENAME, so ".env*" catches env files at *any depth*
# (application/.env.development.local) and "scripts.local" matches that ignored
# directory; every match is recreated at the same relative path, directories
# copied whole (cp -pR; perms preserved — env files are often 600, scripts +x).
#
# Why `git ls-files -oi --exclude-standard --directory`:
#   -oi --exclude-standard  → only paths git IGNORES — exactly "what `worktree add`
#                             didn't bring over"; never tracked paths (already
#                             checked out) nor untracked-but-unignored WIP.
#   --directory             → collapses a wholly-ignored dir to ONE "dir/" entry
#                             instead of every file under it (e.g. the hundreds of
#                             .env files dependencies ship inside node_modules/).
#                             We strip the slash, match the basename, and cp -pR it
#                             ONLY if it matches — so the PATTERN is the only gate:
#                             node_modules/ & dist/ are excluded purely by not
#                             matching. KEEP DEFAULT PATTERNS SPECIFIC; a broad glob
#                             like "*" would now drag in whole ignored dirs.
#
# Emits "worktree: copied N item(s) from main" to STDOUT (the popup captures it for
# display-message; the CLI re-routes it to stderr). Source is always the main
# worktree, regardless of which worktree the caller launched from.
wt_copy_ignored() {
  local newdir="$1" globs="${2:-}"
  local main rel relstripped src dst base pat copied=0
  main="$(wt_main_worktree)"
  [ -n "$main" ] && [ "$main" != "$newdir" ] || return 0
  [ -z "$globs" ] && globs="${WORKTREE_COPY_GLOBS:-}"
  case "$globs" in off|none|no|0|false|disabled) return 0 ;; esac
  [ -z "$globs" ] && globs=".env* .npmrc scripts.local .duet docs.local"
  set -f; set -- $globs; set +f          # split patterns; never pathname-expand them
  while IFS= read -r -d '' rel; do
    relstripped="${rel%/}"               # --directory yields ignored dirs as "dir/"
    src="$main/$relstripped"
    [ -e "$src" ] || continue
    base="${relstripped##*/}"
    for pat in "$@"; do
      case "$base" in
        $pat)
          dst="$newdir/$relstripped"
          mkdir -p "$(dirname "$dst")"
          cp -pR "$src" "$dst" 2>/dev/null && copied=$((copied + 1))
          break ;;
      esac
    done
  done < <(git -C "$main" ls-files -oi --exclude-standard --directory -z)
  [ "$copied" -gt 0 ] && printf 'worktree: copied %d item(s) from main\n' "$copied"
  return 0
}

# Pick the dependency-install command for a Node project from its committed
# lockfile (so we never clobber an npm repo with a pnpm lockfile), defaulting to
# pnpm (repo convention). Prints the command; prints nothing if not a Node project.
# Pure selection only — DELIVERY (popup: send-keys into the new window) is the
# front-end's job. (gwtn does not install at all.)
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

# create <branch> [base] [--no-copy] [--new]
#   base defaults to wt_default_base (origin/HEAD chain) when omitted, and is used
#   ONLY when the branch is being created — an existing local or remote branch is
#   checked out and the base is irrelevant (wt_add says which happened). --new
#   forces creation even when a remote branch of that name exists.
#   Prints ONLY the worktree path to stdout.
_wt_core_create() {
  local branch="" base="" copy=1 force_new=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-copy) copy=0 ;;
      --new) force_new=1 ;;
      --) shift; break ;;
      -*) printf 'create: unknown flag: %s\n' "$1" >&2; return 2 ;;
      *)  if   [ -z "$branch" ]; then branch="$1"
          elif [ -z "$base" ];   then base="$1"
          fi ;;
    esac
    shift
  done
  [ -n "$branch" ] || { printf 'create: branch name required\n' >&2; return 2; }
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || { printf 'create: not inside a git repository: %s\n' "$PWD" >&2; return 1; }
  [ -n "$base" ] || base="$(wt_default_base)"

  local path; path="$(wt_worktree_root)/$branch"
  [ -e "$path" ] && { printf 'create: path already exists: %s\n' "$path" >&2; return 1; }
  mkdir -p "$(dirname "$path")"
  wt_add "$branch" "$base" "$path" "$force_new" || return 1
  if [ "$copy" -eq 1 ]; then
    local msg; msg="$(wt_copy_ignored "$path")"
    [ -n "$msg" ] && printf '%s\n' "$msg" >&2
  fi
  printf '%s\n' "$path"
}

# resolve <branch>
#   Print what <branch> already refers to (the wt_resolve_branch verdict line),
#   refreshing remote refs once if the answer would be "absent". Exists so a
#   front-end can find out whether a base is even a question BEFORE prompting for
#   one: gwt used to ask "fork from <current branch>?" and then discard the answer
#   whenever the branch already existed. Doing the probe here also means the one
#   bounded fetch happens before the prompt, not after it.
_wt_core_resolve() {
  local branch="${1:-}"
  [ -n "$branch" ] || { printf 'resolve: branch name required\n' >&2; return 2; }
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || { printf 'resolve: not inside a git repository: %s\n' "$PWD" >&2; return 1; }
  wt_resolve_branch_fresh "$branch"
}

_wt_core_main() {
  set -u
  local sub="${1:-}"; [ $# -gt 0 ] && shift
  case "$sub" in
    create)  _wt_core_create "$@" ;;
    resolve) _wt_core_resolve "$@" ;;
    "")      printf 'worktree-core.sh: missing subcommand (try: create, resolve)\n' >&2; return 2 ;;
    *)       printf 'worktree-core.sh: unknown subcommand: %s\n' "$sub" >&2; return 2 ;;
  esac
}

# Run the CLI only when executed directly; a `source` leaves BASH_SOURCE[0] != $0.
# A clean `if` (not `[ … ] &&`) so sourcing returns 0 — a trailing false && would
# make `source worktree-core.sh` itself "fail" (same lesson as .zshenv's exit 0).
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  _wt_core_main "$@"
fi
