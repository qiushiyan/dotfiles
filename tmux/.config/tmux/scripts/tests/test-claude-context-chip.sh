#!/usr/bin/env bash
# test-claude-context-chip.sh — the pinned traps for the agent pane border:
# what Claude's statusline publishes, what tears it down, and which other pane
# owners keep the shared border row alive.
#
# The chip has no user-visible failure alarm — a stale model id or a chip that
# stopped updating looks exactly like a correct one, and the two halves that
# can break it are both easy to break silently: the SERVER-side compare-and-set
# gate the statusline builds with tmux-agent-status.sh's agent_claude_publish
# (which must accept a real change and refuse a no-op, three times a second,
# per live session) and the owner's drop (which must retire every option the
# vocabulary publishes). Each case below says which of those it holds down.
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
CHIP="$REPO/claude/.claude/commands/statusline-chip.sh"
CTX="$REPO/tmux/.config/tmux/scripts/tmux-agent-status.sh"
VOCAB="$REPO/tmux/.config/tmux/scripts/lib/agent-vocab.sh"
COUT="$REPO/zsh/.config/zsh/cout.zsh"
CONF="$REPO/tmux/.config/tmux/tmux.conf"
ZUTIL="$REPO/zsh/.config/zsh/tmux-utils.zsh"

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
# The 5th and 6th args are the payload's rate_limits.five_hour and
# rate_limits.seven_day percentages — the vendor's own account-wide figures,
# which reach the chip straight off this document. Either may be given alone
# (the vendor drops a window once it resets); both absent means a payload with
# no rate_limits key at all, which is a real state (API billing has no
# subscription limits) and not the same as a zero. A 7th arg is effort.level,
# absent when the model takes no effort parameter.
pub() {
    local sid="$1" model="$2" tokens="$3" acct="${4:-}" five="${5:-}" seven="${6:-}" effort="${7:-}"
    local payload extra="" windows=""
    [ -n "$five" ] && windows=$(printf '"five_hour":{"used_percentage":%s,"resets_at":9999999999}' "$five")
    [ -n "$seven" ] && windows="${windows:+$windows,}$(printf '"seven_day":{"used_percentage":%s,"resets_at":9999999999}' "$seven")"
    [ -n "$windows" ] && extra=",\"rate_limits\":{$windows}"
    [ -n "$effort" ] && extra="$extra$(printf ',"effort":{"level":"%s"}' "$effort")"
    if [ "$model" = "-" ]; then
        payload=$(printf '{"session_id":"%s","workspace":{"current_dir":"%s"},"context_window":{"context_window_size":1000000,"current_usage":{"input_tokens":%s,"output_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}%s}' "$sid" "$SANDBOX" "$tokens" "$extra")
    else
        payload=$(printf '{"session_id":"%s","model":{"id":"%s"},"workspace":{"current_dir":"%s"},"context_window":{"context_window_size":1000000,"current_usage":{"input_tokens":%s,"output_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}%s}' "$sid" "$model" "$SANDBOX" "$tokens" "$extra")
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
    printf '%s' "$payload" | env "${acct_env[@]}" HOME="$SANDBOX_HOME" TERMINAL_THEME="${PUB_THEME:-gruber_darker}" \
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
        TMUX="$SOCKPATH,0,0" TMUX_PANE="$PANE" bash "$CTX" clear claude
    sleep 0.4
}

