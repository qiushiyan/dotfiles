#!/usr/bin/env bash
# test-rex-upgrade.sh — rex-upgrade takes a Rex server down and brings every
# session back as it was, swapping in a staged app on the way; rexd starts
# once however many shells ask at the same moment.
#
# Usage: bash test-rex-upgrade.sh [U1 U4 ...]
#
# What this pins: the feed names the next build and the next step (U1); a
# restore refuses to run inside Rex or on the snapshot's own server (U2); the
# job restarts the server and rebuilds each session, tab name, split, pane
# label and cwd (U3); a staged app replaces the app and the one it replaced is
# kept (U4); four rexd starts at once leave one rexd (U5); start --dry-run
# writes the launchd job and starts nothing (U6).
#
# ISOLATION. A scratch Rex server under a short temporary HOME, with REX_*
# stripped so no call reaches the live server; the app is a fake bundle
# (REX_UPGRADE_APP) that names no executable, so nothing quits or opens the
# real app; the feed is a fixture file (REX_UPGRADE_FEED). Every server stop
# first checks the endpoint lies in the sandbox. U7 asserts the live server
# and the real upgrades directory are untouched.

set -uo pipefail
unset REX_SERVER REX_SESSION REX_BLOCK XDG_STATE_HOME XDG_CONFIG_HOME
# The environment launchd gives the job: a server started with a tool shell's
# NO_COLOR or a dumb TERM is one the job refuses.
unset NO_COLOR FORCE_COLOR SSH_CONNECTION
export TERM=xterm-256color

BIN="$(cd "$(dirname "$0")/../../../../../rex/.local/bin" && pwd)"
TREE="$(cd "$BIN/../.." && pwd)"
TOOL="$BIN/rex-upgrade"
REAL_HOME=$HOME
PASS=0; FAIL=0; FAILED=""

live_server() { HOME=$REAL_HOME rex --autostart=false server status 2>/dev/null | grep -E '^(pid|instance):' | tr '\n' ' '; }
LIVE_BEFORE=$(live_server)
UPGRADES_BEFORE=$(ls "$REAL_HOME/.local/state/rex-lab/upgrades" 2>/dev/null)

SB=$(mktemp -d /tmp/ru.XXXXXX)
case "$SB" in /tmp/ru.?*) ;; *) echo "bad sandbox $SB"; exit 1;; esac
export HOME=$SB
export REX_UPGRADE_APP="$SB/Applications/Rex Beta.app"
export REX_UPGRADE_FEED="file://$SB/appcast.xml"
mkdir -p "$SB/.config/rex" "$SB/.local/bin" "$SB/Applications" "$SB/w1" "$SB/w2" "$SB/w3"
for f in init.lua lua scripts; do ln -s "$TREE/.config/rex/$f" "$SB/.config/rex/$f"; done
ln -s "$BIN/rex" "$SB/.local/bin/rex"
ln -s "$BIN/rexd" "$SB/.local/bin/rexd"
cd "$SB" || exit 1

in_sandbox() { rex --autostart=false server status 2>/dev/null | grep -q "^endpoint: .*${SB#/}"; }
stop_server() { in_sandbox && rex --autostart=false server stop >/dev/null 2>&1; }
cleanup() {
    stop_server
    [ -n "${KEEP:-}" ] && { echo "kept $SB"; return; }
    case "$SB" in /tmp/ru.?*) rm -rf "$SB";; esac
}
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}
want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

