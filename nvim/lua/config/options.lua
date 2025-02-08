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

-- always show markdown symbols (backticks, stars, etc)
vim.opt.conceallevel = 0

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
-- vim.opt.colorcolumn = "85"
-- vim.cmd([[highlight ColorColumn ctermbg=lightgrey guibg=lightgrey]])

-- cursor line
-- vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "yellow", bg = "#292e42" })
