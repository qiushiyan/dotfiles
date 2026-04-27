# ~/.config/zsh/git.zsh
# Git utility functions

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
compdef _gitclean gitclean

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
compdef _gitstale gitstale

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
compdef _gitgc gitgc

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
compdef _stage stage

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
compdef _gitswitch gitswitch
