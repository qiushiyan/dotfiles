#!/usr/bin/env bash
# test-rex-chip.sh — the Claude status chip of a Rex pane: what a statusline
# render puts in the pane header, what takes it away, and the floating chip's
# line (rex/.local/bin/rex-chip, claude/.claude/commands/statusline-rex.sh).
#
# Usage: bash test-rex-chip.sh [K1 K4 ...]     # requires jq
#
# What this pins. A render in a Rex pane sets the block's label to the account's
# full email, the model and effort behind an icon, the quota windows and a context bar, with
# no mark on a calm value (K1) and a mark and a bar colour that follow 50% and
# 90% (K2). An unchanged render calls Rex no more, and a changed one once (K3):
# the render runs three times a second. Fields leave a narrow pane lowest
# priority first, a quota at its alarm stays, and context always shows (K4).
# The pane's own name leads the chip, a rename through rex-chip keeps both, and
# the name comes back when the chip goes (K5). The statusline's own line is one
# row that leaves the account and the cache to the header, only when the header
# has them (K6). SessionEnd,
# through rex-agent as the hook runs it, clears the chip, and a pane that wears
# none starts nothing (K7). A block that is gone takes its state with it (K8).
# The floating chip's line has the border's fields and colours, right-aligned,
# sheds fields in a float too narrow for them, and the float ends by itself
# when there is no session (K9). The prompt cache's minutes sit before context,
# marked in the last ten and when cold, and a cache that warns stays on a
# narrow pane (K10). A float sized just after it starts paints once, at its
# real width, and a later resize repaints at once, not at the next tick (K11).
# Nothing here
# reaches the live state or the live server (Z1).
#
# ISOLATION. A throwaway HOME holds the state directory and a stub `rex` that
# records each call and keeps the block's label in a file; rex-chip reaches Rex
# only through $HOME/.local/bin/rex, so the stub is the only server there is.
# The statusline and the tools are the working tree's. REX_*, TMUX*, CLAUDE_PID
# and XDG_STATE_HOME are stripped from every command, the quota refresher is
# off (CLAUDE_CTX_REFRESH_CMD=), and the hook in K7 runs under script(1), whose
# pty takes the OSC 7501 report rex-agent writes.

set -uo pipefail
unset CLAUDE_PID

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../../../.." && pwd)"
STATUSLINE="$REPO/claude/.claude/commands/statusline-command.sh"
CHIP="$REPO/rex/.local/bin/rex-chip"
AGENT="$REPO/rex/.local/bin/rex-agent"
PASS=0; FAIL=0; FAILED=""

command -v jq >/dev/null || { echo "rex-chip: skipped, needs jq"; exit 0; }

SANDBOX=$(mktemp -d /tmp/rex-chip-test.XXXXXX)
case "$SANDBOX" in /tmp/rex-chip-test.?*) ;; *) echo "bad sandbox [$SANDBOX]"; exit 1 ;; esac
SANDBOX=$(cd "$SANDBOX" && pwd -P)
H="$SANDBOX/home"
STATE="$H/.local/state/rex-lab/chip"
cleanup() { [ -n "${KEEP:-}" ] && { echo "kept $SANDBOX"; return; }; rm -rf "$SANDBOX"; }
trap cleanup EXIT

# The live state directory. Sessions running on this machine write their own
# blocks' files there while the suite runs, so Z1 looks for this suite's
# blocks, which no live server has.
REAL_STATE="$HOME/.local/state/rex-lab/chip"
real_state() { ls "$REAL_STATE"/block_t1.* "$REAL_STATE"/block_none.* 2>/dev/null; }
REAL_AT_START=$(real_state)

mkdir -p "$H/.local/bin" "$H/work"
ln -s "$CHIP" "$H/.local/bin/rex-chip"
# The stub server: one block, whose label lives in $SANDBOX/label. A file
# $SANDBOX/gone makes every label change fail, as for a closed block.
cat > "$H/.local/bin/rex" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >> "$SANDBOX/rex.log"
while [ \$# -gt 0 ] && [ "\$1" != call ]; do shift; done
case "\${2:-}" in
  session.list_blocks)
    jq -nc --arg l "\$(cat "$SANDBOX/label")" '{blocks: [{block_id: "block:t1", label: \$l}]}' ;;
  session.set_block_label)
    [ -e "$SANDBOX/gone" ] && exit 1
    jq -rj '.label' <<< "\$3" > "$SANDBOX/label"; echo '{"revision":1}' ;;
