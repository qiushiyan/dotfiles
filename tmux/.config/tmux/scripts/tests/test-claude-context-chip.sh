#!/usr/bin/env bash
# test-claude-context-chip.sh — the pinned traps for the Claude context chip:
# what Claude's statusline publishes onto a pane border, and what tears it down.
#
# The chip has no user-visible failure alarm — a stale model id or a chip that
# stopped updating looks exactly like a correct one, and the two halves that
# can break it are both easy to break silently: the SERVER-side compare-and-set
# gate at the tail of statusline-command.sh (which must accept a real change
# and refuse a no-op, three times a second, per live session) and the unset
# list in tmux-claude-ctx.sh's drop_branch (which must retire every option it
# publishes). Each case below says which of those it holds down.
#
# Runs entirely on a throwaway socket, against the WORKING TREE's scripts —
# never the live server, never the stowed copies. Usage:
#   bash test-claude-context-chip.sh [C1 C5 ...]

set -uo pipefail

SOCK="ctxtest-$$"

# The working tree these tests belong to, not $HOME: a suite that reached the
# stowed copies would grade whatever is installed instead of the branch it was
# run from, and pass over a change that was never applied.
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/../../../../.." && pwd)
STATUSLINE="$REPO/claude/.claude/commands/statusline-command.sh"
CTX="$REPO/tmux/.config/tmux/scripts/tmux-claude-ctx.sh"
CONF="$REPO/tmux/.config/tmux/tmux.conf"

PASS=0; FAIL=0; FAILED=""
T() { tmux -L "$SOCK" "$@"; }

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/ctx-chip-test.XXXXXX")
SANDBOX_RESURRECT="$SANDBOX/resurrect"
# A HOME of our own. Both scripts under test resolve a sibling through
# $HOME/.config/tmux/scripts — the statusline's backgrounded `reconcile` call
# most of all — so the override is what keeps this suite on the working tree;
# the symlink is the only thing in it, which also means the statusline finds no
# ~/.config/terminal-theme and takes $TERMINAL_THEME, off the user's live one.
SANDBOX_HOME="$SANDBOX/home"
mkdir -p "$SANDBOX_RESURRECT" "$SANDBOX_HOME/.config/tmux"
ln -s "$REPO/tmux/.config/tmux/scripts" "$SANDBOX_HOME/.config/tmux/scripts"

cleanup() {
    T kill-server 2>/dev/null
    [ -n "${SANDBOX:-}" ] && rm -rf "$SANDBOX"
}
trap cleanup EXIT

fresh() {
    T kill-server 2>/dev/null; sleep 0.2
    # The pane runs `sleep`, NOT a shell. An interactive zsh here sources the
    # user's rc, which installs the production precmd sweep — the one that
    # clears a chip whenever a prompt returns, on the reasoning that a live
    # Claude would be holding the foreground. In a test pane that reasoning is
    # false and the sweep is a second writer: it wipes what the case just
    # published, from inside the pane, at whatever moment zsh finishes loading.
    # That raced invisibly against every case here and cost a debugging pass.
    # A pane occupied by a non-shell process is also the truthful model of the
    # thing under test — a pane with Claude running in it.
    T -f "$CONF" new-session -d -s t -x 200 -y 50 'sleep 100000' 2>/dev/null
    # new-session RETURNING is not the server being ready — the config is still
    # loading behind it, plugins included. A pane id read too early comes back
    # EMPTY, and an empty id doesn't fail: every later command targets nothing,
    # no-ops, and the case's assertions compare one empty string to another. A
    # fixed sleep hid that and lost the race on a cold checkout, so poll for the
    # pane and refuse to run the case without one.
    PANE=""; WIN=""; SOCKPATH=""
    for _ in $(seq 1 50); do
        PANE=$(T list-panes -t t -F '#{pane_id}' 2>/dev/null | head -1)
        [ -n "$PANE" ] && break
        sleep 0.2
    done
    WIN=$(T display -p -t t '#{window_id}' 2>/dev/null)
    SOCKPATH=$(T display -p '#{socket_path}' 2>/dev/null)
    if [ -z "$PANE" ] || [ -z "$WIN" ] || [ -z "$SOCKPATH" ]; then
        no "harness: the test server never came up" \
           "pane=[$PANE] win=[$WIN] socket=[$SOCKPATH] — the case did not run"
        return 1
    fi
    # Same trap the pane-control suite documents: resurrect's save directory is
    # one shared path unless told otherwise, so a throwaway server that reaches
    # the real save.sh overwrites the user's snapshot.
    T set -g @resurrect-dir "$SANDBOX_RESURRECT" 2>/dev/null
}

