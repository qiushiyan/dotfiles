-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- local utils = require("utils")
vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit insert mode" })
-- exit terminal mode
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
-- Copy (Ctrl+C)
vim.keymap.set("n", "<C-c>", '"+yy', { desc = "Copy line to system clipboard", silent = true, noremap = true })
vim.keymap.set("v", "<C-c>", '"+y', { desc = "Copy selection to system clipboard" })
vim.keymap.set("i", "<C-c>", '<ESC>"+yi', { desc = "Copy line to system clipboard" })
-- Cut (Ctrl+X)
vim.keymap.set("n", "<C-x>", '"+dd', { desc = "Cut line to system clipboard" })
vim.keymap.set("v", "<C-x>", '"+x', { desc = "Cut selection to system clipboard" })
vim.keymap.set("i", "<C-x>", '<ESC>"+dda', { desc = "Cut line to system clipboard" })
-- Paste (Ctrl+V)
vim.keymap.set("n", "<C-v>", '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set("v", "<C-v>", '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set("i", "<C-v>", '<ESC>"+pa', { desc = "Paste from system clipboard" })
-- Undo (Ctrl+Z)
vim.keymap.set("i", "<C-z>", "<ESC>ui", { desc = "Undo last change" })
vim.keymap.set("n", "<C-z>", "u", { desc = "Undo last change" })
vim.keymap.set("v", "<C-z>", "<ESC>u", { desc = "Undo last change" })

-- Move lines up and down
-- NOTE: for the option key to work in iterm2, see https://www.redait.com/r/zellij/comments/13twru4/if_you_have_problems_with_alt_option_key_on_macos/
vim.keymap.set("n", "<A-Up>", ":m .-2<CR>==", { desc = "Move line up" })
vim.keymap.set("n", "<A-Down>", ":m .+1<CR>==", { desc = "Move line down" })
vim.keymap.set("v", "<A-Up>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
vim.keymap.set("v", "<A-Down>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("i", "<A-Up>", "<Esc>:m .-2<CR>==gi", { desc = "Move line up" })
vim.keymap.set("i", "<A-Down>", "<Esc>:m .+1<CR>==gi", { desc = "Move line down" })

-- Code Actions
-- NOTE: ctrl + shift keymaps does not work in kitty, see https://github.com/kovidgoyal/kitty/issues/1629
vim.keymap.set({ "n", "v" }, "<C-S-f>", vim.lsp.buf.code_action, { desc = "Code actions" })
vim.keymap.set("n", "<C-S-d>", vim.diagnostic.open_float, { desc = "Show line diagnostics" })

-- Hover
vim.keymap.set("n", "gh", vim.lsp.buf.hover, { desc = "Show hover information" })

-- better scroll
vim.keymap.set("n", "<C-u>", "<C-u>zz", { noremap = true })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { noremap = true })
