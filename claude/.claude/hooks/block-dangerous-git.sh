#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Claude may push any branch, trunk included. The protected-branch and opt-in
# push gates were removed 2026-10; restore them from aa07e9a^ if wanted.

# ─────────────────────────────────────────────────────────────────────────────
# Match against the command's *executable* parts, not inert text.
#
# We strip heredoc bodies and quoted strings before pattern-matching, so a
# dangerous pattern that only appears inside a commit message ("fix the git
# push retry") or a heredoc body no longer trips the guard. Error messages
# still show the full original $COMMAND.
#
# Trade-off (intentional): a dangerous command hidden *inside* a quoted string
# or heredoc — e.g. `bash -c "git push --force"` — is no longer caught. This is
# an accident-prevention guardrail, not an adversarial sandbox; direct and
# chained invocations (`git push`, `… && git push`) are still caught.
# ─────────────────────────────────────────────────────────────────────────────
strip_noise() {
  printf '%s' "$1" | awk '
    function trim(s){ sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); return s }
    {
      if (inhd) { if (trim($0) == term) inhd=0; next }   # drop heredoc body
      # heredoc opener: << [-] [quote] WORD   (not <<< here-strings)
      if (match($0, /<<[^<A-Za-z0-9]*[A-Za-z_][A-Za-z0-9_]*/)) {
        m = substr($0, RSTART, RLENGTH)
        gsub(/[^A-Za-z0-9_]/, "", m)                     # bare terminator word
        term = m; inhd = 1
      }
      print
    }
  ' | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g"             # drop quoted strings
}

SCAN=$(strip_noise "$COMMAND")

# ─────────────────────────────────────────────────────────────────────────────
# Tier 1: Always-blocked git push variants — no env-var bypass.
# Force pushes, deletes, and mirror pushes can wipe history or destroy
# branches. These require the user to run them manually outside Claude.
# ─────────────────────────────────────────────────────────────────────────────
FORCE_PATTERNS=(
  "push --force"
  "push -f\b"
  "push --delete"
  "push --mirror"
)

for pattern in "${FORCE_PATTERNS[@]}"; do
  if echo "$SCAN" | grep -qE -- "$pattern"; then
    cat >&2 <<EOF
BLOCKED: '$COMMAND' is a force/delete/mirror push.

These are NEVER bypassable from inside Claude — they can rewrite or delete
remote history. The user must run them manually after deciding the operation
is intentional.
EOF
    exit 2
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Tier 2: Other dangerous patterns — no bypass (matches prior behavior).
# ─────────────────────────────────────────────────────────────────────────────
DANGEROUS_PATTERNS=(
  "git reset --hard"
  "git clean -fd"
  "git clean -f"
  "git checkout \."
  "git restore \."
  "reset --hard"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$SCAN" | grep -qE "$pattern"; then
    echo "BLOCKED: '$COMMAND' matches dangerous pattern '$pattern'. The user has prevented you from doing this." >&2
    exit 2
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Tier 3: Force branch deletion — gated, with a per-command bypass.
#
# `git branch -D` is how worktree cleanup ends, and it is the only ending that
# works: a squash-merged branch never shares commits with the trunk, so `-d`
# refuses it as unmerged however thoroughly the work shipped. Blocking it
# outright dead-ends every cleanup, so this tier gates rather than forbids —
# deliberately narrower than the patterns above, which destroy uncommitted
# work and stay unbypassable.
# ─────────────────────────────────────────────────────────────────────────────
if echo "$SCAN" | grep -qE "git branch -D"; then
  if echo "$SCAN" | grep -qE "(^|[[:space:]])CLAUDE_ALLOW_BRANCH_DELETE=1[[:space:]]"; then
    exit 0  # user-authorized branch deletion
  fi
  cat >&2 <<'EOF'
BLOCKED: git branch -D force-deletes a branch, which is gated.

Deleting a branch git still considers unmerged can drop commits that exist
nowhere else. This is the expected state — not an error to work around.

How to bypass when authorized:

  CLAUDE_ALLOW_BRANCH_DELETE=1 git branch -D <branch>

When to use the bypass:
- ONLY when the user has authorized this cleanup — "clean up the worktrees",
  "delete that branch", or a cleanup task they asked for.
- Prefer `git branch -d` first. It succeeds whenever git can see the work is
  merged, and its refusal is the signal that this gate exists for.

When NOT to use the bypass:
- On your own initiative after deciding a branch looks finished.
- To clear an error from `git branch -d` you have not explained. Confirm the
  work reached the trunk first: for a squash merge, that the merged PR's head
  equals or contains this branch's HEAD.

If unsure: report the branch and why `-d` refused, then let the user decide.
EOF
  exit 2
fi

exit 0
