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

-- better scroll
vim.keymap.set("n", "<C-u>", "<C-u>zz", { noremap = true })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { noremap = true })

-- search for current word under cursor
vim.keymap.set("n", "g/", function()
  local word = vim.fn.expand("<cWORD>")
  vim.fn.setreg("/", word)
  vim.cmd("normal! n")
end, { desc = "Search current word" })

-- execute buffer
vim.keymap.set("n", "<leader>cg", function()
  local file = vim.fn.expand("%") -- Get the current file name
  if string.match(file, "%.go$") then -- Check if the file is a .go file
    local file_dir = vim.fn.expand("%:p:h") -- Get the directory of the current file
    -- local escaped_file = vim.fn.shellescape(file) -- Properly escape the file name for shell commands
    -- local command_to_run = "go run " .. escaped_file
    local command_to_run = "go run *.go"
    -- `-l 60` specifies the size of the tmux pane, in this case 60 columns
    local cmd = "silent !tmux split-window -h -l 60 'cd "
      .. file_dir
      .. ' && echo "'
      .. command_to_run
      .. '\\n" && bash -c "'
      .. command_to_run
      .. "; echo; echo Press enter to exit...; read _\"'"
    vim.cmd(cmd)
  else
    vim.cmd("echo 'Not a Go file.'") -- Notify the user if the file is not a Go file
  end
end, { desc = "[P]GOLANG, execute file" })

-- -- If this is a bash script, make it executable, and execute it in a split pane on the right
-- -- Had to include quotes around "%" because there are some apple dirs that contain spaces, like iCloud
vim.keymap.set("n", "<leader>cb", function()
  local file = vim.fn.expand("%") -- Get the current file name
  local first_line = vim.fn.getline(1) -- Get the first line of the file
  if string.match(first_line, "^#!/") then -- If first line contains shebang
    local escaped_file = vim.fn.shellescape(file) -- Properly escape the file name for shell commands
    vim.cmd("!chmod +x " .. escaped_file) -- Make the file executable
    vim.cmd("vsplit") -- Split the window vertically
    vim.cmd("terminal " .. escaped_file) -- Open terminal and execute the file
    vim.cmd("startinsert") -- Enter insert mode, recommended by echasnovski on Reddit
  else
    vim.cmd("echo 'Not a script. Shebang line not found.'")
  end
end, { desc = "[P]Execute bash script in pane on the right" })
