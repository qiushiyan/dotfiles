return {
  "folke/noice.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  opts = {
    lsp = {
      hover = {
        -- Set not show a message if hover is not available
        -- ex: shift+k on Typescript code
        silent = true,
      },
    },
    routes = {
      { filter = { event = "msg_show", find = "search hit" }, skip = true },
      { filter = { event = "notify", find = "No information available" }, opts = { skip = true } },
      { view = "notify", filter = { event = "msg_showmode" } },
    },
  },
}