# A SessionStart hook firing for <sid> — the activation that discharges the
# pane's tombstone, and the ONLY thing that does. Same rule: no pane argument.
starts() {
    printf '{"session_id":"%s","source":"resume"}' "$1" | env HOME="$SANDBOX_HOME" \
        TMUX="$SOCKPATH,0,0" TMUX_PANE="$PANE" bash "$CTX" activate claude
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
effective_status() { T show -wAv -t "$WIN" pane-border-status 2>/dev/null; }
# What the border actually draws, styles stripped. Only "#[...]" is a style —
# the sanitizer strips the leading # from anything hostile in a model id, so a
# bracket that survives here is content, and visible as such.
border() {
    T display-message -p -t "$PANE" "$(T show -gv pane-border-format)" \
        | sed 's/#\[[^]]*\]//g'
}

# The border with its styles left in, palette already expanded to hex — what
# the severity colours are asserted against.
styled() { T display-message -p -t "$PANE" "$(T show -gv pane-border-format)"; }
has()    { case "$2" in *"$3"*) ok "$1" ;; *) no "$1" "no [$3] in [$2]" ;; esac; }

# The statusline's own text, colours stripped: render <dir> [VAR=value ...].
# Outside tmux (nothing publishes) and never refreshing; HOME is the sandbox's
# physical path because git reports physical paths. The extra assignments
# override the defaults (env applies them in order).
render() {
    local dir="$1"; shift
    printf '{"session_id":"sid-R","workspace":{"current_dir":"%s"},"context_window":{"context_window_size":1000000,"current_usage":{"input_tokens":0,"output_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}' "$dir" \
        | env -u TMUX -u TMUX_PANE -u CLAUDE_CONFIG_DIR -u COLUMNS -u ANTHROPIC_BASE_URL \
            HOME="$(cd "$SANDBOX_HOME" && pwd -P)" TERMINAL_THEME=gruber_darker CLAUDE_CTX_REFRESH_CMD= \
            GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 "$@" bash "$STATUSLINE" 2>/dev/null \
        | sed $'s/\033\\[[0-9;]*m//g'
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
    check "C18 exactly one SessionStart entry wires activate claude on real starts" \
        "$(jq -r '[(.hooks.SessionStart // [])[]
                   | select(.matcher == "startup|resume|clear|fork"
                            and ([.hooks[]?.command]
                                 | index("bash ~/.config/tmux/scripts/tmux-agent-status.sh activate claude")))]
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
# C21 — the quota numbers. The 5-hour and all-models weekly figures ride in on
# Claude Code's own payload; the model-scoped weekly comes off the cache file,
# and the whole question there is WHEN AN OLD READING IS STILL AN ANSWER. Inside a live
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
    pub sid-A 'claude-opus-5[1m]' 370000 "$lane" 23.5 41.2
    check "C21 the scoped weekly is published" "$(opt @claude_ctx_wk)" "51"
    check "C21 with the model it is scoped to" "$(opt @claude_ctx_wk_model)" "Fable"
    # 23.5 rounds, and it must arrive as a bare integer: the border feeds it to
    # e|/ for the severity colour, which is integer arithmetic.
    check "C21 the 5-hour figure is rounded off the payload" "$(opt @claude_ctx_5h)" "24"
    check "C21 and so is the all-models weekly" "$(opt @claude_ctx_7d)" "41"

    # The vendor drops a window once it resets, so either arrives alone.
    pub sid-A 'claude-opus-5[1m]' 375000 "$lane" "" 41.2
    check "C21 a payload with only the weekly empties the 5-hour" "$(opt @claude_ctx_5h)" ""
    check "C21 and keeps the weekly" "$(opt @claude_ctx_7d)" "41"

    # A payload with no rate_limits at all — API billing. The weekly, which
    # comes from somewhere else entirely, must be untouched by that.
    pub sid-A 'claude-opus-5[1m]' 380000 "$lane"
    check "C21 no rate_limits leaves both payload figures empty" \
        "$(opt @claude_ctx_5h)$(opt @claude_ctx_7d)" ""
    check "C21 and does not disturb the scoped weekly" "$(opt @claude_ctx_wk)" "51"

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
# the trigger is throttled on the last ATTEMPT, which the refresher stamps
# before it fetches (C26). Both are invisible when they break — the chip keeps
# working and the machine just does more work — so they are asserted against a
# stub standing in for the real refresher.
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

    # An attempt older than five minutes: the trigger fires again.
    rm -f "$marker"
    quota "$lane" 400 51 Fable 400 3600
    pub sid-C 'claude-opus-5[1m]' 400000 "$lane" 5
    check "C22 a stale attempt re-arms it" \
        "$(head -1 "$marker" 2>/dev/null)" "$lane"

    unset REFRESH_CMD
    rm -rf "$SANDBOX_HOME/.claude-accounts" "$SANDBOX_HOME/.cache" "$stub" "$marker"
}

