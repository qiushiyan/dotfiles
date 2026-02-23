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

-- Save
vim.keymap.set("n", "<C-S-s>", "<cmd>wall<CR>", { desc = "Save all buffers" })

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

-- By default, CTRL-U and CTRL-D scroll by half a screen (50% of the window height)
-- Scroll by 35% of the window height and keep the cursor centered
local scroll_percentage = 0.4
-- Scroll by a percentage of the window height and keep the cursor centered
vim.keymap.set("n", "<C-d>", function()
  local lines = math.floor(vim.api.nvim_win_get_height(0) * scroll_percentage)
  vim.cmd("normal! " .. lines .. "jzz")
end, { noremap = true, silent = true })
vim.keymap.set("n", "<C-u>", function()
  local lines = math.floor(vim.api.nvim_win_get_height(0) * scroll_percentage)
  vim.cmd("normal! " .. lines .. "kzz")
end, { noremap = true, silent = true })

-- run current buffer, supported
-- bash, go
vim.keymap.set("n", "<leader>cg", function()
  local file = vim.fn.expand("%") -- Get the current file name
  local first_line = vim.fn.getline(1) -- Get the first line of the file
  local file_dir = vim.fn.expand("%:p:h") -- Get the directory of the current file
  if string.match(file, "%.go$") then -- Check if the file is a .go file
    local command_to_run = "go run ."
    local cmd = "silent !tmux split-window -h -l 60 'cd "
      .. file_dir
      .. ' && echo "'
      .. command_to_run
      .. '\\n" && bash -c "'
      .. command_to_run
      .. "; echo; echo Press enter to exit...; read _\"'"
    vim.cmd(cmd)
  elseif string.match(file, "%.py$") then -- Check if the file is a .py file
    local command_to_run = "python3 " .. file -- Use absolute path
    local cmd = "silent !tmux split-window -h -l 60 'cd "
      .. file_dir
      .. ' && echo "'
      .. command_to_run
      .. '\\n" && bash -c "'
      .. command_to_run
      .. "; echo; echo Press enter to exit...; read _\"'"
    vim.cmd(cmd)
  elseif string.match(first_line, "^#!/") then -- If first line contains shebang
    local escaped_file = vim.fn.shellescape(file) -- Properly escape the file name for shell commands
    vim.cmd("!chmod +x " .. escaped_file) -- Make the file executable
    vim.cmd("vsplit") -- Split the window vertically
    vim.cmd("terminal " .. escaped_file) -- Open terminal and execute the file
    vim.cmd("startinsert") -- Enter insert mode, recommended by echasnovski on Reddit
  else
    vim.cmd("echo 'Not a recognized buffer (Go, Bash, Python)'")
  end
end, { desc = "Execute current buffer in a right tmux pane" })

-- Function to open current file in Finder or ForkLift
local function open_in_file_manager()
  local file_path = vim.fn.expand("%:p")
  if file_path ~= "" then
    -- -- Open in Finder or in ForkLift
    local command = "open -R " .. vim.fn.shellescape(file_path)
    -- local command = "open -a ForkLift " .. vim.fn.shellescape(file_path)
    vim.fn.system(command)
    print("Opened file in ForkLift: " .. file_path)
  else
    print("No file is currently open")
  end
end

-- open current file using finder
vim.keymap.set({ "n", "v", "i" }, "<M-f>", open_in_file_manager, { desc = "Open with file explorer" })
vim.keymap.set("n", "<leader>fO", open_in_file_manager, { desc = "Open with file explorer" })

-- Copy relative path
vim.keymap.set("n", "<C-k>y", function()
  local relative_path = vim.fn.expand("%:.")
  vim.fn.setreg("+", relative_path)
  vim.notify("Copied: " .. relative_path)
end, { desc = "Copy relative path to clipboard" })

-- folding
