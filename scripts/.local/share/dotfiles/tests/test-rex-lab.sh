#!/usr/bin/env bash
# test-rex-lab.sh — the Rex lab's Lua on a scratch server: the working tree's
# rex/.config/rex loads clean, every server call it makes matches the schemas
# that server publishes, and its actions do what their keys promise.
#
# Usage: bash test-rex-lab.sh [L1 L2 L3 L4]     # requires rex and jq
#
# What this pins: `rex config check` passes and the keymap has no diagnostics
# (L1); rex-doctor's contract check finds every call's method, payload keys
# and the result fields the code reads in the server's own help.all (L2),
# which is what catches a key Rex renamed, since Rex drops an unknown key
# without an error; and the actions, pressed as keys while another tab is the
# server's active one, move, split, swap, hold and jump where they should
# (L3, rex-lab-actions.lua, whose header says which actions it leaves out).
# rexd names a tab for its pane's directory or the pane's own label, never
# for the status chip the pane wears as its label (L4).
#
# The server is the CLI the installed app bundles (REX_BIN_DIR is dropped, so
# the wrapper does not pick an older running server's CLI): the build the next
# server restart will run. REX_BIN=/path/to/rex tries another.
#
# ISOLATION. A scratch server under a short temporary HOME (the socket path
# must fit a Unix socket's ~104 bytes) holding a copy of the config, with
# REX_* stripped from every command so nothing reaches the live server. The
# tools a split would start are stubs that sleep, and no pane runs a default
# shell.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../../../.." && pwd)"
PASS=0; FAIL=0; FAILED=""
RH=; SERVER_PID=; REXD_PID=
cleanup() {
  [ -n "$REXD_PID" ] && kill "$REXD_PID" 2>/dev/null
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null
    for _ in 1 2 3 4 5; do kill -0 "$SERVER_PID" 2>/dev/null || break; sleep 0.1; done
    kill -9 "$SERVER_PID" 2>/dev/null
  fi
  [ -n "${KEEP:-}" ] && { echo "kept $RH"; return; }
  case "$RH" in /tmp/rxl.*) rm -rf "$RH" ;; esac
}
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
  if [ "$2" = "$3" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}
want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

CLEAN=(env -u REX_SERVER -u REX_SESSION -u REX_BLOCK -u REX_BIN_DIR -u TMUX -u TMUX_PANE -u CLAUDE_PID -u XDG_STATE_HOME)
REX=${REX_BIN:-$("${CLEAN[@]}" /bin/sh -c 'command -v rex')}
if [ -z "$REX" ] || ! command -v jq >/dev/null; then
  echo "rex-lab: skipped, needs rex and jq"; exit 0
fi

RH=$(mktemp -d /tmp/rxl.XXXX)
mkdir -p "$RH/.config" "$RH/.local/bin"
cp -R "$REPO/rex/.config/rex" "$RH/.config/rex"
echo lab-test > "$RH/.config/machine"
for t in rex-label rex-urls rex-worktree rex-pane-pick rex-steps rex-board rex-toast rex-chip rex-clipshare tomini gopen; do
  printf '#!/bin/sh\nexec /bin/sleep 30\n' > "$RH/.local/bin/$t"; chmod +x "$RH/.local/bin/$t"
done
R() { "${CLEAN[@]}" HOME="$RH" "$REX" --autostart=false "$@"; }
( exec "${CLEAN[@]}" HOME="$RH" "$REX" server run ) >"$RH/server.log" 2>&1 &
SERVER_PID=$!
for _ in $(seq 100); do R ls >/dev/null 2>&1 && break; sleep 0.1; done
status=$(R server status --json 2>/dev/null)
if [ "$(jq -r .pid <<<"$status")" != "$SERVER_PID" ]; then
  echo "rex-lab: the server answering under $RH is not the one this suite started"; exit 1
fi
echo "rex-lab: $(jq -r '"\(.rex_version), api \(.api_revision)"' <<<"$status")"

CASE=L1; if want; then
  out=$(R config check "$RH/.config/rex/init.lua" 2>&1); rc=$?
  ok "L1 the config loads" "0" "$rc"
  [ "$rc" = 0 ] || printf '%s\n' "$out" | tail -5 | sed 's/^/    /'
  ok "L1 the keymap has no diagnostics" "[]" "$(R keymap --json 2>/dev/null | jq -c .diagnostics)"
fi

