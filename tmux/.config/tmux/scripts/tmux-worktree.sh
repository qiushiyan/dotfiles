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
#                marked) as ONE confirmed batch — see batch_remove
#   ctrl-g       reap: batch-remove every worktree gwt calls removable whose
#                branch is already merged into the trunk (end-of-week cleanup
#                in 3 keys) — gwt's verdict counts squash and rebase merges, and
#                the trunk is refreshed first, so a PR you merged in the browser
#                counts too
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
# REMOVAL IS gwt remove (~/dev/gwt README § Removal): it refuses what it must,
# moves checkouts to a trash it sweeps in the background, and keeps a
# refs/wt-trash/… recovery ref for anything it discards — dirty work, a
# force-deleted tip. This script owns the prompts and the windows: dirty
# worktrees are flagged in the confirm list and removed only after a second
# explicit [y/N] (declining keeps them and removes just the clean ones),
# branch deletion is offered in aggregate (merged → one [Y/n]; unmerged →
# explicit force), every ref gwt keeps is printed with its restore command,
# and windows are killed by PATH, in every session — a window pointing at a
# deleted directory is broken wherever it lives.
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

# gwt owns creation, seeding, listing, verdicts, removal and recovery; this
# script owns the tmux/fzf UI, the prompts, and the windows.
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

