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
# projects/ symlinks to ~/.claude/projects (see _claude_link_projects and
# claude-sessions.zsh), so the resume picker sees every session regardless
# of account.
#
# Launch routing belongs to headroom (~/dev/headroom, installed to
# ~/.local/bin/headroom): `headroom launch` validates the account, verifies
# the shared-sessions topology, and builds the child environment from that
# decision alone — every inherited CLAUDE_CONFIG_DIR is stripped, exactly
# one is set for a non-primary — so a polluted shell (a tmux server started
# inside a Claude Code session) can never re-route a launch. These wrappers
# only add what is personal: seeding, flags, short aliases, and the one
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
  headroom sessions --cd-file "$tmp/cwd" -- --dangerously-skip-permissions "$@"
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
  _claude_launch "" --dangerously-skip-permissions "$@"
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

# Remove an account dir — or stranded `<dir>.lock` vendor debris — the
# inverse of claude-account-add. Refuses while the account has a live
# registered session; deletes the per-dir Keychain credential item (service
# "Claude Code-credentials-" + sha256(dir)[:8], the same derivation Claude
# Code and headroom use), then the dir, and scrubs the `.order` line.
# Transcripts are machine-global and survive: the picker shows the removed
# owner as degraded, and `x` on a row re-homes it. Nothing rewrites
# `.current` behind headroom's back — if bare `x` pointed here, `headroom
# launch` refuses (corrupt-vs-chosen stays distinguishable) until the
# board's enter repicks.
claude-account-remove() {
  emulate -L zsh
  if [[ "${1-}" != *@* && "${1-}" != *.lock ]] || [[ "$1" == */* ]]; then
    echo "usage: claude-account-remove <email> (or a stranded <dir>.lock)" >&2
    return 1
  fi
  local email="$1" dir="$CLAUDE_ACCOUNTS_ROOT/$1"
  if [[ ! -d "$dir" ]]; then
    echo "claude-account-remove: $dir does not exist" >&2
    return 1
  fi
  # A registered session whose pid is still alive refuses the removal:
  # deleting a config dir under a running claude orphans its login state.
  local f pid
  for f in "$dir"/sessions/*.json(N); do
    pid=$(grep -o '"pid":[0-9]*' "$f" 2>/dev/null | head -1)
    pid="${pid#*:}"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "claude-account-remove: live session (pid $pid, $f) — quit it first" >&2
      return 1
    fi
  done
  local login
  login=$(grep -o '"emailAddress": *"[^"]*"' "$dir/.claude.json" 2>/dev/null | head -1)
  login="${${login##*: \"}%\"}"; login="${${login##*:\"}%\"}"
  echo "removing $dir${login:+ (logged in as $login)}"
  printf 'type the dir name to confirm: '
  local reply; read -r reply
  if [[ "$reply" != "$email" ]]; then
    echo "aborted" >&2
    return 1
  fi
  # The Keychain item exists only if this dir ever ran /login; lock debris
  # and never-bound seeds have none, and that is not an error.
  local svc="Claude Code-credentials-$(printf %s "$dir" | shasum -a 256 | cut -c1-8)"
  if security delete-generic-password -s "$svc" -a "$USER" >/dev/null 2>&1; then
    echo "deleted Keychain item ($svc)"
  else
    echo "no Keychain item ($svc) — never logged in, or already gone"
  fi
  rm -rf -- "$dir"
  local ord="$CLAUDE_ACCOUNTS_ROOT/.order"
  if [[ -f "$ord" ]] && grep -Fqx "$email" "$ord"; then
    grep -Fvx "$email" "$ord" > "$ord.tmp" && mv "$ord.tmp" "$ord"
    echo "removed from .order"
  fi
  unfunction "x-$email" 2>/dev/null || true
  _claude_gen_launchers
  echo "removed $dir"
  echo "if bare x pointed here it now refuses — x-acc repicks; exec zsh drops stale short aliases"
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
    functions[x-$email]="_claude_launch ${(q)email} --dangerously-skip-permissions \"\$@\""
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
  functions[x-$CLAUDE_PRIMARY_NAME]="_claude_launch $CLAUDE_PRIMARY_NAME --dangerously-skip-permissions \"\$@\""
}
_claude_gen_launchers
