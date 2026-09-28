# ~/.config/zsh/git.zsh
# Git utility functions

# lazygit reads its config from this repo-managed file (stow: lazygit package)
# via LG_CONFIG_FILE, while its runtime state.yml stays in lazygit's default OS
# config dir — never in this repo. See lazygit/.config/lazygit/config.yml.
export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml"

# delta pages through less; force -FRX (git's own default) so a short diff
# renders inline and STAYS on screen instead of vanishing when less uses the
# alternate screen and exits. -F quit-if-one-screen, -R raw color, -X no
# term init (keep output). Scoped to delta via DELTA_PAGER, so $LESS is untouched.
export DELTA_PAGER='less -FRX'

# difftastic — AST-aware structural diff on demand. difft owns the terminal
# (--no-pager bypasses the delta pager); DFT_BACKGROUND (set in theme.zsh)
# keeps its colors matched to $TERMINAL_THEME.
gdft()    { emulate -L zsh; GIT_EXTERNAL_DIFF=difft git --no-pager diff "$@"; }
gdftlog() { emulate -L zsh; GIT_EXTERNAL_DIFF=difft git --no-pager log -p --ext-diff "$@"; }

# --------------------------------------------------------------------
# gitclean - Delete local branches whose upstream has been deleted
# --------------------------------------------------------------------
# Use after merging a PR on GitHub and deleting the remote branch:
# the local branch is now orphaned ([gone] upstream) and gitclean
# will remove it. Branches you never pushed are naturally protected
# (they have no upstream, so the [gone] marker doesn't apply).
# --------------------------------------------------------------------
gitclean() {
  local force=false skip_fetch=false skip_confirm=false
  local protected="main|master|develop|release|staging|production"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--force) force=true; shift ;;
      -y|--yes) skip_confirm=true; shift ;;
      --no-fetch) skip_fetch=true; shift ;;
      -h|--help) _gitclean_help; return 0 ;;
      -*) echo "gitclean: unknown option '$1'" >&2; _gitclean_help; return 1 ;;
      *) echo "gitclean: unexpected argument '$1'" >&2; _gitclean_help; return 1 ;;
    esac
  done

  if ! git rev-parse --git-dir &>/dev/null; then
    echo "gitclean: not a git repository" >&2
    return 1
  fi

  if ! $skip_fetch; then
    echo "Fetching and pruning remotes..."
    git fetch --all --prune --quiet 2>/dev/null
  fi

  # Empty in detached HEAD
  local current_branch
  current_branch=$(git symbolic-ref --short -q HEAD 2>/dev/null)

  # Branches checked out in other worktrees (git won't let us delete them anyway)
  local -a worktree_branches
  local line
  while IFS= read -r line; do
    [[ "$line" == "branch refs/heads/"* ]] && worktree_branches+=("${line#branch refs/heads/}")
  done < <(git worktree list --porcelain 2>/dev/null)

  local -a candidates
  local branch track w is_worktree
  while IFS=$'\t' read -r branch track; do
    [[ "$track" == "[gone]" ]] || continue
    [[ "$branch" =~ ^($protected)$ ]] && continue
    [[ -n "$current_branch" && "$branch" == "$current_branch" ]] && continue

    is_worktree=false
    for w in "${worktree_branches[@]}"; do
      [[ "$w" == "$branch" ]] && { is_worktree=true; break; }
    done
    $is_worktree && continue

    candidates+=("$branch")
  done < <(git for-each-ref --format='%(refname:short)%09%(upstream:track)' refs/heads/)

  if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "No branches to clean — no local branches with [gone] upstream."
    return 0
  fi

  echo "Branches with deleted upstream ([gone]):"
  echo "----------------------------------------"
  local sha cdate subject
  for branch in "${candidates[@]}"; do
    sha=$(git rev-parse --short "$branch" 2>/dev/null)
    cdate=$(git log -1 --format=%cs "$branch" 2>/dev/null)
    subject=$(git log -1 --format=%s "$branch" 2>/dev/null)
    printf "  %-40s %s  %s  %s\n" "$branch" "$sha" "$cdate" "$subject"
  done
  echo "----------------------------------------"

  if ! $force; then
    echo "Total: ${#candidates[@]} branch(es) (dry run — pass -f to delete)"
    return 0
  fi

  if ! $skip_confirm; then
    echo -n "Delete ${#candidates[@]} branch(es)? [y/N] "
    local answer
    read -r answer
    [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Aborted."; return 1; }
  fi

  local deleted=0
  for branch in "${candidates[@]}"; do
    if git branch -D "$branch" 2>/dev/null; then
      echo "Deleted: $branch"
      ((deleted++))
    else
      echo "Failed: $branch" >&2
    fi
  done
  echo "----------------------------------------"
  echo "Deleted: $deleted branch(es)"
}

