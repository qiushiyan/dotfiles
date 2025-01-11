return {
  -- { "ellisonleao/gruvbox.nvim", transparent_mode = true },
  -- { "shaunsingh/nord.nvim" },
  {
    "folke/tokyonight.nvim",
    ---@class tokyonight.Config
    opts = {
      style = "storm",
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
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
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },
  -- border highlight when background is transparent
  {
    "hrsh7th/nvim-cmp",
    opts = function(_, opts)
      opts.window = {
        completion = {
          border = "rounded",
          winhighlight = "Normal:MyHighlight",
          winblend = 0,
        },
        documentation = {
          border = "rounded",
          winhighlight = "Normal:MyHighlight",
          winblend = 0,
        },
      }
    end,
  },
  {
    "williamboman/mason.nvim",
    opts = {
      ui = {
        border = "rounded",
      },
    },
  },
  {
    "folke/noice.nvim",
    opts = {
      presets = {
        lsp_doc_border = true,
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      DIAGNOSTICS = {
        float = {
          border = "rounded",
        },
      },
    },
  },
}
