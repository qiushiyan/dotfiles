#!/usr/bin/env bash
# tmux worktree support: snapshots, recovery refs, and removal housekeeping.
# gwt (~/dev/gwt, installed into ~/.local/bin, resolved through PATH) owns
# creation, listing, the trunk, and every merged verdict (gwt list/merged/trunk).
# This file keeps what only the popup's trash-and-sweep removal needs.
# The CLI shim at the bottom keeps already-running shells usable after migration.

# --- repo identity & worktree root -------------------------------------------

# Read placement from gwt so changing worktree_root also changes cleanup's bounds.
wt_worktree_root() {
  gwt path
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