_gitclean_help() {
  cat <<'EOF'
Usage: gitclean [options]

Delete local branches whose upstream has been deleted on the remote.
Typical post-PR cleanup: merge PR on GitHub → delete remote branch →
run `gitclean` to remove the now-orphaned local branch.

Detection:
  Runs `git fetch --prune` to update remote refs, then finds branches
  where upstream tracking is marked [gone]. Branches that have never
  been pushed (no upstream at all) are skipped — they may be WIP.

Protected:
  main, master, develop, release, staging, production
  Current branch, branches checked out in other worktrees.

Options:
  -f, --force       Actually delete (default is dry-run preview)
  -y, --yes         Skip confirmation prompt when used with -f
      --no-fetch    Skip automatic `git fetch --prune`
  -h, --help        Show this help message

Examples:
  gitclean              Preview branches whose upstream is gone
  gitclean -f           Delete after confirmation prompt
  gitclean -f -y        Delete without prompting
  gitclean --no-fetch   Preview without touching the network

See also: gitstale — delete branches by inactivity (age-based)
EOF
}

_gitclean() {
  _arguments -s \
    '(-f --force)'{-f,--force}'[Actually delete (default is dry-run)]' \
    '(-y --yes)'{-y,--yes}'[Skip confirmation prompt]' \
    '--no-fetch[Skip automatic git fetch --prune]' \
    '(-h --help)'{-h,--help}'[Show help]'
}

# --------------------------------------------------------------------
# gitstale - Delete branches inactive for more than N days
# --------------------------------------------------------------------
gitstale() {
  local days=30
  local dry_run=false
  local include_remote=false
  local force_unmerged=false
  local skip_confirm=false
  local protected="main|master|develop|release|staging|production"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run) dry_run=true; shift ;;
      -r|--remote) include_remote=true; shift ;;
      -d|--days) days="$2"; shift 2 ;;
      -f|--force) force_unmerged=true; shift ;;
      -y|--yes) skip_confirm=true; shift ;;
      -h|--help) _gitstale_help; return 0 ;;
      -*) echo "gitstale: unknown option '$1'" >&2; _gitstale_help; return 1 ;;
      *) days="$1"; shift ;;
    esac
  done

  if ! git rev-parse --git-dir &>/dev/null; then
    echo "gitstale: not a git repository" >&2
    return 1
  fi

  local cutoff_date
  cutoff_date=$(date -v-${days}d +%s 2>/dev/null || date -d "$days days ago" +%s)
  local cutoff_display
  cutoff_display=$(date -r "$cutoff_date" +%Y-%m-%d 2>/dev/null || date -d "@$cutoff_date" +%Y-%m-%d)

  echo "Branches inactive for more than $days days (before $cutoff_display)"
  echo "Dry run: $dry_run | Remote: $include_remote | Force unmerged: $force_unmerged"
  echo "----------------------------------------"

  # Branches checked out in other worktrees (git blocks deletion; we skip cleanly)
  local -a worktree_branches
  local line
  while IFS= read -r line; do
    [[ "$line" == "branch refs/heads/"* ]] && worktree_branches+=("${line#branch refs/heads/}")
  done < <(git worktree list --porcelain 2>/dev/null)

  # Empty in detached HEAD
  local current_branch
  current_branch=$(git symbolic-ref --short -q HEAD 2>/dev/null)

  local deleted=0
  local branch last_commit last_date del_flag w is_worktree
  for branch in $(git for-each-ref --format='%(refname:short)' refs/heads/); do
    [[ "$branch" =~ ^($protected)$ ]] && continue
    [[ -n "$current_branch" && "$branch" == "$current_branch" ]] && continue

    is_worktree=false
    for w in "${worktree_branches[@]}"; do
      [[ "$w" == "$branch" ]] && { is_worktree=true; break; }
    done
    $is_worktree && continue

    last_commit=$(git log -1 --format=%ct "$branch" 2>/dev/null)
    [[ -z "$last_commit" ]] && continue

    if [[ "$last_commit" -lt "$cutoff_date" ]]; then
      last_date=$(date -r "$last_commit" +%Y-%m-%d 2>/dev/null || date -d "@$last_commit" +%Y-%m-%d)
      if $dry_run; then
        echo "[dry run] local: $branch ($last_date)"
        ((deleted++))
      else
        # Try safe delete; -D only when user opts in with --force
        del_flag="-d"
        $force_unmerged && del_flag="-D"
        if git branch "$del_flag" "$branch" 2>/dev/null; then
          echo "Deleted local: $branch ($last_date)"
          ((deleted++))
        else
          echo "Skipped local: $branch ($last_date) — unmerged (use -f to force)" >&2
        fi
      fi
    fi
  done

  if $include_remote; then
    if ! $dry_run && ! $skip_confirm; then
      echo
      echo "WARNING: --remote will delete branches from origin."
      echo "This affects coworkers and CI if they reference these branches."
      echo -n "Continue? [y/N] "
      local answer
      read -r answer
      if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
        echo "Aborted remote cleanup."
        echo "----------------------------------------"
        echo "Total: $deleted branch(es)"
        return 1
      fi
    fi

    git fetch --prune origin 2>/dev/null

    for branch in $(git for-each-ref --format='%(refname:short)' refs/remotes/origin/ | sed 's|^origin/||'); do
      [[ "$branch" == "HEAD" ]] && continue
      [[ "$branch" =~ ^($protected)$ ]] && continue

      last_commit=$(git log -1 --format=%ct "origin/$branch" 2>/dev/null)
      [[ -z "$last_commit" ]] && continue

      if [[ "$last_commit" -lt "$cutoff_date" ]]; then
        last_date=$(date -r "$last_commit" +%Y-%m-%d 2>/dev/null || date -d "@$last_commit" +%Y-%m-%d)
        if $dry_run; then
          echo "[dry run] remote: origin/$branch ($last_date)"
        else
          echo "Deleting remote: origin/$branch ($last_date)"
          git push origin --delete "$branch"
        fi
        ((deleted++))
      fi
    done
  fi

  echo "----------------------------------------"
  echo "Total: $deleted branch(es)"
}

