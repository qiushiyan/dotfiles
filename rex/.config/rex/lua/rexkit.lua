-- rexkit: helpers shared by init.lua and the scripts under ../scripts.
--
-- Everything here runs inside Rex's Lua 5.1 (init.lua actions on the server,
-- or `rex do` scripts), so the only API is the `rex` global. Lab notes on how
-- that API behaves live in ~/dotfiles/docs/rex.md.

local M = {}

M.TERMINAL = "com.superlogical.terminal"

-- rex.call returns nil plus a message on failure instead of raising.
function M.call(method, payload)
  local result, err = M.try(method, payload)
  if result == nil and err ~= nil then error(method .. ": " .. tostring(err), 2) end
  return result
end

-- A control connection must attach to a session before calling into it.
-- init.lua's state outlives the connection an action runs on, so the record
-- of what is attached can be stale: a call refused as not attached attaches
-- and tries once more.
local attached = {}
function M.attach(session_id)
  if attached[session_id] then return end
  M.call("session.attach", { session_id = session_id })
  attached[session_id] = true
end

function M.try(method, payload)
  payload = payload or {}
  local result, err = rex.call(method, payload)
  if result == nil and payload.session_id and tostring(err):find("not attached", 1, true) then
    attached[payload.session_id] = nil
    rex.call("session.attach", { session_id = payload.session_id })
    attached[payload.session_id] = true
    result, err = rex.call(method, payload)
  end
  return result, err
end

function M.sessions()
  return M.call("session.list").sessions or {}
end

function M.terminals(session_id)
  M.attach(session_id)
  local out = {}
  for _, b in ipairs(M.call("session.list_blocks", { session_id = session_id }).blocks or {}) do
    if b.block_id and (b.creator_name == M.TERMINAL or (b.flavor or ""):find(M.TERMINAL, 1, true) == 1) then
      out[#out + 1] = b
    end
  end
  return out
end

function M.block(session_id, block_id, method, args)
  M.attach(session_id)
  return M.try(M.TERMINAL .. "." .. method, { session_id = session_id, block_id = block_id, args = args or {} })
end

-- A table as one line of text, for logs.
function M.dump(v, depth)
  depth = depth or 0
  if type(v) ~= "table" or depth > 4 then return tostring(v) end
  local parts = {}
  for key, x in pairs(v) do parts[#parts + 1] = tostring(key) .. "=" .. M.dump(x, depth + 1) end
  table.sort(parts)
  return "{" .. table.concat(parts, ", ") .. "}"
end

-- The block that has focus in a session's active window.
function M.focused_block(session_id)
  M.attach(session_id)
  local view = M.try("session.view", { session_id = session_id })
  return view and view.focused_window and view.focused_window.focused_block_id
end

-- Agent records (OSC 7501) ------------------------------------------------------

-- Lower ranks need the human sooner. `clear` never reaches a record list.
M.RANK = { blocked = 1, error = 2, done = 3, working = 4, idle = 5 }

-- "2026-10-08T13:55:29.96152+01:00" -> epoch seconds.
local utc_offset = os.time() - os.time(os.date("!*t"))
function M.epoch(iso)
  if not iso then return nil end
  local y, mo, d, h, mi, s, rest = iso:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)[%.%d]*(.*)$")
  if not y then return nil end
  local t = os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = s }) + utc_offset
  local sign, oh, om = rest:match("^([%+%-])(%d+):(%d+)$")
  if sign then
    local off = tonumber(oh) * 3600 + tonumber(om) * 60
    t = sign == "+" and t - off or t + off
  end
  return t
end

function M.age(iso)
  local t = M.epoch(iso)
  if not t then return "" end
  local s = os.time() - t
  if s < 60 then return s .. "s" end
  if s < 3600 then return math.floor(s / 60) .. "m" end
  if s < 86400 then return math.floor(s / 3600) .. "h" end
  return math.floor(s / 86400) .. "d"
end

-- One row per agent record across every session on this server.
function M.agents()
  local rows = {}
  for _, s in ipairs(M.sessions()) do
    for _, b in ipairs(M.terminals(s.session_id)) do
      local status = M.block(s.session_id, b.block_id, "program_status")
      local title = M.block(s.session_id, b.block_id, "title")
      for _, r in ipairs((status and status.records) or {}) do
        rows[#rows + 1] = {
          session_id = s.session_id, session = s.label or s.session_id,
          block_id = b.block_id, block = b.label, window_id = b.window_id,
          term_title = title and title.title or nil, record = r,
        }
      end
    end
  end
  M.sort(rows)
  return rows
end

function M.sort(rows)
  table.sort(rows, function(a, b)
    local ra, rb = M.RANK[a.record.state] or 9, M.RANK[b.record.state] or 9
    if ra ~= rb then return ra < rb end
    return (a.record.updated_at or "") < (b.record.updated_at or "")
  end)
end

-- The agent that has waited longest in the most urgent state, skipping
-- `working` and `idle`, which need nobody.
function M.most_urgent(rows)
  for _, row in ipairs(rows) do
    if (M.RANK[row.record.state] or 9) <= M.RANK.done then return row end
  end
end

-- Claude sessions ------------------------------------------------------------

