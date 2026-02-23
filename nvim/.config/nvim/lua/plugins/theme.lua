-- Theme settings

return {
  {
    "folke/tokyonight.nvim",
    enabled = false,
    opts = {
      style = "storm",
      ---@class tokyonight.Config
      -- transparent = true,
      -- styles = {
      --   sidebars = "transparent",
      --   floats = "transparent",
      -- },
      -- on_highlights = function(hl, colors)
      --   hl.CursorLine = {
      --     bg = "#363b52",
      --   }
      --   hl.CursorLineNr = {
      --     fg = "yellow",
      --   }
      -- end,
    },
  },
  {
    "rose-pine/neovim",
    enabled = false,
    priority = 1000,
    lazy = false,
    opts = {
      variant = "dawn",
      styles = {
        bold = true,
        italic = false,
        transparency = false,
      },
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    enabled = false,
    priority = 1000,
    lazy = false,
    opts = {
      flavour = "latte",
      -- highlight_overrides = {
      --   all = function(colors)
      --     return {
      --       CursorLine = { bg = colors.surface0 },
      --       CursorLineNr = { fg = "yellow" },
      --     }
      --   end,
      -- },
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
    opts = {
      colorscheme = "tailwind-dark-contrast",
    },
  },
}
