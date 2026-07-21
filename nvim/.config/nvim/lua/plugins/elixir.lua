return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Expert is the Elixir core team's official LSP; the lang.elixir
        -- extra's elixir-ls (maintenance mode) stays off.
        expert = {},
        elixirls = { enabled = false },
      },
    },
  },
}
