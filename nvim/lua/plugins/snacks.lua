return {
  "folke/snacks.nvim",
  keys = {
    -- overwrite default, which is from the root dir
    {
      "<leader><space>",
      -- LazyVim.pick("files", { root = false })
      function()
        Snacks.picker.files({
          finder = "files",
          format = "file",
          hidden = true,
          show_empty = true,
          ignored = false,
          supports_live = true,
          dirs = { vim.fn.getcwd() },
        })
      end,
      desc = "Find Files (cwd)",
    },
    { "<leader>/", LazyVim.pick("grep", { root = false }), desc = "Grep (cwd)" },

    -- disable scratch buffer
    { "<leader>.", function() end },
    { "<leader>S", function() end },
    {
      "<leader>,",
      function()
        Snacks.picker.buffers({
          on_show = function()
            vim.cmd.stopinsert()
          end,
          finder = "buffers",
          format = "buffer",
          hidden = true,
          unloaded = true,
          -- dont list current buffer so previous buffer is at top
          current = false,
          filter = { cwd = true },
          sort_lastused = true,
          win = {
            input = {
              keys = {
                ["d"] = "bufdelete",
              },
            },
            list = { keys = { ["d"] = "bufdelete" } },
          },
          layout = "buffers",
        })
      end,
      desc = "Pick buffers",
    },
    {
      "<leader>gl",
      function()
        Snacks.picker.git_log({
          finder = "git_log",
          format = "git_log",
          preview = "git_show",
          confirm = "git_checkout",
          layout = "vertical",
        })
      end,
      desc = "Git Log",
    },
    {

      "<M-k>",
      function()
        Snacks.picker.keymaps({
          layout = "vertical",
        })
      end,
      desc = "Keymaps",
    },
  },
  ---@module "snacks"
  ---@type snacks.Config
  opts = {
    image = {
      enabled = true,
      doc = {
        inline = false,
        float = true,
        max_height = 30,
        max_width = 60,
      },
    },
    styles = {
      snacks_image = {
        relative = "editor",
        col = -1,
      },
    },
    -- configure welcome screen
    dashboard = {
      preset = {
        keys = {
          { icon = " ", key = "s", desc = "Restore Session", section = "session" },
          { icon = " ", key = "<esc>", desc = "Quit", action = ":qa" },
        },
      },
    },
    -- smooth scroll
    scroll = { enabled = true },
    -- borrowed from https://github1s.com/linkarzu/dotfiles-latest/blob/main/neovim/quarto-nvim-kickstarter/lua/config/wip/r-targets-refactor.lua
    picker = {
      layout = {
        preset = "ivy",
        cycle = false,
      },
      layouts = {
        ivy = {
          layout = {
            box = "vertical",
            backdrop = false,
            row = -1,
            width = 0,
            height = 0.6,
            border = "top",
            title = " {title} {live} {flags}",
            title_pos = "left",
            { win = "input", height = 1, border = "bottom" },
            {
              box = "horizontal",
              { win = "list", border = "none" },
              { win = "preview", title = "{preview}", width = 0.5, border = "left" },
            },
          },
        },
        vertical = {
          layout = {
            backdrop = false,
            width = 0.8,
            min_width = 80,
            height = 0.8,
            min_height = 30,
            box = "vertical",
            border = "rounded",
            title = "{title} {live} {flags}",
            title_pos = "center",
            { win = "input", height = 1, border = "bottom" },
            { win = "list", border = "none" },
            { win = "preview", title = "{preview}", height = 0.4, border = "top" },
          },
        },
        buffers = {
          layout = {
            backdrop = false,
            row = 1,
            width = 0.7,
            min_width = 70,
            height = 0.8,
            border = "none",
            box = "vertical",
            {
              box = "vertical",
              border = "rounded",
              title = "{title}",
              title_pos = "center",
              { win = "input", height = 1, border = "bottom" },
              { win = "list", border = "none" },
            },
          },
        },
      },
      matcher = {
        frecency = true,
      },
      win = {
        input = {
          keys = {
            ["<Esc>"] = { "close", mode = { "n", "i" } },
            ["J"] = { "preview_scroll_down", mode = { "i", "n" } },
            ["K"] = { "preview_scroll_up", mode = { "i", "n" } },
            ["H"] = { "preview_scroll_left", mode = { "i", "n" } },
            ["L"] = { "preview_scroll_right", mode = { "i", "n" } },
          },
        },
      },
    },
  },
}
