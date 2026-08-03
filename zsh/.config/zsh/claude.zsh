# ~/.config/zsh/claude.zsh
# Claude Code launchers — one login per account, keyed by email.
# System model and use patterns: docs/claude-accounts.md.
#
# The filesystem is the account registry:
#   ~/.claude                      primary (qiushi@planlab.ai)
#   ~/.claude-accounts/<email>/    one dir per extra subscription
#   ~/.claude-accounts/.current    which account bare `x` targets — written
#                                  by headroom (`launch --remember`, the
#                                  board's enter); nothing here parses it
#   ~/.claude-accounts/.order      board display order (optional)
#   ~/.claude-accounts/state.json  headroom's own file — its request ledger,
#                                  the usage answers it fetched, session
#                                  re-homes. Nothing here reads or writes it.
#
# A distinct CLAUDE_CONFIG_DIR gives a session its own Keychain login (the
# credentials service name is suffixed with sha256(dir)[0:8]), so /login on
# one account never touches another and all tokens coexist. Account dirs are
# seeded with symlinks to the tracked config in dotfiles/claude/.claude —
# settings, skills, hooks, rules stay shared; login and prompt history stay
# per-account. Session transcripts are machine-global: every account's
# projects/ symlinks to ~/.claude/projects (see _claude_link_projects and
# claude-sessions.zsh), so the resume picker sees every session regardless
# of account.
#
# Launch routing belongs to headroom (~/dev/headroom, installed to
# ~/.local/bin/headroom): `headroom launch` validates the account and builds
# the child environment from that decision alone — every inherited
# CLAUDE_CONFIG_DIR is stripped, exactly one is set for a non-primary — so a
# polluted shell (a tmux server started inside a Claude Code session) can
# never re-route a launch. These wrappers only add what is personal: the
# shared-sessions topology preflight, seeding, flags, and short aliases.
#
#   x                     permissions bypassed, on the *last explicitly
#                         chosen* account — x-<name> chooses and sticks
#   x-<email>             a specific account, permissions bypassed —
#                         generated at shell init from the dirs; when the
#                         local part is unique (and isn't the primary's
#                         name or a reserved word) a short alias exists
#                         too (x-yan, …)
#   x-select              session picker (headroom resume): pick any session
#                         on the machine, resume it in its own project dir
#                         on the account that last drove it (the cd sticks;
#                         bare `x`'s target is untouched)
#   x-accounts / x-acc    account board (headroom accounts): live usage for
#                         every account, refreshing while it is open; enter
#                         sticks like x-<name> does, then launches on it
#   x-check               ≡ headroom check — verifies the reverse-engineered
#                         machinery after a Claude Code update
#   x-account             ≡ claude-account <name|email> [args...] — prompted
#                         (no bypass) session; also makes it current
#   x-account-add         ≡ claude-account-add <email> — seed a new account
#                         dir, then /login
#
# To bypass permissions on every invocation instead — plain `claude`
# included — set  "permissions": { "defaultMode": "bypassPermissions" }  in
# claude/.claude/settings.json (shared by all accounts). PreToolUse hooks
# such as block-dangerous-git.sh still fire and block in bypass mode.

typeset -g CLAUDE_ACCOUNTS_ROOT="$HOME/.claude-accounts"
typeset -g CLAUDE_PRIMARY_NAME="qiushi"   # x-qiushi ≡ default ~/.claude
# Local parts that never get a short launcher alias: x-<these> are utilities.
# Purely this file's concern — headroom advertises only the guaranteed
# x-<email> identities, so there is no naming policy to keep in sync anymore.
typeset -ga CLAUDE_X_RESERVED=(usage account account-add select accounts acc check)

