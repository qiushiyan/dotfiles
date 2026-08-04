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
# empty one. The optional 4th arg is an account DIR NAME (an email): the
# statusline learns the account from CLAUDE_CONFIG_DIR, not from the payload,
# so it arrives via env — and when absent it is explicitly UNSET, because this
# suite itself runs inside a Claude session that carries the real variable;
# inheriting it would make "the primary is unmarked" pass on a path mismatch
# instead of on absence. Everything the scripts touch is pinned to the test
# server ($TMUX, the socket the scripts resolve tmux through — without it they
# fall through to the DEFAULT socket, the user's live server, where these pane
# ids don't exist and every assertion below would pass for the wrong reason)
# and to the sandbox HOME.
pub() {
    local sid="$1" model="$2" tokens="$3" acct="${4:-}" payload
    if [ "$model" = "-" ]; then
        payload=$(printf '{"session_id":"%s","workspace":{"current_dir":"%s"},"context_window":{"context_window_size":1000000,"current_usage":{"input_tokens":%s,"output_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}' "$sid" "$SANDBOX" "$tokens")
    else
        payload=$(printf '{"session_id":"%s","model":{"id":"%s"},"workspace":{"current_dir":"%s"},"context_window":{"context_window_size":1000000,"current_usage":{"input_tokens":%s,"output_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}' "$sid" "$model" "$SANDBOX" "$tokens")
    fi
    local -a acct_env
    if [ -n "$acct" ]; then
        acct_env=(CLAUDE_CONFIG_DIR="$SANDBOX_HOME/.claude-accounts/$acct")
    else
        acct_env=(-u CLAUDE_CONFIG_DIR)
    fi
    printf '%s' "$payload" | env "${acct_env[@]}" HOME="$SANDBOX_HOME" TERMINAL_THEME=flexoki_light \
        TMUX="$SOCKPATH,0,0" TMUX_PANE="$PANE" bash "$STATUSLINE" >/dev/null 2>&1
    sleep 0.4   # the accepted branch reconciles the border in the background
}

# A SessionEnd hook firing for <sid>.
ends() {
    printf '{"session_id":"%s"}' "$1" | env HOME="$SANDBOX_HOME" \
        TMUX="$SOCKPATH,0,0" TMUX_PANE="$PANE" bash "$CTX" clear-session "$PANE"
    sleep 0.4
}

# A SessionStart hook firing for <sid> — the activation that discharges the
# pane's tombstone, and the ONLY thing that does.
starts() {
    printf '{"session_id":"%s","source":"resume"}' "$1" | env HOME="$SANDBOX_HOME" \
        TMUX="$SOCKPATH,0,0" TMUX_PANE="$PANE" bash "$CTX" activate-session "$PANE"
    sleep 0.3
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
    check "C1 primary lane unmarked"  "$(opt @claude_ctx_account)" ""
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
# C11 — the chip sheds by priority as the pane narrows: account below 100
# columns, model below 60, the percentage never. Pure display — the options
# underneath must survive every threshold crossing untouched, so widening the
# pane restores the full chip without a republish. This is the case that
# fails if a width gate is dropped (labels crowd a narrow pane), inverted, or
# written with tmux's STRING comparisons instead of arithmetic e|>=.
# ---------------------------------------------------------------------------
c11() {
    fresh || return
    pub sid-A 'claude-opus-5[1m]' 600000 'yan@planlab.ai'
    check "C11 a wide pane affords all three" "$(border)" " yan opus-5[1m] ✳ 60% "
    T resize-window -t t -x 80 2>/dev/null; sleep 0.2
    check "C11 below 100 columns the account yields first" "$(border)" " opus-5[1m] ✳ 60% "
    T resize-window -t t -x 50 2>/dev/null; sleep 0.2
    check "C11 below 60 columns the model yields too" "$(border)" " ✳ 60% "
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
# C17 — the barrier is pane-local, and it travels with the pane. The same
# conversation resumed in a DIFFERENT pane publishes freely while the old
# pane stays tombstoned (ids are machine-global, tombstones are not); and a
# relocated pane keeps its options, so teardown, the barrier, and its
# discharge all follow the pane id through a move.
# ---------------------------------------------------------------------------
c17() {
    fresh || return
    PANE1="$PANE"
    pub sid-A 'claude-opus-5[1m]' 600000
    ends sid-A
    T split-window -t t -d 'sleep 100000' 2>/dev/null
    PANE=$(T list-panes -t t -F '#{pane_id}' 2>/dev/null | grep -v "^$PANE1$" | head -1)
    if [ -z "$PANE" ]; then
        no "C17 harness: no second pane" "split-window produced nothing"; return
    fi
    pub sid-A 'claude-opus-5[1m]' 300000
    check "C17 the same id publishes freely in another pane" "$(opt @claude_ctx)" "30"
    PANE="$PANE1"
    check "C17 the old pane stays tombstoned" "$(opt @claude_ctx_dead)" "sid-A"
    T break-pane -d -s "$PANE1" 2>/dev/null; sleep 0.3
    check "C17 the barrier moved with the pane" "$(opt @claude_ctx_dead)" "sid-A"
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
    check "C18 SessionStart is wired to activate-session" \
        "$(jq -r '(.hooks.SessionStart // [])[0].hooks[0].command // ""' "$REPO/claude/.claude/settings.json")" \
        "bash ~/.config/tmux/scripts/tmux-claude-ctx.sh activate-session"
    check "C18 activation fires on real starts, never compact" \
        "$(jq -r '(.hooks.SessionStart // [])[0].matcher // ""' "$REPO/claude/.claude/settings.json")" \
        "startup|resume|clear|fork"
}

WANT="${*:-}"
echo "tmux $(tmux -V) — Claude context chip suite"
for c in c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c11 c12 c13 c14 c15 c16 c17 c18; do
    n=$(echo "$c" | tr 'a-z' 'A-Z')
    want "$n" && { echo "[$n]"; $c; }
done
echo
printf 'passed %d, failed %d%s\n' "$PASS" "$FAIL" "${FAILED:+ ($FAILED)}"
[ "$FAIL" -eq 0 ]