# ---------------------------------------------------------------------------
# C23 — Codex uses its native terminal-title surface for runtime information
# and publishes its compact path separately. The path leads, so normal terminal
# clipping sheds the model at the right edge first.
# ---------------------------------------------------------------------------
c23() {
    fresh || return
    T set -p -t "$PANE" @codex_active 1
    T set -p -t "$PANE" @codex_path planlab/main
    T select-pane -t "$PANE" -T 'ctx 12% · weekly 58% left · gpt-5.6-sol high fast'
    env HOME="$SANDBOX_HOME" TMUX="$SOCKPATH,0,0" TMUX_PANE="$PANE" \
        bash "$CTX" reconcile "$PANE"
    check "C23 a live Codex title owns the border row" "$(status)" "top"
    local drawn=no
    case $(border) in
        *' planlab/main │ ctx 12% · weekly 58% left · gpt-5.6-sol high fast '*) drawn=yes ;;
    esac
    check "C23 path leads the native runtime title" "$drawn" "yes"

    T set -p -u -t "$PANE" @codex_active
    T set -p -u -t "$PANE" @codex_path
    env HOME="$SANDBOX_HOME" TMUX="$SOCKPATH,0,0" TMUX_PANE="$PANE" \
        bash "$CTX" reconcile "$PANE"
    check "C23 Codex exit releases the border row" "$(effective_status)" "off"
}

# ---------------------------------------------------------------------------
# C24 — the interactive zsh wrapper owns exactly Codex's process lifetime. A
# fake codex (sleep) makes both edges observable without starting a real agent
# or touching the live tmux socket.
# ---------------------------------------------------------------------------
c24() {
    fresh || return
    mkdir -p "$SANDBOX/bin"
    ln -sf /bin/sleep "$SANDBOX/bin/codex"

    local main="$SANDBOX_HOME/dev/planlab/main"
    local worktree="$SANDBOX_HOME/dev/.worktrees/main/feat/eval-invoker-production-parity"
    git init -q "$main"
    git -C "$main" -c user.name=test -c user.email=test@example.invalid \
        commit -q --allow-empty -m root
    git -C "$main" worktree add -q -b feat/eval-invoker-production-parity "$worktree"

    local cmd marker="" path=""
    printf -v cmd \
        "cd '%s' && env HOME='%s' PATH='%s/bin:/opt/homebrew/bin:/usr/bin:/bin' zsh -f -ic \"source '%s'; codex 1; sleep 100000\"" \
        "$worktree" "$SANDBOX_HOME" "$SANDBOX" "$ZUTIL"
    T respawn-pane -k -t "$PANE" "$cmd"
    for _ in $(seq 1 20); do
        marker=$(opt @codex_active)
        [ "$marker" = 1 ] && break
        sleep 0.1
    done
    check "C24 wrapper marks Codex's lifetime" "$marker" "1"
    path=$(opt @codex_path)
    check "C24 worktree path resolves to its main checkout" "$path" "planlab/main"
    check "C24 wrapper raises the border" "$(effective_status)" "top"

    for _ in $(seq 1 30); do
        marker=$(opt @codex_active)
        [ -z "$marker" ] && break
        sleep 0.1
    done
    sleep 0.2
    check "C24 wrapper clears its marker on exit" "$marker" ""
    check "C24 wrapper clears its path on exit" "$(opt @codex_path)" ""
    check "C24 wrapper reconciles the border on exit" "$(effective_status)" "off"
}

