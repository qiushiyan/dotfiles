#!/bin/bash
# doc-check against a throwaway repository: growth, each check, broken §
# references, live-doc scoping, and the nothing-staged refusal. Never touches
# the caller's repository: everything runs inside its own mktemp directory.
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/doc-check"
T=$(mktemp -d "${TMPDIR:-/tmp}/doc-check-test.XXXXXX")
case "$T" in */doc-check-test.*) ;; *) echo "refusing: bad temp dir '$T'"; exit 1 ;; esac
trap 'rm -rf "$T"' EXIT
pass=0 fail=0
check() { if eval "$2"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1"; echo "$out" | sed 's/^/    /'; fi; }

cd "$T" && git init -q . && git config user.email t@t && git config user.name t
mkdir -p docs/specs
printf '# Design\n\n## The hot path\n\nOne line.\n' > docs/design.md
git add -A && git commit -qm base

out=$("$SCRIPT" 2>&1); code=$?
check "nothing staged is refused" '[[ $code -eq 2 && $out == *"no staged Markdown"* ]]'

cat >> docs/design.md <<'DOC'
It no longer retries; there are two queues.
See `docs/design.md` § The hot path and `docs/design.md` § Missing heading.
The plan is in docs/specs/2026-01-01-plan.md.

| a | b |
| --- | --- |
A read owed after merge.
DOC
printf '# Notes\n\nIt is now fast.\n' > notes.md
git add -A
out=$("$SCRIPT" 2>&1); code=$?
check "reports growth per doc in words" '[[ $code -eq 0 && $out == *"docs/design.md: 8 -> "*"grew"* && $out == *"notes.md: 0 -> 6 (+6)"* && $out == *"total +"* ]]'
check "changelog wording" '[[ $out == *"changelog: docs/design.md:"*"no longer"* ]]'
check "cardinal" '[[ $out == *"cardinal: docs/design.md"* ]]'
check "table" '[[ $out == *"table: docs/design.md"* ]]'
check "owed wording without the marker" '[[ $out == *"owed-marker: docs/design.md"* ]]'
check "broken § only for the missing heading" '[[ $(grep -c "broken-§" <<<"$out") -eq 1 && $out == *"broken-§"*"Missing heading"* ]]'
check "proposal reference in a live doc" '[[ $out == *"proposal-ref: docs/design.md"* ]]'
check "notes.md is checked but is not a live doc" '[[ $out == *"changelog: notes.md"* && $out != *"proposal-ref: notes.md"* ]]'
out=$("$SCRIPT" 'notes.md' 2>&1)
check "a live pathspec argument replaces the default" '[[ $out != *"proposal-ref"* ]]'

echo "PASS $pass  FAIL $fail"
[[ $fail -eq 0 ]]
