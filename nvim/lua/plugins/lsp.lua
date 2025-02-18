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

      -- save keys for yanky
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
      {
        "gR",
        function()
          local word = vim.fn.expand("<cword>")
          require("fzf-lua").lsp_document_symbols({ query = word })
        end,
        desc = "References (current buffer)",
        nowait = true,
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        vtsls = {
          keys = {
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
