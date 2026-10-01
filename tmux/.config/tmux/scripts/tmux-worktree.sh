#!/usr/bin/env bash
# tmux-worktree.sh — unified git-worktree popup for tmux (bound to prefix W).
#
# Launched from a tmux display-popup. Lists the current repo's worktrees in fzf
# (» marks the worktree you're in, * marks a dirty one, "· merged" marks one the
# reap would take — @worktree_show_merged off to drop it). The bare list paints
# at once; the * and merged marks land a moment later, when the per-worktree
# probes finish (see bare_rows).
#   enter        switch to the highlighted worktree's window; if the typed name
#                matches no worktree, place that branch in one and open its window
#   ctrl-y       copy the highlighted worktree's path — or every marked one's,
#                one per line — and close
#   ctrl-n       place the TYPED name in a worktree even when the query still
#                fuzzy-matches an existing worktree. gwt resolves the name
#                first, so an existing local or remote branch is checked out
#                rather than created; only a name that exists nowhere is new.
#   tab/ctrl-a   mark one / toggle all entries (shift-tab unmarks)
#   ctrl-x       remove the marked worktrees (or the highlighted one if none are
#                marked) as ONE confirmed batch — trash-and-sweep, see below
#   ctrl-g       reap: batch-remove every clean worktree whose branch is already
#                merged into the trunk (end-of-week cleanup in 3 keys) — gwt's
#                verdict counts squash and rebase merges, and the trunk is
#                refreshed first, so a PR you merged in the browser counts too
#   ctrl-p       PR picker: list open GitHub PRs via gh; enter checks one out
#                into a worktree, ctrl-o opens it in the browser, ctrl-r
#                refetches the list (it's memoized for the popup's lifetime)
#   ctrl-d/u     scroll the preview half a page (vim-style)
#
# switch / create / PR-checkout / copy are EXIT operations (you land in the target
# window and the popup closes); remove and reap are IN-POPUP operations (they
# loop back to the refreshed list so you can keep going). A failed create also
# loops back.
#
# REMOVAL IS TRASH-AND-SWEEP: each selected worktree is mv'd into
# ~/dev/.worktrees/.trash/<batch> (a same-filesystem rename — instant no matter
# how big node_modules is), `git worktree prune` drops the metadata, windows
# are killed, branch deletion is offered in aggregate (merged → one [Y/n];
# unmerged → explicit force), and the real rm -rf runs server-side
# in the background via `tmux run-shell -b`, so it survives the popup closing.
# Because mv bypasses `git worktree remove`'s dirty-refusal, THIS script owns
# the dirty check: dirty worktrees are flagged in the confirm list and removed
# only after a second explicit [y/N] (declining keeps them and removes just the
# clean ones). NOTHING IRREVERSIBLE HAPPENS WITHOUT A WAY BACK: a dirty
# worktree's uncommitted work (tracked AND untracked) and a force-deleted
# branch's tip are parked at refs/wt-trash/<batch>/… first, and the ref is
# printed with the command that restores it. Windows are killed by PATH, in
# every session — a window pointing at a deleted directory is broken wherever
# it lives.
#
# gwt config chooses base, root, and seeding. The default placement is
# ~/dev/.worktrees/<repo>/<branch>. Create seeds the worktree, then opens its window:
#   - copies the gitignored files/dirs a checkout leaves behind (`.env* .npmrc
#     scripts.local .duet docs.local` by default, from the MAIN worktree, at any
#     depth; matched directories are copied whole) into the new tree — configurable
#     via copy_globs in gwt config ([] to disable);
#   - sends ONE visible, cancellable command line into the new window: the
#     dependency install for a Node project (pnpm/npm/yarn/bun, from the
#     lockfile; @worktree_auto_install off to disable) chained with the
#     post-create command — default "x" (the claude alias), so a fresh worktree
#     lands with the agent already starting. Override or disable it with
#     @worktree_post_create_cmd ("off" to disable).
#
# The fzf UI colors itself from the live tmux palette (the @thm_* options the
# theme files publish), so every terminal theme — including future ones —
# styles this popup with zero per-theme config here.
#
# No args: the session is self-detected via `tmux display-message`, and $PWD is
# the repo (the popup is opened there by `display-popup -d` in the keybinding).
# NB: display-popup does NOT expand #{...} in its command argument, so the
# session must be self-detected, not passed as $1 (it would arrive literally).
#
# Portability note: macOS ships bash 3.2 and there is no brew bash here — keep
# this script array-free (strings of TSV lines instead); empty arrays under
# `set -u` are fatal on 3.2.