# ---------------------------------------------------------------------------
# C25 — the priority ladder, on every lane: account, model:effort, the 5h/7d
# pair, the model-scoped weekly, each outliving everything to its right as the
# pane narrows. The scoped weekly yields first WHATEVER its value: an urgent
# one is still the lowest-priority field, and its colour is the only alarm it
# gets. The 5h/7d pair moves as one group — a gate on one number alone would
# leave a lone figure standing where a reader expects the pair. Shedding is
# pure display: the options survive every crossing, so widening restores the
# chip without a republish. The exact boundaries are what catch a gate that
# was dropped, inverted, or written with tmux's STRING comparison instead of
# arithmetic e|>=.
# ---------------------------------------------------------------------------
c25() {
    fresh || return
    local lane width
    for lane in work@example.test personal@example.test; do
        quota "$lane" 10 98 Fable 10 3600
        pub sid-A claude-fable-5-1 220000 "$lane" 12 41 high
        T resize-window -t t -x 200
        check "C25 wide $lane shows every field in priority order" "$(border)" \
            " ${lane%%@*} fable-5-1:high 5h:12 7d:41 Fable:98 ✳ 22% "
        for width in 139 102 80; do
            T resize-window -t t -x "$width"
            check "C25 $lane at $width sheds an urgent scoped weekly first" "$(border)" \
                " ${lane%%@*} fable-5-1:high 5h:12 7d:41 ✳ 22% "
        done
        for width in 79 55; do
            T resize-window -t t -x "$width"
            check "C25 $lane at $width sheds the 5h/7d pair together" "$(border)" \
                " ${lane%%@*} fable-5-1:high ✳ 22% "
        done
        for width in 54 40; do
            T resize-window -t t -x "$width"
            check "C25 $lane at $width keeps the account over the model" "$(border)" \
                " ${lane%%@*} ✳ 22% "
        done
        T resize-window -t t -x 39
        check "C25 a sliver keeps context" "$(border)" " ✳ 22% "
        check "C25 hiding never touched the options" "$(opt @claude_ctx_account)" "${lane%%@*}"
        T resize-window -t t -x 140
        check "C25 widening restores every field without republishing" "$(border)" \
            " ${lane%%@*} fable-5-1:high 5h:12 7d:41 Fable:98 ✳ 22% "
    done
    rm -rf "$SANDBOX_HOME/.cache"
}

# ---------------------------------------------------------------------------
# C26 — the real refresher against a fake headroom: it stamps its attempt
# BEFORE the slow fetch (so concurrent renders stop re-spawning it and a
# refresher killed mid-fetch cannot freeze the lane), then publishes what
# headroom's store holds for the CLAUDE row of this email — the fake lists a
# codex row with the same email first, as a live `headroom limits` does.
# ---------------------------------------------------------------------------
c26() {
    fresh || return
    local lane=recovery@example.test
    local cache="$SANDBOX_HOME/.cache/claude-ctx"
    local fakebin="$SANDBOX/fake-headroom"
    mkdir -p "$fakebin" "$cache"
    quota "$lane" 86400 67 Fable 86400 -60
    cat > "$fakebin/headroom" <<'STUB'
#!/bin/bash
case "${1:-}" in
limits) printf '%s\n' '{"accounts":[{"email":"recovery@example.test","vendor":"codex","usage":{"limits":[]}},{"email":"recovery@example.test","vendor":"claude","usage":{"observed_at":"2026-01-01T00:00:00Z","limits":[{"kind":"weekly_scoped","percent_state":"ok","identity_state":"ok","percent":79,"model":"Fable","resets_at":"2099-01-01T00:00:00Z"}]}}]}' ;;
*) sleep 2 ;;   # any fetching surface: refresh, --json
esac
STUB
    chmod +x "$fakebin/headroom"
    local PATH="$fakebin:$PATH"
    export PATH
    REFRESH_CMD="$REPO/claude/.claude/commands/claude-quota-refresh.sh"
    pub sid-A claude-fable-5-1 220000 "$lane" 15
    # The fake fetch sleeps 2s; the stamp must land well inside it.
    local at state=stale
    for _ in $(seq 1 15); do
        read -r at _ < "$cache/$lane.quota"
        [ $(( $(date +%s) - at )) -lt 60 ] && { state=fresh; break; }
        sleep 0.1
    done
    check "C26 the attempt is stamped before the fetch returns" "$state" "fresh"
    sleep 2   # let the refresher finish before its cache is removed
    pub sid-A claude-fable-5-1 220000 "$lane" 15
    check "C26 the claude row reaches the pane" "$(opt @claude_ctx_wk)" "79"
    check "C26 with its label" "$(opt @claude_ctx_wk_model)" "Fable"
    unset REFRESH_CMD
    rm -rf "$SANDBOX_HOME/.cache" "$fakebin"
}

