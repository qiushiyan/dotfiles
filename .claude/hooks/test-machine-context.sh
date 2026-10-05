#!/usr/bin/env bash
# test-machine-context.sh — the machine-context hook's contract: the marker
# picks its machine's text, and a machine it cannot name is reported, never
# guessed.
#
# Usage: bash .claude/hooks/test-machine-context.sh
#
# ISOLATION. HOME is a temporary directory, so the real marker is not read,
# and PATH holds a stub `twin` or none, so the real one never runs.
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
# The hook's own tools, and nothing else: no twin unless a case stubs one.
BARE="/usr/bin:/bin"
run() { HOME="$SANDBOX" PATH="$BARE" bash "$HOOK"; }
# stub <body>: a `twin` on PATH that logs its arguments, then runs body.
stub() {
  mkdir -p "$SANDBOX/bin"
  printf '#!/bin/sh\necho "$*" >> "%s/twin.args"\n%s\n' "$SANDBOX" "$1" > "$SANDBOX/bin/twin"
  chmod +x "$SANDBOX/bin/twin"
}
with_twin() { HOME="$SANDBOX" PATH="$SANDBOX/bin:$BARE" TWIN_HOOK_LIMIT=1 bash "$HOOK"; }
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

# twin's report follows the machine text. The hook asks for recorded state
# only, which is what keeps it off the network (twin's own suite holds that
# --recorded makes no call to the other machine).
mark mini
stub 'echo "attention: 1"; echo "  mini dotfiles: behind"; exit 1'
out=$(with_twin)
ok "T-text the machine text still comes first" "$(cat "$MACHINES/mini.md")" "$(printf '%s\n' "$out" | head -n "$(wc -l < "$MACHINES/mini.md" | tr -d ' ')")"
ok "T-items the dotfiles items follow it" "  mini dotfiles: behind" "$(printf '%s\n' "$out" | tail -1)"
ok "T-args it asks for recorded state of the dotfiles target" "status dotfiles --recorded" "$(cat "$SANDBOX/twin.args")"

stub 'sleep 5; echo "attention: none"'
ok "T-slow a twin slower than the limit adds nothing" "$(cat "$MACHINES/mini.md")" "$(with_twin)"

rm -rf "$SANDBOX/bin"
ok "T-absent no twin on PATH leaves the machine text alone" "$(cat "$MACHINES/mini.md")" "$(run)"

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
