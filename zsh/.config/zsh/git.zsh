# ~/.config/zsh/git.zsh
# Git utility functions

# --------------------------------------------------------------------
# gitclean - Delete branches inactive for more than N days
# --------------------------------------------------------------------
gitclean() {
  local days=30
  local dry_run=false
  local include_remote=false
  local protected="main|master|develop|release|staging|production"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run) dry_run=true; shift ;;
      -r|--remote) include_remote=true; shift ;;
      -d|--days) days="$2"; shift 2 ;;
      -h|--help) _gitclean_help; return 0 ;;
      -*) echo "gitclean: unknown option '$1'" >&2; _gitclean_help; return 1 ;;
      *) days="$1"; shift ;;
    esac
  done

  if ! git rev-parse --git-dir &>/dev/null; then
    echo "gitclean: not a git repository" >&2
    return 1
  fi

  local cutoff_date
  cutoff_date=$(date -v-${days}d +%s 2>/dev/null || date -d "$days days ago" +%s)
  local cutoff_display
  cutoff_display=$(date -r "$cutoff_date" +%Y-%m-%d 2>/dev/null || date -d "@$cutoff_date" +%Y-%m-%d)

  echo "Branches inactive for more than $days days (before $cutoff_display)"
  echo "Dry run: $dry_run | Remote: $include_remote"
  echo "----------------------------------------"

  local deleted=0
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)

  local branch last_commit last_date
  for branch in $(git for-each-ref --format='%(refname:short)' refs/heads/); do
    [[ "$branch" =~ ^($protected)$ ]] && continue
    [[ "$branch" == "$current_branch" ]] && continue

    last_commit=$(git log -1 --format=%ct "$branch" 2>/dev/null)
    [[ -z "$last_commit" ]] && continue

    if [[ "$last_commit" -lt "$cutoff_date" ]]; then
      last_date=$(date -r "$last_commit" +%Y-%m-%d 2>/dev/null || date -d "@$last_commit" +%Y-%m-%d)
      if $dry_run; then
        echo "[dry run] local: $branch ($last_date)"
      else
        echo "Deleting local: $branch ($last_date)"
        git branch -D "$branch"
      fi
      ((deleted++))
    fi
  done

  if $include_remote; then
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

_gitclean_help() {
  cat <<'EOF'
Usage: gitclean [options] [days]

Delete git branches inactive for more than N days (default: 30).
Protected branches: main, master, develop, release, staging, production

Options:
  -d, --days <n>   Days of inactivity (default: 30)
  -n, --dry-run    Show what would be deleted without deleting
  -r, --remote     Include remote branches (careful!)
  -h, --help       Show this help message

Examples:
  gitclean              Delete local branches inactive >30 days
  gitclean -n           Dry run (preview only)
  gitclean 60           Delete branches inactive >60 days
  gitclean -r -n        Preview local + remote cleanup
  gitclean -d 14 -r     Delete all branches inactive >14 days
EOF
}

_gitclean() {
  _arguments -s \
    '(-n --dry-run)'{-n,--dry-run}'[Show what would be deleted]' \
    '(-r --remote)'{-r,--remote}'[Include remote branches]' \
    '(-d --days)'{-d,--days}'[Days of inactivity]:days:' \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1:days:'
}
compdef _gitclean gitclean

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
