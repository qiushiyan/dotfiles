return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        -- oxfmt (global install via pnpm; conform prefers a project-local
        -- node_modules binary when one exists) -- prettier-compatible output
        typescript = { "oxfmt" },
        typescriptreact = { "oxfmt" },
        javascript = { "oxfmt" },
        javascriptreact = { "oxfmt" },
        json = { "prettier" },
        -- markdown is oxfmt too (it formats prose *and* embedded code blocks).
        -- Never runs on save -- see the autoformat opt-out in conform.lua.
        markdown = { "oxfmt" },
        yaml = { "prettier" },
      },
    },
  },
}
