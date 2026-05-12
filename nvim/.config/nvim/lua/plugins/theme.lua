-- Colorscheme selection is driven by $TERMINAL_THEME via lua/config/theme.lua.
-- Only the matching plugin is enabled; restart Neovim after switching themes.

local theme = require("config.theme")

return {
  {
    "folke/tokyonight.nvim",
    enabled = false,
    opts = { style = "storm" },
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
    enabled = theme.name == "catppuccin_mocha",
    priority = 1000,
    lazy = false,
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
    "kepano/flexoki-neovim",
    name = "flexoki",
    enabled = theme.name == "flexoki_light",
    priority = 1000,
    lazy = false,
    init = function()
      vim.o.background = theme.background
    end,
    opts = {
      variant = theme.background,
    },
    config = function(_, opts)
      require("flexoki").setup(opts)
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = theme.colorscheme },
  },
}
