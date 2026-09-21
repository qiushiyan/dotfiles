# ~/.config/zsh/codex.zsh
# Codex CLI — several subscriptions, launched through headroom.
#
# The Codex counterpart of claude.zsh, deliberately smaller. One state dir
# ("home") per extra subscription lives at ~/.codex-accounts/<email>; the
# default ~/.codex is the primary. headroom's own files sit beside them:
#
#   ~/.codex-accounts/.current    the account bare `cx` targets; written only
#                                 by headroom (the board's enter on its Codex
#                                 page; `launch --remember`)
#   ~/.codex-accounts/state.json  headroom's request ledger and the usage
#                                 responses it fetched — Codex's own, never
#                                 shared with Claude Code's
#
# Sessions are machine-global here too: every extra home's sessions/ is a
# symlink to ~/.codex/sessions (seeded by `headroom accounts add --vendor
# codex`), so Codex's own `resume` reaches any session from any account.
# headroom has no Codex session picker: continuing on another account is
# naming it — `cx-<other> resume` (this directory's sessions) or
# `cx-<other> resume --all`.
#
# Launch routing belongs to headroom: `headroom launch --vendor codex`
# validates the account, verifies the sessions/ link, and builds the child
# environment from that decision alone — inherited CODEX_HOME,
# CODEX_SQLITE_HOME, CODEX_API_KEY and CODEX_ACCESS_TOKEN are stripped, and
# CODEX_HOME is set for an extra and absent for the primary.
#
# Plain `codex` is left alone on purpose, as plain `claude` is: it is the
# vendor's own default (always ~/.codex) and the escape hatch that does not
# depend on headroom. A function over it would also only ever cover
# interactive shells. `cx` is the managed door.
#
#   cx [args]              Codex on the default account (.current; the
#                          board's enter on the Codex page moves it)
#   cx-<email> [args]      Codex on that account, this session only — bare
#                          `cx`'s target is untouched. cx-<local-part> exists
#                          when the local part is unique; cx-qiushi ≡ ~/.codex
#   cx-accounts / cx-acc   the account board, Codex page only. (`x-acc` shows
#                          both vendors; tab switches pages.)
#   cx-account-add <email> seed a new home (sessions/ link + shared config),
#                          then log in once: cx-<email> login
#
# There is no cx-account-remove: headroom refuses to remove a Codex home — it
# cannot tell whether a codex session is running on it — and names the
# directory to delete by hand.
#
# No bypass array here: approval_policy and sandbox_mode live in config.toml,
# which every home shares (see cx-account-add), so one edit lands on all.
typeset -g CODEX_ACCOUNTS_ROOT="$HOME/.codex-accounts"
typeset -g CODEX_PRIMARY_NAME="qiushi"   # cx-qiushi ≡ default ~/.codex
# Pinned for the same reason as HEADROOM_PRIMARY_NAME: `.current` records the
# name, and a derived one would change under a primary logout.
export HEADROOM_CODEX_PRIMARY_NAME="$CODEX_PRIMARY_NAME"
# The board's captions promise the spelling that resolves in this shell.
# (Its log-in hints keep the engine's own spelling on purpose.)
export HEADROOM_CODEX_LAUNCHER_FORMAT="cx-%s"
# envoy's Codex voices would otherwise always run on ~/.codex — no Claude
# session carries a CODEX_HOME to inherit — whatever the board says. See the
# ENVOY_CLAUDE_CMD note in claude.zsh for why this is guarded.
if (( $+commands[headroom] )); then
  export ENVOY_CODEX_CMD="headroom launch --vendor codex --"
fi
# Local parts that never get a short launcher alias: cx-<these> are utilities.
typeset -ga CODEX_CX_RESERVED=(account-add accounts acc)

# Launch codex through headroom. "" means the recorded choice (.current),
# which headroom reads strictly. No fallback to bare `codex` when headroom is
# missing or refuses: a loud failure beats a session on the wrong account.
# The launch runs inside the tmux pane decoration plain `codex` gets
# (tmux-utils.zsh), so a managed session looks the same on the border.
_codex_launch() {
  emulate -L zsh
  local sel="$1"; shift
  if ! command -v headroom >/dev/null 2>&1; then
    print -u2 "codex accounts: headroom not found (is ~/.local/bin on PATH?) — codex was not started"
    return 127
  fi
  if [[ -n "$sel" ]]; then
    _codex_in_pane 6 headroom launch --vendor codex --account "$sel" -- "$@"
  else
    _codex_in_pane 4 headroom launch --vendor codex -- "$@"
  fi
}

cx() {
  emulate -L zsh
  _codex_launch "" "$@"
}

cx-accounts() { headroom accounts --compact --vendor codex "$@" }
cx-acc()      { cx-accounts "$@" }

# Onboard a subscription: headroom seeds the home (the sessions/ link, the
# topology check launch applies) and shares the config this repo stows into
# ~/.codex — config.toml, AGENTS.md, themes — so approvals, models and
# instructions are one edit for every account. Then regenerate the launchers
# so cx-<email> exists in this shell without a restart.
cx-account-add() {
  emulate -L zsh
  headroom accounts add --vendor codex --share-config="$HOME/dotfiles/codex/.codex" "$@" || return $?
  _codex_gen_launchers
}

# cx-<email> always exists and is the guaranteed identity; a short
# cx-<local-part> is added only when the local part is unique among accounts,
# is not the primary's name and is not a utility, so a short name can never
# launch the wrong account. Runs at every shell init: one glob, no subprocess.
_codex_gen_launchers() {
  emulate -L zsh
  local d email name
  local -A count   # local part → number of accounts claiming it
  for d in "$CODEX_ACCOUNTS_ROOT"/*(/N); do
    name="${${d:t}%%@*}"
    count[$name]=$(( ${count[$name]:-0} + 1 ))
  done
  for d in "$CODEX_ACCOUNTS_ROOT"/*(/N); do
    email="${d:t}" name="${email%%@*}"
    functions[cx-$email]="_codex_launch ${(q)email} \"\$@\""
    if [[ "$name" != "$email" && "$name" != "$CODEX_PRIMARY_NAME" ]] && (( ! ${CODEX_CX_RESERVED[(Ie)$name]} )); then
      if (( count[$name] == 1 )); then
        functions[cx-$name]="cx-${(q)email} \"\$@\""
      else
        # a newly added account made this local part ambiguous — drop the
        # stale alias rather than let it point at either account
        unfunction "cx-$name" 2>/dev/null || true
      fi
    fi
  done
  functions[cx-$CODEX_PRIMARY_NAME]="_codex_launch $CODEX_PRIMARY_NAME \"\$@\""
}
_codex_gen_launchers
