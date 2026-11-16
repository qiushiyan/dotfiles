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
check "reports growth per doc in words" '[[ $out == *"docs/design.md: 8 -> "* && $out == *"notes.md: 0 -> 6 (+6)"* && $out == *"total +"* ]]'
check "unexplained growth in a live doc fails" '[[ $code -eq 1 && $out == *"growth: docs/design.md"* ]]'
check "a non-live doc may grow" '[[ $out != *"growth: notes.md"* ]]'
check "changelog wording" '[[ $out == *"changelog: docs/design.md:"*"no longer"* ]]'
check "cardinal" '[[ $out == *"cardinal: docs/design.md"* ]]'
check "table" '[[ $out == *"table: docs/design.md"* ]]'
check "owed wording without the marker" '[[ $out == *"owed-marker: docs/design.md"* ]]'
check "broken § fails, only for the missing heading" '[[ $(grep -c "broken-§" <<<"$out") -eq 1 && $out == *"broken-§"*"Missing heading"* ]]'
check "proposal reference in a live doc" '[[ $out == *"proposal-ref: docs/design.md"* ]]'
check "notes.md is checked but is not a live doc" '[[ $out == *"changelog: notes.md"* && $out != *"proposal-ref: notes.md"* ]]'
out=$("$SCRIPT" 'notes.md' 2>&1)
check "a live pathspec argument replaces the default" '[[ $out != *"proposal-ref"* ]]'

git reset -q && git checkout -q -- docs/design.md && rm -f notes.md
mkdir -p src && printf 'export const liveName = 1;\nexport function oldHelper() {}\n' > src/a.ts
printf '# Notes\n\n## Kept\n\n## Doomed\n' > docs/notes.md
printf '// see docs/notes.md § Doomed\n' > src/b.ts
git add -A && git commit -qm code
printf 'Uses `liveName`, `goneName` and `src/a.ts`, `src/missing.ts`.\n' >> docs/design.md
git add -A
out=$("$SCRIPT" --grew 'docs/design.md=invariant: names the live constant' 2>&1); code=$?
check "--grew clears growth and prints the trailer" '[[ $out != *"growth: docs/design.md"* && $out == *"Doc-Change: docs/design.md — invariant: names the live constant"* ]]'
check "dead-name fails for an identifier nowhere in code" '[[ $code -eq 1 && $out == *"dead-name"*"goneName"* && $out != *"dead-name"*"liveName"* ]]'
check "dead-path fails for a missing file" '[[ $out == *"dead-path"*"src/missing.ts"* && $out != *"dead-path"*"src/a.ts"* ]]'
out=$("$SCRIPT" --grew 'docs/design.md=invariant: x' --allow goneName 2>&1)
check "--allow excuses an external name" '[[ $out != *"dead-name"* ]]'
out=$("$SCRIPT" --grew 'docs/design.md=nonsense: x' 2>&1); code=$?
check "--grew refuses an unknown kind" '[[ $code -ne 0 && $out == *"the kind is one of"* ]]'
git reset -q && git checkout -q -- docs/design.md
printf '# Notes\n\n## Kept\n' > docs/notes.md && git add -A
out=$("$SCRIPT" 2>&1); code=$?
check "inbound fails when code cites a removed heading" '[[ $code -eq 1 && $out == *"inbound"*"Doomed"*"src/b.ts"* ]]'
git reset -q && git checkout -q -- docs/notes.md
git branch -q base && printf 'Calls `oldHelper` here.\n' >> docs/design.md && git commit -qam doc
printf 'export const liveName = 1;\n' > src/a.ts && git commit -qam drop
out=$("$SCRIPT" --stale --base base 2>&1)
check "--stale lists a doc line naming a removed identifier" '[[ $out == *"docs/design.md:"*"oldHelper"* ]]'

git reset -q && git checkout -q -- docs/design.md 2>/dev/null
printf '# Wrap\n\n## The drain and its regimes — what a stop waits for\n' > docs/wrap.md && git add -A && git commit -qm wrap
printf 'See `docs/wrap.md` § The drain and its\nregimes for the cut. Also `docs/wrap.md` § The drain and its regimes.\n' >> docs/design.md && git add -A
out=$("$SCRIPT" --grew 'docs/design.md=route: x' 2>&1)
check "a § reference wrapped across lines, or naming a heading's lead, resolves" '[[ $out != *"broken-§"* ]]'
printf 'Shorthand `lib/nowhere.ts` inside a package doc.\n' >> docs/design.md && git add -A
out=$("$SCRIPT" --grew 'docs/design.md=route: x' 2>&1)
check "an unanchored shorthand path is not judged" '[[ $out != *"dead-path"* ]]'

printf '# Ledger\n\n12. **A numbered entry.** Text.\n' > docs/ledger.md && git add -A && git commit -qm ledger
printf 'See `docs/ledger.md` § 12 and `docs/ledger.md` § 13.\n' >> docs/design.md && git add -A
out=$("$SCRIPT" --grew 'docs/design.md=route: x' 2>&1)
check "a numbered entry resolves; a missing number does not" '[[ $(grep -c "broken-§" <<<"$out") -eq 1 && $out == *"§ 13"* ]]'

git reset -q
mkdir -p .agents/skills/x && printf '# Skill\n\nSee `docs/ledger.md` § 12, and `docs/wrap.md` § The drain and its regimes.\n' > .agents/skills/x/SKILL.md
git add -A && git commit -qm skill
printf '# Wrap\n\n## Something else\n' > docs/wrap.md && git add -A
out=$("$SCRIPT" 2>&1); code=$?
check "inbound fails when a skill cites a removed heading" '[[ $code -eq 1 && $out == *"inbound"*".agents/skills/x/SKILL.md"* ]]'
git reset -q && git checkout -q -- docs/wrap.md
printf 'export class FooBarStore {}\nexport const snake_name = 1;\n' > src/c.ts && git add -A && git commit -qm c
printf 'Uses `FooBarStore` and `snake_name`.\n' >> docs/design.md && git add -A && git commit -qm d
git branch -q base2 && git rm -q src/c.ts && git commit -qm rm
out=$("$SCRIPT" --stale --base base2 2>&1)
check "--stale finds PascalCase and snake_case names" '[[ $out == *"FooBarStore"* && $out == *"snake_name"* ]]'
printf 'More words for growth here.\n' >> docs/design.md && git commit -qam grow
printf 'And a little more.\n' >> docs/design.md && git add -A
out=$("$SCRIPT" --since base2 2>&1)
check "--since counts growth committed earlier on the branch" '[[ $out == *"growth: docs/design.md"* ]]'

printf 'export const fooToken = 1;\n' > src/d.ts && printf 'Reads `fooToken`.\n' >> docs/design.md && git add -A && git commit -qm foo
git branch -q base3 && rm src/d.ts
out=$("$SCRIPT" --stale --base base3 2>&1)
check "--stale sees an uncommitted removal" '[[ $out == *"fooToken"* ]]'
git checkout -q -- src/d.ts

echo "PASS $pass  FAIL $fail"
[[ $fail -eq 0 ]]