# ---------------------------------------------------------------------------
# C27 — one vocabulary. The option names live in lib/agent-vocab.sh and the
# verbs in tmux-agent-status.sh; producers call them instead of spelling the
# names. Drift is silent in every direction: a field the border reads but
# nothing publishes draws nothing, a published field the border forgot never
# shows, a producer's private copy of the list stops matching the owner's
# drop, and a publish whose values shift one slot writes every field wrong.
# The render path also has a budget — one tmux call, no process spawned — so
# the library half of the owner, which the statusline sources, is held to it.
# ---------------------------------------------------------------------------
c27() {
    local fields drawn
    fields=$(bash -c ". '$VOCAB'; printf '%s\n' \$AGENT_CLAUDE_FIELDS" | sort)
    drawn=$(grep '^set -g pane-border-format' "$CONF" | grep -o '@claude_ctx[a-z0-9_]*' | sort -u)
    check "C27 (premise) the vocabulary lists the chip's fields" \
        "$(printf '%s\n' "$fields" | grep -c .)" "9"
    check "C27 the border reads no option the vocabulary does not publish" \
        "$(comm -13 <(printf '%s\n' "$fields") <(printf '%s\n' "$drawn"))" ""
    check "C27 every published field but the owner is drawn" \
        "$(comm -23 <(printf '%s\n' "$fields") <(printf '%s\n' "$drawn") | grep -vx '@claude_ctx_sid')" ""
    check "C27 the statusline spells no agent option" \
        "$(cat "$STATUSLINE" "$CHIP" | grep -v '^[[:space:]]*#' | grep -c '@claude_ctx\|@codex_' || true)" "0"
    check "C27 the zsh prompt sweep and codex wrapper spell no agent option" \
        "$(grep -v '^[[:space:]]*#' "$ZUTIL" | grep -c '@claude_ctx\|@codex_' || true)" "0"
    check "C27 the statusline issues exactly one tmux command" \
        "$(cat "$STATUSLINE" "$CHIP" | grep -v '^[[:space:]]*#' | grep -c '^[[:space:]]*tmux ' || true)" "1"
    check "C27 the owner's sourced half runs no subprocess" \
        "$(sed -n '1,/^\[ "\${BASH_SOURCE\[0\]}" = "\$0" \] || return 0$/p' "$CTX" \
            | grep -v '^[[:space:]]*#' | grep -c '\$([^(]\|`' || true)" "0"
    check "C27 a value count off the vocabulary publishes nothing" \
        "$(bash -c ". '$CTX'; agent_claude_publish %1 60 sid-A && echo built || echo refused")" "refused"
    check "C27 the full count builds the gate" \
        "$(bash -c ". '$CTX'; agent_claude_publish %1 60 sid-A m e a 5 7 6 F && echo built || echo refused")" "built"
}

