return {
  -- add gruvbox
  -- { "ellisonleao/gruvbox.nvim", transparent_mode = true },
  -- { "shaunsingh/nord.nvim" },
  {
    "folke/tokyonight.nvim",
    opts = {
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },
}
