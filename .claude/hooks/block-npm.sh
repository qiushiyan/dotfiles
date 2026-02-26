#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Block npm commands but allow npx
if echo "$COMMAND" | grep -qE '(^|[;&|]\s*)npm\s'; then
  echo "BLOCKED: '$COMMAND' uses npm. Use pnpm instead." >&2
  exit 2
fi

exit 0