_gitstale_help() {
  cat <<'EOF'
Usage: gitstale [options] [days]

Delete git branches inactive for more than N days (default: 30).
Protected: main, master, develop, release, staging, production.
Current branch and branches checked out in other worktrees are skipped.

By default, local deletes use `git branch -d` (refuses unmerged branches).
Pass -f/--force to use `-D` and force-delete unmerged work.

Options:
  -d, --days <n>   Days of inactivity (default: 30)
  -n, --dry-run    Show what would be deleted without deleting
  -r, --remote     Also delete matching remote branches (prompts for confirmation)
  -f, --force      Force-delete unmerged local branches (use -D instead of -d)
  -y, --yes        Skip confirmation prompt for --remote
  -h, --help       Show this help message

Examples:
  gitstale              Delete local branches inactive >30 days (skips unmerged)
  gitstale -n           Dry run (preview only)
  gitstale 60           Delete branches inactive >60 days
  gitstale -f           Also delete unmerged local branches
  gitstale -r -n        Preview local + remote cleanup
  gitstale -r -y        Delete local+remote without remote confirmation

See also: gitclean — delete branches whose upstream is gone (post-PR cleanup)
EOF
}

_gitstale() {
  _arguments -s \
    '(-n --dry-run)'{-n,--dry-run}'[Show what would be deleted]' \
    '(-r --remote)'{-r,--remote}'[Include remote branches]' \
    '(-d --days)'{-d,--days}'[Days of inactivity]:days:' \
    '(-f --force)'{-f,--force}'[Force-delete unmerged branches]' \
    '(-y --yes)'{-y,--yes}'[Skip confirmation for --remote]' \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1:days:'
}

