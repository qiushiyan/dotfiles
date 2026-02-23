---@class InlineMath
---@field setup fun(opts?: table)
local M = {}

---Evaluates math expressions in backticks and appends result
---@param auto_trigger boolean Whether this was triggered automatically (by typing backtick)
local function md_inline_calculator(auto_trigger)
  local line = vim.api.nvim_get_current_line()
  local cursor_col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-based column
  local mode = vim.api.nvim_get_mode().mode
  local expressions = {}
  -- Find all backtick-enclosed expressions
  local start_idx = 1
  while true do
    local expr_start, expr_end = line:find("`([^`]+)`", start_idx)
    if not expr_start then
      break
    end
    table.insert(expressions, {
      start = expr_start + 1,
      finish = expr_end - 1,
      closing = expr_end,
      content = line:sub(expr_start + 1, expr_end - 1),
    })
    start_idx = expr_end + 1
  end
  -- Automatic mode: Check last-closed backtick pair
  if mode == "i" then
    local last_char = line:sub(cursor_col - 1, cursor_col - 1)
    if last_char == "`" then
      for _, expr in ipairs(expressions) do
        if expr.closing == cursor_col - 1 then
          -- Check if content starts with ; and matches allowed characters
          if not expr.content:find("=") and expr.content:match("^;%s*[%d%+%-%*%/%%%s%.%(%)x÷]+$") then
            local success, result = pcall(function()
              return load("return " .. expr.content:gsub("x", "*"):gsub("÷", "/"):sub(2))()
            end)
            if success then
              local cleaned = expr.content:sub(2):gsub("^%s*", "")
              local replacement = string.format("%s=%s", cleaned, result)
              local new_line = line:sub(1, expr.start - 1) .. replacement .. line:sub(expr.finish + 1)
              vim.api.nvim_set_current_line(new_line)
              vim.api.nvim_win_set_cursor(0, { vim.fn.line("."), expr.start + #replacement })
            end
          end
          return
        end
      end
    end
  end
  -- Manual mode: Check cursor position
  local handled = false
  for _, expr in ipairs(expressions) do
    if (cursor_col >= expr.start and cursor_col <= expr.finish) or (mode == "i" and cursor_col == expr.closing) then
      if expr.content:find("=") then
        vim.notify("Expression already calculated", vim.log.levels.INFO)
        return
      end
      local expression = expr.content:gsub("x", "*"):gsub("÷", "/")
      local success, result = pcall(function()
        return load("return " .. expression)()
      end)
      if success then
        local replacement = string.format("%s=%s", expression, result)
        local new_line = line:sub(1, expr.start - 1) .. replacement .. line:sub(expr.finish + 1)
        vim.api.nvim_set_current_line(new_line)
      else
        vim.notify("Invalid expression: " .. expression, vim.log.levels.ERROR)
      end
      handled = true
      return
    end
  end
  -- Handle incomplete backtick pairs in insert mode
  if not handled and (mode == "i" or not auto_trigger) then
    -- Find last opening backtick before cursor
    local open_pos = line:sub(1, cursor_col):find("`[^`]*$")
    if open_pos then
      local content = line:sub(open_pos + 1, cursor_col - 1)
      local pattern = auto_trigger and "^;%s*[%d%+%-%*%/%%%s%.%(%)x÷]+$" or "^[%d%+%-%*%/%%%s%.%(%)x÷]+$"
      if not content:find("=") and content:match(pattern) then
        local expr_to_eval = content:gsub("x", "*"):gsub("÷", "/")
        if auto_trigger then
          expr_to_eval = expr_to_eval:sub(2) -- Remove leading ';' for auto
        end
        local success, result = pcall(function()
          return load("return " .. expr_to_eval)()
        end)
        if success then
          local cleaned = expr_to_eval:gsub("^%s*", "")
          local replacement = string.format("`%s=%s`", cleaned, result)
          local new_line = line:sub(1, open_pos - 1) .. replacement .. line:sub(cursor_col)
          vim.api.nvim_set_current_line(new_line)
          -- Move cursor to end of replacement
          vim.api.nvim_win_set_cursor(0, { vim.fn.line("."), open_pos + #replacement - 1 })
        else
          vim.notify("Invalid expression: " .. content, vim.log.levels.ERROR)
        end
        return
      end
    end
  end
  if not auto_trigger then
    vim.notify("No expression under cursor", vim.log.levels.WARN)
  end
end

-- Markdown inline calculator (works not only in markdown) lamw26wmal
--
-- In INSERT mode if you type `20+20 (NOTICE THAT YOU DON'T NEED TO TYPE THE
-- LAST BACKTICK) and then run the keymap, you get `20+20=40`
--
-- In NORMAL mode if you have `20+20` and run the keymap inside the backticks
-- you get `20+20=40`
--
-- Automatic mode (disabled by default) works if you include a ; so for example
-- If you type `;20+20` when you type the final ` turns into `20+20=40`

---@param opts? table Optional configuration (currently unused)
M.setup = function(opts)
  vim.keymap.set({ "n", "i" }, "<M-3>", function()
    md_inline_calculator(false) -- Explicit manual trigger
  end, { desc = "Inline calculator" })
end

return M
