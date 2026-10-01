#!/usr/bin/env bash
# The lualine band (lua/plugins/ui.lua) follows the active colorscheme's own
# StatusLine bg and Normal fg, at startup and across a live theme switch.
# Runs whole: bash test-statusline-band.sh
#
# Isolation: a temp HOME holds ~/.config/terminal-theme (the startup theme and
# the live-swap watcher's file); XDG config links the working tree's config,
# XDG state/cache are temp; TMUX/TMUX_PANE are unset so the path-publishing
# autocmd cannot reach the live tmux server. Plugins are read from the real
# ~/.local/share/nvim.

set -u
REPO_NVIM=$(cd "$(dirname "$0")/.." && pwd)
REAL_DATA=${XDG_DATA_HOME:-$HOME/.local/share}
T=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$T"' EXIT
FAIL=0

mkdir -p "$T/home/.config" "$T/cfg" "$T/state" "$T/cache"
ln -s "$REPO_NVIM" "$T/cfg/nvim"
export HOME="$T/home" XDG_CONFIG_HOME="$T/cfg" XDG_DATA_HOME="$REAL_DATA" \
  XDG_STATE_HOME="$T/state" XDG_CACHE_HOME="$T/cache" TERMINAL_THEME=
unset TMUX TMUX_PANE
SOCK="$T/n.sock"

ok() { echo "ok   $1"; }
bad() { echo "FAIL $1: $2"; FAIL=1; }
R() { nvim --server "$SOCK" --remote-expr "$1" 2>/dev/null; }

# "<band bg>/<band fg> <StatusLine bg>/<Normal fg>", reverse resolved.
band() {
  R "luaeval('(function()
    local function c(g, a)
      local h = vim.api.nvim_get_hl(0, { name = g, link = false })
      if h.reverse then h.fg, h.bg = h.bg, h.fg end
      return h[a] and string.format(\"#%06x\", h[a]) or \"-\"
    end
    return c(\"lualine_a_normal\", \"bg\") .. \"/\" .. c(\"lualine_a_normal\", \"fg\")
      .. \" \" .. c(\"StatusLine\", \"bg\") .. \"/\" .. c(\"Normal\", \"fg\")
  end)()')"
}

# Start nvim on terminal theme $1; fire UIEnter, which headless never does, so
# lazy.nvim's VeryLazy loads lualine as it would under a UI.
start() {
  printf '%s\n' "$1" >"$HOME/.config/terminal-theme"
  rm -f "$SOCK"
  nvim --headless --listen "$SOCK" "$T/x.txt" >/dev/null 2>&1 &
  NVIM_PID=$!
  for _ in $(seq 50); do
    [ -S "$SOCK" ] && [ "$(R 'v:vim_did_enter')" = 1 ] && break
    sleep 0.1
  done
  R 'execute("doautocmd UIEnter")' >/dev/null
  for _ in $(seq 30); do
    [ "$(R 'hlexists("lualine_a_normal")')" = 1 ] && break
    sleep 0.1
  done
}
stop() { kill "$NVIM_PID" 2>/dev/null; wait "$NVIM_PID" 2>/dev/null; }

# B1: a plugin theme without a hand-written band (tokyonight) gets its own
# StatusLine bg, not another theme's leftover.
start tokyo_night_moon
read -r got want <<<"$(band)"
[ "$got" = "$want" ] && [ "$want" != "-/-" ] && ok B1 || bad B1 "band $got, theme $want"

# B2: a live switch re-derives the band from the new theme. The switch arrives
# the way theme-set sends it, an atomic rewrite of the theme file, so the
# file watcher (config/theme.lua, registered from config/autocmds.lua) is what
# has to apply it; it polls once a second.
printf 'vellum\n' >"$HOME/.config/terminal-theme.tmp"
mv -f "$HOME/.config/terminal-theme.tmp" "$HOME/.config/terminal-theme"
for _ in $(seq 50); do
  [ "$(R 'g:colors_name')" = vellum ] && break
  sleep 0.1
done
[ "$(R 'g:colors_name')" = vellum ] && ok "B2 the watcher applies the rewritten theme" \
  || bad B2 "colorscheme still $(R 'g:colors_name') after the theme file changed"
read -r got want <<<"$(band)"
[ "$got" = "$want" ] && [ "$want" = "#f5ead8/#1f2022" ] && ok B2 || bad B2 "band $got, theme $want"
stop

exit $FAIL