# --------------------------------------------------------------------
# gitgc - Aggressive git garbage collection and cleanup
# --------------------------------------------------------------------
gitgc() {
  local dry_run=false
  local aggressive=true  # aggressive by default

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run) dry_run=true; shift ;;
      -l|--light) aggressive=false; shift ;;
      -h|--help) _gitgc_help; return 0 ;;
      -*) echo "gitgc: unknown option '$1'" >&2; _gitgc_help; return 1 ;;
      *) echo "gitgc: unexpected argument '$1'" >&2; _gitgc_help; return 1 ;;
    esac
  done

  if ! git rev-parse --git-dir &>/dev/null; then
    echo "gitgc: not a git repository" >&2
    return 1
  fi

  local size_before size_after
  size_before=$(du -sh "$(git rev-parse --git-dir)" 2>/dev/null | cut -f1)

  echo "Git repository cleanup"
  echo "Mode: $($aggressive && echo 'aggressive' || echo 'light')"
  echo "Size before: $size_before"
  echo "----------------------------------------"

  if $dry_run; then
    echo "[dry run] Would run:"
    echo "  git remote prune origin"
    echo "  git repack -ad"
    echo "  git prune --expire=now"
    $aggressive && echo "  git gc --aggressive --prune=now"
    $aggressive || echo "  git gc --prune=now"
    echo "  git reflog expire --expire=now --all"
    return 0
  fi

  echo "Pruning remote tracking branches..."
  git remote prune origin

  echo "Repacking objects..."
  git repack -ad

  echo "Pruning unreachable objects..."
  git prune --expire=now

  echo "Running garbage collection..."
  if $aggressive; then
    git gc --aggressive --prune=now
  else
    git gc --prune=now
  fi

  echo "Expiring reflog..."
  git reflog expire --expire=now --all

  size_after=$(du -sh "$(git rev-parse --git-dir)" 2>/dev/null | cut -f1)

  echo "----------------------------------------"
  echo "Size before: $size_before"
  echo "Size after:  $size_after"
  echo "Done."
}

_gitgc_help() {
  cat <<'EOF'
Usage: gitgc [options]

Aggressive git garbage collection and repository cleanup.

Operations performed:
  1. Prune remote tracking branches (git remote prune)
  2. Repack objects (git repack -ad)
  3. Prune unreachable objects (git prune --expire=now)
  4. Garbage collection (git gc --aggressive --prune=now)
  5. Expire reflog (git reflog expire --expire=now --all)

Options:
  -l, --light      Use standard gc instead of aggressive (faster)
  -n, --dry-run    Show what would be run without executing
  -h, --help       Show this help message

Examples:
  gitgc              Aggressive cleanup (default)
  gitgc -l           Light cleanup (faster)
  gitgc -n           Preview commands without running
EOF
}

_gitgc() {
  _arguments -s \
    '(-n --dry-run)'{-n,--dry-run}'[Show what would be run]' \
    '(-l --light)'{-l,--light}'[Use standard gc instead of aggressive]' \
    '(-h --help)'{-h,--help}'[Show help]'
}

# --------------------------------------------------------------------
# stage - Stage feature branch to a staging branch
# --------------------------------------------------------------------
stage() {
  local stay=false
  local auto=false
  local staging=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s|--stay) stay=true; shift ;;
      -a|--auto) auto=true; shift ;;
      -h|--help) _stage_help; return 0 ;;
      -*) echo "stage: unknown option '$1'" >&2; _stage_help; return 1 ;;
      *) staging="$1"; shift ;;
    esac
  done

  local feature=$(git branch --show-current)

  if [[ -z "$staging" ]]; then
    if $auto; then
      staging="staging$(date +%Y%m%d)"
    else
      echo "stage: missing branch name" >&2
      _stage_help
      return 1
    fi
  fi

  echo "Staging '$feature' → '$staging'"

  local branch_exists=false

  if git show-ref --verify --quiet "refs/heads/$staging"; then
    branch_exists=true
  elif git ls-remote --exit-code --heads origin "$staging" &>/dev/null; then
    branch_exists=true
    git fetch origin "$staging:$staging" 2>/dev/null
  fi

  if $branch_exists; then
    git switch "$staging"
    git pull origin "$staging" --ff-only 2>/dev/null
    echo "Merging '$feature' into '$staging'..."
    if git merge "$feature"; then
      if $stay; then
        echo "Merged. Staying on '$staging'."
      else
        git push origin "$staging" && git switch "$feature"
        echo "Done. Back on '$feature'."
      fi
    else
      echo "Conflicts detected. Resolve and commit, then:"
      $stay && echo "  (staying on '$staging')" || echo "  git push origin $staging && git switch $feature"
    fi
  else
    git switch -c "$staging"
    if $stay; then
      echo "Created '$staging'. Staying here."
    else
      git push -u origin "$staging" && git switch "$feature"
      echo "Created '$staging' and back on '$feature'."
    fi
  fi
}

_stage_help() {
  cat <<'EOF'
Usage: stage [options] <branch>
       stage -a [options]

Stage current feature branch to a staging branch (create or merge).

Options:
  -a, --auto   Auto-generate branch name (staging<YYYYMMDD>)
  -s, --stay   Don't push or switch back after merge/create
  -h, --help   Show this help message

Examples:
  stage staging-v2       Merge/create staging-v2, push, switch back
  stage -s staging-v2    Merge/create staging-v2, stay there
  stage -a               Merge/create staging20260126, push, switch back
  stage -a -s            Merge/create staging20260126, stay there
EOF
}

