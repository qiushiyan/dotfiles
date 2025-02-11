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
