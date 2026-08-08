-- Persistent file bookmarks, shared across git worktrees of the same repo.
-- The list is keyed by the repo's common .git dir (identical for the parent
-- checkout and every worktree) and paths are stored relative to the worktree
-- root, so a bookmark made in one checkout resolves to the corresponding file
-- in whichever checkout is current.

local function git(cmd)
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 or #out == 0 then
    return nil
  end
  return out[1]
end

local function toggle_mark()
  local harpoon = require("harpoon")
  local list = harpoon:list()
  local item = list.config.create_list_item(list.config)
  for _, existing in pairs(list.items) do
    if list.config.equals(existing, item) then
      list:remove(item)
      vim.notify("Bookmark removed: " .. item.value)
      return
    end
  end
  list:add(item)
  vim.notify("Bookmark added: " .. item.value)
end

local function menu()
  local harpoon = require("harpoon")
  harpoon.ui:toggle_quick_menu(harpoon:list())
end

return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("harpoon"):setup({
      settings = {
        sync_on_ui_close = true,
        -- one list per repo, not per checkout
        key = function()
          return git("git rev-parse --path-format=absolute --git-common-dir") or vim.uv.cwd()
        end,
      },
      default = {
        -- store paths relative to the worktree root rather than the cwd
        get_root_dir = function()
          return git("git rev-parse --show-toplevel") or vim.uv.cwd()
        end,
        -- harpoon's stock select resolves relative paths against the cwd;
        -- resolve against the current worktree root instead, so jumps land in
        -- the right checkout from any directory
        select = function(list_item, list)
          if not list_item then
            return
          end
          local path = list_item.value
          if not vim.startswith(path, "/") then
            path = list.config.get_root_dir() .. "/" .. path
          end
          local new_buffer = vim.fn.bufexists(path) == 0
          vim.cmd.edit(vim.fn.fnameescape(path))
          if new_buffer and list_item.context then
            local row = math.min(list_item.context.row or 1, vim.api.nvim_buf_line_count(0))
            pcall(vim.api.nvim_win_set_cursor, 0, { row, list_item.context.col or 0 })
          end
        end,
      },
    })
  end,
  keys = {
    { "<leader>m", toggle_mark, desc = "Toggle file bookmark (harpoon)" },
    { "M", menu, desc = "Open bookmarks menu (harpoon)" },
    { "<leader>M", menu, desc = "Open bookmarks menu (harpoon)" },
    -- selection resolves against the current worktree root via the select
    -- override below
    { "<leader>1", function() require("harpoon"):list():select(1) end, desc = "Go to bookmark 1" },
    { "<leader>2", function() require("harpoon"):list():select(2) end, desc = "Go to bookmark 2" },
    { "<leader>3", function() require("harpoon"):list():select(3) end, desc = "Go to bookmark 3" },
    { "<leader>4", function() require("harpoon"):list():select(4) end, desc = "Go to bookmark 4" },
  },
}