set -u

# gwt owns creation, seeding, listing, and verdicts; worktree-core.sh owns
# snapshots and recovery refs; this script owns the tmux/fzf UI and removal flow.
source "${BASH_SOURCE[0]%/*}/worktree-core.sh"
. "${BASH_SOURCE[0]%/*}/lib/tmux-common.sh"   # fzf_colors_from_palette

# --- list:  "<markers> <branch>\t<path>\t<branch>"  (display = field 1) --------

# Marker column: » (green) = the worktree the popup was launched from,
# * (yellow) = dirty. Plain ANSI colors so the terminal theme maps them. A clean
# worktree whose branch has already landed also gets a dim "· merged" tag, so
# the reap set is visible BEFORE pressing ctrl-g. Disable with
# @worktree_show_merged off.
#
# gwt list owns the probes: a status per worktree and a merged verdict against
# the trunk (squash and rebase merges included), memoized, one Git process per
# CPU. They cost ~0.3-1s on 25 worktrees, so they are not the first paint.

# One eligibility rule for the "· merged" tag and for ctrl-g, so the tag marks
# exactly the reap set: merged into the trunk, and removable — not the main
# worktree or the one you are in, clean, unlocked, and still on disk. A row
# whose status probe failed (.error) is unknown state, so it is never reaped.
WT_REAPABLE='def reapable: .merged == true and (.main or .current or .dirty or .locked or .prunable or .error | not);'

probed_rows() {
  local json show=true
  case "$(tmux show-option -gqv @worktree_show_merged 2>/dev/null)" in
    off|0|false|no|disabled) show=false ;;
  esac
  json="$(gwt list --json 2>/dev/null)" || { bare_rows; return; }
  printf '%s\n' "$json" | jq -r --argjson show "$show" "$WT_REAPABLE"'
    .worktrees[]
    | (.branch // "(detached)") as $b
    | (if .current then "\u001b[32m»\u001b[0m" else " " end)
      + (if .dirty then "\u001b[33m*\u001b[0m" else " " end)
      + " " + $b
      + (if $show and reapable then "\u001b[32m · merged\u001b[0m" else "" end)
      + "\t" + .path + "\t" + $b'
}

# The first paint: probed_rows' layout with the probed columns blank, for the
# cost of one `git worktree list`. The picker loads these, and its load event
# re-runs this script with --rows to swap in the probed rows once gwt returns.
# reload-sync keeps the bare list live meanwhile; --id-nth=2 (the path) carries
# marks across the swap, and the cursor keeps its index because gwt lists the
# same worktrees in the same (Git's) order: bare repositories are skipped,
# detached and prunable checkouts kept. --track would also block typing until
# the swap, so it stays off.
bare_rows() {
  git worktree list --porcelain | awk -v cur="$cur_top" '
    function row(b) { printf "%s  %s\t%s\t%s\n", (p == cur ? "\033[32m»\033[0m" : " "), b, p, b }
    /^worktree /{p = substr($0, 10)}
    /^branch /  {b = $2; sub("refs/heads/", "", b); row(b)}
    /^detached$/{row("(detached)")}
  '
}

cur_top="$(git rev-parse --show-toplevel 2>/dev/null)"   # the worktree we're IN

# fzf's re-entry for the probed rows. It runs in the picker's cwd, so gwt's
# "current" is the parent's cur_top, and it skips every startup side effect.
if [ "${1:-}" = --rows ]; then
  probed_rows
  exit 0
fi

# The invoking client's session receives new windows; its active pane is where
# ctrl-y's toclip finds the client to copy to, since a popup has no pane.
IFS=$'\t' read -r session origin_pane <<EOF
$(tmux display-message -p '#{session_name}'$'\t''#{pane_id}' 2>/dev/null)
EOF

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "not inside a git repository: $PWD"
  sleep 1.5
  exit 0
fi

# Everything from here to the picker is on the first paint's path, so anything
# the list does not need runs in the background: two gwt calls and the
# housekeeping below were ~100ms of a ~150ms startup. Listing, switching and
# copying therefore work even when gwt's configuration does not load; creation
# and removal report gwt's own error.

# --- trash (removal staging) --------------------------------------------------