# Fill a fresh account dir with symlinks to the tracked claude config.
_claude_account_seed() {
  emulate -L zsh
  local dir="$1" pkg="$HOME/dotfiles/claude/.claude" item
  mkdir -p "$dir"
  for item in "$pkg"/*(DN); do
    ln -s "$item" "$dir/${item:t}"
  done
  _claude_link_projects "$dir"
}

# Session transcripts are machine-global: every account's projects/ is a
# symlink to the primary's store, so any account's session picker sees every
# session and resume appends to the one canonical file. Strict on purpose —
# never ln -sf: a real directory here holds unmigrated sessions
# (claude-sessions-migrate moves them), and silently shadowing it would strand
# history. Identity is checked by inode (-ef), not readlink text.
_claude_link_projects() {
  emulate -L zsh
  local dir="$1" canon="$HOME/.claude/projects" link="$1/projects"
  if [[ -h "$canon" || ( -e "$canon" && ! -d "$canon" ) ]]; then
    print -u2 "claude accounts: $canon must be a real directory — the canonical session store cannot itself be a link"
    return 1
  fi
  mkdir -p "$canon" || return 1
  if [[ -h "$link" ]]; then
    [[ "$link" -ef "$canon" ]] && return 0
    print -u2 "claude accounts: $link is a symlink but does not resolve to $canon — fix it by hand"
    return 1
  elif [[ -e "$link" ]]; then
    print -u2 "claude accounts: $link is a real directory (unmigrated sessions?) — run claude-sessions-migrate"
    return 1
  fi
  ln -s "$canon" "$link"
}

# Expand a personal shorthand to the canonical name headroom knows: the
# primary's name and full emails pass through, a unique local part becomes
# its email. Convenience only — headroom revalidates whatever this prints,
# so an ambiguous or stale shorthand fails there by name instead of routing
# anywhere.
_claude_canonical() {
  emulate -L zsh
  local q="$1" d
  local -a hits
  if [[ -z "$q" || "$q" == "$CLAUDE_PRIMARY_NAME" || -d "$CLAUDE_ACCOUNTS_ROOT/$q" ]]; then
    print -r -- "$q"
    return 0
  fi
  for d in "$CLAUDE_ACCOUNTS_ROOT"/*(/N); do
    [[ "${${d:t}%%@*}" == "$q" ]] && hits+=("${d:t}")
  done
  (( ${#hits} == 1 )) && { print -r -- "${hits[1]}"; return 0 }
  print -r -- "$q"
}

# The launcher to advertise for <email> — the short alias when it exists,
# else the guaranteed full-email selector.
_claude_selector() {
  emulate -L zsh
  local email="$1"
  local name="${email%%@*}"   # separate `local`: zsh expands a typeset's words before any assignment lands
  if [[ "$name" != "$email" && "$name" != "$CLAUDE_PRIMARY_NAME" ]] \
       && (( ! ${CLAUDE_X_RESERVED[(Ie)$name]} )) && (( ${+functions[x-$name]} )); then
    print -r -- "x-$name"
  else
    print -r -- "x-$email"
  fi
}

# x-* names for the whole toolkit, so one prefix reaches everything.
x-account()     { claude-account "$@" }
x-account-add() { claude-account-add "$@" }
x-check()       { headroom check "$@" }
# Account board (headroom accounts): live usage for every account, refreshing
# itself while it is open; enter sticks like x-<name> does, then launches on
# it. Bare `headroom` is the same board, so this is the only wrapper it needs.
x-accounts()    { headroom accounts && x "$@" }
x-acc()         { x-accounts "$@" }
# Session picker (headroom resume): every session on the machine, resumed in
# its own project dir on the account that last drove it. headroom decides
# and prints one dir<TAB>id<TAB>account-name line; this wrapper only cds
# (the cd sticks) and launches through headroom again. Deliberately no
# --remember: resuming a session never moves where bare `x` points — only
# x-accounts does that.
x-select() {
  emulate -L zsh
  local out dir id account
  out=$(headroom resume) || return
  IFS=$'\t' read -r dir id account <<< "$out"
  if [[ -z "$dir" || -z "$id" || -z "$account" ]]; then
    print -u2 "x-select: unexpected decision line from headroom resume"
    return 1
  fi
  cd -- "$dir" && _claude_launch "$account" --dangerously-skip-permissions --resume "$id"
}

# Launch claude through headroom: resolve for the preflight, then `headroom
# launch` revalidates the name and owns the child environment entirely.
#
#   _claude_launch [--remember] <name|""> [claude args...]
#
# "" means the recorded choice (.current), which headroom reads strictly —
# empty, unreadable, or naming a deleted account refuses rather than
# silently becoming the primary with permissions bypassed.
#
# No fallback to bare `claude` when headroom is missing or refuses: a loud
# stop is recoverable, a silent wrong-account session is not. The unmanaged
# escape hatch is deliberately explicit —
#   env -u CLAUDE_CONFIG_DIR claude              # the primary
#   CLAUDE_CONFIG_DIR=<dir> claude               # a specific account
# — because in a polluted shell, bare `claude` is exactly the misroute the
# managed path exists to prevent.
#
# On the failure messages: "headroom not found" is this wrapper's to say;
# every later refusal prints its own reason from headroom. Nothing is added
# to a nonzero exit after that point — post-exec it is claude's own status
# and must pass through untouched.
_claude_launch() {
  emulate -L zsh
  local -a remember=()
  if [[ "${1-}" == "--remember" ]]; then remember=(--remember); shift; fi
  local sel="$1"; shift
  if ! command -v headroom >/dev/null 2>&1; then
    print -u2 "claude accounts: headroom not found (is ~/.local/bin on PATH?) — claude was not started"
    return 127
  fi
  local out name dir kind
  if [[ -n "$sel" ]]; then
    out=$(headroom resolve "$sel") || return
  else
    out=$(headroom resolve) || return
  fi
  IFS=$'\t' read -r name dir kind <<< "$out"
  if [[ -z "$name" || -z "$dir" || -z "$kind" ]]; then
    print -u2 "claude accounts: unexpected resolve output from headroom — claude was not started"
    return 1
  fi
  # Topology preflight for extra accounts only — the primary owns the
  # canonical store. Which case applies comes from headroom's classification,
  # never from prefix-matching this file's idea of the accounts root: a
  # HEADROOM_* override moves the real root, and a wrapper comparing paths it
  # didn't resolve would skip the one check that keeps history unforked.
  # (Seeding stays claude-account-add's job: a launcher whose dir vanished
  # should refuse — headroom does — not quietly regenerate an empty login.)
  if [[ "$kind" == "extra" ]]; then
    _claude_link_projects "$dir" || { print -u2 "claude accounts: $dir violates the shared-sessions topology — not launching"; return 1 }
  fi
  # Claude Code ignores TMPDIR: its temp base is CLAUDE_CODE_TMPDIR or a
  # hardcoded /tmp, with claude-<uid>/ appended (verified in the 2.1.215
  # binary). Uncomment to make Ctrl+G prompt files (and all other Claude
  # temp files — child-process caches included) land in ./.tmp instead;
  # cleanup becomes manual, so it stays off by default.
  # CLAUDE_CODE_TMPDIR="$PWD/.tmp" \
  headroom launch $remember --account "$name" -- "$@"
}

# Bypassed permissions on the last explicitly chosen account.
x() {
  emulate -L zsh
  _claude_launch "" --dangerously-skip-permissions "$@"
}

# Prompted (no bypass) session on any account; sticks like x-<name> does.
claude-account() {
  emulate -L zsh
  if [[ -z "${1-}" ]]; then
    echo "usage: claude-account <name|email> [claude args...]" >&2
    return 1
  fi
  local name; name=$(_claude_canonical "$1"); shift
  _claude_launch --remember "$name" "$@"
}

# Seed a dir for a new subscription; /login on first launch binds it.
claude-account-add() {
  emulate -L zsh
  if [[ "$1" != *@* ]]; then
    echo "usage: claude-account-add <email>" >&2
    return 1
  fi
  local dir="$CLAUDE_ACCOUNTS_ROOT/$1"
  if [[ -d "$dir" ]]; then
    echo "claude-account-add: $dir already exists" >&2
    return 1
  fi
  if ! _claude_account_seed "$dir"; then
    echo "claude-account-add: seeding $dir failed — inspect and remove it before retrying" >&2
    return 1
  fi
  _claude_gen_launchers
  echo "seeded $dir"
  echo "next: $(_claude_selector "$1") → /login as $1"
}

# Generate launchers for every account dir. Each launches through headroom
# with --remember, so choosing an account and recording it as bare `x`'s
# target is one step. x-<email> always exists and is the guaranteed
# identity; a short x-<local-part> alias is added only when the local part
# is unique among accounts and isn't the primary's name, so a short name can
# never launch the wrong account with permissions bypassed. Short aliases
# are this file's convenience alone — headroom advertises the full identity.
# Runs at every shell init: one glob, no subprocess — startup-perf safe.
_claude_gen_launchers() {
  emulate -L zsh
  local d email name
  local -A count   # local part → number of accounts claiming it
  for d in "$CLAUDE_ACCOUNTS_ROOT"/*(/N); do
    name="${${d:t}%%@*}"
    count[$name]=$(( ${count[$name]:-0} + 1 ))
  done
  for d in "$CLAUDE_ACCOUNTS_ROOT"/*(/N); do
    email="${d:t}" name="${email%%@*}"
    functions[x-$email]="_claude_launch --remember ${(q)email} --dangerously-skip-permissions \"\$@\""
    if [[ "$name" != "$email" && "$name" != "$CLAUDE_PRIMARY_NAME" ]] && (( ! ${CLAUDE_X_RESERVED[(Ie)$name]} )); then
      if (( count[$name] == 1 )); then
        functions[x-$name]="x-${(q)email} \"\$@\""
      else
        # a newly added account made this local part ambiguous — drop the
        # stale alias rather than let it point at either account
        unfunction "x-$name" 2>/dev/null || true
      fi
    fi
  done
  functions[x-$CLAUDE_PRIMARY_NAME]="_claude_launch --remember $CLAUDE_PRIMARY_NAME --dangerously-skip-permissions \"\$@\""
}
_claude_gen_launchers
