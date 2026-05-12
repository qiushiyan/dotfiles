-- Resolve the active terminal theme from (in order):
--   1. $TERMINAL_THEME env var
--   2. ~/.config/terminal-theme  (single line)
--   3. flexoki_light  (default)
--
-- Shared with zsh/.config/zsh/theme.zsh and
-- claude/.claude/commands/statusline-command.sh — keep the supported
-- values list in sync across all three.

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
  local env = vim.env.TERMINAL_THEME
  if env and env ~= "" then return env end
  return read_theme_file() or "flexoki_light"
end

local map = {
  flexoki_light    = { colorscheme = "flexoki-light", background = "light" },
  catppuccin_mocha = { colorscheme = "catppuccin",    background = "dark"  },
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

return M
