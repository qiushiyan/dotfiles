#!/usr/bin/env bash
# test-rex-upgrade.sh — rex-upgrade takes a Rex server down and brings every
# session back as it was, swapping in a staged app on the way; rexd starts
# once however many shells ask at the same moment.
#
# Usage: bash test-rex-upgrade.sh [U1 U4 ...]
#
# What this pins: the feed names the next build (U1); staging takes a
# verified image and refuses each bad one without touching what is staged
# (U2); a restore refuses to run inside Rex or on the snapshot's own server
# (U3); the job rebuilds each window's layout tree, pane labels and cwds,
# resumes every conversation on its account with its flags, has drive reopen
# a driven pane and splits its neighbour in beside it, nudges what the
# restart interrupted, names each pane it could not bring back, swaps in the
# staged app and reports the outcome to the session that ran it (U4); a
# second restore rebuilds nothing twice (U5); rexd starts once, also after a
# start that died (U6); the dry run plans it all and changes nothing (U7); a
# failed snapshot read or wake stop stops the job before it touches anything
# (U8); a new server of the wrong build is refused (U9); the job waits while a session works (U10); start runs the job
# under launchd and refuses a second one (U11).
#
# ISOLATION. A scratch Rex server under a short temporary HOME, with REX_*
# stripped so no call reaches the live server, and drive's directories moved
# into the sandbox. The app is a fake bundle (REX_UPGRADE_APP) that names no
# executable, so nothing quits or opens the real app. Claude Code is a stub
# that registers in the sandbox's sessions directory and names itself
# `claude <flags>` to ps; drive is a stub on the sandbox PATH; a rex shim in
# front of the real CLI injects failures. Every server stop first checks the
# endpoint lies in the sandbox, and the launchd case uses its own label. U12
# asserts the live server and the real upgrades directory are untouched and
# drive's real state holds nothing of the sandbox's batch.

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
export DRIVE_STATE_DIR="$SB/.local/state/drive" DRIVE_CONFIG_DIR="$SB/.config/drive"
export REX_UPGRADE_APP="$SB/Applications/Rex Beta.app"
export REX_UPGRADE_FEED="file://$SB/appcast.xml"
export REX_UPGRADE_LABEL="com.qiushi.rex-upgrade-test.$$"
export REX_UPGRADE_TICK=0.2
export HEADROOM_PRIMARY_NAME=tester
export PATH="$SB/.local/bin:$PATH"
STAGE="$SB/.local/state/rex-lab/upgrades/stage"
mkdir -p "$SB/.config/rex" "$SB/.local/bin" "$SB/Applications" "$SB/w1" "$SB/w2" "$SB/w3" "$SB/gone" "$SB/fx"
for f in init.lua lua scripts; do ln -s "$TREE/.config/rex/$f" "$SB/.config/rex/$f"; done
ln -s "$BIN/rexd" "$SB/.local/bin/rexd"
# A pane the server starts gets a bare PATH; a resumed pane's zsh -lic finds the
# launchers as the real ~/.zshrc puts ~/.local/bin on it.
echo 'export PATH="$HOME/.local/bin:$PATH"' > "$SB/.zshenv"
cd "$SB" || exit 1

in_sandbox() { "$BIN/rex" --autostart=false server status 2>/dev/null | grep -q "^endpoint: .*${SB#/}"; }
stop_server() { in_sandbox && "$BIN/rex" --autostart=false server stop >/dev/null 2>&1; }
cleanup() {
    launchctl bootout "gui/$(id -u)/$REX_UPGRADE_LABEL" 2>/dev/null
    stop_server
    [ -n "${KEEP:-}" ] && { echo "kept $SB"; return; }
    case "$SB" in /tmp/ru.?*) command rm -rf "$SB";; esac
}
trap cleanup EXIT

