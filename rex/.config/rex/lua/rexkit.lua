-- rexkit: helpers shared by init.lua and the scripts under ../scripts.
--
-- Everything here runs inside Rex's Lua 5.1 (init.lua actions on the server,
-- or `rex do` scripts), so the only API is the `rex` global. Lab notes on how
-- that API behaves live in ~/dotfiles/docs/rex.md.

local M = {}

M.TERMINAL = "com.superlogical.terminal"

M.STATE = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/rex-lab"

-- The calls below go to one server: this one (rex.call), or another host's
-- (rex.server(label).call), for the views that span the laptop and the mini.
-- bind gives a table those calls for one server; M is this server's, and
-- M.remote(label) another's.
local function bind(K, raw, label)
  K.label = label

  -- rex.call returns nil plus a message on failure instead of raising.
  function K.call(method, payload)
    local result, err = K.try(method, payload)
    if result == nil and err ~= nil then error(method .. ": " .. tostring(err), 2) end
    return result
  end

  -- A control connection must attach to a session before calling into it.
  -- init.lua's state outlives the connection an action runs on, so the
  -- record of what is attached can be stale: a call refused as not attached
  -- attaches and tries once more.
  local attached = {}
  function K.attach(session_id)
    if attached[session_id] then return end
    K.call("session.attach", { session_id = session_id })
    attached[session_id] = true
  end

  function K.try(method, payload)
    payload = payload or {}
    local result, err = raw(method, payload)
    if result == nil and payload.session_id and tostring(err):find("not attached", 1, true) then
      attached[payload.session_id] = nil
      raw("session.attach", { session_id = payload.session_id })
      attached[payload.session_id] = true
      result, err = raw(method, payload)
    end
    return result, err
  end

  function K.sessions()
    return K.call("session.list").sessions or {}
  end

  function K.terminals(session_id)
    K.attach(session_id)
    local out = {}
    for _, b in ipairs(K.call("session.list_blocks", { session_id = session_id }).blocks or {}) do
      if b.block_id and (b.creator_name == M.TERMINAL or (b.flavor or ""):find(M.TERMINAL, 1, true) == 1) then
        out[#out + 1] = b
      end
    end
    return out
  end

  function K.block(session_id, block_id, method, args)
    K.attach(session_id)
    return K.try(M.TERMINAL .. "." .. method, { session_id = session_id, block_id = block_id, args = args or {} })
  end

  -- The block that has focus in a session's active window.
  function K.focused_block(session_id)
    K.attach(session_id)
    local view = K.try("session.view", { session_id = session_id })
    return view and view.focused_window and view.focused_window.focused_block_id
  end

  -- One row per agent record across every session on this server, each
  -- naming the server when it is another host's.
  function K.agents()
    local rows = {}
    for _, s in ipairs(K.sessions()) do
      for _, b in ipairs(K.terminals(s.session_id)) do
        local status = K.block(s.session_id, b.block_id, "program_status")
        local title = K.block(s.session_id, b.block_id, "title")
        for _, r in ipairs((status and status.records) or {}) do
          rows[#rows + 1] = {
            server = label, session_id = s.session_id, session = s.label or s.session_id,
            block_id = b.block_id, block = b.label, window_id = b.window_id,
            term_title = title and title.title or nil, record = r,
          }
        end
      end
    end
    M.sort(rows)
    return rows
  end

  return K
end

bind(M, function(method, payload) return rex.call(method, payload) end, nil)

-- Another host's server, by its label in `rex hosts`.
function M.remote(label)
  local handle = rex.server(label)
  return bind({}, function(method, payload) return handle.call(method, payload) end, label)
end

-- Every other host's server this one can reach, as M.remote gives them,
-- leaving out a host that is this server under another name. A host that
-- does not answer is left out, so a sleeping laptop costs one failed call.
function M.remotes()
  local out = {}
  if not rex.servers then return out end
  local me = M.try("server.status")
  me = me and me.instance_id
  for _, label in ipairs(rex.servers() or {}) do
    local ok, K = pcall(M.remote, label)
    local status = ok and K.try("server.status")
    if status and status.instance_id and status.instance_id ~= me then out[#out + 1] = K end
  end
  return out
end

-- Agent rows from this server and every other host's, most urgent first.
function M.agents_everywhere(remotes)
  local rows = M.agents()
  for _, K in ipairs(remotes or M.remotes()) do
    local ok, more = pcall(K.agents)
    for _, row in ipairs(ok and more or {}) do rows[#rows + 1] = row end
  end
  M.sort(rows)
  return rows
end

-- Where you are: the session and client of the last thing you did, a key an
-- action took or a tab you switched to (rexd). The app does not say which
-- session it shows (it stays attached to every session it has opened), so
-- this is the best the server knows.
local HERE = M.STATE .. "/here"
function M.note_here(session_id, client_id)
  if not session_id then return end
  os.execute("mkdir -p '" .. M.STATE .. "'")
  local f = io.open(HERE .. ".tmp", "w")
  if not f then return end
  f:write(session_id, " ", client_id or "-", "\n")
  f:close()
  os.rename(HERE .. ".tmp", HERE)
end

function M.here()
  local f = io.open(HERE, "r")
  local line = f and f:read("*l")
  if f then f:close() end
  local sid, cid = (line or ""):match("^(%S+) (%S+)$")
  return sid, cid ~= "-" and cid or nil
end

-- The output of a shell command run on the host the session's calls go
-- to, in directory CWD (optional), or nil. Here it is io.popen; on another
-- host's session (an action run from the laptop's config with ctx.server)
-- a hidden block in SESSION_ID runs it there and its screen is read back,
-- then the block is closed. SCRIPT is sh source; ARGS become $1, $2, ….
function M.run_there(ctx, session_id, script, args, cwd)
  args = args or {}
  if not (ctx and ctx.server) then
    local line = "PATH=" .. M.sh_quote(M.PATH) .. " sh -c " .. M.sh_quote(script) .. " sh"
    for _, a in ipairs(args) do line = line .. " " .. M.sh_quote(a) end
    if cwd then line = "cd " .. M.sh_quote(cwd) .. " && " .. line end
    local p = io.popen(line .. " 2>/dev/null")
    local out = p and p:read("*a") or ""
    if p then p:close() end
    out = out:gsub("%s+$", "")
    return out ~= "" and out or nil
  end
  local mark = "--rex-lab-end--"
  local command = { "/bin/sh", "-c",
    'export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"; '
      .. 'mark=$1; shift; ( ' .. script .. ' ) 2>/dev/null; printf "\\n%s\\n" "$mark"; sleep 10',
    "run", mark }
  for _, a in ipairs(args) do command[#command + 1] = a end
  local r = M.try("session.new_block", { session_id = session_id, flavor = M.TERMINAL .. ".shell",
    label = "rex-lab-run", options = { command = command, cwd = cwd } })
  if not (r and r.block_id) then return nil end
  local text
  for _ = 1, 60 do
    local out = M.block(session_id, r.block_id, "format", { format = "text", unwrap = true })
    out = out and out.content or ""
    local at = out:find(mark, 1, true)
    if at then text = out:sub(1, at - 1); break end
    if rex.sleep then pcall(rex.sleep, 0.05) end
  end
  M.try("block.close", { session_id = session_id, block_id = r.block_id })
  if text then text = text:gsub("%s+$", "") end
  return text ~= "" and text or nil
end

-- The text of a file in the lab's state directory (~/.local/state/rex-lab)
-- on the session's host, or nil.
function M.read_state(ctx, session_id, relpath)
  return M.run_there(ctx, session_id,
    'cat "${XDG_STATE_HOME:-$HOME/.local/state}/rex-lab/$1"', { relpath })
end

-- Whether the app whose key ran an action is on this machine, so `open` and
-- the clipboard here are the ones you are looking at. On another host's
-- session the action runs from the config of the app's own machine (here);
-- otherwise the app may be another machine's, over Tailscale.
function M.app_is_here(ctx)
  if ctx and ctx.server then return true end
  return M.client_is_local(ctx and ctx.client_id)
end

-- Put TEXT on the clipboard of the machine you are looking from: here with
-- pbcopy when the app is here and the block is another host's (no tty of
-- it here), else through the block's terminal (OSC 52).
function M.copy(ctx, session_id, block_id, text)
  if ctx and ctx.server then
    -- Not io.popen(…, "w"): Rex's Lua never closes that pipe, so pbcopy
    -- waits for the end of its input forever.
    return os.execute("printf %s " .. M.sh_quote(text) .. " | pbcopy") == 0
  end
  return M.osc52(session_id, block_id, text)
end

-- Whether a client runs on this machine: a remote app (the laptop's, over
-- Tailscale) reaches the server over the network, so `open` here would open
-- the URL on the wrong screen.
function M.client_is_local(client_id)
  if not client_id then return true end
  local r = M.try("client.inspect", { client_id = client_id })
  local transport = r and r.client and r.client.principal and r.client.principal.transport
  return transport == nil or transport == "unix"
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

-- Layout geometry ---------------------------------------------------------------

-- Every visible tiled block of a window, with its normalized rect.
local function tiled_rects(window)
  local out = {}
  for _, layer in ipairs((window and window.layers) or {}) do
    if layer.kind == "tiled" then
      for _, b in ipairs(layer.blocks or {}) do out[#out + 1] = b end
    end
  end
  return out
end

-- The window of a session's view that holds BLOCK_ID, else nil.
function M.window_of(view, block_id)
  for _, w in ipairs((view and view.windows) or {}) do
    for _, b in ipairs(tiled_rects(w)) do
      if b.block_id == block_id then return w end
    end
  end
end

-- The block beside BLOCK_ID in DIRECTION (left, right, up, down) within its
-- window: of the blocks that touch that edge and overlap it across, the one
-- that overlaps most. nil at the window's edge. tmux's pane_at_right, from
-- the rects session.view reports.
function M.neighbor(view, block_id, direction)
  local w = M.window_of(view, block_id)
  local rects = tiled_rects(w)
  local me
  for _, b in ipairs(rects) do if b.block_id == block_id then me = b.rect end end
  if not me then return nil end
  local eps, best, best_overlap = 1e-3, nil, 0
  local function overlap(a0, a1, b0, b1) return math.min(a1, b1) - math.max(a0, b0) end
  for _, b in ipairs(rects) do
    local r = b.rect
    if b.block_id ~= block_id then
      local touches, across
      if direction == "right" then
        touches, across = math.abs(r.x - (me.x + me.w)) < eps, overlap(me.y, me.y + me.h, r.y, r.y + r.h)
      elseif direction == "left" then
        touches, across = math.abs(r.x + r.w - me.x) < eps, overlap(me.y, me.y + me.h, r.y, r.y + r.h)
      elseif direction == "down" then
        touches, across = math.abs(r.y - (me.y + me.h)) < eps, overlap(me.x, me.x + me.w, r.x, r.x + r.w)
      else
        touches, across = math.abs(r.y + r.h - me.y) < eps, overlap(me.x, me.x + me.w, r.x, r.x + r.w)
      end
      if touches and across > best_overlap then best, best_overlap = b.block_id, across end
    end
  end
  return best
end

-- The session you are in (M.here) and its active window.
function M.app_view()
  local sid = M.here()
  local view = sid and M.try("session.view", { session_id = sid })
  if view then return sid, view.active_window_id end
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

-- The command line for one of the lab's tools in a pane the server starts.
-- The path is resolved by the pane's own shell, on the host it runs on: an
-- action that runs from the laptop's config on the mini's session would
-- otherwise name the laptop's home directory there.
function M.bin(name, ...)
  return { "/bin/sh", "-c", 'exec "$HOME/.local/bin/' .. name .. '" "$@"', name, ... }
end

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

-- A desktop notification from the terminal in a block (OSC 9), as a program
-- in it would send one: Rex turns it into a desktop_notification event for
-- the app.
function M.osc9(session_id, block_id, text)
  local fg = M.foreground(session_id, block_id)
  local tty = fg and tty_of(fg.pid)
  if not tty then return false end
  text = tostring(text):gsub("[%c]", " ")
  return os.execute("printf '\\033]9;%s\\007' " .. M.sh_quote(text) .. " > " .. M.sh_quote(tty)) == 0
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
-- Off: the app paints no floating layer, and neither a block or window label
-- nor a desktop notification (OSC 9, osascript) reached the screen in our
-- tests (docs/rex.md). Callers keep calling it; true turns layers back on.
M.LAYER_TOASTS = false

function M.toast(session_id, block_id, level, title, msg, seconds)
  if not M.LAYER_TOASTS then return { shown = false } end
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
      options = { command = M.bin("rex-toast", "draw",
        level or "info", title, msg, tostring(seconds or 2.5)) },
    } },
    focus = false,
  })
  return { shown = r ~= nil }
end

return M
