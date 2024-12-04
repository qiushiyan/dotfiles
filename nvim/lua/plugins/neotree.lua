return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    window = {
      position = "right",
    },
    filesystem = {
      filtered_items = {
        visible = true,
        show_hidden_count = true,
        hide_dotfiles = false,
        never_show = {
          ".DS_Store",
          ".velite",
        },
      },
    },
  },

  keys = {
    {
      "<C-n>",
      mode = "n",
      "<cmd> Neotree toggle <CR>",
      desc = "open NeoTree",
    },
  },
}