CASE=L2; if want; then
  R api call help.all > "$RH/help.json" 2>/dev/null
  out=$("$REPO/rex/.local/bin/rex-doctor" --contract "$RH/help.json" \
    --config "$REPO/rex/.config/rex" --bin "$REPO/rex/.local/bin" 2>&1); rc=$?
  ok "L2 every call matches this server's schemas" "0" "$rc"
  [ "$rc" = 0 ] || printf '%s\n' "$out" | sed 's/^/    /'
  # The check itself: a key the method does not take is found.
  mkdir -p "$RH/bad/lua" && printf 'call("session.new_split", { session_id = s, anchor_block_id = a })\n' > "$RH/bad/lua/x.lua"
  ok "L2 a payload key the server does not take is reported" "1" \
    "$("$REPO/rex/.local/bin/rex-doctor" --contract "$RH/help.json" --config "$RH/bad" --bin "$RH/bad" | grep -c 'is sent `anchor_block_id`')"
fi

CASE=L3; if want; then
  out=$(R --timeout 60s do "$HERE/rex-lab-actions.lua" 2>&1)
  printf '%s\n' "$out" | grep -e '^  FAIL' -e '^  time'
  result=$(printf '%s\n' "$out" | sed -n 's/^RESULT //p')
  if [ -z "$result" ]; then
    FAIL=$((FAIL+1)); FAILED="$FAILED L3"
    echo "  FAIL L3 the actions script did not finish:"; printf '%s\n' "$out" | tail -5 | sed 's/^/    /'
  else
    p=${result%% passed*}; f=${result##*, }; f=${f%% failed*}
    PASS=$((PASS+p)); FAIL=$((FAIL+f)); [ "$f" = 0 ] || FAILED="$FAILED L3"
  fi
fi

# L4: rexd from the sandbox's copy of the config, on a tab whose one pane
# sleeps in /tmp. The chip's files are written as rex-chip writes them: the
# pane's own label first, then the chip as the block's label.
CASE=L4; if want; then
  ( exec "${CLEAN[@]}" HOME="$RH" "$REX" --autostart=false do "$RH/.config/rex/scripts/rexd.lua" --all ) >"$RH/rexd.log" 2>&1 &
  REXD_PID=$!
  TS=$(R api call session.create '{"label":"tabs"}' | jq -r .session_id)
  made=$(R api call -s "$TS" session.new_window '{"layout":{"block":{"flavor":"com.superlogical.terminal.shell","label":"shell","options":{"command":["/bin/sleep","3600"],"login":false,"cwd":"/tmp"}}}}')
  TB=$(jq -r '.block_ids[0]' <<<"$made")
  tab() { R api call -s "$TS" session.view '{}' | jq -r '.view.windows[0].label // .windows[0].label'; }
  # tab_becomes WANT: the tab's label once it is WANT, or what it still is after 5 s.
  tab_becomes() { local got; for _ in $(seq 50); do got=$(tab); [ "$got" = "$1" ] && break; sleep 0.1; done; printf '%s' "$got"; }
  wear() {  # wear BASE CHIP: the pane takes CHIP as its label, its own being BASE
    mkdir -p "$RH/.local/state/rex-lab/chip"
    printf '%s\n' "$1" > "$RH/.local/state/rex-lab/chip/${TB//:/_}.base"
    R api call -s "$TS" session.set_block_label "$(jq -nc --arg b "$TB" --arg l "$2" '{block_id: $b, label: $l}')" >/dev/null
  }
  ok "L4 a plain pane names its tab for its directory" "1 tmp" "$(tab_becomes "1 tmp")"
  wear api 'a@b.example · 💠 fable-5-2:high · 🟩⬜⬜⬜⬜ 9%'
  ok "L4 a named pane that wears a chip names its tab by its own name" "1 api" "$(tab_becomes "1 api")"
  wear shell 'a@b.example · 💠 fable-5-2:high · 🟩🟩⬜⬜⬜ 31%'
  ok "L4 an unnamed pane that wears a chip keeps the directory" "1 tmp" "$(tab_becomes "1 tmp")"
  rm -f "$RH/.local/state/rex-lab/chip/${TB//:/_}.base"
  R api call -s "$TS" session.set_block_label "$(jq -nc --arg b "$TB" '{block_id: $b, label: "worker"}')" >/dev/null
  ok "L4 without a chip the pane's label names the tab, as before" "1 worker" "$(tab_becomes "1 worker")"
fi

echo "rex-lab: $PASS passed, $FAIL failed${FAILED:+ —$FAILED}"
[ "$FAIL" = 0 ]
