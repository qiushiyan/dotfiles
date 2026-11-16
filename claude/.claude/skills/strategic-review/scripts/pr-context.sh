#!/usr/bin/env bash
# pr-context.sh: the opening read of a strategic review in one call.
#
# Prints a digest: what the PR is, where its code is, how CI stands at its
# head, who reviewed it, and what it changed. Writes the full context (the
# description, every commit message and every file) to <out-dir>/pr-<N>.md,
# for later reads and for the path a subagent brief hands over.
#
# usage: pr-context.sh <pr number or URL> [out-dir]
#
# Run it from a checkout of the PR's repository: it then fetches the head,
# computes the merge-base, takes the file list from git and finds a worktree
# already on the branch. Elsewhere it falls back to the GitHub API.
#
# It avoids two traps in `gh pr view --json`: keys come out in alphabetical
# order, so `| head -c` cuts files, title and url off behind the commits; and
# `files` stops at 100 entries.
set -uo pipefail

pr=${1:?usage: pr-context.sh <pr number or URL> [out-dir]}
out_dir=${2:-$(mktemp -d)}
mkdir -p "$out_dir" || exit 1

fields=number,title,url,state,isDraft,mergeable,author,labels,headRefName,headRefOid,baseRefName,additions,deletions,changedFiles,body,commits,reviews,comments
meta=$(gh pr view "$pr" --json "$fields") || exit 1
j() { jq -r "$1" <<<"$meta"; }

n=$(j .number)
url=$(j .url)
repo=$(j '.url | capture("github.com/(?<r>[^/]+/[^/]+)/pull").r')
branch=$(j .headRefName)
head=$(j .headRefOid)
base=$(j .baseRefName)
file="$out_dir/pr-$n.md"

