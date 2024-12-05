-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

local group = vim.api.nvim_create_augroup("user-persistence", { clear = true })
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "PersistenceSavePre",
  callback = function()
    vim.cmd(":Neotree close")
  end,
})
