-- General plugin configurations
-- For specialized configs, see: fff.lua, snacks.lua, yanky.lua

return {
  -- Auto-create directories when saving files
  { "jghauser/mkdir.nvim" },

  -- Diagnostics
  {
    "folke/trouble.nvim",
    opts = { use_diagnostic_signs = true },
  },

  -- Treesitter parsers: highlighting for viewing files; LSPs are only
  -- configured for typescript, markdown, and config formats
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "bash",
        "html",
        "javascript",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "regex",
        "tsx",
        "typescript",
        "vim",
        "yaml",
      },
    },
  },

  -- left hand line numbers
  {
    "mluders/comfy-line-numbers.nvim",
    opts = {},
  },

  -- Mason tool installer
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "stylua",
        "shellcheck",
        "shfmt",
        "harper-ls",
      },
    },
  },
}
