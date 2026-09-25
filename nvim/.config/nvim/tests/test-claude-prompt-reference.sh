#!/usr/bin/env bash
# Claude Ctrl+G reply reference (docs/claude-prompt-reference.md), driven
# end to end: the working tree's full Neovim config, a fixture Claude config
# dir whose sessions/<pid>.json names THIS script as the claude process, and
# RPC keystrokes. Runs whole: bash test-claude-prompt-reference.sh
#
# Isolation: CLAUDE_CONFIG_DIR, XDG state/cache and the prompt file live in a
# temp dir; TMUX/TMUX_PANE are unset so neither the pane fallback nor the
# path-publishing autocmd can reach the live tmux server. Plugins are read
# from the real ~/.local/share/nvim.

set -u
REPO_NVIM=$(cd "$(dirname "$0")/.." && pwd)
T=$(cd "$(mktemp -d)" && pwd -P) # resolved: nvim reports /private/var, not /var
trap 'rm -rf "$T"' EXIT
FAIL=0

mkdir -p "$T/ccd/sessions" "$T/ccd/projects/-proj" "$T/claude-501" "$T/proj" "$T/cfg" "$T/state" "$T/cache"
ln -s "$REPO_NVIM" "$T/cfg/nvim"
echo "{\"pid\":$$,\"sessionId\":\"sid-1\"}" >"$T/ccd/sessions/$$.json"

