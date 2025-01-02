-- Manages tabline and statusline
-- clear lualine's statusline and configure tabline
-- disable buffline
-- hide stastusline

return {
  {
    "akinsho/bufferline.nvim",
    enabled = false,
    opts = {
      options = {
        mode = "tabs",
        tab_size = 1,
        always_show_bufferline = true,
      },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function()
      -- PERF: we don't need this lualine require madness 🤷
      local lualine_require = require("lualine_require")
      lualine_require.require = require
      local icons = LazyVim.config.icons

      local opts = {
        options = {
          theme = "auto",
          globalstatus = vim.o.laststatus == 3,
          disabled_filetypes = { statusline = { "dashboard", "alpha", "ministarter", "snacks_dashboard" } },
          component_separators = "",
          section_separators = "",
        },
        sections = {
          -- lualine_a = {},
          lualine_b = {
            "branch",
          },
          lualine_c = {},
          lualine_x = {
            {
              "diagnostics",
              symbols = {
                error = icons.diagnostics.Error,
                warn = icons.diagnostics.Warn,
                info = icons.diagnostics.Info,
                hint = icons.diagnostics.Hint,
              },
            },
          },
          lualine_y = {
            { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
            { LazyVim.lualine.pretty_path() },
          },
          -- lualine_z = {},
        },
        -- tabline = {
        --   lualine_a = {
        --     { LazyVim.lualine.pretty_path() },
        --   },
        --   lualine_b = {
        --     {
        --       "mode",
        --       fmt = function(str)
        --         return str:sub(1, 1)
        --       end,
        --       color = { gui = "bold" },
        --     },
        --   },
        --   lualine_c = {
        --     "branch",
        --     {
        --       "diagnostics",
        --       symbols = {
        --         error = icons.diagnostics.Error,
        --         warn = icons.diagnostics.Warn,
        --         info = icons.diagnostics.Info,
        --         hint = icons.diagnostics.Hint,
        --       },
        --     },
        --   },
        --   lualine_x = {
        --     { "filetype", icon_only = false, padding = { left = 1, right = 1 } },
        --   },
        --   lualine_y = {
        --     {
        --       function()
        --         local venv = os.getenv("CONDA_DEFAULT_ENV") or os.getenv("VIRTUAL_ENV") or "No Env"
        --         return " " .. venv
        --       end,
        --       cond = function()
        --         return vim.bo.filetype == "python"
        --       end,
        --     },
        --     -- { "location", padding = { left = 0, right = 1 } },
        --   },
        --   lualine_z = {},
        -- },
        extensions = { "neo-tree", "lazy" },
      }

      return opts
    end,
  },
  {
    "folke/snacks.nvim",
    ---@type snacks.Config
    opts = {
      -- disable smooth scrolling
      scroll = { enabled = false },
    },
  },
  {
    "echasnovski/mini.icons",
    opts = {
      style = "glyph",
    },
  },
  -- Neovim notifications and LSP progress messages
  {
    "j-hui/fidget.nvim",
    branch = "legacy",
    enabled = false,
    config = function()
      require("fidget").setup({
        window = { blend = 0 },
      })
    end,
  },
  {
    "utilyre/barbecue.nvim",
    name = "barbecue",
    version = "*",
    dependencies = {
      "SmiteshP/nvim-navic",
      "nvim-tree/nvim-web-devicons", -- optional dependency
    },
    opts = {
      -- configurations go here
    },
    config = function()
      require("barbecue").setup({
        create_autocmd = false, -- prevent barbecue from updating itself automatically
      })

      vim.api.nvim_create_autocmd({
        "WinScrolled", -- or WinResized on NVIM-v0.9 and higher
        "BufWinEnter",
        "CursorHold",
        "InsertLeave",

        -- include this if you have set `show_modified` to `true`
        -- "BufModifiedSet",
      }, {
        group = vim.api.nvim_create_augroup("barbecue.updater", {}),
        callback = function()
          require("barbecue.ui").update()
        end,
      })
    end,
  },
}
