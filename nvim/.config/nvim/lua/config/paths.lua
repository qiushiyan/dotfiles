-- Centralized path configuration for portability
-- Edit these paths when setting up on a new machine

local M = {}

M.python = "/opt/homebrew/bin/python3.10"
M.todo_file = vim.fn.expand("~/workspace/nvim-notes/todo.md")
M.markdownlint_config = vim.fn.expand("~/.config/.markdownlint-cli2.yaml")

return M