# ---------------------------------------------------------------------------
# C28 — the prompt sweep's verb. The shell prompt returning means no listed
# agent owns the pane any more: its state goes, Claude's with a tombstone so
# an orphaned statusline render cannot resurrect it. An agent left off the
# list (the zsh caller omits one with a suspended job) keeps its state, and
# its presence keeps the border row up.
# ---------------------------------------------------------------------------
c28() {
    fresh || return
    pub sid-A 'claude-opus-5[1m]' 600000
    T set -p -t "$PANE" @codex_active 1
    T set -p -t "$PANE" @codex_path planlab/main
    env HOME="$SANDBOX_HOME" TMUX="$SOCKPATH,0,0" TMUX_PANE="$PANE" \
        bash "$CTX" sweep "$PANE" claude
    check "C28 sweep drops the listed agent's chip" "$(opt @claude_ctx)$(opt @claude_ctx_model)" ""
    check "C28 tombstoning its recorded session" "$(opt @claude_ctx_dead)" "sid-A"
    check "C28 an agent left off the list keeps its state" "$(opt @codex_active)" "1"
    check "C28 and its presence keeps the border up" "$(status)" "top"
    env HOME="$SANDBOX_HOME" TMUX="$SOCKPATH,0,0" TMUX_PANE="$PANE" \
        bash "$CTX" sweep "$PANE"
    check "C28 an empty list sweeps every agent" "$(opt @codex_active)$(opt @codex_path)" ""
    check "C28 and the border drops with the last one" "$(effective_status)" "off"
}

# ---------------------------------------------------------------------------
# C29 — one prompt, one tmux round trip. cout's precmd runs after oh-my-posh's
# and publishes the command it just recorded; the agent sweep rides the same
# call instead of paying two more. The case drives the real zsh modules (no
# rc files: -f) with a logging tmux first on PATH, and a Claude chip left
# behind as a hard kill would leave it — the prompt must clear it through
# that single call.
# ---------------------------------------------------------------------------
c29() {
    fresh || return
    pub sid-A 'claude-opus-5[1m]' 600000
    local bin="$SANDBOX/logbin" log="$SANDBOX/tmux-calls" hooks="$SANDBOX/precmd-hooks"
    mkdir -p "$bin"
    printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s"\nexec "%s" "$@"\n' "$log" "$(command -v tmux)" > "$bin/tmux"
    chmod +x "$bin/tmux"
    env HOME="$SANDBOX_HOME" PATH="$bin:$PATH" TMUX="$SOCKPATH,0,0" TMUX_PANE="$PANE" \
        zsh -f -i -c "source '$ZUTIL'; source '$COUT'; _cout_setup
            print -rl -- \$precmd_functions > '$hooks'
            : > '$log'
            _cout_store=$SANDBOX/no-store _cout_session=s1 _cout_last=s1-7
            _cout_precmd" >/dev/null 2>&1
    sleep 0.8   # the sweep verb runs in the background on the server
    check "C29 cout's hook took over the standalone sweep hook" \
        "$(grep -cx _cout_precmd "$hooks" 2>/dev/null || true) $(grep -cx _agent_border_sweep "$hooks" 2>/dev/null || true)" "1 0"
    check "C29 the prompt made one tmux call" "$(grep -c . "$log" 2>/dev/null || echo 0)" "1"
    check "C29 that call publishes cout's record, then gates the sweep" \
        "$(grep -c '@cout-ready 1 ; if-shell -F' "$log" 2>/dev/null || true)" "1"
    check "C29 cout's record was published" "$(opt @cout-state)" "s1 s1-7"
    check "C29 the prompt swept the dead Claude's chip" "$(opt @claude_ctx)" ""
    check "C29 tombstoning its session" "$(opt @claude_ctx_dead)" "sid-A"
    rm -rf "$bin" "$log" "$hooks"
}