# Publish one statusline render: pub <sid> <model-id|-> <input-tokens> [acct].
# "-" means a payload carrying no model key at all, which is not the same as an
# empty one. The optional 4th arg is the lane: an account DIR NAME (an email)
# for a managed extra, or an absolute PATH to drive CLAUDE_CONFIG_DIR straight
# — the unmanaged escape hatch, and the explicit ~/.claude spelling of the
# primary. The statusline learns the account from CLAUDE_CONFIG_DIR, not from
# the payload, so it arrives via env — and when absent it is explicitly UNSET,
# because this suite itself runs inside a Claude session that carries the real
# variable; inheriting it would make the primary-lane cases pass on a path
# mismatch instead of on absence. Everything the scripts touch is pinned to the
# test server ($TMUX, the socket the scripts resolve tmux through — without it
# they fall through to the DEFAULT socket, the user's live server, where these
# pane ids don't exist and every assertion below would pass for the wrong
# reason) and to the sandbox HOME.
# A 5th arg is the payload's rate_limits.five_hour percentage — the vendor's
# own 5-hour figure, which reaches the chip straight off this document. Absent
# means a payload with no rate_limits key at all, which is a real state (API
# billing has no subscription limits) and not the same as a zero.
pub() {
    local sid="$1" model="$2" tokens="$3" acct="${4:-}" five="${5:-}" payload rl=""
    [ -n "$five" ] && rl=$(printf ',"rate_limits":{"five_hour":{"used_percentage":%s,"resets_at":9999999999}}' "$five")
    if [ "$model" = "-" ]; then
        payload=$(printf '{"session_id":"%s","workspace":{"current_dir":"%s"},"context_window":{"context_window_size":1000000,"current_usage":{"input_tokens":%s,"output_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}%s}' "$sid" "$SANDBOX" "$tokens" "$rl")
    else
        payload=$(printf '{"session_id":"%s","model":{"id":"%s"},"workspace":{"current_dir":"%s"},"context_window":{"context_window_size":1000000,"current_usage":{"input_tokens":%s,"output_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}%s}' "$sid" "$model" "$SANDBOX" "$tokens" "$rl")
    fi
    local -a acct_env
    case "$acct" in
        "")  acct_env=(-u CLAUDE_CONFIG_DIR) ;;
        /*)  acct_env=(CLAUDE_CONFIG_DIR="$acct") ;;
        *)   acct_env=(CLAUDE_CONFIG_DIR="$SANDBOX_HOME/.claude-accounts/$acct") ;;
    esac
    # CLAUDE_CTX_REFRESH_CMD set-but-empty: no quota refresher is spawned. It
    # would run the REAL headroom against the REAL accounts root and the
    # network, and write the user's live ~/.cache — the C9 guard catches that,
    # and it caught it once for real. C22 is where the spawn itself is tested,
    # by pointing this at a stub instead of clearing it.
    printf '%s' "$payload" | env "${acct_env[@]}" HOME="$SANDBOX_HOME" TERMINAL_THEME=flexoki_light \
        CLAUDE_CTX_REFRESH_CMD="${REFRESH_CMD-}" \
        TMUX="$SOCKPATH,0,0" TMUX_PANE="$PANE" bash "$STATUSLINE" >/dev/null 2>&1
    sleep 0.4   # the accepted branch reconciles the border in the background
}

# A SessionEnd hook firing for <sid>. NO explicit pane argument, matching the
# production wiring in settings.json exactly: the hooks pass nothing and the
# verbs resolve the pane from $TMUX_PANE — a helper that also passed the pane
# would keep these cases green while a broken fallback left production inert.
ends() {
    printf '{"session_id":"%s"}' "$1" | env HOME="$SANDBOX_HOME" \
        TMUX="$SOCKPATH,0,0" TMUX_PANE="$PANE" bash "$CTX" clear-session
    sleep 0.4
}

# A SessionStart hook firing for <sid> — the activation that discharges the
# pane's tombstone, and the ONLY thing that does. Same rule: no pane argument.
starts() {
    printf '{"session_id":"%s","source":"resume"}' "$1" | env HOME="$SANDBOX_HOME" \
        TMUX="$SOCKPATH,0,0" TMUX_PANE="$PANE" bash "$CTX" activate-session
    sleep 0.3
}

# The primary account's login file, at the vendor's path: $HOME/.claude.json,
# directly in HOME and NOT inside ~/.claude. It is the primary's only source of
# an email — it has no account dir to be named by — so a case that wants a
# labeled primary lane must lay one down. Cases create it and delete it before
# they end, keeping C9's "nothing in the sandbox HOME" guard meaningful under
# any run order.
primary_login() {
    printf '{"oauthAccount":{"emailAddress":"%s"}}' "$1" > "$SANDBOX_HOME/.claude.json"
}

opt()    { T show -pqv -t "$PANE" "$1"; }
status() { T show -wv -t "$WIN" pane-border-status 2>/dev/null; }
# What the border actually draws, styles stripped. Only "#[...]" is a style —
# the sanitizer strips the leading # from anything hostile in a model id, so a
# bracket that survives here is content, and visible as such.
border() {
    T display-message -p -t "$PANE" "$(T show -gv pane-border-format)" \
        | sed 's/#\[[^]]*\]//g'
}

ok()   { PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
no()   { FAIL=$((FAIL+1)); FAILED="$FAILED $2"; printf '  \033[31mFAIL\033[0m %s\n       %s\n' "$1" "$2"; }
check(){ [ "$2" = "$3" ] && ok "$1" || no "$1" "expected [$3] got [$2]"; }
want() { case " ${WANT:-} " in *" $1 "*) return 0;; esac; [ -z "${WANT:-}" ]; }

# ---------------------------------------------------------------------------
# C1 — a render publishes both halves and lights the border. The model is
# drawn LEFT of the percentage and carries no "claude-" prefix; the percentage
# keeps its own value, which is the field-alignment check on the positional
# read that parses both out of one jq call.
# ---------------------------------------------------------------------------
c1() {
    fresh || return
    pub sid-A 'claude-opus-5[1m]' 600000
    check "C1 percentage published"   "$(opt @claude_ctx)"       "60"
    check "C1 model published trimmed" "$(opt @claude_ctx_model)" "opus-5[1m]"
    check "C1 owner recorded"         "$(opt @claude_ctx_sid)"    "sid-A"
    # No ~/.claude.json in this sandbox, so the primary has no email to read:
    # the label is absent because it is UNKNOWN here, which is the degraded
    # case, not the primary's normal one. C19 covers the normal one.
    check "C1 a primary with no readable login shows no account" \
        "$(opt @claude_ctx_account)" ""
    check "C1 border row on"          "$(status)"                 "top"
    check "C1 border draws model then percentage" "$(border)" " opus-5[1m] ✳ 60% "
}

# ---------------------------------------------------------------------------
# C2 — a /model switch mid-session repaints. Percentage and session id are
# BOTH unchanged here, so the model is the only thing that can carry the write
# past the gate: this is the case that fails if the gate's model arm is
# dropped, mis-nested, or compares against the wrong option. The border row is
# forced off first so an accepted write proves itself by the reconcile it
# queues, not merely by the value it leaves behind.
# ---------------------------------------------------------------------------
c2() {
    fresh || return
    pub sid-A 'claude-opus-5[1m]' 600000
    T set -w -t "$WIN" pane-border-status off
    pub sid-A 'claude-fable-5' 600000
    check "C2 model updated on a model-only change" "$(opt @claude_ctx_model)" "fable-5"
    check "C2 percentage untouched"                 "$(opt @claude_ctx)"       "60"
    check "C2 accepted write reconciled the border" "$(status)"                "top"
    check "C2 border redrawn"                       "$(border)"                " fable-5 ✳ 60% "
}

# ---------------------------------------------------------------------------
# C3 — the other half of the gate, and the reason it exists: an UNCHANGED
# triple must write nothing. set-option costs redraw and layout work even when
# the value is identical, and this runs ~3×/sec per streaming session, so a
# gate that always accepts is a performance regression with no visible symptom.
# Forcing the row off makes the no-op observable: a write would reconcile it
# back on, so "still off" is the assertion that nothing ran.
# ---------------------------------------------------------------------------
c3() {
    fresh || return
    pub sid-A 'claude-opus-5[1m]' 600000
    T set -w -t "$WIN" pane-border-status off
    pub sid-A 'claude-opus-5[1m]' 600000
    check "C3 unchanged triple published nothing" "$(status)"                "off"
    check "C3 values still intact"                "$(opt @claude_ctx_model)" "opus-5[1m]"
}

# ---------------------------------------------------------------------------
# C4 — a payload with no model at all still gets a chip. The percentage alone
# is what "chip shown" means, so the model must degrade to nothing rather than
# to a placeholder, and the border must not keep a separator or a stray space
# where it would have been.
# ---------------------------------------------------------------------------
c4() {
    fresh || return
    pub sid-A - 950000
    check "C4 percentage published"      "$(opt @claude_ctx)"       "95"
    check "C4 model empty, not a sentinel" "$(opt @claude_ctx_model)" ""
    check "C4 border row on"             "$(status)"                "top"
    check "C4 border shows the number alone" "$(border)"            " ✳ 95% "
}

# ---------------------------------------------------------------------------
# C5 — a model id is untrusted text on two paths at once: it is interpolated
# into a tmux FORMAT string and into a single-quoted set-option inside an
# if-shell command string, and it is one whitespace-separated field of a
# positional read. A quote or a comma could end a command early; a space would
# shift every field after it and corrupt the percentage; a "#[" would inject a
# style into the border. All three are the same defense — the jq scrub — so
# one hostile id tests it end to end.
# ---------------------------------------------------------------------------
c5() {
    fresh || return
    pub sid-A "claude-x y, #[fg=red]'; kill-server" 500000
    check "C5 server survived"          "$(T list-sessions -F '#{session_name}' 2>/dev/null | head -1)" "t"
    check "C5 id reduced to one inert token" "$(opt @claude_ctx_model)" "xy[fgred]kill-server"
    check "C5 percentage not corrupted"  "$(opt @claude_ctx)"       "50"
    check "C5 no style injected on the border" "$(border)" " xy[fgred]kill-server ✳ 50% "
}

# ---------------------------------------------------------------------------
# C6 — SessionEnd also fires on /resume switches, where a SUCCESSOR session
# may already own the pane. A dying session must not clear the chip its
# successor just published — including its model, which is the new option this
# check now has to protect too.
# ---------------------------------------------------------------------------
c6() {
    fresh || return
    pub sid-B 'claude-fable-5' 300000
    ends sid-A
    check "C6 stale SessionEnd left the percentage" "$(opt @claude_ctx)"       "30"
    check "C6 stale SessionEnd left the model"      "$(opt @claude_ctx_model)" "fable-5"
    check "C6 stale SessionEnd left the owner"      "$(opt @claude_ctx_sid)"   "sid-B"
    check "C6 border still up"                      "$(status)"                "top"
}

# ---------------------------------------------------------------------------
# C7 — the owner's SessionEnd retires EVERY option it published. A model left
# behind is the specific silent failure: the border row goes down, so nothing
# looks wrong, and the stale id surfaces on the next session to land in this
# pane — wearing the previous session's model.
# ---------------------------------------------------------------------------
c7() {
    fresh || return
    pub sid-A 'claude-opus-5[1m]' 600000 'yan@planlab.ai'
    check "C7 account was set before the end" "$(opt @claude_ctx_account)" "yan"
    ends sid-A
    check "C7 percentage unset"       "$(opt @claude_ctx)"       ""
    check "C7 model unset"            "$(opt @claude_ctx_model)" ""
    check "C7 account unset"          "$(opt @claude_ctx_account)" ""
    check "C7 owner unset"            "$(opt @claude_ctx_sid)"   ""
    check "C7 session tombstoned"     "$(opt @claude_ctx_dead)"  "sid-A"
    check "C7 border row dropped"     "$(status)"                ""
    check "C7 border draws nothing"   "$(border)"                ""
}

# ---------------------------------------------------------------------------
# C8 — the hard-kill race. A statusline subprocess can outlive the Claude it
# belonged to and publish AFTER cleanup ran; the tombstone must refuse it, and
# refuse the model with it. A NEW session in the same pane must still publish
# freely, model included — otherwise the pane is poisoned for its successor.
# ---------------------------------------------------------------------------
c8() {
    fresh || return
    pub sid-A 'claude-opus-5[1m]' 600000
    ends sid-A
    pub sid-A 'claude-opus-5[1m]' 610000
    check "C8 tombstoned session cannot republish"       "$(opt @claude_ctx)"       ""
    check "C8 tombstoned session cannot republish model" "$(opt @claude_ctx_model)" ""
    pub sid-B 'claude-fable-5' 200000 'muji@example.com'
    check "C8 a new session publishes"       "$(opt @claude_ctx)"       "20"
    check "C8 a new session publishes model" "$(opt @claude_ctx_model)" "fable-5"
    check "C8 a new session brings its own account" "$(opt @claude_ctx_account)" "muji"
    check "C8 border back up"                "$(status)"                "top"
}

# ---------------------------------------------------------------------------
# C9 — the isolation guard (see docs/testing.md). Two silent escapes to close:
# a case that forgets $TMUX drives the user's LIVE server, where these pane ids
# don't exist so everything no-ops and the suite passes green having tested
# nothing; and a case that forgets the HOME override grades the stowed copies
# instead of this working tree. Both are invisible in a passing run, so they
# get asserted rather than assumed.
# ---------------------------------------------------------------------------
c9() {
    fresh || return
    pub sid-guard 'claude-opus-5[1m]' 600000

    check "C9 the suite ran against its own socket" \
        "$(basename "$SOCKPATH")" "$SOCK"

    # Nothing this suite published may appear on the default socket. No live
    # server at all is a pass, not an error.
    leaked=$(tmux list-panes -a -F '#{@claude_ctx_sid}' 2>/dev/null | grep -c '^sid-guard$' || true)
    check "C9 the live server carries none of our sessions" "$leaked" "0"

    # The scripts must have been reached through the sandbox HOME, so the code
    # under test is this tree's.
    check "C9 sandbox HOME points at the working tree" \
        "$(readlink "$SANDBOX_HOME/.config/tmux/scripts")" \
        "$REPO/tmux/.config/tmux/scripts"

    # And the sandbox HOME stays a shell: anything written into it means a
    # script wrote to $HOME on a path this suite exercises.
    check "C9 nothing was written into the sandbox HOME" \
        "$(find "$SANDBOX_HOME" -mindepth 1 -not -path "$SANDBOX_HOME/.config" \
            -not -path "$SANDBOX_HOME/.config/tmux" \
            -not -path "$SANDBOX_HOME/.config/tmux/scripts" | wc -l | tr -d ' ')" "0"
}

# ---------------------------------------------------------------------------
# C10 — the account lane. It reaches the statusline through CLAUDE_CONFIG_DIR
# (headroom's launch contract), not the payload: an extra account's email dir
# becomes its local part, drawn left of the model. A second session on a
# DIFFERENT account taking over the pane must swap the label with no teardown
# in between. A hostile dir name rides the same two paths as a hostile
# model id (format string, quoted set-option) and must come out inert.
# ---------------------------------------------------------------------------
c10() {
    fresh || return
    pub sid-A 'claude-opus-5[1m]' 600000 'yan@planlab.ai'
    check "C10 account published as the local part" "$(opt @claude_ctx_account)" "yan"
    check "C10 border draws account, model, percentage" "$(border)" " yan opus-5[1m] ✳ 60% "
    pub sid-B 'claude-fable-5' 500000 "e vil'#[fg=red]@x.com"
    check "C10 server survived a hostile account" \
        "$(T list-sessions -F '#{session_name}' 2>/dev/null | head -1)" "t"
    check "C10 new owner swapped the account without teardown" \
        "$(opt @claude_ctx_account)" "evilfgred"
    check "C10 percentage not corrupted" "$(opt @claude_ctx)" "50"
    check "C10 no style injected on the border" "$(border)" " evilfgred fable-5 ✳ 50% "
}

# ---------------------------------------------------------------------------
# C11 — the chip sheds by priority as the pane narrows: account below 55
# columns, model below 40, the percentage never. Pure display — the options
# underneath must survive every threshold crossing untouched, so widening the
# pane restores the full chip without a republish. This is the case that
# fails if a width gate is dropped (labels crowd a narrow pane), inverted, or
# written with tmux's STRING comparisons instead of arithmetic e|>=.
# ---------------------------------------------------------------------------
c11() {
    fresh || return
    pub sid-A 'claude-opus-5[1m]' 600000 'yan@planlab.ai'
    check "C11 a wide pane affords all three" "$(border)" " yan opus-5[1m] ✳ 60% "
    T resize-window -t t -x 48 2>/dev/null; sleep 0.2
    check "C11 below 55 columns the account yields first" "$(border)" " opus-5[1m] ✳ 60% "
    T resize-window -t t -x 35 2>/dev/null; sleep 0.2
    check "C11 below 40 columns the model yields too" "$(border)" " ✳ 60% "
    T resize-window -t t -x 200 2>/dev/null; sleep 0.2
    check "C11 widening restores the full chip" "$(border)" " yan opus-5[1m] ✳ 60% "
    check "C11 hiding never touched the options" "$(opt @claude_ctx_account)" "yan"
}

# ---------------------------------------------------------------------------
# C12 — the live-upgrade state. This repo is stowed live configuration: a pane
# whose chip was published by the PREVIOUS statusline (no account option yet)
# is a normal state right after an upgrade, not a hypothetical. If its
# percentage, owner and model then hold steady, the render must still backfill
# the missing account — and having backfilled once, fall quiescent again: an
# arm that keeps accepting identical renders is the 3×/sec write regression C3
# exists to prevent, just wearing a new option.
# ---------------------------------------------------------------------------
c12() {
    fresh || return
    # What the pre-account publisher left behind: three options, no account.
    T set -p -t "$PANE" @claude_ctx 60
    T set -p -t "$PANE" @claude_ctx_sid sid-A
    T set -p -t "$PANE" @claude_ctx_model 'opus-5[1m]'
    pub sid-A 'claude-opus-5[1m]' 600000 'yan@planlab.ai'
    check "C12 unchanged triple still backfills the account" \
        "$(opt @claude_ctx_account)" "yan"
    check "C12 the rest untouched" "$(opt @claude_ctx)" "60"
    T set -w -t "$WIN" pane-border-status off
    pub sid-A 'claude-opus-5[1m]' 600000 'yan@planlab.ai'
    check "C12 backfilled once, quiescent after" "$(status)" "off"
}

# ---------------------------------------------------------------------------
# C13 — two accounts sharing a local part. The house policy already lives in
# claude.zsh: a short name is minted only while the local part is UNIQUE among
# account dirs, because two lanes wearing the same label defeats the point of
# labeling lanes. The chip follows the same policy from the same registry (the
# dirs): unique local part → short label, collision → the full email. The
# fixture dirs are removed before the case ends so the C9 guard's "nothing in
# the sandbox HOME" stays true on any run order.
# ---------------------------------------------------------------------------
c13() {
    fresh || return
    mkdir -p "$SANDBOX_HOME/.claude-accounts/alex@work.example" \
             "$SANDBOX_HOME/.claude-accounts/alex@personal.example" \
             "$SANDBOX_HOME/.claude-accounts/yan@planlab.ai"
    pub sid-A 'claude-opus-5[1m]' 600000 'alex@work.example'
    check "C13 a colliding local part keeps its full email" \
        "$(opt @claude_ctx_account)" "alex@work.example"
    check "C13 border draws the full email" "$(border)" " alex@work.example opus-5[1m] ✳ 60% "
    pub sid-B 'claude-fable-5' 600000 'yan@planlab.ai'
    check "C13 a unique local part stays short" \
        "$(opt @claude_ctx_account)" "yan"
    # Uniqueness must be judged on the DISPLAYED form: the scrub deletes "+",
    # so these two raw local parts are distinct on disk but identical on the
    # border. Comparing raw parts calls both unique and draws one label for
    # two lanes — the exact failure the collision policy exists to prevent.
    mkdir -p "$SANDBOX_HOME/.claude-accounts/alex+work@one.example" \
             "$SANDBOX_HOME/.claude-accounts/alexwork@two.example"
    pub sid-C 'claude-fable-5' 600000 'alex+work@one.example'
    check "C13 a post-scrub collision keeps its full email" \
        "$(opt @claude_ctx_account)" "alexwork@one.example"
    pub sid-D 'claude-fable-5' 600000 'alexwork@two.example'
    check "C13 both sides of the post-scrub collision stay distinct" \
        "$(opt @claude_ctx_account)" "alexwork@two.example"
    rm -rf "$SANDBOX_HOME/.claude-accounts"
}

# ---------------------------------------------------------------------------
# C14 — the tombstone is an activation barrier, not a permanent verdict.
# Claude KEEPS the session id across --resume, so "refuse this id forever"
# poisons the same conversation resumed in the same pane hours later — the
# chip never returns and nothing looks broken (found live, pane %70,
# 2026-08-04). SessionStart discharges the tombstone; the barrier holds from
# teardown until exactly that activation.
# ---------------------------------------------------------------------------
c14() {
    fresh || return
    pub sid-A 'claude-opus-5[1m]' 600000 'yan@planlab.ai'
    ends sid-A
    pub sid-A 'claude-opus-5[1m]' 600000 'yan@planlab.ai'
    check "C14 before activation the barrier holds" "$(opt @claude_ctx)" ""
    starts sid-A
    check "C14 activation discharged the tombstone" "$(opt @claude_ctx_dead)" ""
    pub sid-A 'claude-opus-5[1m]' 610000 'yan@planlab.ai'
    check "C14 the resumed session publishes again"   "$(opt @claude_ctx)"         "61"
    check "C14 with its model"                        "$(opt @claude_ctx_model)"   "opus-5[1m]"
    check "C14 and its account"                       "$(opt @claude_ctx_account)" "yan"
    check "C14 border back up"                        "$(status)"                  "top"
}

# ---------------------------------------------------------------------------
# C15 — discharge is EXACT-match. An unrelated session starting in the pane
# must not clear a predecessor's tombstone: A hard-killed, B starts, an
# unconditional clear re-arms A's orphan renders — the exact guard C8 exists
# for, silently deleted. B itself was never blocked (dead=A ≠ B), so it needs
# no discharge to publish.
# ---------------------------------------------------------------------------
c15() {
    fresh || return
    pub sid-A 'claude-opus-5[1m]' 600000
    ends sid-A
    starts sid-B
    check "C15 B's start left A's tombstone standing" "$(opt @claude_ctx_dead)" "sid-A"
    pub sid-A 'claude-opus-5[1m]' 620000
    check "C15 A's orphan is still refused" "$(opt @claude_ctx)" ""
    pub sid-B 'claude-fable-5' 200000
    check "C15 B publishes without any discharge" "$(opt @claude_ctx)" "20"
}

# ---------------------------------------------------------------------------
# C16 — switching BACK to a tombstoned conversation while another session
# owns the pane. dead=A alongside chip=B is a legitimate state; discharge
# must not demand an empty pane (that precondition would rebuild the C14 bug
# right here). A's activation removes only dead=A, A's first render takes
# the owner slot from B, and B's late SessionEnd fails its owner check
# against A — the C6 rule, unchanged by activation.
# ---------------------------------------------------------------------------
c16() {
    fresh || return
    pub sid-A 'claude-opus-5[1m]' 600000
    ends sid-A
    pub sid-B 'claude-fable-5' 200000
    check "C16 B owns the pane over A's tombstone" "$(opt @claude_ctx_sid)"  "sid-B"
    check "C16 A's tombstone still standing"       "$(opt @claude_ctx_dead)" "sid-A"
    starts sid-A
    check "C16 activation discharged despite B's chip" "$(opt @claude_ctx_dead)" ""
    pub sid-A 'claude-opus-5[1m]' 700000
    check "C16 A took the pane over" "$(opt @claude_ctx_sid)" "sid-A"
    ends sid-B
    check "C16 B's late end cannot clear A" "$(opt @claude_ctx)" "70"
}

# ---------------------------------------------------------------------------
# C17 — the barrier is pane-local, and it travels with the pane. The move
# happens BETWEEN publication and teardown — the racy order relocation
# actually produces — so teardown must find the chip in the pane's NEW
# window, tombstone it there, and discharge must follow the same pane id.
# Meanwhile ids are machine-global but tombstones are not: the same
# conversation resumed in a DIFFERENT pane publishes freely throughout.
# (The second pane exists before the break because a window's only pane
# cannot be broken out.)
# ---------------------------------------------------------------------------
c17() {
    fresh || return
    PANE1="$PANE"
    pub sid-A 'claude-opus-5[1m]' 600000
    T split-window -t t -d 'sleep 100000' 2>/dev/null
    PANE=$(T list-panes -t t -F '#{pane_id}' 2>/dev/null | grep -v "^$PANE1$" | head -1)
    if [ -z "$PANE" ]; then
        no "C17 harness: no second pane" "split-window produced nothing"; return
    fi
    T break-pane -d -s "$PANE1" 2>/dev/null; sleep 0.3
    PANE2="$PANE"; PANE="$PANE1"
    check "C17 the live chip moved with the pane" "$(opt @claude_ctx)" "60"
    ends sid-A
    check "C17 teardown followed the relocated pane" "$(opt @claude_ctx)"      ""
    check "C17 and tombstoned it there"              "$(opt @claude_ctx_dead)" "sid-A"
    PANE="$PANE2"
    pub sid-A 'claude-opus-5[1m]' 300000
    check "C17 the same id publishes freely in another pane" "$(opt @claude_ctx)" "30"
    PANE="$PANE1"
    check "C17 the relocated pane stays tombstoned" "$(opt @claude_ctx_dead)" "sid-A"
    starts sid-A
    check "C17 discharge follows the pane too" "$(opt @claude_ctx_dead)" ""
    pub sid-A 'claude-opus-5[1m]' 800000
    check "C17 and the chip returns in the new window" "$(opt @claude_ctx)" "80"
}

# ---------------------------------------------------------------------------
# C18 — the wiring is its own assertion: the sandbox can't make the vendor
# fire hooks, so a suite that only tests the verb passes green with the hook
# unwired and the whole fix inert in production. Declarative, straight off
# the repo's settings.json. compact is deliberately NOT an activation — it
# continues the same live process.
# ---------------------------------------------------------------------------
c18() {
    # Search the entries, don't pin a position: callers depend on "a
    # SessionStart entry with the right matcher carries the verb", not on
    # where in the array it sits — a position pin fails on any unrelated
    # hook added above it while proving nothing more.
    check "C18 exactly one SessionStart entry wires activate-session on real starts" \
        "$(jq -r '[(.hooks.SessionStart // [])[]
                   | select(.matcher == "startup|resume|clear|fork"
                            and ([.hooks[]?.command]
                                 | index("bash ~/.config/tmux/scripts/tmux-claude-ctx.sh activate-session")))]
                  | length' "$REPO/claude/.claude/settings.json")" \
        "1"
    check "C18 no SessionStart entry activates on compact" \
        "$(jq -r '[(.hooks.SessionStart // [])[]
                   | select((.matcher // "") | test("compact"))]
                  | length' "$REPO/claude/.claude/settings.json")" \
        "0"
}

# ---------------------------------------------------------------------------
# C19 — the primary gets a label like everyone else. It is the one account
# with no dir to be named by (CLAUDE_CONFIG_DIR is ABSENT for it, by
# headroom's contract), so its email comes from ~/.claude.json instead — and
# that difference in SOURCE must not become a difference in DISPLAY. It used
# to: the primary was the deliberately unmarked lane, which on the account
# that runs most read as a chip that had simply stopped working.
#
# The primary is then a member of the uniqueness registry, not an exception to
# it. Counting claims among the account DIRS alone — the pre-change registry —
# calls both lanes below unique and draws one "qiushi" for two different
# accounts, which is exactly the confusion the collision rule exists to stop.
# ---------------------------------------------------------------------------
c19() {
    fresh || return
    primary_login 'qiushi@planlab.ai'
    pub sid-A 'claude-opus-5[1m]' 600000
    check "C19 the primary publishes its own account" \
        "$(opt @claude_ctx_account)" "qiushi"
    check "C19 border draws it like any other lane" \
        "$(border)" " qiushi opus-5[1m] ✳ 60% "
    mkdir -p "$SANDBOX_HOME/.claude-accounts/qiushi@other.example"
    pub sid-B 'claude-fable-5' 500000
    check "C19 an extra claiming its local part sends the primary to full" \
        "$(opt @claude_ctx_account)" "qiushi@planlab.ai"
    pub sid-C 'claude-fable-5' 400000 'qiushi@other.example'
    check "C19 and the extra with it" \
        "$(opt @claude_ctx_account)" "qiushi@other.example"
    rm -rf "$SANDBOX_HOME/.claude-accounts" "$SANDBOX_HOME/.claude.json"
}

# ---------------------------------------------------------------------------
# C20 — the two CLAUDE_CONFIG_DIR values that are neither a managed extra nor
# an absent variable. Now that "no variable" resolves to a real email rather
# than to nothing, a dir that is merely UNRECOGNISED must not fall down the
# same arm and inherit it: that would print the primary's address over a
# session spending someone else's quota — the one wrong answer available here,
# and one nothing else on the border would contradict. It wears its own
# basename instead. The mirror case is the explicit spelling of the default
# dir, which IS the primary and has to resolve as such.
# ---------------------------------------------------------------------------
c20() {
    fresh || return
    primary_login 'qiushi@planlab.ai'
    pub sid-A 'claude-opus-5[1m]' 600000 "$SANDBOX/unmanaged"
    check "C20 an unmanaged config dir wears its own name" \
        "$(opt @claude_ctx_account)" "unmanaged"
    pub sid-B 'claude-fable-5' 500000 "$SANDBOX_HOME/.claude"
    check "C20 an explicit ~/.claude is the primary lane" \
        "$(opt @claude_ctx_account)" "qiushi"
    rm -f "$SANDBOX_HOME/.claude.json"
}

# Lay down the line claude-quota-refresh.sh would have left for a lane, with
# every instant expressed RELATIVE TO NOW so a case says what it means:
#   quota <lane> <attempted-ago> <percent> <model> <observed-ago> <resets-in|->
# A negative resets-in is a window that has already ended.
quota() {
    local lane="$1" at_ago="$2" pct="$3" model="$4" obs_ago="$5" res_in="$6" now res obs
    now=$(date +%s)
    res="-"; [ "$res_in" != "-" ] && res=$((now + res_in))
    obs="-"; [ "$obs_ago" != "-" ] && obs=$((now - obs_ago))
    mkdir -p "$SANDBOX_HOME/.cache/claude-ctx"
    printf '%s %s %s %s %s %s\n' "$((now - at_ago))" "$lane" "$pct" "$model" "$obs" "$res" \
        > "$SANDBOX_HOME/.cache/claude-ctx/$lane.quota"
}

# ---------------------------------------------------------------------------
# C21 — the two quota numbers. The 5-hour figure rides in on Claude Code's own
# payload; the model-scoped weekly comes off the cache file, and the whole
# question there is WHEN AN OLD READING IS STILL AN ANSWER. Inside a live
# window usage only climbs, so an aged figure understates and is safe to draw;
# once the window has ended the same figure describes a window nobody is
# spending against, and a low number there reads as headroom that may not
# exist. So the reset instant decides — age only stands in when the vendor
# left the reset null. Every rejection empties the pair rather than drawing a
# zero: a 0 on the border is indistinguishable from free quota.
# ---------------------------------------------------------------------------
c21() {
    fresh || return
    local lane=lane@x.test
    mkdir -p "$SANDBOX_HOME/.claude-accounts/$lane"

    quota "$lane" 10 51 Fable 60 3600
    pub sid-A 'claude-opus-5[1m]' 370000 "$lane" 23.5
    check "C21 the scoped weekly is published" "$(opt @claude_ctx_wk)" "51"
    check "C21 with the model it is scoped to" "$(opt @claude_ctx_wk_model)" "Fable"
    # 23.5 rounds, and it must arrive as a bare integer: the border feeds it to
    # e|/ for the severity colour, which is integer arithmetic.
    check "C21 the 5-hour figure is rounded off the payload" "$(opt @claude_ctx_5h)" "24"

    # A payload with no rate_limits at all — API billing. The weekly, which
    # comes from somewhere else entirely, must be untouched by that.
    pub sid-A 'claude-opus-5[1m]' 380000 "$lane"
    check "C21 no rate_limits leaves the 5-hour empty" "$(opt @claude_ctx_5h)" ""
    check "C21 and does not disturb the weekly" "$(opt @claude_ctx_wk)" "51"

    # The window ended a minute ago.
    quota "$lane" 10 51 Fable 60 -60
    pub sid-A 'claude-opus-5[1m]' 390000 "$lane" 5
    check "C21 a rolled-over window is not drawn" "$(opt @claude_ctx_wk)" ""
    check "C21 and takes its model label with it" "$(opt @claude_ctx_wk_model)" ""
    check "C21 while the 5-hour figure is unaffected" "$(opt @claude_ctx_5h)" "5"

    # No reset instant to judge by: age is the only evidence, and the cutoff
    # sits far past the refresh cadence, so it only fires when refreshing has
    # actually stopped working.
    quota "$lane" 10 62 Fable 60 -
    pub sid-A 'claude-opus-5[1m]' 400000 "$lane" 5
    check "C21 a null reset falls back to a fresh observation" "$(opt @claude_ctx_wk)" "62"
    quota "$lane" 10 62 Fable 7200 -
    pub sid-A 'claude-opus-5[1m]' 410000 "$lane" 5
    check "C21 a null reset with a stale observation is dropped" "$(opt @claude_ctx_wk)" ""

    # A line written for someone else. The filename is sanitized, so two lanes
    # differing only in stripped characters can land on one file — showing one
    # account's quota under another's name is the failure this rejects.
    quota "$lane" 10 77 Fable 60 3600
    sed -i '' "s/$lane/other@x.test/" "$SANDBOX_HOME/.cache/claude-ctx/$lane.quota"
    pub sid-A 'claude-opus-5[1m]' 420000 "$lane" 5
    check "C21 a line naming another lane is refused" "$(opt @claude_ctx_wk)" ""

    # Whatever the refresher could not read comes through as "-", never 0.
    quota "$lane" 10 - - 60 3600
    pub sid-A 'claude-opus-5[1m]' 430000 "$lane" 5
    check "C21 an unreadable percentage draws nothing" "$(opt @claude_ctx_wk)" ""
    quota "$lane" 10 44 - 60 3600
    pub sid-A 'claude-opus-5[1m]' 440000 "$lane" 5
    check "C21 a number with no model label draws nothing" "$(opt @claude_ctx_wk)" ""

    rm -rf "$SANDBOX_HOME/.claude-accounts" "$SANDBOX_HOME/.cache"
}

# ---------------------------------------------------------------------------
# C22 — the refresher trigger. The render path must never WAIT on headroom, and
# a window full of panes must not spawn one refresher per pane per render, so
# the trigger is throttled on the last ATTEMPT and suppressed while a sibling
# holds the lock. Both are invisible when they break — the chip keeps working
# and the machine just does more work — so they are asserted against a stub
# standing in for the real refresher.
# ---------------------------------------------------------------------------
c22() {
    fresh || return
    local lane=lane@x.test
    mkdir -p "$SANDBOX_HOME/.claude-accounts/$lane" "$SANDBOX_HOME/.cache/claude-ctx"
    local stub="$SANDBOX/refresh-stub.sh" marker="$SANDBOX/refreshed"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$1" >> "%s"\n' "$marker" > "$stub"
    chmod +x "$stub"
    rm -f "$marker"
    REFRESH_CMD="$stub"
    # How many refreshers were spawned. An absent marker is ZERO, said out
    # loud: `wc -l` on a missing file errors and prints nothing, which would
    # compare equal to an expected "" and pass the suppression cases without
    # counting anything at all.
    spawns() { if [ -e "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }

    # No cache file at all: the lane has never been asked about.
    pub sid-A 'claude-opus-5[1m]' 370000 "$lane" 5
    check "C22 a cold lane triggers a refresh" \
        "$(head -1 "$marker" 2>/dev/null)" "$lane"

    # A recent attempt, even one that learned nothing, holds the trigger off.
    rm -f "$marker"
    quota "$lane" 10 - - - -
    pub sid-B 'claude-opus-5[1m]' 380000 "$lane" 5
    check "C22 a recent attempt suppresses the next" "$(spawns "$marker")" "0"

    # Stale enough to re-arm, but a sibling pane is already inside a refresh.
    rm -f "$marker"
    quota "$lane" 400 51 Fable 400 3600
    mkdir -p "$SANDBOX_HOME/.cache/claude-ctx/$lane.lock"
    pub sid-C 'claude-opus-5[1m]' 390000 "$lane" 5
    check "C22 the lock suppresses a duplicate refresher" "$(spawns "$marker")" "0"
    check "C22 and the stale line is still drawn meanwhile" "$(opt @claude_ctx_wk)" "51"

    # Lock gone, still stale: the trigger fires again.
    rmdir "$SANDBOX_HOME/.cache/claude-ctx/$lane.lock"
    pub sid-D 'claude-opus-5[1m]' 400000 "$lane" 5
    check "C22 a stale line with no lock re-arms it" \
        "$(head -1 "$marker" 2>/dev/null)" "$lane"

    unset REFRESH_CMD
    rm -rf "$SANDBOX_HOME/.claude-accounts" "$SANDBOX_HOME/.cache" "$stub" "$marker"
}

WANT="${*:-}"
echo "tmux $(tmux -V) — Claude context chip suite"
for c in c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c11 c12 c13 c14 c15 c16 c17 c18 c19 c20 c21 c22; do
    n=$(echo "$c" | tr 'a-z' 'A-Z')
    want "$n" && { echo "[$n]"; $c; }
done
echo
printf 'passed %d, failed %d%s\n' "$PASS" "$FAIL" "${FAILED:+ ($FAILED)}"
[ "$FAIL" -eq 0 ]
