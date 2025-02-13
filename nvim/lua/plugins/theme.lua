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
      on_highlights = function(hl, colors)
        hl.CursorLine = {
          bg = "#363b52",
        }
        hl.CursorLineNr = {
          fg = "yellow",
        }
      end,
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    lazy = false,
    opts = {
      flavour = "mocha",
      highlight_overrides = {
        mocha = function(mocha)
          return {
            CursorLine = { bg = mocha.surface0 },
            CursorLineNr = {
              fg = "yellow",
            },
          }
        end,
      },
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
      colorscheme = "catppuccin",
    },
  },
}