# Batch removal stages worktrees in <gwt root's parent>/.trash (same filesystem
# as the root, so mv is a rename) and sweeps in the background.
wt_shell_quote() {
  local value="$1"
  value=${value//\'/\'\\\'\'}
  printf "'%s'" "$value"
}
trash_dir_for() { printf '%s/.trash' "${1%/*}"; }

# Housekeeping, beside the first paint. Nothing waits on this job;
# await_trunk waits on its own pid only.
#   - Self-heal: sweep whatever a crashed/killed popup left in the trash — only
#     entries older than 2 minutes, so this never races the sweep another live
#     popup just scheduled.
#   - The other thing removal leaves behind: the refs/wt-trash snapshots taken
#     before discarding uncommitted work or force-deleting a branch. They pin
#     objects, so they expire too — same age gate, different store.
#     @worktree_backup_days 0 keeps them forever.
#   - Drop the shell's retired merge memos; gwt keeps its own (gwt-merged-v1).
{
  root="$(gwt path)" &&
    tmux run-shell -b "find $(wt_shell_quote "$(trash_dir_for "$root")") -mindepth 1 -maxdepth 1 -mmin +2 -exec rm -rf {} + 2>/dev/null; true"
  days="$(tmux show-option -gqv @worktree_backup_days)"
  wt_prune_backups "${days:-30}"
  common="$(git rev-parse --path-format=absolute --git-common-dir)" &&
    rm -f "$common"/wt-merged-cache "$common"/wt-merged-cache-v2 "$common"/wt-merged-cache-v3
} >/dev/null 2>&1 &

# --- trunk freshness (background) -----------------------------------------------

# Every merged verdict is read off the trunk's remote-tracking ref, which is
# frozen at your last fetch — merge a PR in the browser and its branch still
# reads "NOT merged". So refresh it, but never make anyone WATCH a fetch: start
# `gwt trunk --fetch` now (it fetches only when the trunk is older than gwt's
# fetch.max_age, bounded by fetch.timeout) and await it only where a verdict is
# needed, by which time browsing the list has usually paid for it.
wt_trunk_json="$(mktemp "${TMPDIR:-/tmp}/wt-trunk.XXXXXX")"
trap 'rm -f "$wt_trunk_json"' EXIT
gwt trunk --fetch --json > "$wt_trunk_json" 2>/dev/null &
wt_fetch_pid=$!

# Block until the startup refresh lands. A FAILED fetch is announced, not
# swallowed: grading against a stale trunk is exactly the false alarm we're
# here to remove, so the user has to know when we're doing it.
await_trunk() {
  [ -n "$wt_fetch_pid" ] || return 0
  kill -0 "$wt_fetch_pid" 2>/dev/null && echo "refreshing the trunk…"
  wait "$wt_fetch_pid" 2>/dev/null
  wt_fetch_pid=""
  jq -r 'select(.fetch_error) | "could not refresh \(.remote) — merge status is as of your last fetch"' \
    "$wt_trunk_json" 2>/dev/null | while IFS= read -r note; do printf '\033[33m%s\033[0m\n' "$note"; done
  return 0
}

# --- fzf theme from the live tmux palette --------------------------------------

# The active terminal theme publishes its palette as @thm_* tmux options
# (tmux.conf force-loads the palette file on start and on every theme switch),
# so the popup reads its colors from tmux at launch instead of keeping
# per-theme tables — a new theme styles this UI with no change here.
fzf_colors="$(fzf_colors_from_palette)"

# --- create / switch -----------------------------------------------------------

win_name() { printf '%s' "$1" | tr '/' '-'; }

# Post-creation work runs VISIBLY in the new window via send-keys — NOT inside
# this script, which would freeze the modal popup. ONE chained command line:
#   <install> && <post-create cmd>
# The install half (Node projects only; package-manager SELECTION by lockfile
# is wt_install_cmd in worktree-core.sh) is toggled by @worktree_auto_install.
# The post-create half defaults to "x" (the claude alias — a fresh worktree
# lands with the agent already starting) and is overridden or disabled via
# @worktree_post_create_cmd. You land in the window, watch it run, and can
# Ctrl-C either half. send-keys types into the window's interactive zsh, which
# is what lets an alias like "x" resolve at all.
maybe_post_create() {
  local path="$1" target="$2" inst="" post cmd=""
  [ -n "$target" ] || return
  case "$(tmux show-option -gqv @worktree_auto_install 2>/dev/null)" in
    off|0|false|no|disabled) ;;
    *) inst="$(wt_install_cmd "$path")" ;;   # empty if not a Node project
  esac
  post="$(tmux show-option -gqv @worktree_post_create_cmd 2>/dev/null)"
  [ -n "$post" ] || post="x"
  case "$post" in off|0|false|no|disabled|none) post="" ;; esac
  if [ -n "$inst" ] && [ -n "$post" ]; then
    cmd="$inst && $post"
  else
    cmd="$inst$post"                         # at most one is non-empty here
  fi
  [ -n "$cmd" ] || return
  # target by window-id (not name): new-window can make duplicate names.
  tmux send-keys -t "$target" "$cmd" Enter
}