_stage() {
  local context state state_descr line ret=1
  typeset -A opt_args

  _arguments -s \
    '(-s --stay)'{-s,--stay}'[Stay mode - no push, no switch back]' \
    '(-a --auto)'{-a,--auto}'[Auto-generate branch name (staging<YYYYMMDD>)]' \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1:branch:->branch' && ret=0

  case $state in
    branch)
      local branches=(${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin 2>/dev/null | sed 's|^origin/||' | sort -u)"})
      compadd -a branches && ret=0
      ;;
  esac

  return ret
}

# --------------------------------------------------------------------
# gremote - git remote -v with SSH-shorthand URLs rewritten to HTTPS
# --------------------------------------------------------------------
# Display only — repo's stored URLs and SSH-key routing are untouched.
gremote() {
  git remote -v "$@" | sed -E 's|git@github\.com(-[a-z]+)?:|https://github.com/|g'
}

# --------------------------------------------------------------------
# gopen - open the current repo/branch on GitHub (the binary on PATH)
# --------------------------------------------------------------------
# ~/dev/gopen owns resolution, the PR cache, and the push prompt; its README
# is the reference. Only the completion lives here; it follows `gopen --help`.
_gopen() {
  _arguments \
    '(-n --print)'{-n,--print}'[print the URL without opening a browser]' \
    '(-y --yes)'{-y,--yes}'[push a branch that is not on origin without asking]' \
    '--tree[open the file tree even when an open PR exists]' \
    '--refresh[re-query the PR, ignoring the cached result]' \
    '(- *)'{-h,--help}'[show help]' \
    '1:file (path or path\:line):_files'
}

# --------------------------------------------------------------------
# gitswitch - Switch between git profiles (personal, marswave, cola)
# --------------------------------------------------------------------
gitswitch() {
  local profile="$1"

  case "$profile" in
    personal)  local config="$HOME/.gitconfig.personal" ;;
    marswave)  local config="$HOME/.gitconfig.marswave" ;;
    cola)      local config="$HOME/.gitconfig.cola" ;;
    -h|--help) _gitswitch_help; return 0 ;;
    "")
      # Show current profile
      local name email
      name=$(git config user.name)
      email=$(git config user.email)
      echo "Current: $name <$email>"
      return 0
      ;;
    *)
      echo "gitswitch: unknown profile '$profile'" >&2
      _gitswitch_help
      return 1
      ;;
  esac

  if [[ ! -f "$config" ]]; then
    echo "gitswitch: config not found: $config" >&2
    return 1
  fi

  if git rev-parse --git-dir &>/dev/null; then
    git config --local include.path "$config"
    echo "Switched to '$profile' (local repo only)"
  else
    echo "gitswitch: not in a git repo — use inside a repository" >&2
    return 1
  fi

  git config user.name
  git config user.email
}

_gitswitch_help() {
  cat <<'EOF'
Usage: gitswitch <profile>
       gitswitch          (show current profile)

Switch git identity for the current repository.

Profiles:
  personal    qiushiyan <qiushi.yann@gmail.com>
  marswave    yanqiushi-mw <y@marswave.ai>
  cola        cola <cola@marswave.ai>

Options:
  -h, --help  Show this help message

Examples:
  gitswitch              Show current git identity
  gitswitch cola         Switch current repo to cola profile
  gitswitch personal     Switch current repo to personal profile
EOF
}

_gitswitch() {
  _arguments '1:profile:(personal marswave cola)'
}

# gwt is the compiled CLI in ~/.local/bin. This function adds only the
# parent-shell cd that a binary cannot perform: with --cd it strips the flag,
# creates through the binary, and enters the printed path. Everything else is
# forwarded untouched, so the binary keeps owning arguments and output.
gwt() {
  emulate -L zsh
  local arg dest enter=0 literal=0
  local -a args
  for arg in "$@"; do
    if (( literal )); then args+=("$arg"); continue; fi
    case "$arg" in
      --) literal=1; args+=("$arg") ;;
      --cd) enter=1 ;;
      *) args+=("$arg") ;;
    esac
  done
  (( enter )) || { command gwt "$@"; return }
  case "$args[1]" in
    resolve|path|remove|config) print -u2 "gwt: --cd is only for create"; return 2 ;;
    create) ;;
    *) args=(create "$args[@]") ;;
  esac
  for arg in "$args[@]"; do
    case "$arg" in
      --) break ;;
      -h|--help) command gwt "$args[@]"; return ;;
      --json) print -u2 "gwt: --cd needs the path output; drop --json or the --cd"; return 2 ;;
    esac
  done
  dest="$(command gwt "$args[@]")" || return $?
  [[ -n "$dest" ]] || { print -u2 "gwt: no worktree path returned; inspect git worktree list"; return 1; }
  cd -- "$dest"
}

