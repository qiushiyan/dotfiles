return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        quarto = { "prettier" },
      },
      -- Ensure prettier is configured for quarto
      formatters = {
        prettier = {
          -- Add quarto to prettier's supported file types
          prepend_args = { "--parser", "markdown" },
        },
      },
    },
  },
}
