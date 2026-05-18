-- Change default LazyVim UI
-- disable file tabs on the top (bufferline)
-- resture lulaine items, filename on top and less items on the bottom
-- tweak lsp and notification window

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
      -- Auto-select palette based on current colorscheme
      local colors = require("config.palette").get_palette()

      -- Bar bg: each palette can expose a `bar_bg` accent (flexoki uses
      -- cyan-50 #EBF2E7 — a soft mint tint, different hue from neutral gray).
      -- Falls back to `mantle` for themes that don't define one.
      local bar_bg = colors.bar_bg or colors.mantle

      -- Uniform lualine theme: every section in every mode gets bar_bg so
      -- both the top tabline (incl. its filler region right of the filename)
      -- and the bottom statusline (incl. its empty middle) read as a single
      -- quiet band. Mode + progress/branch use bold to anchor the eye since
      -- we've dropped the per-mode accent color. Replaces theme = "auto".
      local section = { bg = bar_bg, fg = colors.text }
      local bold_section = vim.tbl_extend("force", section, { gui = "bold" })
      local mode_def = {
        a = bold_section, b = section, c = section,
        x = section,      y = section, z = bold_section,
      }
      local lualine_theme = {
        normal   = mode_def,
        insert   = mode_def,
        visual   = mode_def,
        replace  = mode_def,
        command  = mode_def,
        inactive = mode_def,
      }

      local opts = {
        options = {
          theme = lualine_theme,
          globalstatus = vim.o.laststatus == 3,
          disabled_filetypes = { statusline = { "dashboard", "alpha", "ministarter", "snacks_dashboard" } },
          component_separators = "",
          section_separators = "",
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = {},
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
          lualine_y = {},
          lualine_z = {
            { "progress", pading = { right = 0 } },
            { "branch", padding = { left = 1, right = 1 } },
          },
        },
        tabline = {
          lualine_a = {
            { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
            { LazyVim.lualine.pretty_path() },
          },
          lualine_x = {
            {
              function()
                local venv = os.getenv("CONDA_DEFAULT_ENV") or os.getenv("VIRTUAL_ENV") or "No Env"
                return "  " .. venv
              end,
              cond = function()
                return vim.bo.filetype == "python"
              end,
              color = {
                fg = colors.subtext1,
                bg = bar_bg,
                gui = "italic",
              },
            },
          },
        },
        extensions = { "lazy" },
      }

      return opts
    end,
  },
  {
    "nvim-mini/mini.icons",
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
    enabled = false,
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
  -- border highlight when background is transparent
  {
    "mason-org/mason.nvim",
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
