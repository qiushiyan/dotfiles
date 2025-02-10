local MiniFiles = require("mini.files")

return {
  {
    "echasnovski/mini.files",
    lazy = false,
    opts = {
      windows = {
        preview = true,
        width_focus = 30,
        width_preview = 55,
      },
      options = {
        use_as_default_explorer = true,
        -- To get this dir run :echo stdpath('data')
        permanent_delete = false,
      },
      mappings = {
        close = "q",
        -- Use this if you want to open several files
        go_in = "l",
        -- This opens the file, but quits out of mini.files (default L)
        go_in_plus = "<CR>",
        -- I swapped the following 2 (default go_out: h)
        -- go_out_plus: when you go out, it shows you only 1 item to the right
        -- go_out: shows you all the items to the right
        go_out = "H",
        go_out_plus = "h",
        reset = ",",
        reveal_cwd = ".",
        show_help = "g?",
        -- Default =
        synchronize = "=",
        trim_left = "<",
        trim_right = ">",
      },
    },
    keys = {
      {
        "<esc>",
        function()
          MiniFiles.close()
        end,
      },
      {
        "<leader>e",
        function()
          if not MiniFiles.close() then
            MiniFiles.open(vim.uv.cwd(), true)
          end
        end,
        desc = "Open mini.files (cwd)",
      },
      {
        "<leader>E",
        function()
          local buf_name = vim.api.nvim_buf_get_name(0)
          local dir_name = vim.fn.fnamemodify(buf_name, ":p:h")
          if vim.fn.filereadable(buf_name) == 1 then
            -- Pass the full file path to highlight the file
            require("mini.files").open(buf_name, true)
          elseif vim.fn.isdirectory(dir_name) == 1 then
            -- If the directory exists but the file doesn't, open the directory
            require("mini.files").open(dir_name, true)
          else
            -- If neither exists, fallback to the current working directory
            require("mini.files").open(vim.uv.cwd(), true)
          end
        end,
        desc = "Open mini.files (Directory of Current File)",
      },
    },
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    enabled = false,
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
          group_empty_dirs = false,
          visible = true,
          show_hidden_count = true,
          hide_gitignored = false,
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
  },
}
