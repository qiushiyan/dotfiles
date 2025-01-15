local border = {
  { "🭽", "FloatBorder" },
  { "▔", "FloatBorder" },
  { "🭾", "FloatBorder" },
  { "▕", "FloatBorder" },
  { "🭿", "FloatBorder" },
  { "▁", "FloatBorder" },
  { "🭼", "FloatBorder" },
  { "▏", "FloatBorder" },
}

return {
  {
    "R-nvim/R.nvim",
    lazy = false,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local keys = require("lazyvim.plugins.lsp.keymaps").get()
      keys[#keys + 1] = { "gy", false }

      opts.inlay_hints = { enabled = false }
      opts.servers.pyright = {}
      opts.filetype_opts = {
        typescriptreact = {
          spell = true,
        },
      }
      local on_publish_diagnostics = vim.lsp.diagnostic.on_publish_diagnostics
      opts.servers.bashls = vim.tbl_deep_extend("force", opts.servers.bashls or {}, {
        handlers = {
          ["textDocument/publishDiagnostics"] = function(err, res, ...)
            local file_name = vim.fn.fnamemodify(vim.uri_to_fname(res.uri), ":t")
            if string.match(file_name, "^%.env") == nil then
              return on_publish_diagnostics(err, res, ...)
            end
          end,
        },
      })
    end,
    keys = {
      {
        "gh",
        function()
          return vim.lsp.buf.hover()
        end,
        desc = "Hover",
      },
    },
  },
  {
    "dnlhc/glance.nvim",
    cmd = "Glance",
  },

  {
    "neovim/nvim-lspconfig",
    dependencies = { "dnlhc/glance.nvim" },
    opts = {
      servers = {
        vtsls = {
          keys = {
            {
              "gD",
              "<CMD>Glance definitions<CR>",
              desc = "Preview type definition",
            },
            {
              "<leader>cu",
              LazyVim.lsp.action["source.removeUnused.ts"],
              desc = "Remove unused imports",
            },
          },
        },
      },
    },
  },
}
