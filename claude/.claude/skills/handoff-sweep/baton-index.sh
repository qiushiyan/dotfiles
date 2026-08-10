#!/usr/bin/env bash
# Index this project's handoff batons:  baton-index.sh
#
# One deterministic view of ~/dev/.handoffs/<project>/ — each baton's declared
# fields (anchor, cluster, blocked-by, collides-with) joined against live git
# state (does a branch or PR exist for the slug, how far has the default branch
# moved since the anchor). The judgement half is the handoff-sweep skill; this
# is only the lookup, so it can never disagree with the repo.
#
# The folder comes from the handoff skill's own path helper rather than being
# recomputed here: that scheme handles worktrees, submodules and symlinked dev
# roots, and two copies of it would drift.
set -euo pipefail

helper="$HOME/.claude/skills/handoff/handoff-path.sh"
[ -f "$helper" ] || { echo "baton-index: missing $helper" >&2; exit 1; }

folder=$(dirname "$(bash "$helper" _probe_)")
[ -d "$folder" ] || { echo "baton-index: no baton folder at $folder" >&2; exit 1; }

# Default branch: origin/HEAD when the remote publishes it, else the first
# conventional name that resolves. Never assumed.
default=""
if head_ref=$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null); then
  default=${head_ref#refs/remotes/origin/}
fi
if [ -z "$default" ]; then
  for cand in develop main master trunk; do
    if git rev-parse --verify --quiet "$cand" >/dev/null 2>&1; then default=$cand; break; fi
  done
fi
[ -n "$default" ] || { echo "baton-index: no default branch found" >&2; exit 1; }
default_sha=$(git log -1 --format=%h "$default" 2>/dev/null || echo '?')

# One network call for every PR, matched locally by head branch. Absent or
# unauthenticated gh degrades to git-only state rather than failing the index.
prs=""
if command -v gh >/dev/null 2>&1; then
  prs=$(gh pr list --state all --limit 200 \
        --json number,state,headRefName \
        --jq '.[] | "\(.headRefName)\t#\(.number) \(.state|ascii_downcase)"' 2>/dev/null || true)
fi

field() { # field <file> <label> — first value after the label in the head block
  sed -n '1,12p' "$1" | grep -m1 -i "$2" || true
}

printf 'project %s · default %s @ %s\n\n' "$(basename "$folder")" "$default" "$default_sha"
printf '%-20s %-38s %-19s %5s  %s\n' CLUSTER BATON ANCHOR DRIFT STATE

find "$folder" -name '*.md' -type f | sort | while read -r f; do
  # A baton's line 1 is the invocation its paste fires. Anything else in the
  # folder is a note the folder happens to hold, not a baton to index.
  case $(head -1 "$f") in /*) ;; *) continue ;; esac

  rel=${f#"$folder"/}; slug=${rel%.md}

  # Every extraction tolerates absence: a baton written before these fields
  # existed still gets a row, marked. Under `pipefail` an unmatched grep would
  # otherwise abort the subshell and print an empty table for a full folder.
  anchor_line=$(field "$f" '^anchor:')
  date=$(printf '%s' "$anchor_line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 || true)
  sha=$(printf '%s' "$anchor_line" | grep -oE '`[0-9a-f]{7,12}`' | head -1 | tr -d '`' || true)

  cluster=$(printf '%s\n%s' "$anchor_line" "$(field "$f" 'cluster')" \
            | grep -oE 'cluster[`: ]*[a-z0-9][a-z0-9-]*' | head -1 \
            | sed -E 's/^cluster[`: ]*//' || true)
  blocked=$(field "$f" 'blocked-by' | sed -E 's/.*blocked-by:? *//; s/ *·.*//; s/`//g')
  collides=$(field "$f" 'collides-with' | sed -E 's/.*collides-with:? *//; s/ *·.*//; s/`//g')

  # Drift: commits the default branch has taken since the anchor.
  if [ -n "${sha:-}" ] && git cat-file -e "$sha^{commit}" 2>/dev/null; then
    drift=$(git rev-list --count "$sha..$default" 2>/dev/null || echo '?')
  else
    drift='?'
  fi

  # State: a PR wins over a bare branch; neither means nothing started. A
  # review-posture baton names no new branch — its subject is the slug with the
  # prefix stripped, so look that up or every review reads as unstarted.
  case $slug in
    review-*) subject=${slug#review-}; prefix='review of ' ;;
    *)        subject=$slug;           prefix='' ;;
  esac
  state=$(printf '%s' "$prs" | awk -F'\t' -v s="$subject" '$1==s {print $2; exit}')
  if [ -z "$state" ]; then
    if git rev-parse --verify --quiet "$subject" >/dev/null 2>&1 ||
       git rev-parse --verify --quiet "origin/$subject" >/dev/null 2>&1; then
      state='branch, no PR'
    else
      state='unstarted'
    fi
  fi
  [ -z "$prefix" ] || state="$prefix$subject: $state"
  # A field whose value opens with "none" is empty however much prose trails it.
  case "${blocked:-none}" in none*|'') ;; *) state="$state · blocked-by $blocked" ;; esac
  case "${collides:-none}" in none*|'') ;; *) state="$state · collides $collides" ;; esac

  printf '%-20s %-38s %-19s %5s  %s\n' \
    "${cluster:-(none)}" "$slug" "${date:-no anchor} ${sha:0:7}" "$drift" "$state"
done