# Window ids (one per line) whose PANES live in <path>, across every session.
# Identity by path, not by name: the window name is the branch with "/"→"-",
# which is not injective (feat/x and feat-x produce the same name, so switching
# to one could land you in the other) and goes stale the moment a window is
# renamed. <scope> is "-s <session>" to look in one session or "-a" for all.
windows_for_path() {
  local path="$1"; shift
  tmux list-panes "$@" -F '#{window_id}'$'\t''#{pane_current_path}' 2>/dev/null \
  | while IFS=$'\t' read -r wid p; do
      case "$p" in "$path"|"$path"/*) printf '%s\n' "$wid" ;; esac
    done | awk '!seen[$0]++'
}

switch_worktree() {
  local path branch win wid
  path="$1"; branch="$2"
  win="$(win_name "$branch")"
  # path → name → create. The name fallback still matters: a window opened for
  # this worktree whose pane has since cd'd elsewhere is findable only by name.
  wid="$(windows_for_path "$path" -s -t "$session" | sed -n '1p')"
  [ -n "$wid" ] || wid="$(tmux list-windows -t "$session" -F '#{window_id}'$'\t''#W' 2>/dev/null \
                          | awk -F'\t' -v n="$win" '$2 == n {print $1; exit}')"
  [ -n "$wid" ] || wid="$(tmux new-window -t "$session" -n "$win" -c "$path" -P -F '#{window_id}')"
  tmux select-window -t "$wid" 2>/dev/null || true
  # landing on a worktree window clears its agent-done dot (by window id, so a
  # duplicate name can't send it to the wrong window) and refreshes the ◷ badge.
  tmux set-option -w -t "$wid" @agent_done 0 2>/dev/null || true
  bash "${BASH_SOURCE[0]%/*}/tmux-agent-status.sh" recount 2>/dev/null || true
}

# returns 0 on success (worktree created, window opened → caller exits popup);
# returns 1 on any failure (caller loops back to the list so you can retry).
create_worktree() {
  local name path win winid
  name="$(printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [ -z "$name" ]; then
    echo "type a name first"; sleep 1.5; return 1
  fi
  win="$(win_name "$name")"
  # The binary prints only the path and finishes ignored-file seeding before
  # a destination window can start its install/post-create command.
  if ! path="$(gwt create --non-interactive "$name")"; then
    sleep 2.5; return 1
  fi
  winid="$(tmux new-window -t "$session" -n "$win" -c "$path" -P -F '#{window_id}')"
  maybe_post_create "$path" "$winid"
  return 0
}

# ctrl-y: `prefix y` for worktrees you are not in. Puts the paths on the
# clipboard, one per line with no trailing newline, and reports like prefix y.
# toclip comes from PATH (tests stub it) and is aimed at the invoking pane.
# Returns 1 with nothing selected or a failed copy, so the caller loops back.
copy_paths() {
  local paths="$1" n
  [ -n "$paths" ] || return 1
  printf '%s' "$paths" | TMUX_PANE="$origin_pane" toclip -q || { sleep 2; return 1; }
  n="$(printf '%s\n' "$paths" | wc -l | tr -d ' ')"
  if [ "$n" -eq 1 ]; then
    tmux display-message -l "copied $paths" 2>/dev/null || true
  else
    tmux display-message -l "copied $n worktree paths" 2>/dev/null || true
  fi
}

# --- removal: trash-and-sweep ---------------------------------------------------

# Delete a branch gwt has ALREADY established is contained in the trunk.
# `git branch -d` refuses a squash- or rebase-merged branch, because git's own
# "fully merged" test is the graph-only one — so the safe -d silently left
# exactly the branches this cleanup is most often about. We verified containment
# by patch identity, so fall back to -D. A deletion that still fails (branch
# checked out elsewhere, ref locked) is REPORTED, never swallowed: the old
# `2>/dev/null` made a no-op look identical to success.
delete_merged_branch() {
  local b="$1" err
  git branch -d "$b" >/dev/null 2>&1 && return 0
  err="$(git branch -D "$b" 2>&1)" && return 0
  printf '  could not delete %s: %s\n' "$b" "$err"
  return 1
}

# batch_remove "<path>\t<branch> lines" — confirm once, stage every worktree
# into a fresh trash dir (mv = same-fs rename, instant), prune the git
# metadata, kill their windows, offer AGGREGATED branch deletion, then sweep
# the trash in the background and tidy the empty parent dirs slashed branches
# leave behind. Always returns to the refreshed list.
#
# Safety model: mv bypasses `git worktree remove`'s dirty-refusal, so we own
# the dirty check here — dirty entries are flagged in the confirm list, and
# their uncommitted changes are discarded only after a second explicit [y/N]
# (declining drops the dirty ones from the batch and removes just the clean).
# The main worktree and the worktree the popup runs in are never removed.
batch_remove() {
  local main entries="" path branch dirty st n=0 ndirty=0 ans
  main="$(wt_main_worktree)"
  while IFS=$'\t' read -r path branch; do
    [ -n "$path" ] || continue
    if [ "$path" = "$main" ];    then echo "skipping the main worktree ($branch)"; continue; fi
    if [ "$path" = "$cur_top" ]; then echo "skipping the worktree you're in ($branch)"; continue; fi
    dirty=0
    # A failed probe is unknown dirt, not clean: snapshot or keep, never discard.
    if ! st="$(git -C "$path" status --porcelain 2>/dev/null)"; then [ -d "$path" ] && st=unknown; fi
    [ -n "$st" ] && { dirty=1; ndirty=$((ndirty+1)); }
    entries="$entries$path"$'\t'"$branch"$'\t'"$dirty"$'\n'
    n=$((n+1))
  done <<< "$1"
  if [ "$n" -eq 0 ]; then sleep 1.2; return; fi

  echo "remove $n worktree(s):"
  while IFS=$'\t' read -r path branch dirty; do
    [ -n "$path" ] || continue
    if [ "$dirty" = 1 ]; then
      printf '  %s  \033[33m(dirty — has uncommitted changes)\033[0m\n' "$branch"
    else
      printf '  %s\n' "$branch"
    fi
  done <<< "$entries"
  printf 'proceed? [y/N] '; read -r ans
  case "$ans" in y|Y) ;; *) return ;; esac

  if [ "$ndirty" -gt 0 ]; then
    printf 'also remove the %d dirty one(s)? their changes are snapshotted first [y/N] ' "$ndirty"; read -r ans
    case "$ans" in
      y|Y) ;;
      *) entries="$(printf '%s' "$entries" | awk -F'\t' '$3 == 0')"
         n=$((n - ndirty))
         if [ "$n" -le 0 ]; then echo "nothing left to remove"; sleep 1.2; return; fi ;;
    esac
  fi

  local wt_root trash batch i=0 removed=0 gone="" saved="" snap ref wins w
  wt_root="$(gwt path)" || { sleep 2; return; }
  batch="$(date +%s).$$"
  trash="$(trash_dir_for "$wt_root")/$batch"
  if ! mkdir -p "$trash"; then echo "cannot create $trash"; sleep 2; return; fi
  while IFS=$'\t' read -r path branch dirty; do
    [ -n "$path" ] || continue
    i=$((i+1))
    # Snapshot the dirt BEFORE anything destructive, and refuse to remove a
    # worktree we couldn't snapshot: this batch's trash is swept immediately, so
    # "yes" to the prompt above used to mean the changes were unrecoverable the
    # moment it was answered.
    if [ "$dirty" = 1 ]; then
      snap="$(wt_snapshot_worktree "$path" "wt-trash: $branch")"
      if [ -z "$snap" ]; then echo "could not snapshot $branch — keeping it"; continue; fi
      ref="$(wt_backup_ref "$batch" "$(printf '%03d' "$i")" "$branch" "$snap")" \
        && saved="$saved$ref"$'\n'
    fi
    # Collect the windows BEFORE the mv: a pane whose cwd is renamed out from
    # under it reports the NEW path, so afterwards nothing matches any more.
    wins="$(windows_for_path "$path" -a)"
    if mv "$path" "$trash/$i" 2>/dev/null; then
      wt_remove_empty_parents "$wt_root" "$path"
      removed=$((removed+1))
      gone="$gone$branch"$'\n'
      # every session, not just this one — a window left pointing at a deleted
      # directory is broken wherever it lives. Name match stays as the fallback
      # for a window whose pane has cd'd elsewhere — exact on both parts (=),
      # since a bare target also matches a name prefix: removing reap-me would
      # kill reap-me-too's window.
      while IFS= read -r w; do
        [ -n "$w" ] && tmux kill-window -t "$w" 2>/dev/null
      done <<< "$wins"
      tmux kill-window -t "=$session:=$(win_name "$branch")" 2>/dev/null || true
    else
      echo "could not move $branch ($path) — skipped"
    fi
  done <<< "$entries"
  git worktree prune 2>/dev/null || true
  echo "removed $removed worktree(s)"
  if [ -n "$saved" ]; then
    printf 'uncommitted changes saved — recover with \033[36mgit switch -c <name> <ref>\033[0m:\n'
    printf '%s' "$saved" | sed 's/^/  /'
  fi

  # Aggregated branch cleanup (one prompt per kind, not per branch): merged
  # branches default to YES; unmerged ones need an explicit force past a
  # warning, so unmerged work is never silently dropped.
  # `git branch -d/-D` also removes the branch's [branch …] config section.
  #
  # "Merged" is gwt's verdict against a trunk refreshed a moment ago — it counts
  # squash- and rebase-merges, which the plain ancestor test cannot see. That
  # matters here more than anywhere: a shipped branch landing in the "NOT merged"
  # list is a warning you learn to ignore, and the next time it's real you force
  # past it out of habit. One gwt call judges every branch; a branch it cannot
  # judge counts as unmerged, so it is only ever deleted behind the force prompt.
  local trunk="the trunk" branches="" verdicts="" merged="" unmerged="" nm=0 nu=0 b
  await_trunk
  while IFS= read -r b; do
    [ -n "$b" ] && [ "$b" != "(detached)" ] || continue
    git show-ref --verify --quiet "refs/heads/$b" && branches="$branches$b"$'\n'
  done <<< "$gone"
  if [ -n "$branches" ]; then
    echo "checking branches against the trunk…"
    # Unquoted on purpose: ref names cannot hold whitespace or glob characters.
    verdicts="$(gwt merged --json $branches 2>/dev/null)"
    trunk="$(printf '%s' "$verdicts" | jq -r '.trunk.name // "the trunk"' 2>/dev/null)" || trunk="the trunk"
  fi
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    if [ "$(printf '%s' "$verdicts" | jq -r --arg b "$b" '.branches[] | select(.branch == $b) | .merged' 2>/dev/null)" = true ]; then
      merged="$merged$b"$'\n'; nm=$((nm+1))
    else
      unmerged="$unmerged$b"$'\n'; nu=$((nu+1))
    fi
  done <<< "$branches"
  if [ "$nm" -gt 0 ]; then
    printf 'delete %d merged branch(es)? [Y/n] ' "$nm"; read -r ans
    case "$ans" in
      n|N) ;;
      *) while IFS= read -r b; do
           [ -n "$b" ] && delete_merged_branch "$b"
         done <<< "$merged" ;;
    esac
  fi
  if [ "$nu" -gt 0 ]; then
    printf '%d branch(es) NOT merged into %s:\n' "$nu" "$trunk"
    printf '%s' "$unmerged" | sed 's/^/  /'
    printf 'force-delete them? their tips are kept as refs first [y/N] '; read -r ans
    case "$ans" in
      y|Y) local k=0 tip
           saved=""
           while IFS= read -r b; do
             [ -n "$b" ] || continue
             k=$((k+1))
             # `git branch -D` leaves the commits reachable only from the branch
             # reflog, which the branch deletion takes with it — recovery then
             # means `git fsck --lost-found`. A ref costs nothing and keeps the
             # tip addressable until wt_prune_backups expires it.
             tip="$(git rev-parse -q --verify "refs/heads/$b" 2>/dev/null)"
             ref="$(wt_backup_ref "$batch" "b$(printf '%03d' "$k")" "$b" "$tip")" \
               && saved="$saved$ref"$'\n'
             git branch -D "$b" >/dev/null 2>&1 || printf '  could not delete %s\n' "$b"
           done <<< "$unmerged"
           if [ -n "$saved" ]; then
             printf 'tips kept — restore with \033[36mgit branch <name> <ref>\033[0m:\n'
             printf '%s' "$saved" | sed 's/^/  /'
           fi ;;
    esac
  fi

  # Sweep this batch's trash server-side (survives the popup closing).
  tmux run-shell -b "rm -rf $(wt_shell_quote "$trash")" 2>/dev/null || true
  sleep 0.8
}

# ctrl-g: reap — batch-remove every worktree WT_REAPABLE admits (merged into
# the trunk, squash and rebase merges included), from `gwt list` run after the
# trunk refresh lands: reap's whole value is that it knows what has landed, and
# it knew nothing newer than your last fetch. One confirm, then trash-and-sweep.
reap_merged() {
  local listing cand trunk
  await_trunk
  echo "checking which worktrees are merged into the trunk…"
  listing="$(gwt list --json)" || { sleep 2; return; }
  trunk="$(printf '%s' "$listing" | jq -r .trunk.name)"
  cand="$(printf '%s' "$listing" | jq -r "$WT_REAPABLE"'
    .worktrees[] | select(reapable) | "\(.path)\t\(.branch)"')"
  if [ -z "$cand" ]; then
    echo "nothing to reap — no clean worktree is fully merged into $trunk"
    sleep 1.5
    return
  fi
  echo "reap: clean worktrees already merged into $trunk"
  batch_remove "$cand"
}

# --- PR picker ------------------------------------------------------------------

# ctrl-p: open GitHub PRs via gh; enter fetches the PR head into a local branch
# (refs/pull/<n>/head exists for fork PRs too) and reuses the normal create
# path — gwt resolves the now-local branch and checks it out, then window, file
# seed, install + agent as usual. ctrl-o opens the PR in the browser instead;
# esc returns to the worktree list.
# Output contract HERE is two lines (--expect without --print-query): line 1 =
# pressed key, line 2 = selected row.
# Returns 0 only when a worktree was created (the caller then exits the popup).
#
# The PR list is memoized for the POPUP's lifetime (pr_cache): esc-ing out of
# the picker and re-entering skips the loading screen. ctrl-r inside the picker
# clears the memo and refetches; a fresh popup always fetches anew (the cache
# dies with the process — no files, no TTL, no invalidation to get wrong).
# A stale row is harmless for checkout: enter fetches the PR's LIVE head ref.
# An empty result is deliberately NOT memoized, so "no open PRs" re-checks.
pr_cache=""

pick_pr() {
  local prs out key row branch num
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI not found"; sleep 1.5; return 1
  fi
  while true; do
    if [ -n "$pr_cache" ]; then
      prs="$pr_cache"
    else
      echo "fetching open PRs…"
      if ! prs="$(gh pr list --limit 50 --json number,title,headRefName,author \
          --template '{{range .}}#{{.number}} {{.title}} — {{.author.login}}{{"\t"}}{{.headRefName}}{{"\t"}}{{.number}}{{"\n"}}{{end}}' 2>&1)"; then
        printf '%s\n' "$prs"; sleep 2.5; return 1
      fi
      if [ -z "$prs" ]; then echo "no open PRs"; sleep 1.5; return 1; fi
      pr_cache="$prs"
    fi
    out="$(printf '%s\n' "$prs" | fzf \
      --ansi --cycle --layout=reverse \
      --delimiter='\t' --with-nth=1 \
      --padding=1,2 \
      --prompt='pr ❯ ' --pointer='▌' --info=inline-right \
      --header='enter: checkout into a worktree   ctrl-o: browser   ctrl-r: refresh   esc: back' \
      --expect=ctrl-o,ctrl-r \
      --bind 'ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up' \
      --color="$fzf_colors" \
      --preview='GH_FORCE_TTY=$FZF_PREVIEW_COLUMNS gh pr view {3} 2>/dev/null' \
      --preview-label=' pr ' \
      --preview-window='right,55%,wrap')" || return 1   # esc / no pick → back
    key="$(printf '%s\n' "$out" | sed -n '1p')"
    row="$(printf '%s\n' "$out" | sed -n '2p')"
    if [ "$key" = "ctrl-r" ]; then pr_cache=""; continue; fi
    break
  done
  branch="$(printf '%s' "$row" | cut -f2)"
  num="$(printf '%s' "$row" | cut -f3)"
  [ -n "$branch" ] || return 1
  if [ "$key" = "ctrl-o" ]; then
    gh pr view --web "$num" >/dev/null 2>&1 || true
    return 1
  fi
  # An existing local branch is used as-is (likely this PR's, from an earlier
  # checkout; never force-move a local branch — it may hold local commits).
  # Otherwise fetch the PR head into a new local branch of the same name.
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "using existing local branch $branch"
  elif ! git fetch origin "pull/$num/head:$branch"; then
    sleep 2.5; return 1
  fi
  create_worktree "$branch"
}

# --- pick & dispatch ------------------------------------------------------------

# fzf runs the --rows re-entry through $SHELL; the path travels in the
# environment so no quoting survives into fzf's action syntax.
export WT_POPUP_SELF="${BASH_SOURCE[0]}"

# Looped so remove (ctrl-x) and reap (ctrl-g) can return to a refreshed list.
# switch / create / PR-checkout / copy break the loop with `exit`; remove, reap,
# a cancelled PR pick, and a failed create or copy fall through and re-run fzf.
# esc / ctrl-c (fzf exit 130) closes the whole popup.
while true; do
  out="$(bare_rows | fzf \
    --ansi --multi --cycle --layout=reverse \
    --delimiter='\t' --with-nth=1 --id-nth=2 \
    --padding=1,2 \
    --prompt='❯ ' --pointer='▌' --marker='✓' --info=inline-right \
    --ghost='filter, or type a new branch name' \
    --header=$'enter switch/create   ctrl-y copy path   ctrl-n new-from-name\ntab/ctrl-a mark   ctrl-x remove   ctrl-g reap merged\nctrl-p PRs   ctrl-d/u preview' \
    --print-query \
    --expect=ctrl-n,ctrl-x,ctrl-g,ctrl-p,ctrl-y \
    --bind 'load:unbind(load)+reload-sync:bash "$WT_POPUP_SELF" --rows' \
    --bind 'ctrl-a:toggle-all,ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up' \
    --color="$fzf_colors" \
    --preview='git -C {2} -c color.status=always status -sb 2>/dev/null; echo; git -C {2} log --color=always --oneline -8 2>/dev/null' \
    --preview-label=' status · log ' \
    --preview-window='right,55%,wrap')"
  code=$?
  [ "$code" -eq 130 ] && exit 0   # esc / ctrl-c

  query="$(printf '%s\n' "$out" | sed -n '1p')"
  key="$(printf '%s\n'   "$out" | sed -n '2p')"
  # with --multi, everything from line 3 on is a selected row (the marked ones,
  # or just the highlighted row when nothing is marked)
  selections="$(printf '%s\n' "$out" | sed -n '3,$p')"
  choice="$(printf '%s\n' "$selections" | sed -n '1p')"
  sel_path="$(printf '%s' "$choice" | cut -f2)"
  sel_branch="$(printf '%s' "$choice" | cut -f3)"

  case "$key" in
    # force-create from the typed name; on failure, loop back to the list.
    ctrl-n) create_worktree "$query" && exit 0 ;;
    # batch-remove the marked rows (or the highlighted one); always loops back.
    ctrl-x) batch_remove "$(printf '%s\n' "$selections" | cut -f2,3)" ;;
    # reap merged+clean worktrees; always loops back.
    ctrl-g) reap_merged ;;
    # PR picker: exits the popup only when a worktree was actually created.
    ctrl-p) pick_pr && exit 0 ;;
    # copy the marked rows' paths (or the highlighted one's), then close.
    ctrl-y) copy_paths "$(printf '%s\n' "$selections" | cut -f2)" && exit 0 ;;
    # plain enter: switch to the (first) selected row; if nothing matched the
    # typed query, treat enter as "create it". Both exit the popup on success.
    *)
      if [ -n "$sel_path" ]; then
        switch_worktree "$sel_path" "$sel_branch"; exit 0
      elif [ -n "$query" ]; then
        create_worktree "$query" && exit 0
      else
        exit 0   # empty query, nothing highlighted — nothing to do
      fi
      ;;
  esac
done
