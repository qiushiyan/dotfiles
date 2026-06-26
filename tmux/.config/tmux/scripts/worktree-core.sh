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
#   message (the copy summary, errors) goes to STDERR, so the caller can do
#   `path="$(worktree-core.sh create ...)"` and get a clean path while the messages
#   still stream to the terminal.
#
# New worktrees land at  ~/dev/.worktrees/<repo>/<branch>  for every project
# (repo = the toplevel's basename; no per-repo special-casing).

# --- repo identity & worktree root -------------------------------------------

# Every project's worktrees live under one root, grouped by repo dir name.
wt_worktree_root() {
  printf '%s\n' "$HOME/dev/.worktrees/$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"
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

# --- create ------------------------------------------------------------------

# Add a worktree at <path> for branch <branch>, forked from <base>. Tries a NEW
# branch first (--no-track -b); if that branch already exists, falls back to
# checking it out into the worktree. Returns 0/1; on failure prints git's own
# error (under a header) to stderr so either front-end can surface it.
wt_add() {
  local branch="$1" base="$2" path="$3" tmp
  tmp="$(mktemp)"
  # Capture BOTH git streams to $tmp: git prints "Preparing worktree…" (stderr) and
  # "HEAD is now at…" (stdout), and we must not let either leak to OUR stdout — the
  # CLI's stdout is the worktree path alone. Silent on success; on failure the
  # captured output is replayed to stderr.
  if git worktree add --no-track -b "$branch" "$path" "$base" >"$tmp" 2>&1; then
    rm -f "$tmp"; return 0
  elif git worktree add "$path" "$branch" >>"$tmp" 2>&1; then
    rm -f "$tmp"; return 0   # branch already existed — checked it out into the worktree instead
  fi
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

# --- CLI (only when EXECUTED directly, not when sourced) ----------------------

# create <branch> [base] [--no-copy]
#   base defaults to wt_default_base (origin/HEAD chain) when omitted — but gwtn
#   always passes an explicit base (the current branch), so that default is just a
#   standalone-use convenience. Prints ONLY the worktree path to stdout.
_wt_core_create() {
  local branch="" base="" copy=1
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-copy) copy=0 ;;
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
  wt_add "$branch" "$base" "$path" || return 1
  if [ "$copy" -eq 1 ]; then
    local msg; msg="$(wt_copy_ignored "$path")"
    [ -n "$msg" ] && printf '%s\n' "$msg" >&2
  fi
  printf '%s\n' "$path"
}

_wt_core_main() {
  set -u
  local sub="${1:-}"; [ $# -gt 0 ] && shift
  case "$sub" in
    create) _wt_core_create "$@" ;;
    "")     printf 'worktree-core.sh: missing subcommand (try: create)\n' >&2; return 2 ;;
    *)      printf 'worktree-core.sh: unknown subcommand: %s\n' "$sub" >&2; return 2 ;;
  esac
}

# Run the CLI only when executed directly; a `source` leaves BASH_SOURCE[0] != $0.
[ "${BASH_SOURCE[0]}" = "$0" ] && _wt_core_main "$@"
