-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit insert mode" })

-- exit terminal mode
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Copy (Ctrl+C)
--
vim.keymap.set("n", "<C-c>", '"+y$', { desc = "Copy line to system clipboard" })
vim.keymap.set("v", "<C-c>", '"+y', { desc = "Copy selection to system clipboard" })
vim.keymap.set("i", "<C-c>", '<ESC>"+yi', { desc = "Copy line to system clipboard" })
-- Cut (Ctrl+X)
vim.keymap.set("n", "<C-x>", 'dd"+dd', { desc = "Cut line to system clipboard" })
vim.keymap.set("v", "<C-x>", '"+x', { desc = "Cut selection to system clipboard" })
vim.keymap.set("i", "<C-x>", '<ESC>dd"+dda', { desc = "Cut line to system clipboard" })
-- Paste (Ctrl+V)
vim.keymap.set("n", "<C-v>", '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set("v", "<C-v>", '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set("i", "<C-v>", '<ESC>"+pa', { desc = "Paste from system clipboard" })
-- Undo (Ctrl+Z)
vim.keymap.set("n", "<C-z>", "u", { desc = "Undo last change" })
vim.keymap.set("i", "<C-z>", "<ESC>ui", { desc = "Undo last change" })
vim.keymap.set("v", "<C-z>", "<ESC>u", { desc = "Undo last change" })
