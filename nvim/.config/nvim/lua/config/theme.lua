-- Resolves the active terminal theme (env → ~/.config/terminal-theme →
-- flexoki_light) and maps it to a colorscheme + background. The live-swap
-- watcher in config/autocmds.lua reuses M.map. See docs/theming.md.

local M = {}

local function read_theme_file()
  local f = io.open(vim.fn.expand("~/.config/terminal-theme"), "r")
  if not f then return nil end
  local line = f:read("*l") or ""
  f:close()
  line = line:gsub("%s+", "")
  return line ~= "" and line or nil
end

local function resolve()
  -- File-first, like the Claude statusline (and the live-swap watcher in
  -- config/autocmds.lua): ~/.config/terminal-theme is the live source of truth
  -- that theme-set rewrites. A nvim launched from a shell that started *before* a
  -- switch inherited a now-stale $TERMINAL_THEME (it's only a per-shell snapshot,
  -- fixed at shell startup); trusting that env over the file made startup revert
  -- to whatever the launching shell still held. Read the file first so every
  -- startup tracks the current theme regardless of stale env; env/default back it.
  local name = read_theme_file()
  if name then return name end
  local env = vim.env.TERMINAL_THEME
  if env and env ~= "" then return env end
  return "flexoki_light"
end

local map = {
  flexoki_light    = { colorscheme = "flexoki-light",            background = "light" },
  catppuccin_mocha = { colorscheme = "catppuccin",               background = "dark"  },
  tailwind_light   = { colorscheme = "tailwind-light-contrast",  background = "light" },
  tokyo_night_moon = { colorscheme = "tokyonight-moon",          background = "dark"  },
  gruvbox_dark     = { colorscheme = "gruvbox",                  background = "dark"  },
}

M.name = resolve()
local entry = map[M.name]
if not entry then
  vim.notify(
    ("config.theme: unknown TERMINAL_THEME '%s', falling back to flexoki_light"):format(M.name),
    vim.log.levels.WARN
  )
  M.name = "flexoki_light"
  entry = map.flexoki_light
end

M.colorscheme = entry.colorscheme
M.background = entry.background
-- exposed so the live-theme watcher (config/autocmds.lua) can resolve any
-- theme name written to ~/.config/terminal-theme, not just the startup one.
M.map = map

return M