# The "· merged" tag and ctrl-g select the same rows, `.removable and .merged`:
# gwt's removable is the rule gwt remove itself applies, so the tag marks
# exactly the reap set.
probed_rows() {
  local json show=true
  case "$(tmux show-option -gqv @worktree_show_merged 2>/dev/null)" in
    off|0|false|no|disabled) show=false ;;
  esac
  json="$(gwt list --json 2>/dev/null)" || { bare_rows; return; }
  printf '%s\n' "$json" | jq -r --argjson show "$show" '
    .worktrees[]
    | (.branch // "(detached)") as $b
    | (if .current then "\u001b[32m»\u001b[0m" else " " end)
      + (if .dirty then "\u001b[33m*\u001b[0m" else " " end)
      + " " + $b
      + (if $show and .removable and .merged == true then "\u001b[32m · merged\u001b[0m" else "" end)
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
# the list does not need runs in the background. Listing, switching and copying
# therefore work even when gwt's configuration does not load; creation and
# removal report gwt's own error.

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

# The dependency install for a Node project, chosen by its committed lockfile
# (so an npm repo never gets a pnpm lockfile), pnpm when there is none. Prints
# nothing for a non-Node project. gwt does not install.
wt_install_cmd() {
  local path="$1"
  [ -f "$path/package.json" ] || return 0
  if   [ -f "$path/pnpm-lock.yaml" ];    then echo "pnpm install"
  elif [ -f "$path/yarn.lock" ];         then echo "yarn"
  elif [ -f "$path/package-lock.json" ]; then echo "npm install"
  elif [ -f "$path/bun.lockb" ] || [ -f "$path/bun.lock" ]; then echo "bun install"
  else echo "pnpm install"; fi
}

# Post-creation work runs VISIBLY in the new window via send-keys — NOT inside
# this script, which would freeze the modal popup. ONE chained command line:
#   <install> && <post-create cmd>
# The install half (Node projects only, wt_install_cmd) is toggled by
# @worktree_auto_install.
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
  # duplicate name can't send it to the wrong window).
  tmux set-option -w -t "$wid" @agent_done 0 2>/dev/null || true
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

# --- removal ---------------------------------------------------------------------

# gwt_remove <gwt remove args> — run gwt remove, report each refusal and each
# recovery ref it kept, and print "<path>\x1f<branch>" for every checkout it
# removed. \x1f, not a tab: read collapses runs of tabs, which would shift an
# empty field into the next.
gwt_remove() {
  local p b removed ref err
  gwt remove --json "$@" 2>/dev/null \
  | jq -r '[.path // "", .branch // "", (.worktree_removed | tostring), .recovery_ref // "", .error // ""] | join("\u001f")' \
  | while IFS=$'\x1f' read -r p b removed ref err; do
      [ -n "$err" ] && printf '  could not remove %s: %s\n' "${b:-$p}" "$err" >&2
      [ -n "$ref" ] && printf '  kept %s — restore with \033[36mgit branch <name> %s\033[0m\n' "$ref" "$ref" >&2
      [ "$removed" = true ] && printf '%s\x1f%s\n' "$p" "$b"
    done
}

# batch_remove "<path lines>" [listing] — confirm once, kill the windows on
# the checkouts so nothing writes during removal, let gwt remove them as one
# batch with their branches kept, then offer branch deletion in aggregate. The listing (gwt list --json) says which
# selections are dirty and which are the main worktree or the one you are in;
# reap passes the one it already has. Always returns to the refreshed list.
batch_remove() {
  local listing="${2:-}" entries="" path branch dirty n=0 ndirty=0 ans discard=""
  [ -n "$listing" ] || listing="$(gwt list --json)" || { sleep 2; return; }
  while IFS=$'\x1f' read -r path branch dirty; do
    [ -n "$path" ] || continue
    case "$dirty" in
      main)    echo "skipping the main worktree ($branch)" ;;
      current) echo "skipping the worktree you're in ($branch)" ;;
      *) entries="$entries$path"$'\t'"$branch"$'\t'"$dirty"$'\n'
         n=$((n+1)); [ "$dirty" = 1 ] && ndirty=$((ndirty+1)) ;;
    esac
  done <<< "$(printf '%s' "$listing" | jq -r --arg sel "$1" '
    ($sel | split("\n")) as $s | .worktrees[] | select(.path | IN($s[]))
    | [.path, .branch // "(detached)",
       (if .main then "main" elif .current then "current" elif .dirty then "1" else "0" end)]
    | join("\u001f")')"
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
      y|Y) discard=--discard-dirty ;;
      *) entries="$(printf '%s' "$entries" | awk -F'\t' '$3 == 0')"
         n=$((n - ndirty))
         if [ "$n" -le 0 ]; then echo "nothing left to remove"; sleep 1.2; return; fi ;;
    esac
  fi

  # Stop the writers first: kill every window on a selected checkout, in every
  # session, before gwt reads the checkout for the last time, so nothing writes
  # between gwt's final dirt check and the move. It has to be before anyway: a
  # pane whose cwd is renamed out from under it reports the NEW path, so
  # afterwards nothing matches any more. Name match is the fallback for a
  # window whose pane has cd'd elsewhere — exact on both parts (=), since a
  # bare target also matches a name prefix: removing reap-me would kill
  # reap-me-too. A checkout gwt then refuses stays, without its windows.
  local w gone removed=0 branches="" b
  set --
  while IFS=$'\t' read -r path branch dirty; do
    [ -n "$path" ] || continue
    set -- "$@" "$path"
    for w in $(windows_for_path "$path" -a); do tmux kill-window -t "$w" 2>/dev/null; done
    [ "$branch" = "(detached)" ] || tmux kill-window -t "=$session:=$(win_name "$branch")" 2>/dev/null || true
  done <<< "$entries"
  gone="$(gwt_remove --keep-branch $discard "$@")"
  while IFS=$'\x1f' read -r path branch; do
    [ -n "$path" ] || continue
    removed=$((removed+1))
    [ -n "$branch" ] && branches="$branches$branch"$'\n'
  done <<< "$gone"
  echo "removed $removed worktree(s)"

  # Aggregated branch cleanup (one prompt per kind, not per branch): merged
  # branches default to YES; unmerged ones need an explicit force past a
  # warning, and gwt keeps their tips as recovery refs.
  #
  # "Merged" is gwt's verdict against a trunk refreshed a moment ago — it counts
  # squash- and rebase-merges, which the plain ancestor test cannot see. That
  # matters here more than anywhere: a shipped branch landing in the "NOT merged"
  # list is a warning you learn to ignore, and the next time it's real you force
  # past it out of habit. A branch gwt cannot judge counts as unmerged, so it is
  # only ever deleted behind the force prompt.
  local trunk="the trunk" verdicts="" merged="" unmerged="" nm=0 nu=0
  [ -n "$branches" ] || { sleep 0.8; return; }
  await_trunk
  echo "checking branches against the trunk…"
  # Unquoted on purpose: ref names cannot hold whitespace or glob characters.
  verdicts="$(gwt merged --json $branches 2>/dev/null)"
  trunk="$(printf '%s' "$verdicts" | jq -r '.trunk.name // "the trunk"' 2>/dev/null)" || trunk="the trunk"
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    if [ "$(printf '%s' "$verdicts" | jq -r --arg b "$b" '.branches[] | select(.branch == $b) | .merged' 2>/dev/null)" = true ]; then
      merged="$merged $b"; nm=$((nm+1))
    else
      unmerged="$unmerged $b"; nu=$((nu+1))
    fi
  done <<< "$branches"
  if [ "$nm" -gt 0 ]; then
    printf 'delete %d merged branch(es)? [Y/n] ' "$nm"; read -r ans
    case "$ans" in n|N) ;; *) gwt_remove $merged >/dev/null ;; esac
  fi
  if [ "$nu" -gt 0 ]; then
    printf '%d branch(es) NOT merged into %s:\n' "$nu" "$trunk"
    printf '  %s\n' $unmerged
    printf 'force-delete them? their tips are kept as refs first [y/N] '; read -r ans
    case "$ans" in y|Y) gwt_remove --force $unmerged >/dev/null ;; esac
  fi
  sleep 0.8
}

# ctrl-g: reap — batch-remove every worktree gwt calls removable that is merged
# into the trunk (squash and rebase merges included), from `gwt list` run after
# the trunk refresh lands: reap's whole value is that it knows what has landed,
# and it knew nothing newer than your last fetch. One confirm, then removal.
reap_merged() {
  local listing cand trunk
  await_trunk
  echo "checking which worktrees are merged into the trunk…"
  listing="$(gwt list --json)" || { sleep 2; return; }
  trunk="$(printf '%s' "$listing" | jq -r .trunk.name)"
  cand="$(printf '%s' "$listing" | jq -r '.worktrees[] | select(.removable and .merged == true) | .path')"
  if [ -z "$cand" ]; then
    echo "nothing to reap — no clean worktree is fully merged into $trunk"
    sleep 1.5
    return
  fi
  echo "reap: clean worktrees already merged into $trunk"
  batch_remove "$cand" "$listing"
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
    ctrl-x) batch_remove "$(printf '%s\n' "$selections" | cut -f2)" ;;
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
