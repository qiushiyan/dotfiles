return {
  {
    "mrjones2014/legendary.nvim",
    priority = 10000,
    lazy = false,
    keys = {
      {
        "<C-p>",
        function()
          require("legendary").open()
        end,
        mode = { "n" },
        desc = "Open command palette",
      },
    },
  },
}