# ---------------------------------------------------------------------------
# C30 — effort rides the model. It is a suffix of the model field, never a
# field of its own: with no model there is nothing for it to qualify, and it
# sheds with the model as one unit. /effort changes it mid-session with every
# other value unchanged, so it needs its own gate arm — the C2 trap, for the
# new option. It is untrusted text on the same two paths as the model id.
# ---------------------------------------------------------------------------
c30() {
    fresh || return
    pub sid-A 'claude-opus-5[1m]' 600000 'yan@planlab.ai' "" "" high
    check "C30 effort published" "$(opt @claude_ctx_effort)" "high"
    check "C30 border joins it to the model" "$(border)" " yan opus-5[1m]:high ✳ 60% "
    T set -w -t "$WIN" pane-border-status off
    pub sid-A 'claude-opus-5[1m]' 600000 'yan@planlab.ai' "" "" xhigh
    check "C30 an effort-only change is accepted" "$(opt @claude_ctx_effort)" "xhigh"
    check "C30 and reconciles the border" "$(status)" "top"
    T resize-window -t t -x 48 2>/dev/null; sleep 0.2
    check "C30 effort sheds with the model" "$(border)" " yan ✳ 60% "
    T resize-window -t t -x 200 2>/dev/null; sleep 0.2
    pub sid-A 'claude-opus-5[1m]' 600000 'yan@planlab.ai'
    check "C30 a model with no effort empties it" "$(opt @claude_ctx_effort)" ""
    check "C30 and the model stands alone, no stray colon" "$(border)" " yan opus-5[1m] ✳ 60% "
    pub sid-A - 600000 'yan@planlab.ai' "" "" high
    check "C30 effort without a model draws nothing" "$(border)" " yan ✳ 60% "
    pub sid-A 'claude-opus-5[1m]' 500000 'yan@planlab.ai' "" "" "hi gh, #[fg=red]'; kill-server"
    check "C30 server survived a hostile effort" \
        "$(T list-sessions -F '#{session_name}' 2>/dev/null | head -1)" "t"
    check "C30 effort reduced to one inert token" "$(opt @claude_ctx_effort)" "highfgredkill-server"
    check "C30 percentage not corrupted" "$(opt @claude_ctx)" "50"
}

# ---------------------------------------------------------------------------
# C31 — colour is the only severity signal the quota numbers have, and
# border() strips it, so a ramp that broke would pass every other case. Calm
# 5h/7d wear the quiet accent — a step above the muted fields, never the
# alarm colours — and each number moves up the ramp on its OWN value. The
# model-scoped weekly stays muted while calm: it is the demoted field.
# ---------------------------------------------------------------------------
c31() {
    fresh || return
    local lane=tone@example.test accent muted yellow red
    accent=$(T show -gv @thm_sapphire); muted=$(T show -gv @thm_overlay_1)
    yellow=$(T show -gv @thm_yellow);  red=$(T show -gv @thm_red)
    check "C31 (premise) the palette is loaded and the accent is its own colour" \
        "$([ -n "$accent" ] && [ "$accent" != "$muted" ] && [ "$accent" != "$yellow" ] &&
           [ "$accent" != "$red" ] && echo distinct)" "distinct"
    quota "$lane" 10 15 Fable 10 3600
    pub sid-A claude-fable-5-1 220000 "$lane" 12 49 high
    has "C31 a calm 5-hour wears the accent"  "$(styled)" "#[fg=$accent] 5h:12"
    has "C31 a calm 7-day wears the accent"   "$(styled)" "#[fg=$accent] 7d:49"
    has "C31 a calm scoped weekly stays muted" "$(styled)" "#[fg=$muted] Fable:15"
    has "C31 the account stays muted"         "$(styled)" "#[fg=$muted] tone "
    quota "$lane" 10 90 Fable 10 3600
    pub sid-A claude-fable-5-1 220000 "$lane" 50 90 high
    has "C31 50 turns one number yellow"      "$(styled)" "#[fg=$yellow] 5h:50"
    has "C31 90 turns its neighbour red"      "$(styled)" "#[fg=$red] 7d:90"
    has "C31 an urgent scoped weekly is red"  "$(styled)" "#[fg=$red] Fable:90"
    rm -rf "$SANDBOX_HOME/.cache"
}

