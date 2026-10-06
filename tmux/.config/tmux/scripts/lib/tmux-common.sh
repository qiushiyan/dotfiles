# shellcheck shell=bash
# lib/tmux-common.sh — helpers the tmux scripts share. Sourced, never run:
#
#   . "${BASH_SOURCE[0]%/*}/lib/tmux-common.sh"
#
# Relative to the sourcing script, so a script and its helpers always come
# from the same tree (a test run from a worktree grades that worktree).
#
# Keep it bash-3.2-safe. /bin/bash is 3.2 on macOS, and tmux's run-shell
# resolves whichever bash its PATH finds: no mapfile, no associative arrays,
# no ${var,,}, and never expand an empty array under `set -u`.
#
# Every helper here is silent on failure and returns rather than exits, so a
# sourcing script keeps control of its own error handling.

_TMUX_COMMON_DIR=${BASH_SOURCE[0]%/*}

# The owner of per-pane agent status and of pane-border-status teardown.
AGENT_STATUS="$_TMUX_COMMON_DIR/../tmux-agent-status.sh"

msg() { tmux display-message "$*" 2>/dev/null || true; }

pane_fmt() { tmux display-message -p -t "$1" "$2" 2>/dev/null; }

# Existence is NON-EMPTY OUTPUT, never the exit status: tmux 3.7c exits 0 for
# a target that no longer exists and prints nothing, so an rc check calls
# every dead pane and window alive. (The float's own copies did exactly that;
# T38 pins it.)
pane_exists() { [ -n "$(pane_fmt "$1" '#{pane_id}')" ]; }
win_exists()  { [ -n "$(pane_fmt "$1" '#{window_id}')" ]; }

# Where a pane stands with respect to floating, in one round trip:
#   gone    no such pane
#   native  a tmux 3.7 native floating pane (`prefix *`)
#   phased  mid-float under tmux-float-pane.sh (`prefix z`): it carries @fl_phase
#   holder  in a `_float_*` holder session with no phase (state lost mid-clear,
#           or joined in by hand) — still the floated pane, seen through its
#           container
#   (empty) an ordinary tiled pane
# The float owns the @fl_* names; other scripts ask this instead of reading
# them. A session user option resolves inside a pane format, which is what
# lets one call see the holder mark. A gone pane still prints the literal
# text, so the test is the `%` of a real pane id.
pane_float_state() { # <pane>
    case "$(pane_fmt "$1" '#{pane_id}:#{pane_floating_flag}#{?#{@fl_phase},P,}#{?#{@fl_holder_nonce},H,}')" in
        %*:1*) printf native ;;
        %*P*)  printf phased ;;
        %*H)   printf holder ;;
        %*)    ;;
        *)     printf gone ;;
    esac
}

# Tiled (non-floating) pane ids of a window, in index order. tmux 3.7's native
# floating panes are counted by #{window_panes} and embedded in
# #{window_layout}; the `-f` filter is server-side, so callers never see one.
tiled_panes() {
    tmux list-panes -t "$1" -f '#{==:#{pane_floating_flag},0}' -F '#{pane_id}' 2>/dev/null
}

# Restore `want_order` (space-separated pane ids) as the window's tiled pane
# ORDER, then apply `layout` (skipped when empty). Order first: select-layout
# restores geometry but not identity — the layout string addresses panes by
# index — so a replay alone brings %0 %1 %2 back as %0 %2 %1.
apply_order_and_layout() { # <window> <want_order> [layout]
    local win="$1" want_order="$2" layout="${3:-}" i=0 want have
    for want in $want_order; do
        pane_exists "$want" || { i=$((i + 1)); continue; }
        have=$(tiled_panes "$win" | sed -n "$((i + 1))p")
        [ -n "$have" ] && [ "$have" != "$want" ] && \
            tmux swap-pane -d -s "$want" -t "$have" 2>/dev/null
        i=$((i + 1))
    done
    [ -n "$layout" ] && tmux select-layout -t "$win" "$layout" 2>/dev/null
    return 0
}

# A pane's human label: its title, unless that title is the hostname, which is
# tmux's unset default rather than a name — then the running command. The
# border draws the same rule inline (tmux.conf, pane-border-format), except
# that it shows nothing instead of the command.
# shellcheck disable=SC2034  # read by the sourcing scripts
PANE_LABEL_FMT='#{?#{==:#{pane_title},#{host}},#{pane_current_command},#{pane_title}}'

# The client name to pass as `-c`, or nothing. A `-c <name>` target resolves a
# client by tty NAME, first match in attach order — and tmux does not skip a
# SUSPENDED client there, although list-clients hides one (cmd_find_client vs
# sort_get_clients, 3.7b). A client suspended and never resumed (stock
# suspend-client, then `tmux attach` again from the same terminal) is a ghost
# that shares the live client's name and precedes it: it wins the lookup and
# the popup is drawn onto a stopped tty. Seen live 2026-08-16 — the float and
# the scratch went dark for a day (float-pane.md, "Traps"). Keep the name only
# if it resolves to a pid list-clients can see; otherwise print nothing, and
# the caller passes no -c so tmux picks the most recently active client —
# on the keypress path, the one that pressed the key. Pinned by T27.
live_client() { # <client name>
    local name="${1:-}" pid
    [ -n "$name" ] || return 0
    pid=$(tmux display-message -p -c "$name" '#{client_pid}' 2>/dev/null)
    [ -n "$pid" ] || return 0
    tmux list-clients -F '#{client_pid}' 2>/dev/null | grep -qx "$pid" && printf '%s' "$name"
    return 0
}

# display-popup on the live client, or tmux's own pick when the name is a
# ghost (live_client above). The only way a script here opens a popup, so no
# caller can forget the ghost check. display-popup BLOCKS until the popup
# closes, which is why every binding that reaches one uses `run-shell -b`.
popup() { # <client name> <display-popup args...>
    local c; c=$(live_client "$1"); shift
    if [ -n "$c" ]; then tmux display-popup -c "$c" "$@"; else tmux display-popup "$@"; fi
}

# A popup border value from a user option, validated: display-popup rejects an
# unknown value outright, which would fail the whole presentation over a typo.
resolve_border() { # <@option> <default>
    local b
    b=$(tmux show -gqv "$1" 2>/dev/null)
    case "$b" in
        single|rounded|double|heavy|simple|padded|none) printf '%s' "$b" ;;
        "") printf '%s' "$2" ;;
        *)  msg "ignoring invalid $1 '$b'"; printf '%s' "$2" ;;
    esac
}

# An fzf --color value from the live tmux palette, so every popup follows the
# active terminal theme with no per-theme table. The theme files publish
# @thm_* options and tmux.conf reloads them on every theme switch. One tmux
# round trip: six `tmux show` calls cost the worktree popup ~50ms of
# time-to-first-paint.
#
# Output contract (stable; popups pass it straight to `fzf --color`): one line,
#
#   hl:R,hl+:R,fg+:-1,bg+:S,gutter:-1,query:-1,pointer:A,prompt:A,spinner:A,
#   marker:G,info:M,header:M,label:M,border:D,preview-border:D
#
# (without the wrap) where A=@thm_mauve, M=@thm_overlay_2, D=@thm_overlay_0,
# S=@thm_surface_0, G=@thm_green, R=@thm_red. With no palette loaded it
# prints `fg+:-1`, leaving the rest to fzf's defaults.
fzf_colors_from_palette() {
    local accent muted dim surface green red
    IFS='|' read -r accent muted dim surface green red <<EOF
$(tmux display-message -p '#{@thm_mauve}|#{@thm_overlay_2}|#{@thm_overlay_0}|#{@thm_surface_0}|#{@thm_green}|#{@thm_red}' 2>/dev/null)
EOF
    if [ -z "$accent" ]; then
        printf '%s\n' 'fg+:-1'
        return 0
    fi
    printf '%s\n' "hl:$red,hl+:$red,fg+:-1,bg+:$surface,gutter:-1,query:-1,pointer:$accent,prompt:$accent,spinner:$accent,marker:$green,info:$muted,header:$muted,footer:$muted,label:$muted,border:$dim,preview-border:$dim"
}

# Recompute pane-border-status for EVERY window. Border state is window-scoped
# and shared between producers, and a moved pane strands markers on both
# ends — a targeted call can fix only one — so relocation always reconciles
# with no target. TMUX_PANE is blanked so the owner cannot fall back to it.
reconcile_borders() {
    TMUX_PANE='' bash "$AGENT_STATUS" reconcile >/dev/null 2>&1 || true
}