# Older spelling of gwt --cd.
gwtcd() {
  gwt --cd "$@"
}

# Completes local branches AND remote-only branch names (lstrip=3 drops
# refs/remotes/<remote>/, which is the form you actually type — gwt resolves the
# remote itself).
_gwt() {
  local subcommand="$words[2]" commands="create resolve path remove config"
  if [[ "$words[1]" == gwtcd ]]; then
    subcommand=""
    commands=""
  fi
  if [[ "$subcommand" == config ]]; then
    _arguments '2:action:(show)' '--json[print effective values and sources as JSON]'
    return
  fi
  if [[ "$subcommand" == (create|resolve|path|remove) ]]; then
    commands=""
    words=("$words[1]" "${words[@]:2}")
    (( CURRENT-- ))
  fi
  case "$subcommand" in
    remove)
      _arguments '--force[allow deleting unmerged commits; protects dirty worktrees]' \
        '--json[report each removal step as JSON]' \
        '1:local branch:($(git for-each-ref --format="%(refname:short)" refs/heads 2>/dev/null))'
      ;;
    path|resolve)
      local -a flags
      flags=('--json[print structured output]')
      [[ "$subcommand" == resolve ]] && flags+=('--no-fetch[use cached remote refs]')
      _arguments "${flags[@]}" \
        '1:branch:($(git for-each-ref --format="%(refname:short)" refs/heads 2>/dev/null; git for-each-ref --format="%(refname:lstrip=3)" refs/remotes 2>/dev/null | grep -v "^HEAD$"))'
      ;;
    *)
      local -a enter
      [[ "$words[1]" == gwt ]] && enter=('--cd[enter the new worktree in this shell]')
      _arguments "${enter[@]}" \
        '--new[create a new branch even if a remote branch of that name exists]' \
        '--non-interactive[use the configured base without confirmation]' \
        '--no-copy[skip ignored prerequisites]' \
        '--no-fetch[use cached remote refs]' \
        '--json[print structured output]' \
        '1:branch or command:('"$commands"' $(git for-each-ref --format="%(refname:short)" refs/heads 2>/dev/null; git for-each-ref --format="%(refname:lstrip=3)" refs/remotes 2>/dev/null | grep -v "^HEAD$"))' \
        '2:base branch:($(git for-each-ref --format="%(refname:short)" refs/heads refs/remotes 2>/dev/null))'
      ;;
  esac
}

# --------------------------------------------------------------------
# git (wrapper) - stale-base branch guard; repository push flags
# --------------------------------------------------------------------
# The one git() for every shell. .zshenv sources this module everywhere,
# so a second git() elsewhere (say, in .zshrc) silently replaces this one
# and disables both behaviors below.
#
# Branch guard. Intercepts branch-creating invocations typed at the prompt
#   git switch -c/-C/--create <name>
#   git checkout -b/-B <name>
#   git branch <name>
# and, when the current branch is behind its upstream, prompts before
# creating (create anyway / fast-forward first / abort). Everything else
# passes straight through to the git binary (~0.1 ms added per call).
#
# Scope is deliberate: only *interactive* shells are guarded (scripts,
# editors, and tools exec the git binary directly and never see this),
# and an explicit start-point (`git switch -c foo origin/main`) skips
# the check — you already chose your base.
#
# Freshness: comparing against the local tracking ref is only honest if
# it's recent, so the guard fetches the one upstream branch first —
# except when any fetch/pull happened in the last GIT_GUARD_MAX_AGE
# seconds (FETCH_HEAD mtime), which makes "pull, then branch" free
# (~15 ms). The fetch is bounded by GIT_GUARD_TIMEOUT via coreutils
# timeout; on timeout/failure it falls back to the last-fetched state
# and *says so* — a failed probe never passes silently.
#
# Toggle: `gitguard on|off` (persistent, all shells, immediate — it's a
# marker file checked when a creation is detected, so no per-call cost).
# GIT_GUARD_OFF=1 additionally disables it for the current shell only.
#
# Repository push flags. `git push` gets every value of the repository's
# multi-valued repo.pushArgs, one argument each, and names them on stderr.
# git config is the policy's only home: gopen reads the same key, and dotfiles
# decides which repositories carry it (git/.config/git/planlab.gitconfig sets
# --no-verify for the planlab clone and its worktrees, skipping the git-lfs
# pre-push upload hook). That is safe for everyday commits that don't touch
# LFS-tracked binaries; when you DO change an asset, push with
# `command git push` (bypasses this function) or force the blobs with
# `git lfs push --all origin <branch>`. Unlike the guard it needs no
# terminal, so agent shells get it too. Only `push` spawns the config read.
# --------------------------------------------------------------------