ok() {  # ok <name> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); FAILED="$FAILED $1"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}
has() { grep -q -- "$2" "$1" 2>/dev/null && echo yes || echo no; }  # has FILE TEXT
want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

py() { /usr/bin/python3 - "$@"; }
plist_set() {  # plist_set APP KEY=VALUE...: a bundle's Info.plist
    mkdir -p "$1/Contents"
    py "$@" <<'PY'
import plistlib, sys
plistlib.dump(dict(a.split("=", 1) for a in sys.argv[2:]), open(sys.argv[1] + "/Contents/Info.plist", "wb"))
PY
}
build_of() { /usr/bin/python3 -c 'import plistlib,sys; print(plistlib.load(open(sys.argv[1], "rb")).get("CFBundleVersion"))' "$1/Contents/Info.plist" 2>/dev/null; }
js() { /usr/bin/python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }
instance() { rex --autostart=false server status 2>/dev/null | grep '^instance:'; }

# --- stubs ------------------------------------------------------------------------

# rex: the real CLI, unless $HOME/rex-fail names words a call must not get past.
cat > "$SB/.local/bin/rex" <<EOF
#!/bin/bash
if [ -f "\$HOME/rex-fail" ] && [[ " \$* " == *" \$(cat "\$HOME/rex-fail") "* ]]; then echo "injected failure" >&2; exit 1; fi
exec "$BIN/rex" "\$@"
EOF

# Claude Code: registers <config>/sessions/<pid>.json as the real one does, names
# itself "claude <flags>" to ps, and on each typed line logs it, reads busy for
# two seconds, then idle. Run with an empty environment so its title is clean.
cat > "$SB/.local/bin/claude-stub.pl" <<'EOF'
use strict; use File::Path qw(make_path);
my ($cfg, $sid, $cwd, $recv, $status, @flags) = @ARGV;
$0 = join(" ", "claude", @flags);
make_path("$cfg/sessions");
sub reg { open(my $f, ">", "$cfg/sessions/$$.tmp"); print $f qq({"pid":$$,"sessionId":"$sid","cwd":"$cwd","status":"$_[0]"}); close $f;
          rename("$cfg/sessions/$$.tmp", "$cfg/sessions/$$.json"); }
reg($status);
while (my $line = <STDIN>) { open(my $r, ">>", $recv); print $r "$sid\t$line"; close $r; reg("busy"); sleep 2; reg("idle"); }
unlink "$cfg/sessions/$$.json";
EOF

# x-<account>: the account launcher. The primary's (tester's) sessions live in ~/.claude,
# another account's in ~/.claude-accounts/<account>@example.com. busy-<sid>
# starts it mid-turn once; fail-<sid> makes it fail.
cat > "$SB/.local/bin/x-account" <<'EOF'
#!/bin/bash
acct=$(basename "$0"); acct=${acct#x-}
if [ "$acct" = tester ]; then cfg="$HOME/.claude"; else cfg="$HOME/.claude-accounts/$acct@example.com"; fi
sid=""; flags=()
while [ $# -gt 0 ]; do case "$1" in --resume|--session-id) sid=$2; shift 2;; *) flags+=("$1"); shift;; esac; done
echo "x-$acct ${flags[*]} --resume $sid" >> "$HOME/launches.log"
[ -f "$HOME/fail-$sid" ] && exit 3
status=idle; [ -f "$HOME/busy-$sid" ] && { status=busy; rm -f "$HOME/busy-$sid"; }
exec env -i /usr/bin/perl "$HOME/.local/bin/claude-stub.pl" "$cfg" "$sid" "$PWD" "$HOME/received.log" "$status" "${flags[@]}"
EOF
for a in tester bob; do ln -s x-account "$SB/.local/bin/x-$a"; done

# drive: one batch, run by a driver of no name, its state in $HOME/drive.json;
# every call is logged to $HOME/drive.log.
cat > "$SB/.local/bin/drive" <<'EOF'
#!/usr/bin/python3
import json, os, subprocess, sys
H = os.environ["HOME"]; F = f"{H}/drive.json"
st = json.load(open(F)) if os.path.exists(F) else {"batches": {}, "block_jobs": {}}
a = sys.argv[1:]
open(f"{H}/drive.log", "a").write(" ".join(a) + "\n")
batch = a[a.index("--batch") + 1] if "--batch" in a else None
a = [x for i, x in enumerate(a) if x != "--batch" and (i == 0 or a[i - 1] != "--batch")]
def save(): json.dump(st, open(F, "w"))
if a[:1] == ["watch"] and "--stop-all" in a:
    if os.path.exists(f"{H}/drive-fail-stop"):
        sys.exit("drive: cannot stop the wakes (injected)")
    print("timers run on\nonce Rex's server runs again, run in each batch:")
    for b in st["batches"]:
        print(f"  drive --batch {b} watch --due")
    sys.exit(0)
if a[:1] == ["watch"]:
    print("no session needs its wake armed"); sys.exit(0)
if a[:1] == ["status"] and not batch:
    if not st["batches"]:
        sys.exit("drive: no batch is live")
    for b, v in st["batches"].items():
        print(f"{v['driver'] + ' drives' if v['driver'] else 'a driver of no name drives'} {b}", file=sys.stderr)
    sys.exit(1)
B = st["batches"][batch]
if a[:1] == ["status"]:
    print(json.dumps({"batch": {"name": batch}, "sessions": B["sessions"], "in_flight": []})); sys.exit(0)
if a[:1] == ["read"]:
    s = next((s for s in B["sessions"] if s["label"] == a[1]), None)
    if s:
        print(json.dumps({"session": s["block"], "view": f"{s['label']}@v1", "jobs": s.get("jobs") or []}))
    else:
        print(json.dumps({"session": a[1], "jobs": [{"command": "sleep"}] if st["block_jobs"].get(a[1]) else []}))
    sys.exit(0)
if a[:1] == ["open"]:
    label, opt = a[1], dict(zip(a[2::2], a[3::2]))
    acct = os.environ["HEADROOM_PRIMARY_NAME"] if opt["--account"] == "primary" else opt["--account"]
    r = subprocess.run(["rex", "--autostart=false", "run", "-s", B["rex_session"], "--focus=false", "--json", "--label", label,
                        "-c", opt["--dir"], "--shell", "none", "--", f"{H}/.local/bin/x-{acct}", "--resume", opt["--resume"]],
                       capture_output=True, text=True)
    if r.returncode:
        sys.exit(r.stderr)
    s = next(s for s in B["sessions"] if s["label"] == label)
    s["block"], s["state"], s["jobs"] = json.loads(r.stdout)["block_ids"][0][-6:], "done", []
    save(); sys.exit(0)
if a[:1] == ["send"]:
    sys.exit(0)
sys.exit(f"drive stub: {a}")
EOF
chmod +x "$SB/.local/bin/rex" "$SB/.local/bin/x-account" "$SB/.local/bin/drive"

plist_set "$REX_UPGRADE_APP" CFBundleVersion=100

# The feed: build 200 is the newest; the staging fixtures add their own.
feed() {  # feed "BUILD URL LENGTH [MINOS]"...
    { echo '<?xml version="1.0"?><rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel>'
      for item in "$@"; do set -- $item
        echo "<item><sparkle:version>$1</sparkle:version>${4:+<sparkle:minimumSystemVersion>$4</sparkle:minimumSystemVersion>}"
        echo "<description><![CDATA[Preview $1

Rex 0.0.$1-gbbbbbb]]></description><pubDate>Thu, 29 Oct 2026</pubDate><enclosure url=\"$2\" length=\"$3\"/></item>"
      done
      echo '</channel></rss>'; } > "$SB/appcast.xml"
}
feed "150 file:///nonexistent/150.dmg 1" "200 file:///nonexistent/200.dmg 1"

"$BIN/rex" server start >/dev/null 2>&1
if ! in_sandbox; then echo "the scratch server is not in the sandbox; stopping before any case"; exit 1; fi

# --- the scratch layout -----------------------------------------------------------

C1=11111111-0000-4000-8000-000000000001; C2=22222222-0000-4000-8000-000000000002
C3=33333333-0000-4000-8000-000000000003; L1=44444444-0000-4000-8000-000000000004
C4=55555555-0000-4000-8000-000000000005
touch "$SB/busy-$C1"
leaf() {  # leaf LABEL CWD [launcher args...]: a layout leaf
    local label=$1 cwd=$2; shift 2
    py "$label" "$cwd" "$@" <<'PY'
import json, sys
label, cwd, cmd = sys.argv[1], sys.argv[2], sys.argv[3:]
opts = {"cwd": cwd}
if cmd:
    opts.update(shell="none", login=False, command=cmd)
print(json.dumps({"block": {"flavor": "com.superlogical.terminal.shell", "label": label, "options": opts}}))
PY
}
split() { echo "{\"split\":{\"direction\":\"$1\",\"ratio\":$2,\"before\":$3,\"after\":$4}}"; }
X="$SB/.local/bin"
WORK=$(split vertical 0.3 "$(leaf a1 "$SB/w1")" "$(split horizontal 0.5 "$(leaf c1 "$SB/w2" "$X/x-tester" --session-id "$C1" --effort high)" "$(leaf a2 "$SB/w3")")")
DRIVEN=$(split horizontal 0.6 "$(leaf L1 "$SB/w1" "$X/x-bob" --session-id "$L1")" "$(leaf side "$SB/w2")")
rex api call session.create "{\"label\":\"alpha\",\"initial_windows\":[{\"window_label\":\"work\",\"layout\":$WORK},{\"window_label\":\"L1\",\"layout\":$DRIVEN}]}" > "$SB/alpha.json"
TWO=$(split horizontal 0.5 "$(leaf other "$SB/w1" /bin/sleep 600)" "$(leaf gone "$SB/gone")")
rex api call session.create "{\"label\":\"beta\",\"initial_windows\":[{\"window_label\":\"one\",\"layout\":$(leaf c2 "$SB/w2" "$X/x-bob" --session-id "$C2")},{\"window_label\":\"two\",\"layout\":$TWO},{\"window_label\":\"auto\",\"layout\":$(leaf autopane "$SB/w3")},{\"window_label\":\"c3\",\"layout\":$(leaf c3 "$SB/w1" "$X/x-tester" --session-id "$C3")},{\"window_label\":\"rep\",\"layout\":$(leaf c4 "$SB/w2" "$X/x-tester" --session-id "$C4")}]}" > "$SB/beta.json"
L1BLOCK=$(js 'd["initial_windows"][1]["block_ids"][0]' < "$SB/alpha.json")
C2BLOCK=$(js 'd["initial_windows"][0]["block_ids"][0]' < "$SB/beta.json")
AUTOWIN=$(js 'd["initial_windows"][2]["window_id"]' < "$SB/beta.json")
mkdir -p "$SB/.local/state/rex-lab"; printf '%s\tauto\n' "$AUTOWIN" > "$SB/.local/state/rex-lab/tab-names"
cat > "$SB/drive.json" <<EOF
{"batches": {"b1": {"driver": null, "rex_session": "alpha", "sessions": [
  {"label": "L1", "block": "${L1BLOCK: -6}", "sid": "$L1", "account": "bob", "state": "working", "watch": "", "jobs": []}]}},
 "block_jobs": {"${C2BLOCK: -6}": true}}
EOF
sleep 2

# Each window as "name: tree", the tree's leaves its pane labels and its splits
# direction and ratio, to one decimal.
layout() {
    rex window ls -s "$1" --json > "$SB/windows.json"
    py "$SB/windows.json" <<'PY'
import json, re, sys
def t(n):
    if "split" in n:
        s = n["split"]
        return f"{s['direction'][0]}{round(s.get('ratio', 0.5), 1)}({t(s['before'])},{t(s['after'])})"
    return labels.get(n["block_id"], "?")
d = json.load(open(sys.argv[1]))
labels = {b["block_id"]: b.get("label") for w in d["windows"] for l in w["layers"] for b in l.get("blocks", [])}
for w in sorted(d["windows"], key=lambda w: int(m.group()) if (m := re.match(r"\d+", w["label"] or "")) else 99):
    lay = [l for l in w["layers"] if l["kind"] == "tiled" and l.get("layout")]
    print(re.sub(r"^\d+\s*", "", w["label"] or "") + ": " + (t(lay[0]["layout"]) if lay else "-"))
PY
}
ALPHA_BEFORE=$(layout alpha); BETA_BEFORE=$(layout beta)

# --- cases ------------------------------------------------------------------------

CASE=U1; if want; then
    out=$("$TOOL" check 2>&1)
    ok "U1 check names the feed's newest build" "feed:    200 (server 0.0.200-gbbbbbb), Thu, 29 Oct 2026" "$(grep '^feed:' <<<"$out")"
    ok "U1 check says to stage it" "next:    rex-upgrade stage, then rex-upgrade start" "$(grep '^next:' <<<"$out")"
    ok "U1 stage refuses a build the feed lacks" "the feed has no build 999" "$("$TOOL" stage 999 2>&1)"
fi

CASE=U2; if want; then
    REAL_BUILD=$(build_of "/Applications/Rex Beta.app")
    dmg() {  # dmg NAME APP...: an image holding the apps
        local name=$1 src="$SB/fx/$1.src"; shift
        mkdir -p "$src"; for a in "$@"; do ditto "$a" "$src/$(basename "$a")"; done
        hdiutil create -quiet -ov -fs HFS+ -format UDRO -srcfolder "$src" "$SB/fx/$name.dmg" && command rm -rf "$src"
    }
    size() { stat -f %z "$SB/fx/$1.dmg"; }
    url() { echo "file://$SB/fx/$1.dmg"; }
    dmg good "/Applications/Rex Beta.app"
    feed "$REAL_BUILD $(url good) $(size good)"
    "$TOOL" stage > "$SB/stage.log" 2>&1
    ok "U2 a signed, notarized image stages" "$REAL_BUILD" "$(build_of "$STAGE/Rex Beta.app")"
    plist_set "$SB/fx/Rex Beta.app" CFBundleVersion=777
    dmg unsigned "$SB/fx/Rex Beta.app"
    mkdir -p "$SB/fx/adhoc/Rex Beta.app/Contents/MacOS"; printf '#!/bin/sh\nexit 0\n' > "$SB/fx/adhoc/Rex Beta.app/Contents/MacOS/Fake"
    chmod +x "$SB/fx/adhoc/Rex Beta.app/Contents/MacOS/Fake"
    plist_set "$SB/fx/adhoc/Rex Beta.app" CFBundleVersion=777 CFBundleExecutable=Fake CFBundleIdentifier=test.rex-upgrade.fake
    codesign -s - --force "$SB/fx/adhoc/Rex Beta.app" 2>/dev/null
    dmg adhoc "$SB/fx/adhoc/Rex Beta.app"
    mkdir -p "$SB/fx/second.app/Contents"; cp "$SB/fx/Rex Beta.app/Contents/Info.plist" "$SB/fx/second.app/Contents/"
    dmg two "$SB/fx/Rex Beta.app" "$SB/fx/second.app"
    stage_says() { feed "$1"; "$TOOL" stage 2>&1 | tail -1; }
    ok "U2 a short download is refused" "downloaded $(size unsigned) bytes, the feed says 5" "$(stage_says "777 $(url unsigned) 5")"
    ok "U2 an image of another build is refused" "the image holds build 777, not 778" "$(stage_says "778 $(url unsigned) $(size unsigned)")"
    ok "U2 an image of two apps is refused" "the image holds 2 apps, not one" "$(stage_says "777 $(url two) $(size two)")"
    ok "U2 a build for a newer macOS is refused" "build 777 needs macOS 99.0" "$(stage_says "777 $(url unsigned) $(size unsigned) 99.0")"
    ok "U2 an unsigned app is refused" "its code signature does not verify" "$(stage_says "777 $(url unsigned) $(size unsigned)" | cut -d: -f1)"
    ok "U2 an app Gatekeeper refuses is refused" "Gatekeeper refuses it" "$(stage_says "777 $(url adhoc) $(size adhoc)" | cut -d: -f1)"
    ok "U2 a refused image leaves the staged build" "$REAL_BUILD" "$(build_of "$STAGE/Rex Beta.app")"
    ok "U2 no download is left behind" "stage" "$(ls "$SB/.local/state/rex-lab/upgrades")"
    command rm -rf "$STAGE"
    feed "150 file:///nonexistent/150.dmg 1" "200 file:///nonexistent/200.dmg 1"
fi

CASE=U3; if want; then
    "$TOOL" snapshot "$SB/pre" >/dev/null 2>&1
    ok "U3 restore refuses to run inside Rex" "run this from outside Rex" \
        "$(REX_BLOCK=block:x "$TOOL" restore --go "$SB/pre/snapshot.json" 2>&1 | grep -o 'run this from outside Rex')"
    ok "U3 restore refuses the server the snapshot was taken on" \
        "this is still the server the snapshot was taken on; restart it first" \
        "$("$TOOL" restore --go "$SB/pre/snapshot.json" 2>&1 | grep 'still the server')"
fi

CASE=U8; if want; then
    before=$(instance)
    echo "block ls" > "$SB/rex-fail"
    "$TOOL" job "$SB/.local/state/rex-lab/upgrades/fail1" --now > "$SB/fail1.log" 2>&1; code=$?
    command rm -f "$SB/rex-fail"
    ok "U8 a failed snapshot read stops the job" "1 yes" "$code $(has "$SB/fail1.log" 'STOPPED before touching anything: the snapshot failed')"
    touch "$SB/drive-fail-stop"
    "$TOOL" job "$SB/.local/state/rex-lab/upgrades/fail2" --now > "$SB/fail2.log" 2>&1; code=$?
    command rm -f "$SB/drive-fail-stop"
    ok "U8 a failed wake stop stops the job" "1 yes" "$code $(has "$SB/fail2.log" 'STOPPED before touching anything: drive could not stop')"
    ok "U8 neither touched the server" "$before" "$(instance)"
fi

CASE=U4; if want; then
    before=$(instance)
    mkdir -p "$STAGE"; plist_set "$STAGE/Rex Beta.app" CFBundleVersion=200
    touch "$SB/fail-$C3"; rmdir "$SB/gone"
    : > "$SB/launches.log"; : > "$SB/drive.log"
    "$TOOL" job "$SB/.local/state/rex-lab/upgrades/run1" --now --report "$C4" > "$SB/run1.log" 2>&1; code=$?
    R="$SB/.local/state/rex-lab/upgrades/run1/restore.log"
    ok "U4 the job ends with problems, and says so" "1 done, with problems" "$code $(tail -1 "$SB/run1.log" | cut -c10- | cut -d: -f1)"
    ok "U4 the server is a new instance" "yes" "$([ -n "$(instance)" ] && [ "$(instance)" != "$before" ] && echo yes || echo no)"
    ok "U4 alpha's windows come back with their layouts" "$ALPHA_BEFORE" "$(layout alpha)"
    ok "U4 beta's windows come back, the name rexd gave left to rexd" \
        "$(sed 's/^auto:/autopane:/' <<<"$BETA_BEFORE")" "$(layout beta | sed 's/^Window [0-9a-f]*:/autopane:/')"
    ok "U4 a conversation resumes on its account with its flags" "x-tester --effort high --resume $C1" "$(grep "resume $C1" "$SB/launches.log" | tail -1)"
    ok "U4 another account's conversation resumes on it" "x-bob  --resume $C2" "$(grep "resume $C2" "$SB/launches.log" | tail -1)"
    ok "U4 drive reopens the driven pane in its batch" "yes" "$(has "$SB/drive.log" "^--batch b1 open L1 --dir $SB/w1 --resume $L1 --account bob")"
    ok "U4 the session that was mid-turn gets the continue line" "yes" "$(has "$SB/received.log" "^$C1	Rex restarted and ended this session mid-turn")"
    ok "U4 the driven session that was working gets it through drive" "yes" "$(has "$SB/drive.log" '^--batch b1 send L1@v1 Rex restarted')"
    ok "U4 an idle session whose background jobs died gets the continue line" "yes" "$(has "$SB/received.log" "^$C2	Rex restarted")"
    ok "U4 the session that ran start is asked to report, not to continue" "yes no" \
        "$(has "$SB/received.log" "^$C4	rex-upgrade ran while this session was stopped") $(has "$SB/received.log" "^$C4	Rex restarted")"
    ok "U4 a conversation that does not come back is named" "yes" "$(has "$R" "conversation ${C3:0:8} did not come back")"
    ok "U4 a pane whose folder is gone is named" "yes" "$(has "$R" "pane gone ran in .*/gone, which is gone")"
    ok "U4 a pane that ran another program is named" "yes" "$(has "$R" "pane other ran '/bin/sleep 600'")"
    ok "U4 the staged app replaced the app, the old one kept" "200 100" \
        "$(build_of "$REX_UPGRADE_APP") $(build_of "$SB/.local/state/rex-lab/upgrades/run1/old/Rex Beta.app")"
    ok "U4 drive's wakes are armed again" "yes" "$(has "$SB/drive.log" '^--batch b1 watch --due')"
    command rm -f "$SB/fail-$C3"; mkdir -p "$SB/gone"
fi

CASE=U5; if want; then
    windows() { for s in alpha beta; do rex window ls -s $s --json | js 'len(d["windows"])'; done | tr '\n' ' '; }
    before=$(windows)
    "$TOOL" restore --go "$SB/.local/state/rex-lab/upgrades/run1/snapshot.json" > "$SB/rerun.log" 2>&1
    ok "U5 a second restore rebuilds nothing twice" "$before" "$(windows)"
    ok "U5 it says each tab is back already" "7" "$(grep -c 'restored already' "$SB/rerun.log")"
fi

CASE=U6; if want; then
    "$BIN/rexd" stop >/dev/null 2>&1
    for _ in 1 2 3 4; do REX_SESSION= "$BIN/rexd" >/dev/null 2>&1 & done
    wait; sleep 1
    ok "U6 four rexd starts at once leave one" "1" "$("$BIN/rexd" status | grep -c '^rexd runs in\|^session:')"
    "$BIN/rexd" stop >/dev/null 2>&1
    # What a start that died leaves: a lock its holder no longer holds, and the aged
    # lock directory rexd once took instead.
    lockf -k "$SB/.local/state/rex-lab/rexd.lock" sleep 30 & holder=$!
    sleep 0.5; kill -9 $holder 2>/dev/null; wait $holder 2>/dev/null
    mkdir -p "$SB/.local/state/rex-lab/rexd.starting"; touch -t 202601010000 "$SB/.local/state/rex-lab/rexd.starting"
    for _ in 1 2 3 4; do REX_SESSION= "$BIN/rexd" >/dev/null 2>&1 & done
    wait; sleep 1
    ok "U6 a start that died leaves no lock behind" "1" "$("$BIN/rexd" status | grep -c '^rexd runs in\|^session:')"
fi

CASE=U7; if want; then
    before="$(instance) $(layout alpha)"
    mkdir -p "$STAGE"; plist_set "$STAGE/Rex Beta.app" CFBundleVersion=300
    out=$("$TOOL" start --dry-run 2>&1)
    plist=$(ls -t "$SB"/.local/state/rex-lab/upgrades/*/job.plist 2>/dev/null | head -1)
    ok "U7 the dry run writes the job and starts nothing" "dry run" "$(tail -1 <<<"$out" | cut -c1-7)"
    ok "U7 the dry run leaves the server and its panes" "$before" "$(instance) $(layout alpha)"
    ok "U7 the plan names the swap" "yes" "$(grep -q -- '-> 300' <<<"$out" && echo yes || echo no)"
    ok "U7 the plan creates alpha from its layout" "yes" "$(grep -q 'api call session.create .{"label": "alpha"' <<<"$out" && echo yes || echo no)"
    ok "U7 the plan reopens the driven pane through drive" "yes" "$(grep -q 'drive --batch b1 open L1' <<<"$out" && echo yes || echo no)"
    ok "U7 the job runs the tool's job in its run directory, under this HOME" "job $(dirname "$plist") $SB" \
        "$(py "$plist" <<'PY'
import plistlib, sys
p = plistlib.load(open(sys.argv[1], "rb")); print(p["ProgramArguments"][2], p["ProgramArguments"][3], p["EnvironmentVariables"]["HOME"])
PY
)"
    command rm -rf "$STAGE"
fi

CASE=U10; if want; then
    before=$(instance)
    reg=$(ls -t $(grep -l "$C1" "$SB"/.claude/sessions/*.json) | head -1)  # a killed stub's file stays behind
    sed -i '' 's/"status":"idle"/"status":"busy"/' "$reg"
    "$TOOL" job "$SB/.local/state/rex-lab/upgrades/quiet" > "$SB/quiet.log" 2>&1 & job=$!
    sleep 3
    ok "U10 the job waits while a session works" "$before" "$(instance)"
    sed -i '' 's/"status":"busy"/"status":"idle"/' "$reg"
    wait $job
    ok "U10 it goes on once the session is idle" "yes" "$(has "$SB/quiet.log" 'done: every session came back')"
fi

CASE=U11; if want; then
    D=$(mktemp -d); cat > "$D/busy.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>Label</key><string>$REX_UPGRADE_LABEL</string>
<key>ProgramArguments</key><array><string>/bin/sleep</string><string>20</string></array><key>RunAtLoad</key><true/></dict></plist>
EOF
    launchctl bootstrap "gui/$(id -u)" "$D/busy.plist"; sleep 0.5
    ok "U11 start refuses while a job runs" "a rex-upgrade job runs already" "$("$TOOL" start 2>&1 | cut -d: -f1)"
    launchctl bootout "gui/$(id -u)/$REX_UPGRADE_LABEL" 2>/dev/null; command rm -rf "$D"
    before=$(instance)
    "$TOOL" start --now > "$SB/start.log" 2>&1
    log=$(sed -n 's/^started; follow it with: tail -f //p' "$SB/start.log")
    for _ in $(seq 120); do grep -q '^.\{9\}done' "$log" 2>/dev/null && break; sleep 0.5; done
    ok "U11 launchd runs the job to the end" "yes" "$(has "$log" 'done: every session came back')"
    ok "U11 the job restarted the scratch server" "yes" "$([ "$(instance)" != "$before" ] && echo yes || echo no)"
fi

CASE=U9; if want; then
    H="$REX_UPGRADE_APP/Contents/Helpers/Rex Server.rex/Contents/MacOS"; mkdir -p "$H"
    printf '#!/bin/sh\n[ "$1" = version ] && { echo "rex 9.9.9-gfake"; exit 0; }\nexec "%s" "$@"\n' "$BIN/rex" > "$H/rex"; chmod +x "$H/rex"
    "$TOOL" job "$SB/.local/state/rex-lab/upgrades/wrong" --now > "$SB/wrong.log" 2>&1; code=$?
    ok "U9 a server of another build is refused" "1 yes yes" \
        "$code $(has "$SB/wrong.log" 'runs 0.0.[0-9]*-g[0-9a-f]*, not 9.9.9-gfake') $(has "$SB/wrong.log" 'GAVE UP')"
    command rm -rf "$REX_UPGRADE_APP/Contents/Helpers"
    # The check for a tool shell's NO_COLOR in the new server has no case: from build
    # 1497, rex server start passes the server only PATH, HOME, SHELL, the locale and
    # the like, so no start here can carry it.
fi

CASE=U12; if want; then
    ok "U12 the live server is untouched" "$LIVE_BEFORE" "$(live_server)"
    ok "U12 the real upgrades directory is untouched" "$UPGRADES_BEFORE" "$(ls "$REAL_HOME/.local/state/rex-lab/upgrades" 2>/dev/null)"
    # The live machine's own bots arm wakes while this runs, so the guard looks only for
    # the sandbox's batch in drive's real state.
    ok "U12 drive's real state holds nothing of the sandbox's batch" "" \
        "$(ls "$REAL_HOME/.local/state/drive/watches" "$REAL_HOME/.local/state/drive/batches" 2>/dev/null | grep -x 'b1\|drive-b1-.*')"
fi

echo "rex-upgrade: $PASS passed, $FAIL failed${FAILED:+ ($FAILED )}"
[ "$FAIL" -eq 0 ]