-- Claude Code writes <config dir>/sessions/<pid>.json for each running
-- process, naming its session id. The pid comes from the block's status
-- record (its owner is the process that reported) or, failing that, the
-- block's foreground process.
local function session_file(pid)
  local home = os.getenv("HOME")
  local dirs = { home .. "/.claude" }
  -- Not in the constructor: a nil there would end ipairs before ~/.claude.
  if os.getenv("CLAUDE_CONFIG_DIR") then table.insert(dirs, 1, os.getenv("CLAUDE_CONFIG_DIR")) end
  local p = io.popen("ls -d " .. home .. "/.claude-accounts/*/ 2>/dev/null")
  if p then
    for d in p:lines() do dirs[#dirs + 1] = (d:gsub("/$", "")) end
    p:close()
  end
  for _, dir in ipairs(dirs) do
    local f = io.open(dir .. "/sessions/" .. pid .. ".json", "r")
    if f then
      local body = f:read("*a")
      f:close()
      return body
    end
  end
end

-- The Claude session running in a block: its id and directory, or nil.
function M.claude_session(session_id, block_id)
  local pids = {}
  local status = M.block(session_id, block_id, "program_status")
  for _, r in ipairs((status and status.records) or {}) do
    if r.owner and r.owner.pid then pids[#pids + 1] = r.owner.pid end
  end
  local proc = M.block(session_id, block_id, "process")
  if proc and proc.foreground then pids[#pids + 1] = proc.foreground.pid end
  for _, pid in ipairs(pids) do
    local body = session_file(pid)
    if body then
      return body:match('"sessionId"%s*:%s*"([^"]+)"'), body:match('"cwd"%s*:%s*"([^"]+)"')
    end
  end
end

-- Panes: directory, tty, clipboard, feedback ---------------------------------

-- Actions and the panes they start inherit the server's bare system PATH.
M.PATH = os.getenv("HOME") .. "/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

function M.sh_quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

-- The process in front in a block: the one a key press is about. Its cwd
-- comes from the OS, so it is right while nvim or Claude runs.
function M.foreground(session_id, block_id)
  local proc = M.block(session_id, block_id, "process")
  return proc and (proc.foreground or proc.child)
end

function M.cwd(session_id, block_id)
  local fg = M.foreground(session_id, block_id)
  return fg and fg.cwd
end

local function tty_of(pid)
  local p = io.popen("ps -o tty= -p " .. tonumber(pid) .. " 2>/dev/null")
  local tty = p and (p:read("*l") or ""):gsub("%s", "") or ""
  if p then p:close() end
  if tty == "" or tty == "??" then return nil end
  return "/dev/" .. tty
end

-- Ask the terminal in a block to copy TEXT (OSC 52 on its output side). Rex
-- turns that into a clipboard_written event, and the app showing the block
-- copies it: the clipboard of the machine you are looking from.
function M.osc52(session_id, block_id, text)
  local fg = M.foreground(session_id, block_id)
  local tty = fg and tty_of(fg.pid)
  if not tty then return false end
  local cmd = "printf '\\033]52;c;%s\\007' \"$(printf %s " .. M.sh_quote(text)
    .. " | base64 | tr -d '\\n')\" > " .. M.sh_quote(tty)
  return os.execute(cmd) == 0
end

-- A macOS notification: the one way an action has to say something.
function M.notify(title, text)
  local script = "display notification " .. string.format("%q", text) .. " with title " .. string.format("%q", title)
  os.execute("osascript -e " .. M.sh_quote(script) .. " >/dev/null 2>&1 &")
end

-- Toasts ----------------------------------------------------------------------

-- The window a block is placed in, with the block's normalized rect there.
local function placement(session_id, block_id)
  local view = M.try("session.view", { session_id = session_id })
  for _, w in ipairs((view and view.windows) or {}) do
    for _, layer in ipairs(w.layers or {}) do
      for _, b in ipairs(layer.blocks or {}) do
        if b.block_id == block_id then return w.window_id, b.rect end
      end
    end
  end
end

-- A snacks-style notification at the top right of the window BLOCK is in
-- (rex-toast draws it). The layer is sized in cells from the block's own grid
-- and rect, takes no focus, and closes when the toast's process exits. A new
-- toast replaces one still showing.
function M.toast(session_id, block_id, level, title, msg, seconds)
  title, msg = tostring(title or ""), tostring(msg or "")
  local window_id, rect = placement(session_id, block_id)
  local size = M.block(session_id, block_id, "size")
  if not (window_id and rect and size and size.columns) then return { shown = false } end
  local cols = size.columns / rect.w
  local rows = size.rows / rect.h
  for _, b in ipairs(M.terminals(session_id)) do
    if b.label == "toast" then M.try("block.close", { session_id = session_id, block_id = b.block_id }) end
  end
  -- The box is 3 rows by the message plus its frame. The app pads a layer by
  -- about a row and two columns, so the layer asks for that much more.
  local width = math.min(math.max(#msg + 4, #title + 10, 28), math.floor(cols * 0.45))
  local w, h = (width + 2) / cols, 4 / rows
  local r = M.try("session.new_layer", {
    session_id = session_id, window_id = window_id,
    bounds = { x = math.max(0, 1 - w - 2 / cols), y = math.min(1 / rows, 1 - h), w = w, h = h },
    layout = { block = {
      flavor = "com.superlogical.terminal.shell", label = "toast",
      options = { command = { os.getenv("HOME") .. "/.local/bin/rex-toast", "draw",
        level or "info", title, msg, tostring(seconds or 2.5) } },
    } },
    focus = false,
  })
  return { shown = r ~= nil }
end

return M