# Two replies on the active branch. The second turn has progress text, a tool
# call, a tool result and a meta record (none of which may split the turn); a
# rewound branch off the first reply must not appear.
cat >"$T/ccd/projects/-proj/sid-1.jsonl" <<'EOF'
{"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":"first"}}
{"type":"assistant","uuid":"a1","parentUuid":"u1","message":{"content":[{"type":"text","text":"**Decision 1:** earlier question?"}]}}
{"type":"user","uuid":"x1","parentUuid":"a1","message":{"role":"user","content":"abandoned prompt"}}
{"type":"assistant","uuid":"x2","parentUuid":"x1","message":{"content":[{"type":"text","text":"ABANDONED reply"}]}}
{"type":"user","uuid":"u2","parentUuid":"a1","message":{"role":"user","content":[{"type":"text","text":"go"}]}}
{"type":"assistant","uuid":"a2","parentUuid":"u2","message":{"content":[{"type":"text","text":"Let me look around."}]}}
{"type":"assistant","uuid":"a3","parentUuid":"a2","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{}}]}}
{"type":"user","uuid":"u3","parentUuid":"a3","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":"ok"}]}}
{"type":"user","uuid":"m1","parentUuid":"u3","isMeta":true,"message":{"role":"user","content":"<system-reminder>x</system-reminder>"}}
{"type":"assistant","uuid":"a4","parentUuid":"m1","message":{"content":[{"type":"text","text":"**Decision 2:** newest question?"}]}}
{"type":"user","uuid":"p1","parentUuid":"a4","message":{"role":"user","content":"partial li
EOF

export CLAUDE_CONFIG_DIR="$T/ccd" XDG_CONFIG_HOME="$T/cfg" XDG_STATE_HOME="$T/state" XDG_CACHE_HOME="$T/cache"
unset TMUX TMUX_PANE
SOCK="$T/n.sock"

ok() { echo "ok   $1"; }
bad() { echo "FAIL $1: $2"; FAIL=1; }
R() { nvim --server "$SOCK" --remote-expr "$1" 2>/dev/null; }
keys() { nvim --server "$SOCK" --remote-send "$1"; sleep 0.3; }
ref_text() { R 'join(getbufline(winbufnr(win_getid(1)), 1, "$"), "|")'; }

# Start nvim on $1 as a direct child of this script; wait for its UI to settle.
start() {
  rm -f "$SOCK"
  nvim --headless --listen "$SOCK" "$1" >/dev/null 2>&1 &
  NVIM_PID=$!
  for _ in $(seq 50); do
    [ -S "$SOCK" ] && [ "$(R 'v:vim_did_enter')" = 1 ] && break
    sleep 0.1
  done
  sleep 0.5
}
stop() { kill "$NVIM_PID" 2>/dev/null; wait "$NVIM_PID" 2>/dev/null; }

# R1: a Ctrl+G-shaped file opens the reference on the newest reply's whole
# turn (tool records and meta don't split it), cursor left in the draft.
DRAFT="$T/claude-501/claude-prompt-abc.md"
: >"$DRAFT"
start "$DRAFT"
got=$(ref_text)
[ "$got" = "Let me look around.||**Decision 2:** newest question?" ] && ok R1 || bad R1 "reference shows [$got]"
[ "$(R 'bufname("%")')" = "$DRAFT" ] && ok R1-focus || bad R1-focus "focus on [$(R 'bufname("%")')]"

# R2: history from the draft, final-message toggle from the reference; the
# rewound branch is not a reply.
keys '[r'
got=$(ref_text)
[ "$got" = "**Decision 1:** earlier question?" ] && ok R2-prev || bad R2-prev "[$got]"
keys '[r]r'
[ "$(ref_text)" = "Let me look around.||**Decision 2:** newest question?" ] && ok R2-bounded || bad R2-bounded "[$(ref_text)]"
keys '[R'
[ "$(ref_text)" = "**Decision 1:** earlier question?" ] && ok R2-oldest || bad R2-oldest "[$(ref_text)]"
keys ']R<C-w>tf<C-w>p'
got=$(ref_text)
[ "$got" = "**Decision 2:** newest question?" ] && ok R2-final || bad R2-final "[$got]"

# R3: :wq in the draft ends nvim (Claude is waiting on it) and the file holds
# exactly what was typed.
keys 'i1. yes<Esc>'
printf '1. yes\n' >"$T/expected"
nvim --server "$SOCK" --remote-send ':wq<CR>' 2>/dev/null
for _ in $(seq 30); do kill -0 "$NVIM_PID" 2>/dev/null || break; sleep 0.1; done
if kill -0 "$NVIM_PID" 2>/dev/null; then
  bad R3 "nvim still running after :wq"
  stop
else
  ok R3-exit
fi
cmp -s "$DRAFT" "$T/expected" && ok R3-draft || bad R3-draft "draft is [$(cat "$DRAFT")]"

# R5: closing either window never strands the editor. History keys reopen a
# closed reference; closing the draft window (<C-w>c) leaves the draft on
# screen, not a lone reference Claude would wait behind.
DRAFT2="$T/claude-501/claude-prompt-def.md"
: >"$DRAFT2"
start "$DRAFT2"
keys '<C-w>tq'
keys '[r'
[ "$(R 'len(nvim_list_wins())')" = 2 ] && [ "$(ref_text)" = "**Decision 1:** earlier question?" ] &&
  ok R5-reopen || bad R5-reopen "$(R 'len(nvim_list_wins())') windows, reference [$(ref_text)]"
keys '<C-w>c'
[ "$(R 'len(nvim_list_wins())')" = 1 ] && [ "$(R 'bufname("%")')" = "$DRAFT2" ] &&
  ok R5-draft-close || bad R5-draft-close "$(R 'len(nvim_list_wins())') windows showing [$(R 'bufname("%")')]"
nvim --server "$SOCK" --remote-send ':wq<CR>' 2>/dev/null
for _ in $(seq 30); do kill -0 "$NVIM_PID" 2>/dev/null || break; sleep 0.1; done
kill -0 "$NVIM_PID" 2>/dev/null && { bad R5-exit "nvim still running"; stop; } || ok R5-exit

# R4: an ordinary project file that merely shares the name gets no reference.
start "$T/proj/claude-prompt-notes.md"
[ "$(R 'len(nvim_list_wins())')" = 1 ] && ok R4 || bad R4 "$(R 'len(nvim_list_wins())') windows"
stop

exit $FAIL