# Local git, when this checkout's origin is the PR's repository.
mb='' numstat='' worktree_line='' diff_line=''
origin_url=$(git remote get-url origin 2>/dev/null || true)
if [[ $origin_url == *"$repo"* || $origin_url == *"${repo}.git"* ]]; then
  git fetch -q origin "pull/$n/head" "$base" 2>/dev/null || true
  if git cat-file -e "$head^{commit}" 2>/dev/null; then
    mb=$(git merge-base "origin/$base" "$head" 2>/dev/null || true)
  fi
  if [[ -n $mb ]]; then
    numstat=$(git diff --numstat "$mb" "$head")
    diff_line="diff: git diff ${mb:0:11} ${head:0:11}  (head fetched; merge-base with origin/$base)"
  fi
  wt=$(git worktree list --porcelain | awk -v b="refs/heads/$branch" '
    /^worktree / { path = substr($0, 10) }
    /^HEAD /     { at = $2 }
    $0 == "branch " b { print path "\t" at; exit }')
  if [[ -n $wt ]]; then
    wt_path=${wt%%$'\t'*}
    wt_at=${wt##*$'\t'}
    dirty=$(git -C "$wt_path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    state=$([[ $wt_at == "$head" ]] && echo "at head" || echo "at ${wt_at:0:11}, head is ${head:0:11}")
    [[ $dirty != 0 ]] && state="$state, $dirty uncommitted"
    worktree_line="worktree on $branch: $wt_path ($state)"
  else
    worktree_line="worktree on $branch: none in this checkout"
  fi
fi
if [[ -z $numstat ]]; then
  numstat=$(gh api "repos/$repo/pulls/$n/files" --paginate \
    --jq '.[] | "\(.additions)\t\(.deletions)\t\(.filename)"' 2>/dev/null || true)
  diff_line="diff: not fetched (run from a checkout of $repo for the merge-base)"
fi

# CI at the head, failures and pending runs named.
checks=$(gh pr checks "$n" --repo "$repo" --json name,bucket,link 2>/dev/null || true)
if [[ -z $checks || $checks == "[]" ]]; then
  ci="CI: no checks reported"
else
  ci=$(jq -r '
    (group_by(.bucket) | map("\(length) \(.[0].bucket)") | join(", ")) as $counts
    | "CI at head: \($counts)",
      (.[] | select(.bucket != "pass" and .bucket != "skipping")
           | "  \(.bucket | ascii_upcase)  \(.name)  \(.link)")' <<<"$checks")
fi

# Review activity, so the rounds that patched the same place can be found.
inline=$(gh api "repos/$repo/pulls/$n/comments" --paginate --jq '.[].user.login' 2>/dev/null \
  | sort | uniq -c | sort -rn | awk '{printf "%s%s %s", (NR>1?", ":""), $2, $1}')
reviews="Reviews: $(j '.reviews | length') reviews, $(j '.comments | length') PR comments; inline comments: ${inline:-none}"

specs=$(awk -F'\t' '$3 ~ /(^|\/)specs?\/.*\.md$/ { printf "  %s (+%s -%s)\n", $3, $1, $2 }' <<<"$numstat")

body=$(j .body | perl -0pe 's/<!--.*?-->//gs')
nfiles=$(grep -c . <<<"$numstat" || true)

# Commits from git when it has them: GitHub cuts a headline near 70
# characters. Merges of the base carry no review history and are counted only.
if [[ -n $mb ]]; then
  headlines=$(git log --reverse --no-merges --format='%h %s' "$mb..$head")
  messages=$(git log --reverse --no-merges --format='%n### %h %s%n%n%b' "$mb..$head")
  merges=$(git rev-list --count --merges "$mb..$head")
else
  headlines=$(j '.commits[] | "\(.oid[0:11]) \(.messageHeadline)"')
  messages=$(j '.commits[] | "\n### \(.oid[0:11]) \(.messageHeadline)\n\n\(.messageBody)"')
  merges=0
fi
messages=$(grep -v -E '^(Co-Authored-By|Signed-off-by):' <<<"$messages")
ncommits=$(grep -c . <<<"$headlines" || true)
merge_note=$( (( merges > 0 )) && echo ", $merges merges not listed" )

files_table() {
  sort -t$'\t' -k3 <<<"$numstat" | awk -F'\t' '{ printf "%+6s %-6s %s\n", "+" $1, "-" $2, $3 }'
}

# The full context file.
{
  echo "# PR #$n: $(j .title)"
  echo
  echo "$url"
  echo "head $branch @ $head; base $base${mb:+ @ merge-base $mb}"
  echo
  echo "## Description"
  echo
  echo "$body"
  echo
  echo "## Commits ($ncommits, oldest first$merge_note)"
  echo "$messages"
  echo
  echo "## Files ($nfiles)"
  echo
  files_table
} >"$file"

# The digest.
echo "PR #$n  $(j .title)"
echo "$url"
echo "$(j .state) · $(j 'if .isDraft then "draft" else "ready" end') · $(j .mergeable) · by $(j .author.login) · labels: $(j '[.labels[].name] | join(", ") | if . == "" then "none" else . end')"
echo "head $branch @ ${head:0:11} · base $base${mb:+ @ ${mb:0:11}}"
echo "$diff_line"
[[ -n $worktree_line ]] && echo "$worktree_line"
echo "+$(j .additions) -$(j .deletions) · $nfiles files · $ncommits commits"
echo
echo "$ci"
echo "$reviews"
if [[ -n $specs ]]; then
  echo "Specs in the diff:"
  echo "$specs"
fi
echo
echo "Full context (description, every commit message, every file): $file"
echo
echo "## Description"
echo
echo "$body"
echo
echo "## Commits ($ncommits, oldest first$merge_note; messages in the full context)"
echo "$headlines"
echo
if (( nfiles <= 120 )); then
  echo "## Files ($nfiles)"
  files_table
else
  echo "## Files ($nfiles, by directory; every file in the full context)"
  awk -F'\t' '{
      n = split($3, p, "/"); d = p[1]; for (i = 2; i < n && i <= 3; i++) d = d "/" p[i]
      a[d] += $1; r[d] += $2; c[d]++
    } END { for (d in c) printf "%+7s %-7s %3d  %s\n", "+" a[d], "-" r[d], c[d], d }' <<<"$numstat" \
    | sort -k4
fi
