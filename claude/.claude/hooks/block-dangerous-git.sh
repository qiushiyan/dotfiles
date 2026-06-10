#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Branches Claude may NEVER push (no bypass) — your trunk(s). Edit this list to
# protect more, e.g. "main master develop release".
PROTECTED_BRANCHES="main master"

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
# Tier 2: Pushes from a protected branch (see PROTECTED_BRANCHES) — no bypass.
# Even when pushes are otherwise allowed, pushing the trunk warrants a fresh
# manual decision by the user.
# ─────────────────────────────────────────────────────────────────────────────
if echo "$COMMAND" | grep -qE "(^|[^a-zA-Z0-9_])git push"; then
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
if [ "$CLAUDE_GATE_PUSH" = "1" ] && echo "$COMMAND" | grep -qE "(^|[^a-zA-Z0-9_])git push"; then
  if echo "$COMMAND" | grep -qE "(^|[[:space:]])CLAUDE_ALLOW_PUSH=1[[:space:]]"; then
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
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCKED: '$COMMAND' matches dangerous pattern '$pattern'. The user has prevented you from doing this." >&2
    exit 2
  fi
done

exit 0
