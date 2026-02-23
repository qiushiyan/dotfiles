-- General plugin configurations
-- For specialized configs, see: outline.lua, git-blame.lua, fzf-extras.lua, yanky.lua

return {
  -- Terminal
  { "akinsho/toggleterm.nvim", version = "*", config = true },

  -- Auto-create directories when saving files
  { "jghauser/mkdir.nvim" },

  -- Lorem ipsum generator
  {
    "derektata/lorem.nvim",
    config = function()
      require("lorem").opts({
        sentenceLength = "medium",
        comma_chance = 0.2,
        max_commas_per_sentence = 2,
      })
    end,
  },

  -- Diagnostics
  {
    "folke/trouble.nvim",
    opts = { use_diagnostic_signs = true },
  },

  -- Add emoji completion source to nvim-cmp
  {
    "hrsh7th/nvim-cmp",
    dependencies = { "hrsh7th/cmp-emoji" },
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      table.insert(opts.sources, { name = "emoji" })
    end,
  },

  -- Telescope customizations
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      {
        "<leader>fp",
        function()
          require("telescope.builtin").find_files({ cwd = require("lazy.core.config").options.root })
        end,
        desc = "Find Plugin File",
      },
    },
    opts = {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = { prompt_position = "top" },
        sorting_strategy = "ascending",
        winblend = 0,
      },
    },
  },

  -- Buffer deletion without closing window
  {
    "famiu/bufdelete.nvim",
    event = "VeryLazy",
    config = function()
      vim.keymap.set(
        "n",
        "Q",
        ":lua require('bufdelete').bufdelete(0, false)<cr>",
        { noremap = true, silent = true, desc = "Delete buffer" }
      )
    end,
  },

  -- LazyVim language extras
  { import = "lazyvim.plugins.extras.lang.typescript" },
  { import = "lazyvim.plugins.extras.lang.json" },

  -- Treesitter parsers
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
    enable = true,
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
        "flake8",
        "harper-ls",
      },
    },
  },
}
