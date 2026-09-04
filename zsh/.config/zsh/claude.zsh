# ~/.config/zsh/claude.zsh
# Claude Code launchers — one login per account, keyed by email.
# System model and use patterns: docs/claude-accounts.md.
#
# The filesystem is the account registry:
#   ~/.claude                      primary (qiushi@planlab.ai)
#   ~/.claude-accounts/<email>/    one dir per extra subscription
#   ~/.claude-accounts/.current    which account bare `x` targets — written
#                                  by headroom (the board's enter; `launch
#                                  --remember` is the explicit scriptable
#                                  spelling); nothing here parses it
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
# projects/ symlinks to ~/.claude/projects (seeded by `headroom accounts
# add`; migration of pre-share dirs in claude-sessions.zsh), so the resume
# picker sees every session regardless of account.
#
# Launch routing belongs to headroom (~/dev/headroom, installed to
# ~/.local/bin/headroom): `headroom launch` validates the account, verifies
# the shared-sessions topology, and builds the child environment from that
# decision alone — every inherited CLAUDE_CONFIG_DIR is stripped, exactly
# one is set for a non-primary — so a polluted shell (a tmux server started
# inside a Claude Code session) can never re-route a launch. These wrappers
# only add what is personal: the share source, flags, short aliases, and the one
# thing only a parent shell can do (make a cd stick). The rule behind the
# split, learned twice: shell functions are frozen at shell init and live
# for weeks, so nothing that can misroute, mutate, or misparse belongs
# here — the binary is re-resolved from PATH at every keystroke.
#
#   x                     permissions bypassed, on the default account —
#                         only the board's enter (x-acc) moves that target
#   x-<email>             one session on a specific account, permissions
#                         bypassed; bare `x`'s target is untouched —
#                         generated at shell init from the dirs; when the
#                         local part is unique (and isn't the primary's
#                         name or a reserved word) a short alias exists
#                         too (x-yan, …)
#   x-select              session picker (headroom sessions): pick any
#                         session on the machine; headroom enters its
#                         project dir and execs claude on the account that
#                         last drove it. This wrapper only cds afterwards,
#                         from the advisory --cd-file (bare `x`'s target is
#                         untouched)
#   x-accounts / x-acc    account board (headroom accounts): live usage for
#                         every account, refreshing while it is open; enter
#                         repins bare `x` and exits — no session starts
#                         until `x` is typed
#   x-check               ≡ headroom check — verifies the reverse-engineered
#                         machinery after a Claude Code update
#   x-account             ≡ claude-account <name|email> [args...] — prompted
#                         (no bypass) session; bare `x`'s target untouched
#   x-account-add         ≡ claude-account-add <email> — seed a new account
#                         dir, then /login
#   x-account-remove      ≡ claude-account-remove <email> — delete an
#                         account dir + its Keychain item (also removes
#                         stranded <dir>.lock vendor debris)
#
# To bypass permissions on every invocation instead — plain `claude`
# included — set  "permissions": { "defaultMode": "bypassPermissions" }  in
# claude/.claude/settings.json (shared by all accounts). PreToolUse hooks
# such as block-dangerous-git.sh still fire and block in bypass mode.
#
# Every bypass launcher passes CLAUDE_X_BYPASS, one array, so a flag lands
# on all of them or none. Bypass is not the whole story: permissions.deny
# rules survive it, and Claude Code 2.1.259 added a Bash check that stops
# for a human prompt when a command does `cd DIR;` (anything but a pure
# `&&` chain) and then greps/rgs/diffs/gits/cps/mvs a relative path while
# any `Read(...)` deny rule is loaded (planlab commits Read(./.env)). `--setting-sources user,local` silences
# that by not loading project settings — rejected 2026-09-03 because the
# project source also carries the project's skills, commands, agents,
# plugins, allow list and .mcp.json: an `x` session would lose every
# project skill and `/` completion, and stop inheriting settings the way
# every other Claude Code session does. The fix lived in claude/.claude/hooks/bypass-cd-read-guard.sh
# instead: in bypass mode it refused that command shape with a message
# telling the model to re-issue it, so the prompt was never reached. That
# hook is dormant since 2026-09-03 (planlab dropped its Read() deny rules,
# so the prompt no longer arms); it stays as a reference implementation.
# Re-arming and retirement: docs/bypass-cd-read-guard.md.
#
typeset -g CLAUDE_ACCOUNTS_ROOT="$HOME/.claude-accounts"
typeset -ga CLAUDE_X_BYPASS=(--dangerously-skip-permissions)
typeset -g CLAUDE_PRIMARY_NAME="qiushi"   # x-qiushi ≡ default ~/.claude
# headroom derives the primary's name from the logged-in email unless told;
# pin it to ours so `.current`, `--account qiushi` and x-qiushi agree even
# across a primary logout. Exported: the launchers, tmux and hooks all inherit it.
export HEADROOM_PRIMARY_NAME="$CLAUDE_PRIMARY_NAME"
# The board advertises `headroom launch --account <name>` by default; this
# shell has x-<name> for every account, so let it promise that spelling.
export HEADROOM_LAUNCHER_FORMAT="x-%s"
# Local parts that never get a short launcher alias: x-<these> are utilities.
# Purely this file's concern — headroom advertises only the guaranteed
# x-<email> identities, so there is no naming policy to keep in sync anymore.
typeset -ga CLAUDE_X_RESERVED=(usage account account-add select accounts acc check)

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
    [[ "${d:t}" == *.lock ]] && continue  # stranded vendor lock dir, not an account
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
x-account()        { claude-account "$@" }
x-account-add()    { claude-account-add "$@" }
x-account-remove() { claude-account-remove "$@" }
x-check()       { headroom check "$@" }
# Account board (headroom accounts): live usage for every account, refreshing
# itself while it is open. Enter repins bare `x` and exits — deliberately no
# launch chained on: "change the default account" and "start a session" are
# separate decisions, and when a session is wanted it is one keystroke (`x`)
# away. Bare `headroom` is the same board, so this is the only wrapper it
# needs.
x-accounts()    { headroom accounts "$@" }
x-acc()         { x-accounts "$@" }
# Session picker (headroom sessions): every session on the machine, entered
# in its own project dir and continued — by exec, inside headroom — on the
# account that last drove it. Nothing routing-shaped crosses back into this
# shell; the old decision-line protocol is a tombstone (`headroom resume`
# exits 2 with a stale-shell message — if you are reading that, exec zsh).
# The advisory cd file carries exactly one fact: empty means no launch was
# committed (cancel or refusal — do not cd), non-empty means headroom
# entered that dir, and the cd then sticks here regardless of how claude
# exited. mktemp per invocation, never a fixed path: two concurrent shells
# sharing one file would cd each other. Deliberately no --remember:
# resuming a session never moves where bare `x` points — only the board's
# enter (x-acc) does that.
x-select() {
  emulate -L zsh
  if ! command -v headroom >/dev/null 2>&1; then
    print -u2 "claude accounts: headroom not found (is ~/.local/bin on PATH?) — claude was not started"
    return 127
  fi
  local tmp rc dir
  tmp=$(mktemp -d "${${TMPDIR:-/tmp}%/}/x-select.XXXXXX") || return
  headroom sessions --cd-file "$tmp/cwd" -- "${CLAUDE_X_BYPASS[@]}" "$@"
  rc=$?
  if [[ -s "$tmp/cwd" ]]; then
    dir="$(<"$tmp/cwd")"
    if [[ "$dir" == /* ]]; then
      cd -- "$dir"
    else
      print -u2 "x-select: ignoring malformed cd advice: $dir"
    fi
  fi
  rm -rf "$tmp"
  return $rc
}

# Launch claude through headroom, which owns the whole decision: name
# validation, the shared-sessions topology check, and the child environment.
# This wrapper parses nothing back — the resolve round-trip and the shell-side
# topology preflight moved into the binary after the 2026-08-03 incident,
# because a check that lives in a shell function is frozen at shell init and
# a stale copy is worse than none.
#
#   _claude_launch <name|""> [claude args...]
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
  local sel="$1"; shift
  if ! command -v headroom >/dev/null 2>&1; then
    print -u2 "claude accounts: headroom not found (is ~/.local/bin on PATH?) — claude was not started"
    return 127
  fi
  # Claude Code ignores TMPDIR: its temp base is CLAUDE_CODE_TMPDIR or a
  # hardcoded /tmp, with claude-<uid>/ appended (verified in the 2.1.215
  # binary). Uncomment to make Ctrl+G prompt files (and all other Claude
  # temp files — child-process caches included) land in ./.tmp instead;
  # cleanup becomes manual, so it stays off by default.
  # CLAUDE_CODE_TMPDIR="$PWD/.tmp" \
  if [[ -n "$sel" ]]; then
    headroom launch --account "$sel" -- "$@"
  else
    headroom launch -- "$@"
  fi
}

# Bypassed permissions on the default account (.current; the board's enter
# is what moves it).
x() {
  emulate -L zsh
  _claude_launch "" "${CLAUDE_X_BYPASS[@]}" "$@"
}

# Prompted (no bypass) session on any account; bare `x`'s target untouched.
claude-account() {
  emulate -L zsh
  if [[ -z "${1-}" ]]; then
    echo "usage: claude-account <name|email> [claude args...]" >&2
    return 1
  fi
  local name; name=$(_claude_canonical "$1"); shift
  _claude_launch "$name" "$@"
}

# Onboard a subscription: `headroom accounts add` owns the seeding (dir,
# projects/ → the machine-global store, the topology check it must pass);
# what is personal here is the share source — the tracked config package in
# this repo, every entry of it — and regenerating the launchers afterwards.
claude-account-add() {
  emulate -L zsh
  headroom accounts add --share-config="$HOME/dotfiles/claude/.claude" "$@" || return $?
  _claude_gen_launchers
  [[ "${1-}" == *@* ]] && echo "launcher: $(_claude_selector "$1")"
  return 0
}

# Retire a subscription (or delete stranded `<dir>.lock` debris): the engine
# refuses while a session is live, asks for the dir name back, deletes the
# account's own Keychain item and the dir, scrubs `.order`, and leaves
# `.current` for the board to repick. Transcripts are machine-global and
# survive. This wrapper only drops the launchers the shell generated.
claude-account-remove() {
  emulate -L zsh
  headroom accounts remove "$@" || return $?
  local a
  for a in "$@"; do
    [[ "$a" == -* ]] && continue
    unfunction "x-$a" 2>/dev/null || true
  done
  _claude_gen_launchers
  echo "exec zsh drops stale short aliases; x-acc repicks if bare x pointed here"
  return 0
}

# Generate launchers for every account dir. Each starts one session on its
# account and nothing more — deliberately no --remember: a named launch is
# scoped ("this session, that account"), and a pin riding along as its side
# effect let a two-minute hop to another account silently retarget every
# later bare `x`. Only the board's enter moves `.current`; `headroom launch
# --remember` remains the explicit spelling. x-<email> always exists and is
# the guaranteed identity; a short x-<local-part> alias is added only when
# the local part is unique among accounts and isn't the primary's name, so
# a short name can never launch the wrong account with permissions
# bypassed. Short aliases are this file's convenience alone — headroom
# advertises the full identity.
# Runs at every shell init: one glob, no subprocess — startup-perf safe.
_claude_gen_launchers() {
  emulate -L zsh
  local d email name
  local -A count   # local part → number of accounts claiming it
  for d in "$CLAUDE_ACCOUNTS_ROOT"/*(/N); do
    [[ "${d:t}" == *.lock ]] && continue  # stranded vendor lock dir, not an account
    name="${${d:t}%%@*}"
    count[$name]=$(( ${count[$name]:-0} + 1 ))
  done
  for d in "$CLAUDE_ACCOUNTS_ROOT"/*(/N); do
    [[ "${d:t}" == *.lock ]] && continue
    email="${d:t}" name="${email%%@*}"
    functions[x-$email]="_claude_launch ${(q)email} \"\${CLAUDE_X_BYPASS[@]}\" \"\$@\""
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
  functions[x-$CLAUDE_PRIMARY_NAME]="_claude_launch $CLAUDE_PRIMARY_NAME \"\${CLAUDE_X_BYPASS[@]}\" \"\$@\""
}
_claude_gen_launchers