: ${GIT_GUARD_MAX_AGE:=600}   # seconds a previous fetch counts as fresh
: ${GIT_GUARD_TIMEOUT:=6}     # seconds to wait for the network probe
: ${GIT_GUARD_STATE:=$HOME/.config/git-guard-off}   # exists = disabled

git() {
  emulate -L zsh
  if [[ ( -t 0 && -t 1 ) || -n "$GIT_GUARD_FORCE" ]] && [[ -z "$GIT_GUARD_OFF" ]]; then
    case "$1" in
      switch|checkout|branch)
        if [[ ! -e "$GIT_GUARD_STATE" ]] && _git_guard_creates_branch "$@"; then
          _git_guard_confirm || return $?
        fi
        ;;
    esac
  fi
  if [[ "$1" == push ]]; then
    local -a extra
    extra=(${(f)"$(command git config --get-all repo.pushArgs 2>/dev/null)"})
    if (( $#extra )); then
      print -P "%F{242}↳ push ${(j: :)${extra//\%/%%}} (repo.pushArgs)%f" >&2
      shift
      command git push "${extra[@]}" "$@"
      return
    fi
  fi
  command git "$@"
}

# True (0) only for a branch creation based on HEAD — the case where a
# stale base silently becomes the new branch's history. Any explicit
# start-point, or anything this parser doesn't recognize, skips the
# guard (fails open: worst case is git's normal behavior).
_git_guard_creates_branch() {
  emulate -L zsh
  local sub="$1"; shift
  local creating=0
  local -a positional

  case "$sub" in
    switch|checkout)
      while (( $# )); do
        case "$1" in
          -c|-C|--create|--force-create)
            [[ "$sub" == switch ]] && creating=1
            (( $# )) && shift   # the flag's value (branch name)
            ;;
          -b|-B)
            [[ "$sub" == checkout ]] && creating=1
            (( $# )) && shift
            ;;
          --create=*|--force-create=*)
            [[ "$sub" == switch ]] && creating=1
            ;;
          --) shift; positional+=("$@"); break ;;
          -*) ;;   # other flags; a flag with a separate value lands in
                   # positional and reads as a start-point → fails open
          *) positional+=("$1") ;;
        esac
        (( $# )) && shift
      done
      (( creating )) || return 1
      (( ${#positional} == 0 )) || return 1   # explicit start-point
      ;;
    branch)
      # Only the bare `git branch <name>` form; any flag means list/
      # delete/move/copy or an explicit start-point follows.
      local a
      for a in "$@"; do [[ "$a" == -* ]] && return 1; done
      (( $# == 1 )) || return 1
      ;;
    *) return 1 ;;
  esac
  return 0
}

_git_guard_confirm() {
  emulate -L zsh
  zmodload -F zsh/stat b:zstat 2>/dev/null
  zmodload zsh/datetime 2>/dev/null

  # One spawn for both facts; fails (→ pass through) when there is no
  # upstream or we're detached. --git-common-dir, not --git-dir: that's
  # where FETCH_HEAD lives when inside a linked worktree.
  local info
  info=$(command git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' \
           --path-format=absolute --git-common-dir 2>/dev/null) || return 0
  local upstream="${info%%$'\n'*}" gitdir="${info#*$'\n'}"
  [[ -n "$upstream" && "$upstream" != "$info" ]] || return 0

  local remote="${upstream%%/*}" rbranch="${upstream#*/}"

  # Skip the network probe if anything fetched recently. -s, not -e: a
  # fetch killed mid-flight (our timeout, or a Ctrl-C'd pull) truncates
  # FETCH_HEAD to empty with a fresh mtime — that must read as stale.
  local fresh=0 mtime
  if [[ -s "$gitdir/FETCH_HEAD" ]]; then
    mtime=$(zstat +mtime -- "$gitdir/FETCH_HEAD" 2>/dev/null)
    (( EPOCHSECONDS - ${mtime:-0} < GIT_GUARD_MAX_AGE )) && fresh=1
  fi

  local note="" probe_failed=0
  if (( ! fresh )); then
    local -a runner
    if (( $+commands[timeout] )); then runner=(timeout "$GIT_GUARD_TIMEOUT")
    elif (( $+commands[gtimeout] )); then runner=(gtimeout "$GIT_GUARD_TIMEOUT")
    fi
    if ! "${runner[@]}" git fetch --quiet -- "$remote" "$rbranch" 2>/dev/null; then
      probe_failed=1
      note=" (couldn't reach '$remote' — comparing against last-fetched state)"
    fi
  fi

  local behind
  behind=$(command git rev-list --count "HEAD..$upstream" -- 2>/dev/null) || return 0
  if (( behind == 0 )); then
    # A failed probe must not pass silently: "not behind" is only as
    # good as the last successful fetch, and we couldn't get one.
    (( probe_failed )) && print -u2 \
      "git-guard: couldn't reach '$remote' to verify against $upstream — proceeding from last-fetched state"
    return 0
  fi

  local cur
  cur=$(command git symbolic-ref --short -q HEAD 2>/dev/null) || cur=HEAD

  print -u2 "git-guard: '$cur' is $behind commit(s) behind $upstream$note"
  local reply
  read -r "reply?Create branch anyway? [y]es / [f]ast-forward '$cur' first / [N]o: " || reply=n
  case "$reply" in
    y|Y|yes) return 0 ;;
    f|F|ff)
      if command git merge --ff-only "$upstream"; then
        return 0
      fi
      print -u2 "git-guard: fast-forward failed ('$cur' and $upstream have diverged) — aborting"
      return 1
      ;;
    *) return 1 ;;
  esac
}

# gitguard — persistent on/off switch for the branch-creation guard.
# Applies to all shells immediately (state lives in a file, not the env).
gitguard() {
  emulate -L zsh
  case "$1" in
    on)        rm -f -- "$GIT_GUARD_STATE"; print "git-guard: on" ;;
    off)       touch -- "$GIT_GUARD_STATE"; print "git-guard: off" ;;
    ""|status) [[ -e "$GIT_GUARD_STATE" ]] && print "git-guard: off" || print "git-guard: on" ;;
    *)         print -u2 "usage: gitguard [on|off|status]"; return 1 ;;
  esac
}

