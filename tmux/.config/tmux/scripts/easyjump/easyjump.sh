#!/bin/bash
# easyjump.sh — launcher for the vendored flash-style jump (see DESIGN.md).
# Bound from tmux.conf (prefix s / copy-mode-vi C-s). Resolves python3 robustly
# because tmux run-shell's PATH can be thinner than an interactive shell's, and
# logs stderr so failures are debuggable (the overlay is written straight to the
# pane tty, so stdout/stderr carry only errors, never the rendering).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="${TMPDIR:-/tmp}/tmux-easyjump.log"

PY="$(command -v python3 || true)"
if [ -z "$PY" ]; then
  for p in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
    [ -x "$p" ] && PY="$p" && break
  done
fi

exec "$PY" "$DIR/easyjump.py" \
  --smart-case=on \
  --auto-begin-selection=on \
  --autojump=on \
  "$@" >>"$LOG" 2>&1
