-- rexkit.state: the lab's files in ~/.local/state/rex-lab, and the records
-- kept there: where you are (here), where keys were pressed (keys), the
-- held pane (held), and the actions log.
--
-- Rex's Lua cannot make a directory without a shell, so the directory is
-- made once, when this module loads, and again only when a write finds it
-- gone. A key press forks nothing.

local M = {}

M.DIR = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/rex-lab"

local function mkdir() os.execute("mkdir -p '" .. M.DIR:gsub("'", "'\\''") .. "'") end
mkdir()

local function open(rel, mode)
  local path = M.DIR .. "/" .. rel
  local f = io.open(path, mode)
  if not f and mode ~= "r" then
    mkdir()
    f = io.open(path, mode)
  end
  return f
end

-- The text of a state file, or nil.
function M.read(rel)
  local f = io.open(M.DIR .. "/" .. rel, "r")
  if not f then return nil end
  local text = f:read("*a")
  f:close()
  return text
end

-- Replace a state file whole: a reader never sees half of it.
function M.write(rel, text)
  local f = open(rel .. ".tmp", "w")
  if not f then return false end
  f:write(text)
  f:close()
  return os.rename(M.DIR .. "/" .. rel .. ".tmp", M.DIR .. "/" .. rel) ~= nil
end

function M.remove(rel) os.remove(M.DIR .. "/" .. rel) end

-- A table as one line of text, for logs.
function M.dump(v, depth)
  depth = depth or 0
  if type(v) ~= "table" or depth > 4 then return tostring(v) end
  local parts = {}
  for key, x in pairs(v) do parts[#parts + 1] = tostring(key) .. "=" .. M.dump(x, depth + 1) end
  table.sort(parts)
  return "{" .. table.concat(parts, ", ") .. "}"
end

-- One timestamped entry in actions.log: an action's failure, or what it
-- did on another host's session, which the app's own report does not show.
function M.log(text)
  local f = open("actions.log", "a")
  if not f then return end
  f:write(os.date("%Y-%m-%d %H:%M:%S "), text, "\n")
  f:close()
end

-- Where you are -----------------------------------------------------------------

-- The session and client of the last thing you did, a key an action took or
-- a tab you switched to (rexd). The app does not say which session it shows
-- (it stays attached to every session it has opened), so this is the best
-- the server knows.
function M.note_here(session_id, client_id)
  if not session_id then return end
  M.write("here", session_id .. " " .. (client_id or "-") .. "\n")
end

function M.here()
  local sid, cid = (M.read("here") or ""):match("^(%S+) (%S+)")
  return sid, cid ~= "-" and cid or nil
end

-- Where each key was pressed, newest last: "<host> <session> <block>", the
-- host "-" for this server. prefix Tab reads it. The record lives with the
-- config that ran the action, so it covers another host's sessions too,
-- which that host's own watcher cannot report here.
local KEEP_KEYS = 100

function M.note_key(ctx)
  if not (ctx.session_id and ctx.block_id) then return end
  local line = (ctx.server or "-") .. " " .. ctx.session_id .. " " .. ctx.block_id
  local lines = {}
  for l in (M.read("keys") or ""):gmatch("[^\n]+") do lines[#lines + 1] = l end
  if lines[#lines] == line then return end
  lines[#lines + 1] = line
  local first = math.max(1, #lines - KEEP_KEYS + 1)
  M.write("keys", table.concat(lines, "\n", first) .. "\n")
end

-- The key records, oldest first: { server = label or nil, session_id, block_id }.
function M.keys()
  local out = {}
  for line in (M.read("keys") or ""):gmatch("[^\n]+") do
    local host, s, b = line:match("^(%S+) (%S+) (%S+)$")
    if host then out[#out + 1] = { server = host ~= "-" and host or nil, session_id = s, block_id = b } end
  end
  return out
end

-- The held pane (pane mode g), a file so it survives a config reload.
function M.hold(session_id, block_id) return M.write("held", session_id .. " " .. block_id .. "\n") end

function M.held() return (M.read("held") or ""):match("^(%S+) (%S+)") end

function M.release() M.remove("held") end

return M