esac
STUB
chmod +x "$H/.local/bin/rex"

ok() {  # ok <name> <expected> <actual>
  if [ "$2" = "$3" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); FAILED="$FAILED ${1%% *}"; printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"; fi
}
want() { [ ${#ONLY[@]} -eq 0 ] && return 0; case " ${ONLY[*]} " in *" $CASE "*) return 0;; esac; return 1; }
ONLY=("$@")

CLEAN=(env -u REX_SERVER -u REX_SESSION -u REX_BLOCK -u REX_BIN_DIR -u TMUX -u TMUX_PANE -u CLAUDE_PID
  -u CLAUDE_CONFIG_DIR -u XDG_STATE_HOME -u COLUMNS -u ANTHROPIC_BASE_URL -u REX_CHIP_CMD)
IN_REX=(HOME="$H" REX_BLOCK=block:t1 REX_SESSION=session:t LC_ALL=en_US.UTF-8)

# fresh [LABEL]: a block with no chip, labelled LABEL ("shell" by default).
fresh() {
  rm -rf "$H/.local/state" "$H/.cache" "$H/.claude.json" "$SANDBOX/gone"
  : > "$SANDBOX/rex.log"
  printf '%s' "${1:-shell}" > "$SANDBOX/label"
  printf '{"oauthAccount":{"emailAddress":"yan@planlab.ai"}}' > "$H/.claude.json"
}
label() { cat "$SANDBOX/label"; }
chars() { printf '%s' "$1" | LC_ALL=en_US.UTF-8 wc -m | tr -d ' '; }   # awk counts bytes here
sets() { grep -c 'session.set_block_label' "$SANDBOX/rex.log"; }
chip() { "${CLEAN[@]}" "${IN_REX[@]}" /bin/bash "$CHIP" "$@"; }

# weekly PCT MODEL: the model-scoped weekly, as the quota refresher leaves it.
weekly() {
  mkdir -p "$H/.cache/claude-ctx"
  printf '%s yan@planlab.ai %s %s %s 9999999999\n' "$(date +%s)" "$1" "$2" "$(date +%s)" \
    > "$H/.cache/claude-ctx/yan@planlab.ai.quota"
}

# render CTX FIVE SEVEN [COLS] [VAR=value ...]: one statusline render in the
# Rex pane, with CTX percent of context used; prints the line, colours
# stripped and rows joined by " ⏎ ". Then waits for the label rex-chip sets
# detached: until rex has been called and has been quiet for a moment.
# CACHE, when set, is the prompt cache: minutes left, or "cold".
render() {
  local ctx=$1 five=$2 seven=$3 cols=${4:-200}; shift $(( $# < 4 ? $# : 4 ))
  local windows="" extra="" before n
  case "${CACHE:-}" in
    "") ;;
    cold) extra=',"prompt_cache":{"warm":false,"expires_at":1}' ;;
    *) extra=$(printf ',"prompt_cache":{"warm":true,"expires_at":%s}' "$(( $(date +%s) + CACHE * 60 - 30 ))") ;;
  esac
  [ -n "$five" ] && windows=$(printf '"five_hour":{"used_percentage":%s,"resets_at":9999999999}' "$five")
  [ -n "$seven" ] && windows="${windows:+$windows,}$(printf '"seven_day":{"used_percentage":%s,"resets_at":9999999999}' "$seven")"
  [ -n "$windows" ] && extra="$extra,\"rate_limits\":{$windows}"
  before=$(wc -l < "$SANDBOX/rex.log")
  printf '{"session_id":"sid-K","model":{"id":"claude-fable-5-2"},"effort":{"level":"xhigh"},"workspace":{"current_dir":"%s"},"context_window":{"context_window_size":1000000,"current_usage":{"input_tokens":%s,"output_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}%s}' \
      "$H/work" "$((ctx * 10000))" "$extra" |
    "${CLEAN[@]}" "${IN_REX[@]}" COLUMNS="$cols" TERMINAL_THEME=gruber_darker CLAUDE_CTX_REFRESH_CMD= \
      REX_CHIP_CMD="$CHIP" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 "$@" bash "$STATUSLINE" 2>/dev/null |
    sed $'s/\033\\[[0-9;]*m//g' | awk 'NR > 1 { printf " ⏎ " } { printf "%s", $0 }'
  for _ in $(seq 30); do
    n=$(wc -l < "$SANDBOX/rex.log")
    [ "$n" -gt "$before" ] && { sleep 0.25; [ "$(wc -l < "$SANDBOX/rex.log")" = "$n" ] && break; }
    sleep 0.1
  done
}

CASE=K1; if want; then
  fresh; weekly 4 opus
  CACHE=43 render 31 12 30 >/dev/null
  ok "K1 a render sets the header: full email, model:effort, calm quotas bare, the cache, a bar" \
    "yan@planlab.ai · 💠 fable-5-2:xhigh · 5h 12% · 7d 30% · wk opus 4% · ⏳ cache 43m · 🟩🟩🟩⬜⬜⬜⬜⬜⬜⬜ 31%" "$(label)"
  ok "K1 the state is the sandbox's" "block_t1.base block_t1.chip block_t1.label block_t1.width" "$(ls "$STATE" | tr '\n' ' ' | sed 's/ $//')"
  ok "K1 the label fits Rex's 128 characters" "1" "$([ "$(chars "$(label)")" -le 128 ] && echo 1)"
fi

CASE=K2; if want; then
  fresh
  render 71 93 58 >/dev/null
  ok "K2 a quota at 90 and one at 50 wear their marks, and the bar turns yellow" \
    "yan@planlab.ai · 💠 fable-5-2:xhigh · 🔴 5h 93% · 🟡 7d 58% · 🟨🟨🟨🟨🟨🟨🟨⬜⬜⬜ 71%" "$(label)"
  render 95 49 '' >/dev/null
  ok "K2 context at 90 is a red bar, and an absent window is not drawn" \
    "yan@planlab.ai · 💠 fable-5-2:xhigh · 5h 49% · 🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥 95%" "$(label)"
  render 2 '' '' >/dev/null
  ok "K2 any context at all fills one cell" "yan@planlab.ai · 💠 fable-5-2:xhigh · 🟩⬜⬜⬜⬜⬜⬜⬜⬜⬜ 2%" "$(label)"
fi

CASE=K3; if want; then
  fresh
  render 31 12 30 >/dev/null; first=$(sets)
  render 31 12 30 >/dev/null; sleep 0.5
  ok "K3 the first render sets the label once" "1" "$first"
  ok "K3 an unchanged render calls Rex no more" "$(wc -l < "$SANDBOX/rex.log" | tr -d ' ')" "2"
  render 32 12 30 >/dev/null
  ok "K3 a changed value sets it once more" "2" "$(sets)"
fi

CASE=K4; if want; then
  fresh; weekly 4 opus
  render 31 12 30 100 >/dev/null
  ok "K4 under 110 columns the model's weekly leaves" \
    "yan@planlab.ai · 💠 fable-5-2:xhigh · 5h 12% · 7d 30% · 🟩🟩🟩⬜⬜⬜⬜⬜⬜⬜ 31%" "$(label)"
  render 31 12 30 60 >/dev/null
  ok "K4 under 70 the quota pair leaves and the bar halves" "yan@planlab.ai · 💠 fable-5-2:xhigh · 🟩🟩⬜⬜⬜ 31%" "$(label)"
  render 31 93 30 60 >/dev/null
  ok "K4 a quota at its alarm stays on a narrow pane" "yan@planlab.ai · 💠 fable-5-2:xhigh · 🔴 5h 93% · 🟩🟩⬜⬜⬜ 31%" "$(label)"
  render 31 12 30 45 >/dev/null
  ok "K4 under 50 the model leaves" "yan@planlab.ai · 🟩🟩⬜⬜⬜ 31%" "$(label)"
  render 31 12 30 30 >/dev/null
  ok "K4 under 36 the account leaves and context stays" "🟩🟩⬜⬜⬜ 31%" "$(label)"
fi

CASE=K5; if want; then
  fresh "api server"
  render 31 '' '' >/dev/null
  ok "K5 the pane's own name leads the chip" "api server · yan@planlab.ai · 💠 fable-5-2:xhigh · 🟩🟩🟩⬜⬜⬜⬜⬜⬜⬜ 31%" "$(label)"
  chip rename block:t1 "worker"
  ok "K5 a rename through rex-chip keeps the chip" "worker · yan@planlab.ai · 💠 fable-5-2:xhigh · 🟩🟩🟩⬜⬜⬜⬜⬜⬜⬜ 31%" "$(label)"
  chip clear block:t1
  ok "K5 clear gives the pane its name back" "worker" "$(label)"
  ok "K5 and leaves no state" "" "$(ls "$STATE" 2>/dev/null)"
  fresh
  render 31 '' '' >/dev/null; chip clear block:t1
  ok "K5 an unnamed pane goes back to shell" "shell" "$(label)"
  ok "K5 rename without a chip is refused, for rex-label to set the label itself" "1" "$(chip rename block:t1 x; echo $?)"
fi

CASE=K6; if want; then
  fresh
  ok "K6 in a Rex pane the line is one row, without the account or the cache" "work | 31%" \
    "$(CACHE=43 render 31 12 30 | sed "s|^$H/||")"
  ok "K6 the billing mark joins that row" "work | 31% | API" \
    "$(CACHE=43 render 31 12 30 200 ANTHROPIC_BASE_URL=http://proxy.invalid | sed "s|^$H/||")"
  fresh
  ok "K6 with the header chip off the line keeps its second row" "work | 31% ⏎ yan | cache 43m" \
    "$(CACHE=43 render 31 12 30 200 REX_CHIP_CMD= | sed "s|^$H/||")"
  ok "K6 and nothing is published" "" "$(ls "$STATE" 2>/dev/null)$(cat "$SANDBOX/rex.log")"
  ok "K6 outside Rex the line keeps its second row" "work | 31% ⏎ yan | cache 43m" \
    "$(CACHE=43 render 31 12 30 200 REX_BLOCK= | sed "s|^$H/||")"
fi

# hook JSON: one Claude Code hook through rex-agent, as settings.json runs it.
hook() {
  printf '%s' "$1" > "$SANDBOX/in.json"
  "${CLEAN[@]}" "${IN_REX[@]}" script -q "$SANDBOX/tty" /bin/bash -c "'$AGENT' claude < '$SANDBOX/in.json'" < /dev/null >/dev/null 2>&1
  sleep 0.6   # the clear runs in the background
}

CASE=K7; if want; then
  fresh "api server"
  render 31 12 30 >/dev/null
  hook '{"hook_event_name":"SessionEnd","session_id":"sid-K","reason":"prompt_input_exit","cwd":"/tmp/x"}'
  ok "K7 SessionEnd gives the header back" "api server" "$(label)"
  ok "K7 and removes the state" "" "$(ls "$STATE" 2>/dev/null)"
  : > "$SANDBOX/rex.log"
  hook '{"hook_event_name":"SessionEnd","session_id":"sid-K","reason":"other","cwd":"/tmp/x"}'
  ok "K7 a pane that wears no chip starts nothing" "" "$(cat "$SANDBOX/rex.log")"
fi

CASE=K8; if want; then
  fresh
  : > "$SANDBOX/gone"
  render 31 12 30 >/dev/null
  ok "K8 a block that is gone takes its state with it" "" "$(ls "$STATE" 2>/dev/null)"
fi

CASE=K9; if want; then
  fresh; weekly 4 opus
  render 31 12 58 >/dev/null
  line=$(chip render block:t1 80)
  ok "K9 the floating chip has the border's fields" \
    "yan@planlab.ai  fable-5-2:xhigh  5h:12  7d:58  opus:4  ✳ 31%" "$(printf '%s' "$line" | sed $'s/\033\\[[0-9;]*m//g; s/^ *//')"
  ok "K9 a calm quota is cyan and one past 50 yellow" "1" \
    "$(printf '%s' "$line" | grep -c $'\033\\[36m5h:12\033\\[0m  \033\\[33m7d:58')"
  ok "K9 right-aligned in a wider float, one column from its edge" "79" \
    "$(chars "$(printf '%s' "$line" | sed $'s/\033\\[[0-9;]*m//g')")"
  ok "K9 its width is kept for the layer" "60" "$(cat "$STATE/block_t1.width")"
  ok "K9 a float too narrow for every field sheds the weekly, then the quotas, and keeps context" \
    "yan@planlab.ai  fable-5-2:xhigh  5h:12  7d:58  ✳ 31% | yan@planlab.ai  fable-5-2:xhigh  ✳ 31% | ✳ 31%" \
    "$(for w in 55 40 12; do chip render block:t1 $w | sed $'s/\033\\[[0-9;]*m//g; s/^ *//'; done | paste -sd'|' - | sed 's/|/ | /g')"
  out=$(chip draw block:none 2>/dev/null); rc=$?
  ok "K9 with no session the float says so and ends" "0 1" "$rc $(printf '%s' "$out" | grep -c 'no Claude Code session')"
fi

CASE=K10; if want; then
  fresh
  CACHE=9 render 31 '' '' >/dev/null
  ok "K10 a cache in its last ten minutes is marked" "yan@planlab.ai · 💠 fable-5-2:xhigh · 🟡 cache 9m · 🟩🟩🟩⬜⬜⬜⬜⬜⬜⬜ 31%" "$(label)"
  CACHE=cold render 31 '' '' >/dev/null
  ok "K10 a cold cache is marked red" "yan@planlab.ai · 💠 fable-5-2:xhigh · 🔴 cache cold · 🟩🟩🟩⬜⬜⬜⬜⬜⬜⬜ 31%" "$(label)"
  ok "K10 the floating chip draws it red too" "1" "$(chip render block:t1 80 | grep -c $'\033\\[31mcache cold')"
  CACHE=43 render 31 '' '' 45 >/dev/null
  ok "K10 under 50 columns a calm cache leaves" "yan@planlab.ai · 🟩🟩⬜⬜⬜ 31%" "$(label)"
  CACHE=9 render 31 '' '' 30 >/dev/null
  ok "K10 a cache that warns stays on the narrowest pane" "🟡 cache 9m · 🟩🟩⬜⬜⬜ 31%" "$(label)"
  render 31 '' '' >/dev/null
  ok "K10 a session that reports no cache draws none" "yan@planlab.ai · 💠 fable-5-2:xhigh · 🟩🟩🟩⬜⬜⬜⬜⬜⬜⬜ 31%" "$(label)"
fi

# The float on a pty of its own (chip-resize.py): 80 columns as it starts, 55
# a tenth of a second later, as the app sizes a new layer, then 70. It prints
# the paints of the first 0.9 s and the width the last was laid out for, then
# whether the second resize was painted within 0.4 s and that paint's width.
CASE=K11; if want; then
  fresh
  render 31 12 58 >/dev/null
  ok "K11 a float sized as it starts paints once at its real width, and a resize repaints at once" "1 55 fast 70" \
    "$("${CLEAN[@]}" "${IN_REX[@]}" /usr/bin/python3 "$HERE/chip-resize.py" "$CHIP" block:t1)"
fi

CASE=Z1; if want; then
  ok "Z1 the live state directory holds nothing of this suite's blocks" "" "$REAL_AT_START$(real_state)"
  ok "Z1 no real path in the stub's log" "0" "$(grep -c "$HOME/" "$SANDBOX/rex.log" 2>/dev/null | head -1)"
fi

echo "rex-chip: $PASS passed, $FAIL failed${FAILED:+ —$FAILED}"
[ "$FAIL" = 0 ]
