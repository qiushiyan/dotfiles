return {
  -- add gruvbox
  -- { "ellisonleao/gruvbox.nvim", transparent_mode = true },
  {
    "folke/tokyonight.nvim",
    enabled = true,
    opts = {
      -- transparent = true,
      styles = {
        -- sidebars = "transparent",
        -- floats = "transparent",
      },
    },
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight-night",
    },
  },
}