_gitguard() {
  _arguments '1:state:(on off status)'
}

# --------------------------------------------------------------------
# brief — thin wrapper over the brief CLI (~/dev/brief).
# --------------------------------------------------------------------
# The binary owns everything whose staleness could misroute: the folder
# scheme, the parser, resolution, placement, the pointer. This init-frozen
# layer holds only what a parent shell alone can do — make the cd stick —
# via the binary's --cd-file contract (empty file = no entry, do not cd).
brief() {
  emulate -L zsh
  local bin="$HOME/.local/bin/brief"
  [[ -x $bin ]] || { print -u2 "brief: binary missing — (cd ~/dev/brief && make install)"; return 1 }
  if [[ $1 == start ]]; then
    local cdf rc
    cdf=$(mktemp "${TMPDIR:-/tmp}/brief-cd.XXXXXX") || return 1
    "$bin" "$@" --cd-file "$cdf"
    rc=$?
    [[ -s $cdf ]] && cd "$(<$cdf)"
    rm -f "$cdf"
    return $rc
  fi
  "$bin" "$@"
}

_brief() {
  # The binary owns brief detection; resolve's bare form is the completion
  # feed (file scan only — no network on this path).
  local -a slugs
  slugs=(${(f)"$("$HOME/.local/bin/brief" resolve 2>/dev/null)"})
  (( $#slugs )) && _describe 'brief' slugs
}

# --------------------------------------------------------------------
# Completion registration — called from .zshrc after compinit. compdef is
# unavailable when this file is first sourced from .zshenv (pre-compinit),
# so registration is deferred here instead of re-sourcing the whole file.
# --------------------------------------------------------------------
_git_zsh_register_completions() {
  compdef _gitclean  gitclean
  compdef _gitstale  gitstale
  compdef _gitgc     gitgc
  compdef _stage     stage
  compdef _gitswitch gitswitch
  compdef _gopen     gopen
  compdef _gwt      gwt gwtcd
  compdef _brief     brief b   # b is the alias (aliases.zsh); register both
  compdef _gitguard  gitguard
}
