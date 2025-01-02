return {
  "nvim-neo-tree/neo-tree.nvim",
  dependencies = {
    "saifulapm/neotree-file-nesting-config",
  },
  opts = {
    hide_root_node = true,
    retain_hidden_root_indent = true,
    default_component_configs = {
      indent = {
        with_expanders = true,
        expander_collapsed = "",
        expander_expanded = "",
      },
    },
    close_if_last_window = true,
    event_handlers = {
      -- {
      --   event = "file_open_requested",
      --   handler = function()
      --     require("neo-tree.command").execute({ action = "close" })
      --   end,
      -- },
    },
    window = {
      position = "right",
      width = 35,
    },
    filesystem = {
      filtered_items = {
        visible = true,
        hide_gitignored = true,
        hide_dotfiles = false,
        hide_by_name = {
          "package-lock.json",
          "lazy-lock.json",
          ".changeset",
        },
        never_show = { ".git", "node_modules", ".next", ".velite", ".DS_Store" },
      },
      window = {
        mappings = {
          ["o"] = "system_open",
          -- can use both a and n to create files
          ["n"] = "add",
          -- invoke cmdline on file path
          ["i"] = "run_command",
        },
      },
      commands = {
        system_open = function(state)
          local node = state.tree:get_node()
          local path = node:get_id()
          vim.fn.jobstart({ "open", "-g", path }, { detach = true })
        end,
        run_command = function(state)
          local node = state.tree:get_node()
          local path = node:get_id()
          vim.api.nvim_input(": " .. path .. "<Home>")
        end,
      },
    },
  },
  config = function(_, opts)
    -- Adding rules from plugin
    opts.nesting_rules = require("neotree-file-nesting-config").nesting_rules
    require("neo-tree").setup(opts)
  end,
  keys = {
    {
      "<C-n>",
      mode = "n",
      "<cmd> Neotree toggle <CR>",
      desc = "open NeoTree",
    },
  },
}
