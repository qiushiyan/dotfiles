# ~/.config/zsh/claude.zsh
# Claude Code launchers — one login per account, keyed by email.
# System model and use patterns: docs/claude-accounts.md.
#
# The filesystem is the account registry:
#   ~/.claude                      primary (qiushi@planlab.ai)
#   ~/.claude-accounts/<email>/    one dir per extra subscription
#   ~/.claude-accounts/.current    which account bare `x` targets
#   ~/.claude-accounts/.order      dashboard display order (optional)
#
# A distinct CLAUDE_CONFIG_DIR gives a session its own Keychain login (the
# credentials service name is suffixed with sha256(dir)[0:8]), so /login on
# one account never touches another and all tokens coexist. Account dirs are
# seeded with symlinks to the tracked config in dotfiles/claude/.claude —
# settings, skills, hooks, rules stay shared; login, history and sessions
# stay per-account. scripts/.local/bin/claude-usage discovers the same dirs
# and renders /usage for every account, each labeled by the email its
# .claude.json reports as actually logged in.
#
#   x                     permissions bypassed, on the *last explicitly
#                         chosen* account — x-<name> chooses and sticks
#   x-<email>             a specific account, permissions bypassed —
#                         generated at shell init from the dirs; when the
#                         local part is unique (and isn't the primary's
#                         name or a reserved word) a short alias exists
#                         too (x-yan, …)
#   x-usage               ≡ claude-usage (the dashboard; --check works too)
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
typeset -g CLAUDE_ACCOUNT_STATE="$CLAUDE_ACCOUNTS_ROOT/.current"
typeset -g CLAUDE_PRIMARY_NAME="qiushi"   # x-qiushi ≡ default ~/.claude
# Local parts that never get a short launcher alias: x-<these> are utilities.
# claude-usage's xcmd_for mirrors this list — keep the two in sync.
typeset -ga CLAUDE_X_RESERVED=(usage account account-add)

# Fill a fresh account dir with symlinks to the tracked claude config.
_claude_account_seed() {
  emulate -L zsh
  local dir="$1" pkg="$HOME/dotfiles/claude/.claude" item
  mkdir -p "$dir"
  for item in "$pkg"/*(DN); do
    ln -s "$item" "$dir/${item:t}"
  done
}

# Resolve <name|email> to an account dir; prints "" for the primary. A local
# part shared by several accounts resolves to none of them — use the email.
_claude_account_dir() {
  emulate -L zsh
  local q="$1" d
  local -a hits
  [[ -z "$q" || "$q" == "$CLAUDE_PRIMARY_NAME" ]] && { print -r -- ""; return 0 }
  [[ -d "$CLAUDE_ACCOUNTS_ROOT/$q" ]] && { print -r -- "$CLAUDE_ACCOUNTS_ROOT/$q"; return 0 }
  for d in "$CLAUDE_ACCOUNTS_ROOT"/*(/N); do
    [[ "${${d:t}%%@*}" == "$q" ]] && hits+=("$d")
  done
  (( ${#hits} == 1 )) && { print -r -- "${hits[1]}"; return 0 }
  return 1
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
x-usage()       { claude-usage "$@" }
x-account()     { claude-account "$@" }
x-account-add() { claude-account-add "$@" }

# Record the account bare `x` should target from now on.
_claude_remember() {
  emulate -L zsh
  mkdir -p "$CLAUDE_ACCOUNTS_ROOT"
  print -r -- "$1" >| "$CLAUDE_ACCOUNT_STATE"
}

# Launch claude against an account dir ("" = primary), seeding on first use.
_claude_launch() {
  emulate -L zsh
  local dir="$1"; shift
  # Claude Code ignores TMPDIR: its temp base is CLAUDE_CODE_TMPDIR or a
  # hardcoded /tmp, with claude-<uid>/ appended (verified in the 2.1.215
  # binary). Uncomment to make Ctrl+G prompt files (and all other Claude
  # temp files — child-process caches included) land in ./.tmp instead;
  # cleanup becomes manual, so it stays off by default.
  # CLAUDE_CODE_TMPDIR="$PWD/.tmp" \
  if [[ -z "$dir" ]]; then
    command claude "$@"
  else
    [[ -d "$dir" ]] || _claude_account_seed "$dir"
    CLAUDE_CONFIG_DIR="$dir" command claude "$@"
  fi
}

# Bypassed permissions on the last explicitly chosen account.
x() {
  emulate -L zsh
  local cur="" dir
  [[ -r "$CLAUDE_ACCOUNT_STATE" ]] && cur=$(<"$CLAUDE_ACCOUNT_STATE")
  if ! dir=$(_claude_account_dir "$cur"); then
    print -u2 "x: last account '$cur' no longer exists — using primary"
    dir=""
  fi
  _claude_launch "$dir" --dangerously-skip-permissions "$@"
}

# Prompted (no bypass) session on any account; sticks like x-<name> does.
claude-account() {
  emulate -L zsh
  local dir
  if ! dir=$(_claude_account_dir "$1"); then
    echo "claude-account: unknown account '$1' — dirs live in $CLAUDE_ACCOUNTS_ROOT" >&2
    return 1
  fi
  shift
  _claude_remember "${${dir:t}:-$CLAUDE_PRIMARY_NAME}"
  _claude_launch "$dir" "$@"
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
  _claude_account_seed "$dir"
  _claude_gen_launchers
  echo "seeded $dir"
  echo "next: $(_claude_selector "$1") → /login as $1"
}

# Generate launchers for every account dir. Each records itself as the
# target of bare `x`, then launches. x-<email> always exists and is the
# guaranteed identity; a short x-<local-part> alias is added only when the
# local part is unique among accounts and isn't the primary's name, so a
# short name can never launch the wrong account with permissions bypassed.
# Runs at every shell init: one glob, no subprocess — startup-perf safe.
# claude-usage's xcmd_for mirrors this rule — keep the two in sync.
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
    functions[x-$email]="_claude_remember ${(q)email}; _claude_launch ${(q)d} --dangerously-skip-permissions \"\$@\""
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
  functions[x-$CLAUDE_PRIMARY_NAME]="_claude_remember $CLAUDE_PRIMARY_NAME; _claude_launch \"\" --dangerously-skip-permissions \"\$@\""
}
_claude_gen_launchers
