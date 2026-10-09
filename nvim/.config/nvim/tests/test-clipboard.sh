#!/usr/bin/env bash
# Neovim's clipboard where Claude Code's Ctrl+G editor opens (lua/config/
# options.lua): P reads the host's pasteboard, where `brief start` leaves its
# pickup prompt, both pressed at once on startup and later; y writes that
# pasteboard, so yy/P round-trips; and y also goes out through the terminal
# (OSC 52) wherever the screen may be another machine's: over ssh, and in any
# Rex pane, whatever SSH variables the Rex server handed it.
# Runs whole: bash test-clipboard.sh
#
# The case that bought this suite: a Rex pane carries SSH_CONNECTION without
# SSH_TTY, LazyVim blanked 'clipboard' on the first while the override keyed
# on the second, and P pasted an empty register instead of the pickup prompt.
#
# Isolation: pbcopy and pbpaste are stubs on PATH over a sandbox file, so the
# real pasteboard is never read or written (the last check asserts it). Each
# nvim runs with a UI on a pty under script(1), whose typescript keeps what it
# sent to the terminal. A temp HOME holds ~/.config/terminal-theme; XDG config
# links the working tree's config, XDG state/cache are temp; TMUX/TMUX_PANE are
# unset. Plugins are read from the real ~/.local/share/nvim.

set -u
REPO_NVIM=$(cd "$(dirname "$0")/.." && pwd)
REAL_DATA=${XDG_DATA_HOME:-$HOME/.local/share}
REAL_CLIP_BEFORE=$(/usr/bin/pbpaste | shasum)
T=$(cd "$(mktemp -d)" && pwd -P)
NVIM_PID=
trap '[ -n "$NVIM_PID" ] && kill "$NVIM_PID" 2>/dev/null; rm -rf "$T"' EXIT
FAIL=0

mkdir -p "$T/home/.config" "$T/cfg" "$T/state" "$T/cache" "$T/bin"
ln -s "$REPO_NVIM" "$T/cfg/nvim"
printf 'tokyo_night_moon\n' >"$T/home/.config/terminal-theme"
cat >"$T/bin/pbcopy" <<EOF
#!/bin/sh
cat >"$T/pasteboard"
EOF
cat >"$T/bin/pbpaste" <<EOF
#!/bin/sh
cat "$T/pasteboard"
EOF
chmod +x "$T/bin/pbcopy" "$T/bin/pbpaste"
export HOME="$T/home" XDG_CONFIG_HOME="$T/cfg" XDG_DATA_HOME="$REAL_DATA" \
  XDG_STATE_HOME="$T/state" XDG_CACHE_HOME="$T/cache" TERMINAL_THEME= \
  PATH="$T/bin:$PATH"
unset TMUX TMUX_PANE
SOCK="$T/n.sock"

ok() { echo "ok   $1"; }
bad() { echo "FAIL $1: $2"; FAIL=1; }
check() { [ "$2" = "$3" ] && ok "$1" || bad "$1" "expected '$2', got '$3'"; }
R() { nvim --server "$SOCK" --remote-expr "$1" 2>/dev/null; }
pasteboard() { cat "$T/pasteboard"; }
# The text of every OSC 52 copy the case's nvim sent to its terminal.
osc52_sent() {
  perl -MMIME::Base64 -ne 'print decode_base64($1), "\n" while /\e\]52;c;([A-Za-z0-9+\/=]*)/g' "$T/ts.$1"
}

# start <case> <env assignment>...: nvim on a pty in the given environment,
# with the SSH and Rex variables of the shell running the suite cleared first.
# A P queued for the moment startup ends records what it pasted.
start() {
  local name=$1; shift
  printf 'pickup prompt %s' "$name" >"$T/pasteboard"
  rm -f "$SOCK"
  script -q "$T/ts.$name" env -u SSH_CONNECTION -u SSH_CLIENT -u SSH_TTY -u REX_BLOCK -u REX_SESSION \
    "$@" TERM=xterm-256color nvim --listen "$SOCK" \
    --cmd 'autocmd VimEnter * ++once lua vim.schedule(function() pcall(vim.cmd, "normal! P") vim.g.startup_paste = vim.fn.getline(1) end)' \
    --cmd 'autocmd User VeryLazy ++once let g:very_lazy = 1' \
    "$T/x.txt" </dev/null >/dev/null 2>&1 &
  NVIM_PID=$!
  for _ in $(seq 100); do
    [ -S "$SOCK" ] && [ "$(R 'get(g:, "very_lazy", 0)')" = 1 ] && [ "$(R 'exists("g:startup_paste")')" = 1 ] && return
    sleep 0.1
  done
  bad "$name" "nvim did not finish starting"
}
stop() { R 'execute("qa!")' >/dev/null; wait "$NVIM_PID" 2>/dev/null; NVIM_PID=; }

empty() { R 'luaeval("vim.api.nvim_buf_set_lines(0, 0, -1, false, {})")' >/dev/null; }
line() { R "luaeval('vim.api.nvim_buf_set_lines(0, 0, -1, false, { \"$1\" })')" >/dev/null; }
normal() { R "execute('normal! $1')" >/dev/null; }

# case <name> <terminal: yes|no> <env assignment>...
case_() {
  local name=$1 terminal=$2; shift 2
  start "$name" "$@"
  check "$name: P at startup reads the pasteboard" "pickup prompt $name" "$(R 'g:startup_paste')"
  printf 'later prompt %s' "$name" >"$T/pasteboard"
  empty; normal P
  check "$name: P after startup reads the pasteboard" "later prompt $name" "$(R 'getline(1)')"
  line "yank $name"; normal yy
  check "$name: yy writes the pasteboard" "yank $name" "$(pasteboard | tr -d '\n')"
  empty; normal P
  check "$name: yy then P round-trips" "yank $name" "$(R 'getline(1)')"
  stop
  local sent; sent=$(osc52_sent "$name" | grep -cx "yank $name")
  if [ "$terminal" = yes ]; then
    check "$name: yy goes out through the terminal" 1 "$sent"
  else
    check "$name: yy stays off the terminal" 0 "$sent"
  fi
}

case_ rex-ssh yes REX_BLOCK=block:t 'SSH_CONNECTION=10.0.0.1 1 10.0.0.2 22' 'SSH_CLIENT=10.0.0.1 1 22'
case_ rex-bare yes REX_BLOCK=block:t
case_ ssh yes 'SSH_CONNECTION=10.0.0.1 1 10.0.0.2 22' 'SSH_CLIENT=10.0.0.1 1 22' SSH_TTY=/dev/ttys999
case_ screen no

check "the real pasteboard is untouched" "$REAL_CLIP_BEFORE" "$(/usr/bin/pbpaste | shasum)"
exit "$FAIL"