# ---------------------------------------------------------------------------
# C32 — the statusline's own text. Everything above reads the border; this is
# the line Claude Code draws under the prompt, colours stripped. A branch is
# the porcelain header minus any "...upstream" (a dotted name like release-1.2
# once lost everything after its first dot), an unborn branch is its name, the
# counts are staged files, +added -removed lines against HEAD and untracked
# files, a linked worktree draws its main checkout behind the clone glyph
# (U+F24D, once saved as a bare space), and ~/dev and ~ are abbreviated only
# on a whole path component.
# ---------------------------------------------------------------------------
c32() {
    local home repo wt
    home=$(cd "$SANDBOX_HOME" && pwd -P)   # git reports physical paths
    repo="$home/dev/proj"; wt="$home/dev/.worktrees/proj/x"
    # The suite's own git, isolated from the user's config and hooks.
    g() { env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -c user.name=t -c user.email=t@t "$@" >/dev/null 2>&1; }
    mkdir -p "$repo/sub" "${home}2/x"
    g -C "$repo" init -b main
    check "C32 an unborn branch is its name" "$(render "$repo")" "proj | main | 0%"
    printf '1\n2\n3\n' > "$repo/a.txt"; printf 'k\n' > "$repo/sub/k.txt"
    g -C "$repo" add -A; g -C "$repo" commit -m init
    g -C "$repo" checkout -b release-1.2; g -C "$repo" branch -u main
    printf '1\n2\nx\ny\n' > "$repo/a.txt"            # unstaged: +2 -1
    printf 'b\n' > "$repo/b.txt"; g -C "$repo" add b.txt   # staged new file: +1
    printf 'c\n' > "$repo/c.txt"                       # untracked
    check "C32 a dotted branch keeps its dots and drops its upstream" \
        "$(render "$repo")" "proj | release-1.2 | 0% | +1 +3 -1 ?1"
    g -C "$repo" worktree add -b feat/x.y "$wt"
    check "C32 a linked worktree draws its main checkout and subpath" \
        "$(render "$wt/sub")" "$(printf '\xef\x89\x8d') proj/sub | feat/x.y | 0%"
    check "C32 a sibling of HOME is not abbreviated" \
        "$(render "${home}2/x")" "${home}2/x | 0%"
    check "C32 HOME itself is ~" "$(render "$home")" "~ | 0%"
    rm -rf "$SANDBOX_HOME/dev" "${home}2"
}

# ---------------------------------------------------------------------------
# C33 — a theme the palette has no arm for (a port that reached theme-set but
# not statusline-palette.sh) once ended the statusline before the chip was
# published: the border froze at its last values and the line went blank. The
# chip publishes before the palette is consulted, and the line falls back to
# the default colours.
# ---------------------------------------------------------------------------
c33() {
    fresh || return
    PUB_THEME=no_such_theme pub sid-A 'claude-opus-5[1m]' 600000
    check "C33 an unknown theme still publishes the chip" "$(opt @claude_ctx)" "60"
    check "C33 and the line still draws" "$(render / TERMINAL_THEME=no_such_theme)" "/ | 0%"
}

WANT="${*:-}"
echo "tmux $(tmux -V) — Claude context chip suite"
for c in c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c13 c14 c15 c16 c17 c18 c19 c20 c21 c22 c23 c24 c25 c26 c27 c28 c29 c30 c31 c32 c33; do
    n=$(echo "$c" | tr 'a-z' 'A-Z')
    want "$n" && { echo "[$n]"; $c; }
done
echo
printf 'passed %d, failed %d%s\n' "$PASS" "$FAIL" "${FAILED:+ ($FAILED)}"
[ "$FAIL" -eq 0 ]
