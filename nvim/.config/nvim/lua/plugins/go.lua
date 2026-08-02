-- Go. The `lang.go` extra already brings gopls, gofumpt + goimports via
-- conform, and the go/gomod/gowork/gosum parsers. This file covers what it
-- leaves out.

-- LazyVim keeps client-side codelens off globally, which leaves the extra's
-- carefully-configured `codelenses` server settings inert — gopls computes the
-- lenses and nothing draws them. Turn the display on for gopls buffers only:
-- `run test` above each test func, `go generate` above each directive, and
-- tidy / govulncheck / upgrade on go.mod. With no neotest adapter in this
-- config, that first one is the only way to run a single test from the buffer.
-- `<leader>cc` runs the lens under the cursor; it is already bound by LazyVim.
--
-- `codelens.enable` is the nvim 0.12 capability API: it drives refresh itself
-- via a decoration provider, so this needs none of the BufEnter/CursorHold
-- refresh autocmds LazyVim's own (older) codelens path installs.
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("go_codelens", { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client.name == "gopls" then
      vim.lsp.codelens.enable(true, { bufnr = ev.buf })
    end
  end,
})

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gopls = {
          settings = {
            gopls = {
              -- Flag vulnerable dependencies from the import graph, without
              -- the call-graph analysis a full govulncheck run does.
              -- Default is "Prompt", i.e. only on request.
              vulncheck = "Imports",
            },
          },
        },
        -- golangci-lint as a language server: it lints on save and caches,
        -- rather than re-running the whole linter on every buffer event.
        -- lspconfig picks the right CLI flags for golangci-lint v1 vs v2.
        golangci_lint_ls = {},
      },
    },
  },

  -- The extra pins three analyzers that gopls has since turned on by default
  -- (nilness, unusedparams, unusedwrite) plus `useany`, which was folded into
  -- the `any` modernizer and is no longer a valid key. Drop the dead one; a
  -- table literal can't, since a nil value is just an absent key to the merge.
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local analyses = vim.tbl_get(opts, "servers", "gopls", "settings", "gopls", "analyses")
      if analyses then
        analyses.useany = nil
      end
    end,
  },

  -- With golangci-lint served over LSP above, the extra's nvim-lint entry
  -- would be a second, slower source of the same diagnostics.
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      if opts.linters_by_ft then
        opts.linters_by_ft.go = nil
      end
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "gotmpl" } },
  },

  {
    "mason-org/mason.nvim",
    opts = {
      -- gofumpt and goimports come from the extra. The extra's gomodifytags
      -- and impl are deliberately absent: it only wires them up through
      -- none-ls, which isn't used here, and modern gopls covers them itself
      -- ("Add struct tags", "Add test for …", declare missing methods).
      ensure_installed = {
        "gopls",
        "golangci-lint",
        "golangci-lint-langserver",
      },
    },
  },
}
