-- Enhanced yank/paste with history
return {
  "gbprod/yanky.nvim",
  keys = {
    {
      "gy",
      function()
        vim.cmd([[YankyRingHistory]])
      end,
      mode = { "n", "x" },
      desc = "Open Yank History",
    },
  },
}
