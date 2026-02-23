-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
--
-- Default splitting will cause your main splits to jump when opening an edgebar.
-- To prevent this, set `splitkeep` to either `screen` or `topline`.
vim.opt.splitkeep = "screen"
vim.opt.showtabline = 0
vim.opt.laststatus = 3
vim.opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }
vim.opt.swapfile = false
-- always show markdown symbols (backticks, stars, etc)
vim.opt.conceallevel = 0

vim.g.lazyvim_python_lsp = "pyright"
vim.g.lazyvim_python_ruff = "ruff"

local paths = require("config.paths")
vim.g.python3_host_prog = paths.python
vim.g.python_host_prog = paths.python

-- handle github pattern when opening links
local open = vim.ui.open
vim.ui.open = function(uri) ---@diagnostic disable-line: duplicate-set-field
  if not string.match(uri, "[a-z]*://[^ >,;]*") and string.match(uri, "[%w%p\\-]*/[%w%p\\-]*") then
    uri = string.format("https://github.com/%s", uri)
  end
  open(uri)
end

-- wrapping
vim.opt.textwidth = 100

-- Markdown: no auto-wrap, but continue bullets on Enter
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.textwidth = 0 -- disable auto-wrap
    vim.opt_local.formatoptions:remove("t") -- don't auto-wrap text
    vim.opt_local.formatoptions:append("ro") -- continue bullets on Enter/o/O
    vim.opt_local.comments = "b:- [ ],b:- [x],b:-,b:*,b:>"
  end,
})
-- vim.opt.colorcolumn = "85"
-- vim.cmd([[highlight ColorColumn ctermbg=lightgrey guibg=lightgrey]])

-- cursor line
-- vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "yellow", bg = "#292e42" })

-- neovide specific
if vim.g.neovide then
  vim.keymap.set("n", "<D-s>", ":w<CR>") -- Save
  vim.keymap.set("v", "<D-c>", '"+y') -- Copy
  vim.keymap.set("n", "<D-v>", '"+P') -- Paste normal mode
  vim.keymap.set("v", "<D-v>", '"+P') -- Paste visual mode
  vim.keymap.set("c", "<D-v>", "<C-R>+") -- Paste command mode
  vim.keymap.set("i", "<D-v>", '<ESC>l"+Pli') -- Paste insert mode

  -- This allows me to use cmd+v to paste stuff into neovide
  vim.keymap.set("", "<D-v>", "+p<CR>", { noremap = true, silent = true })
  vim.keymap.set("!", "<D-v>", "<C-R>+", { noremap = true, silent = true })
  vim.keymap.set("t", "<D-v>", "<C-R>+", { noremap = true, silent = true })
  vim.keymap.set("v", "<D-v>", "<C-R>+", { noremap = true, silent = true })

  -- Specify the font used by Neovide
  vim.o.guifont = "JetBrainsMono Nerd Font:h18"
  -- This is limited by the refresh rate of your physical hardware, but can be
  -- lowered to increase battery life
  -- This setting is only effective when not using vsync,
  -- for example by passing --no-vsync on the commandline.
  --
  -- NOTE: vsync is configured in the neovide/config.toml file, I disabled it and set
  -- this to 120 even though my monitor is 75Hz, had a similar case in wezterm,
  -- see: https://github.com/wez/wezterm/issues/6334
  vim.g.neovide_refresh_rate = 120
  -- This is how fast the cursor animation "moves", default 0.06
  vim.g.neovide_cursor_animation_length = 0.04
  -- Default 0.7
  vim.g.neovide_cursor_trail_size = 0.7

  -- produce particles behind the cursor, if want to disable them, set it to ""
  -- vim.g.neovide_cursor_vfx_mode = "railgun"
  -- vim.g.neovide_cursor_vfx_mode = "torpedo"
  -- vim.g.neovide_cursor_vfx_mode = "pixiedust"
  vim.g.neovide_cursor_vfx_mode = "sonicboom"
  -- vim.g.neovide_cursor_vfx_mode = "ripple"
  -- vim.g.neovide_cursor_vfx_mode = "wireframe"

  -- Really weird issue in which my winbar would be drawn multiple times as I
  -- scrolled down the file, this fixed it, found in:
  -- https://github.com/neovide/neovide/issues/1550
  vim.g.neovide_scroll_animation_length = 0

  -- This allows me to use the right "alt" key in macOS, because I have some
  -- neovim keymaps that use alt, like alt+t for the terminal
  -- https://youtu.be/33gQ9p-Zp0I
  vim.g.neovide_input_macos_option_key_is_meta = "only_right"
end
