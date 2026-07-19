-- Paste an image from the clipboard or drag-and-drop. The <C-v> image-aware
-- paste in config/keymaps.lua depends on this (pasting screenshots into
-- markdown, e.g. to show Claude Code).
return {
  "HakonHarnes/img-clip.nvim",
  event = "BufEnter",
  opts = {
    -- default: one-off pastes (e.g. to show Claude Code) go to /tmp with an
    -- absolute path; purged after 3 days on plugin load since this macOS has
    -- no periodic clean-tmps. <leader>iI pastes into the project instead.
    default = {
      dir_path = "/tmp/img-clip",
      use_absolute_path = true,
      prompt_for_file_name = false,
    },
    filetypes = {
      markdown = {
        url_encode_path = true,
        template = "![$CURSOR]($FILE_PATH)",
        drag_and_drop = {
          download_images = false,
        },
      },
    },
  },
  config = function(_, opts)
    require("img-clip").setup(opts)
    vim.system({ "find", "/tmp/img-clip", "-type", "f", "-mtime", "+3", "-delete" })
    vim.keymap.set("n", "<leader>ii", function()
      require("img-clip").paste_image()
    end, { desc = "insert [i]mage from clipboard (temp)" })
    vim.keymap.set("n", "<leader>iI", function()
      require("img-clip").paste_image({
        dir_path = "img",
        use_absolute_path = false,
        prompt_for_file_name = true,
      })
    end, { desc = "insert [I]mage from clipboard (project img/)" })
  end,
}
