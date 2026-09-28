-- JS/TS: oxfmt only in projects that configure it, prettier everywhere else.
-- oxfmt reads only its own config, so running it in a prettier project ignores
-- .prettierrc (quotes, bracket spacing, import-sort plugins) and rewrites the
-- file in a style the repo doesn't use. Prettier finds the project's config
-- on its own; with no config either way, both produce prettier's defaults.
-- conform prefers a project-local node_modules binary for both.
-- Not vite.config.*: conform's oxfmt treats it as a Vite+ config file, but
-- plain Vite projects have one too.
local oxfmt_configs = { ".oxfmtrc.json", ".oxfmtrc.jsonc", "oxfmt.config.ts" }

local function oxfmt_or_prettier(bufnr)
  return { vim.fs.root(bufnr, oxfmt_configs) and "oxfmt" or "prettier" }
end

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        typescript = oxfmt_or_prettier,
        typescriptreact = oxfmt_or_prettier,
        javascript = oxfmt_or_prettier,
        javascriptreact = oxfmt_or_prettier,
        json = { "prettier" },
        -- markdown is oxfmt everywhere (it formats prose *and* embedded code
        -- blocks). Never runs on save -- see the autoformat opt-out in
        -- conform.lua -- so it only ever runs when asked for.
        markdown = { "oxfmt" },
        yaml = { "prettier" },
      },
    },
  },
}
