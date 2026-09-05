-- Colorscheme plugins for each terminal theme. All are installed (the active one
-- eager, the rest lazy) so the live-swap watcher can switch in any direction.
-- See docs/theming.md.

local theme = require("config.theme")

return {
  {
    "folke/tokyonight.nvim",
    -- Same pattern as catppuccin: always installed so the live-theme watcher can
    -- swap to it, eager only when active. "moon" is the variant the
    -- tokyo_night_moon terminal theme maps to (colorscheme "tokyonight-moon").
    priority = 1000,
    lazy = theme.name ~= "tokyo_night_moon",
    opts = { style = "moon" },
  },
  {
    "ellisonleao/gruvbox.nvim",
    -- Same pattern as the others: always installed so the live-theme watcher can
    -- swap to it, eager only when active. Plugin-only (no hand-rolled colors/
    -- file); registers the "gruvbox" colorscheme and reads vim.o.background,
    -- which config.options / the watcher set to "dark" for gruvbox_dark.
    priority = 1000,
    lazy = theme.name ~= "gruvbox_dark",
    opts = { contrast = "" }, -- "" = medium (#282828), matching Ghostty "Gruvbox Dark" + morhetz
  },
  {
    "oxfist/night-owl.nvim",
    -- Same pattern as the others: always installed so the live-theme watcher can
    -- swap to it, eager only when active. Plugin-only (no hand-rolled colors/
    -- file); registers the "night-owl" colorscheme — Sarah Drasner's Night Owl,
    -- the same palette as the Zed "Night Owl" theme and Ghostty's built-in
    -- "Night Owl" (bg #011627 / #021727, fg #d6deeb).
    priority = 1000,
    lazy = theme.name ~= "night_owl",
    opts = {},
  },
  {
    "rose-pine/neovim",
    enabled = false,
    priority = 1000,
    lazy = false,
    opts = {
      variant = "dawn",
      styles = { bold = true, italic = false, transparency = false },
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    -- Always installed so the live-theme watcher can swap to it; loaded eagerly
    -- only when it's the active theme, lazily otherwise (lazy.nvim's
    -- ColorSchemePre autoloads it the first time :colorscheme runs).
    priority = 1000,
    lazy = theme.name ~= "catppuccin_mocha",
    opts = {
      flavour = "mocha",
      integrations = {
        blink_cmp = true,
        mason = true,
        noice = true,
        copilot_vim = true,
        which_key = true,
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = theme.colorscheme },
  },
}
