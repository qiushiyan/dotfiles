-- Read-only window beside a Ctrl+G prompt buffer showing the assistant reply
-- being answered, so questions stay visible while the draft is written. The
-- draft file is never touched: what Claude receives is only what was typed.
-- Design and keys: docs/claude-prompt-reference.md.

local transcript = require("claude-prompt.transcript")

local M = {}

-- one reference per editor: Claude spawns a fresh nvim for every Ctrl+G.
-- win/buf are the reference, present only while its window is open (the
-- buffer wipes with it); replies/index/full outlive it so keys can reopen it.
local state = {} -- draft_win, win, buf, replies, index, full

local WIN_OPTS = {
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
}

local function valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local open_window -- forward: render() reopens a closed reference

local function render()
  if not valid_win(state.win) then
    open_window()
  end
  local reply = state.replies[state.index]
  local text = state.full and reply.full or reply.final
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
  vim.bo[state.buf].modifiable = false
  vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
  vim.wo[state.win].winbar = string.format(
    " reply %d/%d · %s%%=[r ]r  ]R newest  f %s  q close ",
    state.index,
    #state.replies,
    state.full and "whole turn" or "final message",
    state.full and "final" or "whole turn"
  )
end

local function step(delta)
  if not state.replies or not valid_win(state.draft_win) then
    return
  end
  state.index = math.max(1, math.min(#state.replies, state.index + delta))
  render()
end

local function toggle_full()
  if state.replies and valid_win(state.draft_win) then
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

-- short, wide agent panes read best side by side; narrow ones stack
local function side_by_side()
  return vim.o.columns >= 100
end

local function size(win)
  if state.side then
    vim.api.nvim_win_set_width(win, vim.o.columns - math.max(50, math.floor(vim.o.columns * 0.4)))
  else
    vim.api.nvim_win_set_height(win, math.floor(vim.o.lines * 0.55))
  end
end

local function close()
  if valid_win(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
end

function open_window()
  local buf = vim.api.nvim_create_buf(false, true) -- unlisted scratch
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"

  state.side = side_by_side()
  vim.cmd(state.side and "topleft vsplit" or "topleft split")
  local win = vim.api.nvim_get_current_win()
  size(win)
  vim.api.nvim_win_set_buf(win, buf)
  for opt, value in pairs(WIN_OPTS) do
    vim.wo[win][opt] = value
  end
  -- however it closes (q, :q, <C-w>o from the draft), forget it; the id
  -- check keeps a stale window from clearing a newer reference
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      if state.win == win then
        state.win, state.buf = nil, nil
      end
    end,
  })

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
  state.replies, state.index, state.full = replies, #replies, false
  render()
end

-- Follow pane resizes (tmux zoom, splits): flip the layout when the width
-- crosses the threshold, otherwise restore the reference's share. Scheduled
-- so it runs after LazyVim's VimResized `wincmd =`.
local function relayout()
  if not valid_win(state.win) then
    return
  end
  if state.side == side_by_side() then
    return size(state.win)
  end
  local in_ref = vim.api.nvim_get_current_win() == state.win
  local view = vim.api.nvim_win_call(state.win, vim.fn.winsaveview)
  close()
  render()
  vim.api.nvim_win_call(state.win, function()
    vim.fn.winrestview(view)
  end)
  if in_ref then
    vim.api.nvim_set_current_win(state.win)
  end
end

-- Closing the draft window without quitting (<C-w>c, :close) must not leave
-- the reference as the editor's only window: Claude would wait behind it.
-- Put the draft back into that window instead.
local function watch_draft(win, buf)
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = vim.schedule_wrap(function()
      local ref = state.win
      if not valid_win(ref) or not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      if #vim.api.nvim_tabpage_list_wins(0) > 1 then
        return close()
      end
      state.win, state.buf = nil, nil
      vim.api.nvim_win_set_buf(ref, buf) -- wipes the reference buffer
      for opt in pairs(WIN_OPTS) do
        vim.wo[ref][opt] = vim.go[opt]
      end
      vim.wo[ref].winbar = vim.go.winbar
      state.draft_win = ref
      watch_draft(ref, buf)
    end),
  })
end

local function attach(buf)
  if state.draft_win or vim.bo[buf].buftype ~= "" then
    return
  end
  if not require("claude-prompt").is_prompt_file(vim.api.nvim_buf_get_name(buf)) then
    return
  end
  state.draft_win = vim.api.nvim_get_current_win()
  watch_draft(state.draft_win, buf)
  vim.api.nvim_create_autocmd("VimResized", { callback = vim.schedule_wrap(relayout) })

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
