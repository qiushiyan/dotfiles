-- Resolves the active terminal theme (~/.config/terminal-theme → env →
-- gruber_darker), maps it to a colorscheme + background, and watches the file
-- for live swaps (M.watch, started from config/autocmds.lua). See
-- docs/theming.md.

local M = {}

local state = vim.fn.expand("~/.config/terminal-theme")

-- The theme name in ~/.config/terminal-theme, or nil when absent or empty.
function M.read()
  local f = io.open(state, "r")
  if not f then return nil end
  local line = f:read("*l") or ""
  f:close()
  line = line:gsub("%s+", "")
  return line ~= "" and line or nil
end

local function resolve()
  -- File-first, like the Claude statusline (and M.watch below):
  -- ~/.config/terminal-theme is the live source of truth
  -- that theme-set rewrites. A nvim launched from a shell that started *before* a
  -- switch inherited a now-stale $TERMINAL_THEME (it's only a per-shell snapshot,
  -- fixed at shell startup); trusting that env over the file made startup revert
  -- to whatever the launching shell still held. Read the file first so every
  -- startup tracks the current theme regardless of stale env; env/default back it.
  local name = M.read()
  if name then return name end
  local env = vim.env.TERMINAL_THEME
  if env and env ~= "" then return env end
  return "gruber_darker"
end

local map = {
  gruber_darker    = { colorscheme = "gruber-darker",            background = "dark"  },
  catppuccin_mocha = { colorscheme = "catppuccin",               background = "dark"  },
  tailwind_light   = { colorscheme = "tailwind-light-contrast",  background = "light" },
  tokyo_night_moon = { colorscheme = "tokyonight-moon",          background = "dark"  },
  gruvbox_dark     = { colorscheme = "gruvbox",                  background = "dark"  },
  vitesse_light_soft = { colorscheme = "vitesse-light-soft",     background = "light" },
  night_owl        = { colorscheme = "night-owl",                background = "dark"  },
  orng_light       = { colorscheme = "orng-light",               background = "light" },
  forest_night     = { colorscheme = "forest-night",             background = "dark"  },
  waffle_cat = { colorscheme = "waffle-cat", background = "dark" },
  vellum           = { colorscheme = "vellum",                   background = "light" },
  token_meridian_light = { colorscheme = "token-meridian-light", background = "light" },
  token_ultra_dark = { colorscheme = "token-ultra-dark", background = "dark" },
  raindrop = { colorscheme = "raindrop", background = "dark" },
}

M.name = resolve()
local entry = map[M.name]
if not entry then
  vim.notify(
    ("config.theme: unknown TERMINAL_THEME '%s', falling back to gruber_darker"):format(M.name),
    vim.log.levels.WARN
  )
  M.name = "gruber_darker"
  entry = map.gruber_darker
end

M.colorscheme = entry.colorscheme
M.background = entry.background

-- Switch a running nvim to the theme `name`; unknown names are ignored.
function M.apply(name)
  local e = map[name]
  if not e or e.colorscheme == vim.g.colors_name then
    return
  end
  vim.o.background = e.background
  pcall(vim.cmd.colorscheme, e.colorscheme)
end

-- Live theme switching. `theme-set` (the shared switcher behind tmux `prefix t`)
-- writes the canonical name to ~/.config/terminal-theme; every running nvim
-- watches that file and re-applies the matching colorscheme without a restart.
-- fs_poll, not fs_event: on macOS fs_event watches the inode and goes stale on
-- the atomic rename theme-set does, so it would only ever fire once. lazy.nvim's
-- ColorSchemePre autoloads the matching (lazy) colorscheme plugin when
-- :colorscheme runs, so swapping in any direction works.
function M.watch()
  if not (vim.uv and M.read()) then -- only watch if the state file exists
    return
  end
  local poll = vim.uv.new_fs_poll()
  if not poll then
    return
  end
  poll:start(state, 1000, vim.schedule_wrap(function(err)
    if err then
      return
    end
    local name = M.read()
    if name then
      M.apply(name)
    end
  end))
end

return M
