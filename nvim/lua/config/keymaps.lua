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
vim.keymap.set("i", "<C-z>", "<ESC>ui", { desc = "Undo last change" })
vim.keymap.set("n", "<C-z>", "u", { desc = "Undo last change" })
vim.keymap.set("v", "<C-z>", "<ESC>u", { desc = "Undo last change" })

-- Move lines up and down
vim.keymap.set("n", "<A-Up>", ":m .-2<CR>==", { desc = "Move line up" })
vim.keymap.set("n", "<A-Down>", ":m .+1<CR>==", { desc = "Move line down" })
vim.keymap.set("v", "<A-Up>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
vim.keymap.set("v", "<A-Down>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("i", "<A-Up>", "<Esc>:m .-2<CR>==gi", { desc = "Move line up" })
vim.keymap.set("i", "<A-Down>", "<Esc>:m .+1<CR>==gi", { desc = "Move line down" })

-- Code Actions
vim.keymap.set({ "n", "v" }, "<C-S-f>", vim.lsp.buf.code_action, { desc = "Code actions" })
