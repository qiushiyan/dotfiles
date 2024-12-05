return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    close_if_last_window = true,
    window = {
      position = "right",
      width = 30,
    },
    filesystem = {
      filtered_items = {
        visible = true,
        hide_gitignored = true,
        hide_dotfiles = false,
        hide_by_name = {
          "package-lock.json",
          ".changeset",
        },
        never_show = { ".git", "node_modules", ".next", ".velite", ".DS_Store" },
      },
      window = {
        mappings = {
          ["o"] = "system_open",
        },
      },
      commands = {
        system_open = function(state)
          local node = state.tree:get_node()
          local path = node:get_id()
          vim.fn.jobstart({ "open", "-g", path }, { detach = true })
        end,
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
