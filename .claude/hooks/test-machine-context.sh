#!/usr/bin/env bash
# test-machine-context.sh — the machine-context hook's contract: the marker
# picks its machine's text, and a machine it cannot name is reported, never
# guessed.
#
# Usage: bash .claude/hooks/test-machine-context.sh
#
# ISOLATION. HOME is a temporary directory, so the real marker is not read.
set -uo pipefail

HOOK="$(cd "$(dirname "$0")" && pwd)/machine-context.sh"
MACHINES="$(cd "$(dirname "$0")/../machines" && pwd)"
SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/machine-context-test.XXXXXX")
trap 'rm -rf "$SANDBOX"' EXIT
PASS=0; FAIL=0

ok() {  # ok <name> <expected> <actual>
  if [ "$2" = "$3" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}
run() { HOME="$SANDBOX" bash "$HOOK"; }
mark() { mkdir -p "$SANDBOX/.config"; printf '%s\n' "$1" > "$SANDBOX/.config/machine"; }

for m in mac mini; do
  mark "$m"
  ok "M-$m prints its own file" "$(cat "$MACHINES/$m.md")" "$(run)"
  ok "M-$m names the machine first" "You are on the $m:" "$(run | head -1 | cut -d' ' -f1-5)"
done

mark "  mini  "
ok "M-space marker whitespace is ignored" "$(cat "$MACHINES/mini.md")" "$(run)"

rm -f "$SANDBOX/.config/machine"
ok "M-none a missing marker is reported" "This machine is not identified: ~/.config/machine is missing or empty." "$(run | head -1)"

mark nosuchhost
ok "M-unknown an unknown name is reported" "This machine is not identified: ~/.config/machine names 'nosuchhost', which has no .claude/machines/nosuchhost.md." "$(run | head -1)"
ok "M-unknown exits 0, so the session still starts" "0" "$(run >/dev/null; echo $?)"

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
