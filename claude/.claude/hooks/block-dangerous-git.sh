#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Branches Claude may NEVER push (no bypass) — your trunk(s). Edit this list to
# protect more, e.g. "main master develop release".
PROTECTED_BRANCHES="main master"

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
# Tier 2: Pushes from a protected branch (see PROTECTED_BRANCHES) — no bypass.
# Even when pushes are otherwise allowed, pushing the trunk warrants a fresh
# manual decision by the user.
# ─────────────────────────────────────────────────────────────────────────────
if echo "$SCAN" | grep -qE "(^|[^a-zA-Z0-9_])git push"; then
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  for b in $PROTECTED_BRANCHES; do
    if [ "$CURRENT_BRANCH" = "$b" ]; then
      cat >&2 <<EOF
BLOCKED: current branch is '$CURRENT_BRANCH' (protected).

Pushes from protected branches ($PROTECTED_BRANCHES) cannot be bypassed by
CLAUDE_ALLOW_PUSH. The user must run these manually.
EOF
      exit 2
    fi
  done
fi

# ─────────────────────────────────────────────────────────────────────────────
# Tier 3: Plain git push from a NON-protected branch.
#
# Default: ALLOWED. Claude may push feature branches freely — the trunk is
# already covered by Tier 2 and force/delete by Tier 1.
#
# Opt-in gate: set CLAUDE_GATE_PUSH=1 in the hook's environment (e.g. add it to
# the "env" block in ~/.claude/settings.json) to restore the old default-block
# behavior. When the gate is on, each push must be authorized per-command with
# a CLAUDE_ALLOW_PUSH=1 prefix.
# ─────────────────────────────────────────────────────────────────────────────
if [ "$CLAUDE_GATE_PUSH" = "1" ] && echo "$SCAN" | grep -qE "(^|[^a-zA-Z0-9_])git push"; then
  if echo "$SCAN" | grep -qE "(^|[[:space:]])CLAUDE_ALLOW_PUSH=1[[:space:]]"; then
    exit 0  # user-authorized push
  fi
  cat >&2 <<'EOF'
BLOCKED: git push is gated (CLAUDE_GATE_PUSH=1).

The gate exists so the user can review your local commits before they reach
the remote. This is the expected state while the gate is on — not an error you
should work around on your own.

How to bypass when authorized:

  CLAUDE_ALLOW_PUSH=1 git push <args>

When to use the bypass:
- ONLY when the user has explicitly said something like "go ahead and push",
  "you can push", or has authorized pushes for this task (e.g., during a
  multi-round code-review loop).
- Force pushes (--force, -f, --delete, --mirror) and pushes from a protected
  branch are NEVER bypassable, even with the env var.

When NOT to use the bypass:
- On your own initiative because you decided the work looks ready.
- After only an implicit signal — silence, "okay", or topic shift is not
  authorization.

If unsure: tell the user the commit is ready locally and the branch is
unpushed, then let them push.
EOF
  exit 2
fi

# ─────────────────────────────────────────────────────────────────────────────
# Tier 4: Other dangerous patterns — no bypass (matches prior behavior).
# ─────────────────────────────────────────────────────────────────────────────
DANGEROUS_PATTERNS=(
  "git reset --hard"
  "git clean -fd"
  "git clean -f"
  "git branch -D"
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

exit 0
