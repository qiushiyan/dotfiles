#!/usr/bin/env bash
# check-refs.sh <spec.md> [repo-root]
# A heuristic check of the references it recognises: backticked repository
# paths with a slash and an extension (resolved at the repo root, relative to
# the spec for ../ links, or under a directory another cited path established)
# and `§ Heading` references to this spec's own headings, by leading words.
# Skipped: paths without an extension, symbols, URLs, route paths, and another
# document's headings. Prints each detected miss with its line; exits 1 on
# any. A clean run means no detected misses, not that every reference holds.
set -euo pipefail
spec=${1:?usage: check-refs.sh <spec.md> [repo-root]}
root=${2:-$(git -C "$(dirname "$spec")" rev-parse --show-toplevel 2>/dev/null || pwd)}
spec_dir=$(cd "$(dirname "$spec")" && pwd)
miss=0
bases=()

# 1. Paths: backticked, containing a slash and a file extension, no glob or placeholder.
while IFS=: read -r line ref; do
  [ -z "$ref" ] && continue
  case "$ref" in *'*'*|*'<'*|*'{'*|http*|*'|'*|/*) continue;; esac   # globs, placeholders, URLs, route paths
  p=${ref%%:*}; p=${p%%#*}          # drop :line and #anchor suffixes
  if [[ $p == ../* || $p == ./* ]]; then target="$spec_dir/$p"; else target="$root/$p"; fi
  if [ -e "$target" ]; then bases+=("$(dirname "$target")"); continue; fi
  # a package-relative path resolves under a directory another cited path established
  found=0
  for b in "${bases[@]:-}"; do
    d=$b
    while [ -n "$d" ] && [ "$d" != "$root" ] && [ "$d" != / ]; do
      if [ -e "$d/$p" ]; then found=1; break 2; fi
      d=$(dirname "$d")
    done
  done
  if [ $found = 0 ]; then echo "path  line $line  $ref"; miss=$((miss+1)); fi
done < <(grep -n -o '`[A-Za-z0-9_./@-]*/[A-Za-z0-9_.@-]*\.[A-Za-z0-9]\{1,6\}\(:[0-9]*\)\?`' "$spec" | sed 's/`//g' | sort -u -t: -k2 | awk -F: '{print (index($2,"/")>1 && $2 ~ /^(packages|application|services|infra|docs|scripts)\//) ? 0 : 1, $0}' | sort -k1,1n | cut -d' ' -f2-)

# 2. Section references: "§ Heading", optionally "§ Heading — Subheading". A
# reference to another document's heading (a `.md` path earlier on the line)
# is not checked here. Trailing prose after the heading is tolerated: the
# reference resolves when a heading starts with its leading words.
headings=$(grep -E '^#{1,6} ' "$spec" | sed -E 's/^#+ //; s/[[:space:]]+$//' | tr '[:upper:]' '[:lower:]')
resolves() {  # $1: one heading reference, lowercased
  local ref=$1 words n
  ref=$(echo "$ref" | sed -E "s/'s( |$)/ /g; s/[[:space:]]+/ /g; s/^ | $//g")
  read -ra words <<< "$ref"
  for ((n=${#words[@]}; n>=1; n--)); do
    local prefix; prefix=$(printf '%s ' "${words[@]:0:n}"); prefix=${prefix% }
    grep -E -q -- "^${prefix//./\.}( |$)" <<< "$headings" && return 0
  done
  return 1
}
prev=""
while IFS=: read -r line text; do
  [ -z "$text" ] && continue
  case "$prev$text" in *'.md`'*'§'*) prev=$text; continue;; esac   # another document's heading, cited on this line or the one before
  prev=$text
  while read -r ref; do
    [ -z "$ref" ] && continue
    ok=1
    IFS='—' read -ra parts <<< "$ref"
    for part in "${parts[@]}"; do
      part=$(echo "${part%%,*}" | tr '[:upper:]' '[:lower:]')
      [ -z "${part// /}" ] && continue
      resolves "$part" || ok=0
    done
    if [ $ok = 0 ]; then echo "§     line $line  § $ref"; miss=$((miss+1)); fi
  done < <(grep -o '§ [A-Z][A-Za-z0-9 ,'"'"'’—/-]*' <<< "$text" | sed -E 's/^§ //; s/[ ,]+$//' | sort -u)
done < <(grep -n '' "$spec")

if [ $miss = 0 ]; then echo "all references resolve"; else echo "$miss unresolved"; exit 1; fi
