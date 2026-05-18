#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

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
  if echo "$COMMAND" | grep -qE -- "$pattern"; then
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
# Tier 2: Pushes from a protected current branch — no env-var bypass.
# (`develop`, `main`, `master`.) Even when the user has authorized pushes
# generally, a push from a protected branch warrants a fresh manual decision.
# ─────────────────────────────────────────────────────────────────────────────
if echo "$COMMAND" | grep -qE "(^|[^a-zA-Z0-9_])git push"; then
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  case "$CURRENT_BRANCH" in
    develop|main|master)
      cat >&2 <<EOF
BLOCKED: current branch is '$CURRENT_BRANCH' (protected).

Pushes from develop / main / master cannot be bypassed by CLAUDE_ALLOW_PUSH.
The user must run these manually.
EOF
      exit 2 ;;
  esac
fi

# ─────────────────────────────────────────────────────────────────────────────
# Tier 3: Plain git push — bypassable via CLAUDE_ALLOW_PUSH=1 prefix.
# Default-block so the user can review local commits before they reach the
# remote. Claude must only set the env var when the user has explicitly
# authorized this push (or pushes during the current task).
# ─────────────────────────────────────────────────────────────────────────────
if echo "$COMMAND" | grep -qE "(^|[^a-zA-Z0-9_])git push"; then
  if echo "$COMMAND" | grep -qE "(^|[[:space:]])CLAUDE_ALLOW_PUSH=1[[:space:]]"; then
    exit 0  # user-authorized push
  fi
  cat >&2 <<'EOF'
BLOCKED: git push is gated by default.

The gate exists so the user can review your local commits before they reach
the remote. This is the expected default state — not an error you should
work around on your own.

How to bypass when authorized:

  CLAUDE_ALLOW_PUSH=1 git push <args>

When to use the bypass:
- ONLY when the user has explicitly said something like "go ahead and push",
  "you can push", or has authorized pushes for this task (e.g., during a
  multi-round code-review loop).
- Force pushes (--force, -f, --delete, --mirror) and pushes from develop /
  main / master are NEVER bypassable, even with the env var.

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
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCKED: '$COMMAND' matches dangerous pattern '$pattern'. The user has prevented you from doing this." >&2
    exit 2
  fi
done

exit 0
