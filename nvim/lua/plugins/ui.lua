-- Manages tabline and statusline
-- clear lualine's statusline and configure tabline
-- disable buffline
-- hide stastusline

return {
  {
    "akinsho/bufferline.nvim",
    enabled = false,
    opts = {
      -- options = {
      --   mode = "tabs",
      --   tab_size = 1,
      --   always_show_bufferline = true,
      -- },
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
          component_separators = "", -- ┊ |        
          section_separators = "", -- { left = "", right = "" },
        },
        sections = {
          -- lualine_a = {},
          -- lualine_b = {},
          -- lualine_c = {},
          -- lualine_x = {},
          -- lualine_y = {},
          -- lualine_z = {},
        },
        tabline = {
          lualine_a = {
            { LazyVim.lualine.pretty_path() },
          },
          lualine_b = {
            {
              "mode",
              fmt = function(str)
                return str:sub(1, 1)
              end,
              color = { gui = "bold" },
            },
          },
          lualine_c = {
            "branch",
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
          lualine_x = {
            { "filetype", icon_only = false, padding = { left = 1, right = 1 } },
          },
          lualine_y = {
            {
              function()
                local venv = os.getenv("CONDA_DEFAULT_ENV") or os.getenv("VIRTUAL_ENV") or "No Env"
                return " " .. venv
              end,
              cond = function()
                return vim.bo.filetype == "python"
              end,
            },
            -- { "location", padding = { left = 0, right = 1 } },
          },
          lualine_z = {},
        },
        extensions = { "neo-tree", "lazy" },
      }

      return opts
    end,
  },
}
