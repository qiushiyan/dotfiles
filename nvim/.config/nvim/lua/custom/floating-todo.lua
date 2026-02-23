local utils = require("utils")

---@class FloatingTodoOpts
---@field global_file string Path to global todo file
---@field target_file? string Resolved target file path (set during setup)

---@class FloatingTodo
---@field setup fun(opts: FloatingTodoOpts)
local M = {}

---@return vim.api.keyset.win_config
local function float_win_config()
  local width = math.min(math.floor(vim.o.columns * 0.8), 64)
  local height = math.floor(vim.o.lines * 0.8)

  return {
    relative = "editor",
    width = width,
    height = height,
    col = utils.center_in(vim.o.columns, width),
    row = utils.center_in(vim.o.lines, height),
    border = "rounded",
    title = " TODO List ",
    title_pos = "center",
  }
end

---Opens a floating window with the specified file
---@param filepath string Path to the file to open
local function open_floating_file(filepath)
  local path = utils.expand_path(filepath)

  -- Check if the file exists
  if vim.fn.filereadable(path) == 0 then
    vim.notify("[FloatingTodo] File does not exist: " .. path, vim.log.levels.ERROR)
    return
  end

  -- Look for an existing buffer with this file
  local buf = vim.fn.bufnr(path, true)

  -- If the buffer doesn't exist, create one and edit the file
  if buf == -1 then
    buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(buf, path)
    vim.api.nvim_buf_call(buf, function()
      vim.cmd("edit " .. vim.fn.fnameescape(path))
    end)
  end

  local win = vim.api.nvim_open_win(buf, true, float_win_config())
  vim.cmd("setlocal nospell")

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    noremap = true,
    silent = true,
    callback = function()
      -- Check if the buffer has unsaved changes
      if vim.api.nvim_get_option_value("modified", { buf = buf }) then
        vim.notify("Unsaved changes", vim.log.levels.WARN)
      else
        vim.api.nvim_win_close(0, true)
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      vim.api.nvim_win_set_config(win, float_win_config())
    end,
    once = false,
  })

  -- Add or find the current date heading
  local date_heading = "## " .. os.date("%Y-%m-%d")
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local found_date_heading = false
  local insert_line = 0

  for i, line in ipairs(lines) do
    if line:match("^# ") then
      insert_line = i
    elseif line:match("^## %d%d%d%d%-%d%d%-%d%d") then
      if line == date_heading then
        found_date_heading = true
        insert_line = i
        break
      else
        break
      end
    elseif line:match("^%s*$") then
      -- Skip empty lines
    else
      insert_line = i
      break
    end
  end

  if not found_date_heading then
    vim.api.nvim_buf_set_lines(buf, insert_line, insert_line, false, { date_heading, "" })
    insert_line = insert_line + 2
  else
    insert_line = insert_line + 1
  end

  -- Ensure there are at least 2 lines below the date heading
  local line_count = vim.api.nvim_buf_line_count(buf)
  if insert_line + 2 > line_count then
    vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, { "", "" })
    line_count = vim.api.nvim_buf_line_count(buf)
  end

  vim.api.nvim_win_set_cursor(win, { insert_line, 0 })
  -- -- Set the cursor position safely
  -- if insert_line + 2 <= line_count then
  -- else
  --   vim.api.nvim_win_set_cursor(win, { line_count, 0 })
  -- end

  vim.cmd("startinsert")
end

---@param opts FloatingTodoOpts
local function setup_user_commands(opts)
  local project_root = vim.fn.getcwd()
  local project_todo_file = project_root .. "/todo.md"
  local project_todo_file_upper = project_root .. "/TODO.md"

  if vim.fn.filereadable(project_todo_file) == 1 then
    opts.target_file = project_todo_file
  elseif vim.fn.filereadable(project_todo_file_upper) == 1 then
    opts.target_file = project_todo_file_upper
  else
    opts.target_file = opts.global_file
  end

  vim.api.nvim_create_user_command("FloatingTodoOpen", function()
    open_floating_file(opts.target_file)
  end, {})
end

local function setup_keymaps()
  vim.keymap.set("n", "<leader>td", ":FloatingTodoOpen<CR>", { silent = true })
end

---@param opts FloatingTodoOpts
M.setup = function(opts)
  setup_user_commands(opts)
  setup_keymaps()
end

return M