fake_app() {  # fake_app DIR BUILD: a bundle that names a build and no executable
    mkdir -p "$1/Contents"
    /usr/bin/python3 -c 'import plistlib,sys; plistlib.dump({"CFBundleVersion": sys.argv[2]}, open(sys.argv[1], "wb"))' "$1/Contents/Info.plist" "$2"
}
build_of() { /usr/bin/python3 -c 'import plistlib,sys; print(plistlib.load(open(sys.argv[1], "rb")).get("CFBundleVersion"))' "$1/Contents/Info.plist" 2>/dev/null; }
js() { /usr/bin/python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

cat > "$SB/appcast.xml" <<'XML'
<?xml version="1.0"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel>
<item><sparkle:version>150</sparkle:version><description><![CDATA[Rex 0.0.150-gaaaaaa]]></description>
<enclosure url="file:///nonexistent/150.dmg" length="1"/></item>
<item><sparkle:version>200</sparkle:version><description><![CDATA[Preview 200

Rex 0.0.200-gbbbbbb (`bbbb`)]]></description><pubDate>Thu, 29 Oct 2026</pubDate>
<enclosure url="file:///nonexistent/200.dmg" length="1"/></item>
</channel></rss>
XML
fake_app "$REX_UPGRADE_APP" 100

rex server start >/dev/null 2>&1
if ! in_sandbox; then echo "the scratch server is not in the sandbox; stopping before any case"; exit 1; fi

# A scratch layout: alpha has a named tab split in two with a labelled pane,
# beta two tabs.
A=$(rex new alpha --window work --json -c "$SB/w1" | js 'd["initial_windows"][0]["block_ids"][0]')
rex run -s alpha -b "$A" --split right --focus=false -c "$SB/w2" -- /bin/zsh -l >/dev/null
rex block rename -s alpha "$A" editor >/dev/null
rex new beta --window one -c "$SB/w3" >/dev/null
rex window new -s beta two --focus=false -c "$SB/w1" >/dev/null
sleep 1

CASE=U1; if want; then
    out=$("$TOOL" check 2>&1)
    ok "U1 check names the feed's newest build" "feed:    200 (server 0.0.200-gbbbbbb), Thu, 29 Oct 2026" "$(grep '^feed:' <<<"$out")"
    ok "U1 check says to stage it" "next:    rex-upgrade stage, then rex-upgrade start" "$(grep '^next:' <<<"$out")"
    ok "U1 stage refuses a build the feed lacks" "the feed has no build 999" "$("$TOOL" stage 999 2>&1)"
fi

CASE=U2; if want; then
    "$TOOL" snapshot "$SB/pre" >/dev/null 2>&1
    ok "U2 restore refuses to run inside Rex" "run this from outside Rex" \
        "$(REX_BLOCK=block:x "$TOOL" restore --go "$SB/pre/snapshot.json" 2>&1 | grep -o 'run this from outside Rex')"
    ok "U2 restore refuses the server the snapshot was taken on" \
        "this is still the server the snapshot was taken on; restart it first" \
        "$("$TOOL" restore --go "$SB/pre/snapshot.json" 2>&1 | grep 'still the server')"
fi

CASE=U3; if want; then
    before=$(rex --autostart=false server status | grep '^instance:')
    mkdir -p "$SB/.local/state/rex-lab/upgrades/stage"
    fake_app "$SB/.local/state/rex-lab/upgrades/stage/Rex Beta.app" 200
    "$TOOL" job "$SB/run1" --now > "$SB/run1.log" 2>&1
    ok "U3 the job finishes" "done" "$(tail -1 "$SB/run1.log" | cut -c10-)"
    after=$(rex --autostart=false server status | grep '^instance:')
    ok "U3 the server is a new instance" "yes" "$([ -n "$after" ] && [ "$after" != "$before" ] && echo yes || echo "no: $before / $after")"
    ok "U3 both sessions are back" "alpha beta" "$(rex ls --json | js '" ".join(sorted(s["label"] for s in d["sessions"]))')"
    ok "U3 alpha's tab keeps its name and both panes" "work 2" \
        "$(rex window ls -s alpha --json | js '" ".join(__import__("re").sub(r"^\d+\s*", "", w["label"]) + " " + str(sum(len(l["blocks"]) for l in w["layers"])) for w in d["windows"])')"
    ok "U3 the pane label comes back" "yes" "$(rex block ls -s alpha --json | js '"yes" if any(b.get("label") == "editor" for b in d["blocks"]) else "no"')"
    ok "U3 beta's tabs come back in order" "one two" \
        "$(rex window ls -s beta --json | js '" ".join(__import__("re").sub(r"^\d+\s*", "", w["label"]) for w in sorted(d["windows"], key=lambda w: w["label"]))')"
    cwds=$(for b in $(rex block ls -s alpha --json | js '" ".join(b["block_id"] for b in d["blocks"] if b.get("label") != "rexd")'); do
        rex block call -s alpha --block "$b" process | js '(d.get("foreground") or {}).get("cwd") or (d.get("child") or {}).get("cwd")'; done | sed "s#^/private##" | sort | tr '\n' ' ')
    ok "U3 each pane opens in its cwd" "$SB/w1 $SB/w2 " "$cwds"
fi

CASE=U4; if want; then
    ok "U4 the staged app replaced the app" "200" "$(build_of "$REX_UPGRADE_APP")"
    ok "U4 the replaced app is kept with the run" "100" "$(build_of "$SB/run1/old/Rex Beta.app")"
    ok "U4 nothing stays staged" "" "$(ls "$SB/.local/state/rex-lab/upgrades/stage" 2>/dev/null)"
fi

CASE=U5; if want; then
    "$BIN/rexd" stop >/dev/null 2>&1
    for _ in 1 2 3 4; do REX_SESSION= "$BIN/rexd" >/dev/null 2>&1 & done
    wait
    sleep 1
    ok "U5 four rexd starts at once leave one" "1" "$("$BIN/rexd" status | grep -c '^rexd runs in\|^session:')"
fi

CASE=U6; if want; then
    out=$("$TOOL" start --dry-run 2>&1)
    plist=$(ls "$SB"/.local/state/rex-lab/upgrades/*/job.plist 2>/dev/null | head -1)
    ok "U6 the dry run writes the job and starts nothing" "dry run" "$(tail -1 <<<"$out" | cut -c1-7)"
    ok "U6 the job runs the tool's job in its run directory" "job $(dirname "$plist")" \
        "$(/usr/bin/python3 -c 'import plistlib,sys; a=plistlib.load(open(sys.argv[1],"rb"))["ProgramArguments"]; print(a[2], a[3])' "$plist" 2>/dev/null)"
fi

CASE=U7; if want; then
    ok "U7 the live server is untouched" "$LIVE_BEFORE" "$(live_server)"
    ok "U7 the real upgrades directory is untouched" "$UPGRADES_BEFORE" "$(ls "$REAL_HOME/.local/state/rex-lab/upgrades" 2>/dev/null)"
fi

echo "rex-upgrade: $PASS passed, $FAIL failed${FAILED:+ ($FAILED )}"
[ "$FAIL" -eq 0 ]
