---@class FoldMarkdownHeadings
---@field setup fun(opts?: table)
local M = {}

---Configure fold settings for expression-based folding
local function set_foldmethod_expr()
  -- These are lazyvim.org defaults but setting them just in case a file
  -- doesn't have them set
  if vim.fn.has("nvim-0.10") == 1 then
    vim.opt.foldmethod = "expr"
    vim.opt.foldexpr = "v:lua.require'lazyvim.util'.ui.foldexpr()"
    vim.opt.foldtext = ""
  else
    vim.opt.foldmethod = "indent"
    vim.opt.foldtext = "v:lua.require'lazyvim.util'.ui.foldtext()"
  end
  vim.opt.foldlevel = 99
end

---Fold all markdown headings of a specific level
---@param level integer The heading level to fold (1-6)
local function fold_headings_of_level(level)
  -- Move to the top of the file
  vim.cmd("normal! gg")
  -- Get the total number of lines
  local total_lines = vim.fn.line("$")
  for line = 1, total_lines do
    -- Get the content of the current line
    local line_content = vim.fn.getline(line)
    -- "^" -> Ensures the match is at the start of the line
    -- string.rep("#", level) -> Creates a string with 'level' number of "#" characters
    -- "%s" -> Matches any whitespace character after the "#" characters
    -- So this will match `## `, `### `, `#### ` for example, which are markdown headings
    if line_content:match("^" .. string.rep("#", level) .. "%s") then
      -- Move the cursor to the current line
      vim.fn.cursor(line, 1)
      -- Fold the heading if it matches the level
      if vim.fn.foldclosed(line) == -1 then
        vim.cmd("normal! za")
      end
    end
  end
end

---Fold multiple heading levels, preserving viewport position
---@param levels integer[] Array of heading levels to fold
local function fold_markdown_headings(levels)
  set_foldmethod_expr()
  -- I save the view to know where to jump back after folding
  local saved_view = vim.fn.winsaveview()
  for _, level in ipairs(levels) do
    fold_headings_of_level(level)
  end
  vim.cmd("nohlsearch")
  -- Restore the view to jump to where I was
  vim.fn.winrestview(saved_view)
end

local function setup_keymaps()
  vim.keymap.set("n", "zj", function()
    vim.cmd("silent update")
    vim.cmd("edit!")
    vim.cmd("normal! zR")
    fold_markdown_headings({ 6, 5, 4, 3, 2, 1 })
    vim.cmd("normal! zz") -- center the cursor line on screen
  end, { desc = "Fold all headings level 1 or above" })

  vim.keymap.set("n", "zk", function()
    -- "Update" saves only if the buffer has been modified since the last save
    vim.cmd("silent update")
    -- vim.keymap.set("n", "<leader>mfk", function()
    -- Reloads the file to refresh folds, otherwise you have to re-open neovim
    vim.cmd("edit!")
    -- Unfold everything first or I had issues
    vim.cmd("normal! zR")
    fold_markdown_headings({ 6, 5, 4, 3, 2 })
    vim.cmd("normal! zz") -- center the cursor line on screen
  end, { desc = "Fold all headings level 2 or above" })

  vim.keymap.set("n", "zl", function()
    -- "Update" saves only if the buffer has been modified since the last save
    vim.cmd("silent update")
    -- vim.keymap.set("n", "<leader>mfl", function()
    -- Reloads the file to refresh folds, otherwise you have to re-open neovim
    vim.cmd("edit!")
    -- Unfold everything first or I had issues
    vim.cmd("normal! zR")
    fold_markdown_headings({ 6, 5, 4, 3 })
    vim.cmd("normal! zz") -- center the cursor line on screen
  end, { desc = "Fold all headings level 3 or above" })
end

---@param opts? table Optional configuration (currently unused)
M.setup = function(opts)
  setup_keymaps()
end

return M
