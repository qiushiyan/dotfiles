#!/usr/bin/env bash
# test-repos-map.sh — docs/repos.md has exactly one entry for each repository
# twin's manifest lists, except this one and those its `Left out ...:` line
# names. A repository added to the manifest without an entry fails M1, and an
# entry or left-out name that is not in the manifest fails M2.
#
# Usage: bash test-repos-map.sh [M1 M2]
#
# ISOLATION. Read-only: it reads the two files from the working tree (or
# REPOS_DOC / TWIN_MANIFEST, used to grade a broken copy) and writes nothing.

set -uo pipefail

ROOT=$(cd "$(dirname "$0")/../../../../.." && pwd)
DOC="${REPOS_DOC:-$ROOT/docs/repos.md}"
MANIFEST="${TWIN_MANIFEST:-$ROOT/twin/.config/twin/twin.toml}"
PASS=0; FAIL=0; FAILED=""
SELECTED=("$@")
want() { [ ${#SELECTED[@]} -eq 0 ] && return 0; for c in "${SELECTED[@]}"; do [ "$c" = "$1" ] && return 0; done; return 1; }
ok()   { PASS=$((PASS+1)); echo "ok   $1"; }
bad()  { FAIL=$((FAIL+1)); FAILED="$FAILED $1"; echo "FAIL $1: $2"; }

[ -f "$DOC" ] && [ -f "$MANIFEST" ] || { echo "missing $DOC or $MANIFEST"; exit 1; }

listed=$(sed -nE 's/^\[repos\.([A-Za-z0-9_.-]+)\].*/\1/p' "$MANIFEST" | grep -vx dotfiles | sort)
entries=$(sed -nE 's/^- \*\*([A-Za-z0-9_.-]+)(:\*\*|\*\* \().*/\1/p' "$DOC" | sort)
omitted=$(sed -nE 's/^Left out[^:]*:(.*)/\1/p' "$DOC" | grep -oE '`[A-Za-z0-9_.-]+`' | tr -d '`' | sort)
entries=$(printf '%s\n%s\n' "$entries" "$omitted" | grep -v '^$' | sort)

if want M1; then
  missing=$(comm -23 <(echo "$listed") <(echo "$entries" | sort -u))
  if [ -z "$missing" ]; then ok "M1 every manifest repository has an entry"
  else bad M1 "no entry in docs/repos.md for: $(echo $missing)"; fi
fi

if want M2; then
  stale=$(comm -13 <(echo "$listed") <(echo "$entries" | sort -u))
  dup=$(echo "$entries" | uniq -d)
  if [ -z "$stale$dup" ]; then ok "M2 every entry names a manifest repository, once"
  else bad M2 "not in the manifest: $(echo $stale)${dup:+; listed twice: $(echo $dup)}"; fi
fi

echo "$PASS passed, $FAIL failed${FAILED:+ ($FAILED )}"
[ "$FAIL" -eq 0 ]
