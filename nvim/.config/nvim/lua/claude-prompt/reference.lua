-- Read-only window beside a Ctrl+G prompt buffer showing the assistant reply
-- being answered, so questions stay visible while the draft is written. The
-- draft file is never touched: what Claude receives is only what was typed.
-- Design and keys: docs/claude-prompt-reference.md.

local transcript = require("claude-prompt.transcript")

local M = {}

-- one reference per editor: Claude spawns a fresh nvim for every Ctrl+G
local state = {} -- draft_win, win, buf, replies, index, full

local function valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function render()
  local reply = state.replies[state.index]
  local text = state.full and reply.full or reply.final
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
  vim.bo[state.buf].modifiable = false
  if valid_win(state.win) then
    vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
    vim.wo[state.win].winbar = string.format(
      " reply %d/%d · %s%%=[r ]r  ]R newest  f %s  q close ",
      state.index,
      #state.replies,
      state.full and "whole turn" or "final message",
      state.full and "final" or "whole turn"
    )
  end
end

local function step(delta)
  if not state.replies then
    return
  end
  state.index = math.max(1, math.min(#state.replies, state.index + delta))
  render()
end

local function toggle_full()
  if state.replies then
    state.full = not state.full
    render()
  end
end

local function scroll(keys)
  if valid_win(state.win) then
    vim.api.nvim_win_call(state.win, function()
      vim.cmd("normal! " .. vim.keycode(keys))
    end)
  end
end

local function close()
  if valid_win(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

local function open_window()
  local buf = vim.api.nvim_create_buf(false, true) -- unlisted scratch
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"

  -- short, wide agent panes read best side by side; narrow ones stack
  local cols = vim.o.columns
  if cols >= 100 then
    vim.cmd("topleft vsplit")
    vim.api.nvim_win_set_width(0, cols - math.max(50, math.floor(cols * 0.4)))
  else
    vim.cmd("topleft split")
    vim.api.nvim_win_set_height(0, math.floor(vim.o.lines * 0.55))
  end
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  for opt, value in pairs({
    wrap = true,
    linebreak = true,
    number = false,
    relativenumber = false,
    signcolumn = "no",
    statuscolumn = "",
    foldcolumn = "0",
    spell = false,
    cursorline = false,
    winfixwidth = true,
  }) do
    vim.wo[win][opt] = value
  end

  local map = function(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, desc = desc })
  end
  map("[r", function()
    step(-1)
  end, "Previous Claude reply")
  map("]r", function()
    step(1)
  end, "Next Claude reply")
  map("[R", function()
    step(-math.huge)
  end, "Oldest Claude reply")
  map("]R", function()
    step(math.huge)
  end, "Newest Claude reply")
  map("f", toggle_full, "Toggle final message / whole turn")
  map("q", close, "Close reply reference")

  state.win, state.buf = win, buf
  vim.api.nvim_set_current_win(state.draft_win)
end

-- (Re)load the conversation and show its newest reply.
function M.open()
  if not valid_win(state.draft_win) then
    return vim.notify("Claude reply reference: not a Ctrl+G prompt editor", vim.log.levels.INFO)
  end
  local path, err = transcript.find()
  local replies
  if path then
    replies, err = transcript.replies(path)
  end
  if not replies then
    vim.notify("Claude reply reference: " .. err, vim.log.levels.INFO)
    return
  end
  state.replies, state.index, state.full = replies, #replies, true
  if not valid_win(state.win) then
    open_window()
  end
  render()
end

local function attach(buf)
  if state.draft_win or vim.bo[buf].buftype ~= "" then
    return
  end
  if not require("claude-prompt").is_prompt_file(vim.api.nvim_buf_get_name(buf)) then
    return
  end
  state.draft_win = vim.api.nvim_get_current_win()

  local map = function(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, desc = desc })
  end
  map("[r", function()
    step(-1)
  end, "Previous Claude reply")
  map("]r", function()
    step(1)
  end, "Next Claude reply")
  map("[R", function()
    step(-math.huge)
  end, "Oldest Claude reply")
  map("]R", function()
    step(math.huge)
  end, "Newest Claude reply")
  map("<C-f>", function()
    scroll("<C-d>")
  end, "Scroll Claude reply down")
  map("<C-b>", function()
    scroll("<C-u>")
  end, "Scroll Claude reply up")

  -- :wq / ZZ / :q in the draft must end nvim, or Claude keeps waiting on
  -- an editor held open by the reference. QuitPre runs after :wq's write,
  -- so a failed write keeps both windows.
  vim.api.nvim_create_autocmd("QuitPre", {
    buffer = buf,
    callback = function()
      if vim.api.nvim_get_current_win() == state.draft_win then
        close()
      end
    end,
  })

  M.open()
end

function M.setup()
  vim.api.nvim_create_user_command("ClaudeReply", M.open, { desc = "Show the Claude reply being answered" })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = vim.api.nvim_create_augroup("claude_prompt_reference", { clear = true }),
    callback = function(ev)
      -- at startup, wait for the initial layout before splitting
      if vim.v.vim_did_enter == 1 then
        attach(ev.buf)
      else
        vim.api.nvim_create_autocmd("VimEnter", {
          once = true,
          callback = function()
            if vim.api.nvim_buf_is_valid(ev.buf) then
              attach(ev.buf)
            end
          end,
        })
      end
    end,
  })
end

return M
