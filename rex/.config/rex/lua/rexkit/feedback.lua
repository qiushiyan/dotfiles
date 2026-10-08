-- rexkit.feedback: what an action can say back. Rex draws little of it yet
-- (docs/rex.md, § What the app does not show): an escape written to a
-- block's terminal reaches the app as an event (OSC 52 a copy, OSC 9 a
-- notification), a macOS notification needs the app's own machine, and the
-- toast layer is off.

local api = require("rexkit.api")
local shell = require("rexkit.shell")

local M = {}

-- Write an escape to the output side of a block's terminal, through the tty
-- of its front process, found and written in one shell. Rex has no method
-- for either. FG is that process when the caller already has it.
local function emit(session_id, block_id, printf_args, fg)
  fg = fg or api.foreground(session_id, block_id)
  if not (fg and fg.pid) then return false end
  return shell.run("t=$(ps -o tty= -p " .. tonumber(fg.pid) .. " 2>/dev/null | tr -d ' ');"
    .. " case $t in ''|'??') exit 1 ;; esac; " .. printf_args .. " > /dev/$t")
end

-- Ask the terminal in a block to copy TEXT (OSC 52). Rex turns that into a
-- clipboard_written event, and the app showing the block copies it: the
-- clipboard of the machine you are looking from.
function M.osc52(session_id, block_id, text, fg)
  return emit(session_id, block_id, "printf '\\033]52;c;%s\\007' \"$(printf %s " .. shell.quote(text)
    .. " | base64 | tr -d '\\n')\"", fg)
end

-- A desktop notification from the terminal in a block (OSC 9), as a program
-- in it would send one: Rex turns it into a desktop_notification event for
-- the app.
function M.osc9(session_id, block_id, text, fg)
  text = tostring(text):gsub("[%c]", " ")
  return emit(session_id, block_id, "printf '\\033]9;%s\\007' " .. shell.quote(text), fg)
end

-- A macOS notification on this machine.
function M.notify(title, text)
  local script = "display notification " .. string.format("%q", text) .. " with title " .. string.format("%q", title)
  shell.spawn("osascript -e " .. shell.quote(script))
end

-- Toasts --------------------------------------------------------------------------

-- A snacks-style notification at the top right of the window BLOCK is in
-- (rex-toast draws it). The layer is sized in cells from the block's own grid
-- and rect, takes no focus, and closes when the toast's process exits. A new
-- toast replaces one still showing.
-- Off: the app paints no floating layer, and neither a block or window label
-- nor a desktop notification (OSC 9, osascript) reached the screen in our
-- tests (docs/rex.md). Callers keep calling it; true turns layers back on.
M.LAYER_TOASTS = false

-- The window a block is placed in, with the block's normalized rect there.
local function placement(session_id, block_id)
  local view = api.view(session_id)
  for _, w in ipairs((view and view.windows) or {}) do
    for _, layer in ipairs(w.layers or {}) do
      for _, b in ipairs(layer.blocks or {}) do
        if b.block_id == block_id then return w.window_id, b.rect end
      end
    end
  end
end

function M.toast(session_id, block_id, level, title, msg, seconds)
  if not M.LAYER_TOASTS then return { shown = false } end
  title, msg = tostring(title or ""), tostring(msg or "")
  local window_id, rect = placement(session_id, block_id)
  local size = api.block(session_id, block_id, "size")
  if not (window_id and rect and size and size.columns) then return { shown = false } end
  local cols = size.columns / rect.w
  local rows = size.rows / rect.h
  for _, b in ipairs(api.terminals(session_id)) do
    if b.label == "toast" then api.close(session_id, b.block_id) end
  end
  -- The box is 3 rows by the message plus its frame. The app pads a layer by
  -- about a row and two columns, so the layer asks for that much more.
  local width = math.min(math.max(#msg + 4, #title + 10, 28), math.floor(cols * 0.45))
  local w, h = (width + 2) / cols, 4 / rows
  local r = api.try("session.new_layer", {
    session_id = session_id, window_id = window_id,
    bounds = { x = math.max(0, 1 - w - 2 / cols), y = math.min(1 / rows, 1 - h), w = w, h = h },
    layout = rex.layout.block{ flavor = api.SHELL, label = "toast",
      options = { command = shell.bin("rex-toast", "draw", level or "info", title, msg, tostring(seconds or 2.5)) } },
    focus = false,
  })
  return { shown = r ~= nil }
end

return M
