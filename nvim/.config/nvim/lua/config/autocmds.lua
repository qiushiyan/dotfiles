-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- remove padding around neovim instance
vim.api.nvim_create_autocmd({ "UIEnter", "ColorScheme" }, {
  callback = function()
    local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
    if not normal.bg then
      return
    end
    io.write(string.format("\027]11;#%06x\027\\", normal.bg))
  end,
})
vim.api.nvim_create_autocmd("UILeave", {
  callback = function()
    io.write("\027]111\027\\")
  end,
})

-- close neovim if all named buffers are closed
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    -- Check if this is the last buffer
    local bufs = vim.fn.getbufinfo({ buflisted = true })
    if #bufs == 1 then
      -- Check if it's an unnamed buffer with no changes
      local curr_buf = bufs[1]
      if curr_buf.name == "" and not curr_buf.changed then
        vim.cmd("quit")
      end
    end
  end,
})
-- automatically adds "-" or "*" once I type the first character and keeps track of indentation for markdown
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.formatoptions:append("r") -- `<CR>` in insert mode
    vim.opt_local.formatoptions:append("o") -- `o` in normal mode
    vim.opt_local.comments = {
      "b:- [ ]", -- tasks
      "b:- [x]",
      "b:*", -- unordered list
      "b:-",
      "b:+",
    }
  end,
})

-- Live theme switching. `theme-set` (the shared switcher behind tmux `prefix t`)
-- writes the canonical name to ~/.config/terminal-theme; every running nvim
-- watches that file and re-applies the matching colorscheme without a restart.
-- fs_poll, not fs_event: on macOS fs_event watches the inode and goes stale on
-- the atomic rename theme-set does, so it would only ever fire once. lazy.nvim's
-- ColorSchemePre autoloads the matching (lazy) colorscheme plugin when
-- :colorscheme runs, so swapping in any direction works.
do
  local theme = require("config.theme")
  local state = vim.fn.expand("~/.config/terminal-theme")

  local function read_name()
    local f = io.open(state, "r")
    if not f then
      return nil
    end
    local line = (f:read("*l") or ""):gsub("%s+", "")
    f:close()
    return line ~= "" and line or nil
  end

  local function apply(name)
    local entry = theme.map[name]
    if not entry then
      return
    end
    if entry.colorscheme == vim.g.colors_name then
      return -- already on it
    end
    if entry.background then
      vim.o.background = entry.background
    end
    pcall(vim.cmd.colorscheme, entry.colorscheme)
  end

  if vim.uv and read_name() then -- only watch if the state file exists
    local poll = vim.uv.new_fs_poll()
    if poll then
      poll:start(
        state,
        1000,
        vim.schedule_wrap(function(err)
          if err then
            return
          end
          local name = read_name()
          if name then
            apply(name)
          end
        end)
      )
    end
  end
end

-- custom macros
local esc = vim.api.nvim_replace_termcodes("<Esc>", true, true, true)
vim.api.nvim_create_augroup("JSLogMacro", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = "JSLogMacro",
  pattern = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
  callback = function()
    vim.fn.setreg("l", "yoconsole.log('" .. esc .. "pa:" .. esc .. "la," .. esc .. "pl")
  end,
})
