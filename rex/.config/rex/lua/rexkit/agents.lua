-- rexkit.agents: the agents of one server or every reachable one, read from
-- the OSC 7501 program-status records they publish (rex-agent), and the
-- Claude session behind a block.

local api = require("rexkit.api")

local M = {}

-- Lower ranks need the human sooner. `clear` never reaches a record list.
M.RANK = { blocked = 1, error = 2, done = 3, working = 4, idle = 5 }

local function rank(row) return M.RANK[row.record.state] or 9 end

-- Most urgent first; within a state, the one that has waited longest.
function M.sort(rows)
  table.sort(rows, function(a, b)
    local ra, rb = rank(a), rank(b)
    if ra ~= rb then return ra < rb end
    return (a.record.updated_at or "") < (b.record.updated_at or "")
  end)
  return rows
end

-- Whether a row needs the human: blocked, errored or finished. `working`
-- and `idle` need nobody.
function M.waiting(row) return rank(row) <= M.RANK.done end

-- The agent that has waited longest in the most urgent state, else nil.
function M.most_urgent(rows)
  for _, row in ipairs(rows) do
    if M.waiting(row) then return row end
  end
end

-- One row per agent record across every session on server K (api, or an
-- api.remote), most urgent first, each naming the server when it is another
-- host's. opts.titles adds each agent terminal's title (term_title), one
-- call more per agent block: the board shows it, a jump needs none.
function M.rows(K, opts)
  K, opts = K or api, opts or {}
  local rows = {}
  for _, s in ipairs(K.sessions()) do
    for _, b in ipairs(K.terminals(s.session_id)) do
      local status = K.block(s.session_id, b.block_id, "program_status")
      local records = (status and status.records) or {}
      local title = #records > 0 and opts.titles and K.block(s.session_id, b.block_id, "title")
      for _, r in ipairs(records) do
        rows[#rows + 1] = {
          server = K.label, session_id = s.session_id, session = s.label or s.session_id,
          block_id = b.block_id, block = b.label, window_id = b.window_id,
          term_title = title and title.title or nil, record = r,
        }
      end
    end
  end
  return M.sort(rows)
end

-- Rows from every other host's server (api.remotes, unless given), most
-- urgent first. A host that fails is left out.
function M.remote_rows(remotes, opts)
  local rows = {}
  for _, K in ipairs(remotes or api.remotes()) do
    local ok, more = pcall(M.rows, K, opts)
    for _, row in ipairs(ok and more or {}) do rows[#rows + 1] = row end
  end
  return M.sort(rows)
end

-- Time ---------------------------------------------------------------------------

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

-- How long ago ISO was, as 12s, 5m, 3h or 2d.
function M.age(iso)
  local t = M.epoch(iso)
  if not t then return "" end
  local s = os.time() - t
  if s < 60 then return s .. "s" end
  if s < 3600 then return math.floor(s / 60) .. "m" end
  if s < 86400 then return math.floor(s / 3600) .. "h" end
  return math.floor(s / 86400) .. "d"
end

-- Claude sessions ----------------------------------------------------------------

-- Claude Code writes <config dir>/sessions/<pid>.json for each running
-- process, naming its session id. The config dirs are ~/.claude, any
-- CLAUDE_CONFIG_DIR, and each account of the x launchers. Listing the
-- accounts takes a shell, so the list is kept for a minute.
local dirs, dirs_at = nil, 0

local function config_dirs()
  if dirs and os.time() - dirs_at < 60 then return dirs end
  local home = os.getenv("HOME")
  dirs = { home .. "/.claude" }
  -- Not in the constructor: a nil there would end ipairs before ~/.claude.
  if os.getenv("CLAUDE_CONFIG_DIR") then table.insert(dirs, 1, os.getenv("CLAUDE_CONFIG_DIR")) end
  local p = io.popen("ls -d " .. home .. "/.claude-accounts/*/ 2>/dev/null")
  if p then
    for d in p:lines() do dirs[#dirs + 1] = (d:gsub("/$", "")) end
    p:close()
  end
  dirs_at = os.time()
  return dirs
end

local function session_file(pid)
  for _, dir in ipairs(config_dirs()) do
    local f = io.open(dir .. "/sessions/" .. pid .. ".json", "r")
    if f then
      local body = f:read("*a")
      f:close()
      return body
    end
  end
end

-- The Claude session running in a block of this server: its id and
-- directory, or nil. The pid comes from the block's status record (its
-- owner is the process that reported) or, failing that, the block's
-- foreground process.
function M.claude_session(session_id, block_id)
  local pids = {}
  local status = api.block(session_id, block_id, "program_status")
  for _, r in ipairs((status and status.records) or {}) do
    if r.owner and r.owner.pid then pids[#pids + 1] = r.owner.pid end
  end
  local fg = api.foreground(session_id, block_id)
  if fg then pids[#pids + 1] = fg.pid end
  for _, pid in ipairs(pids) do
    local body = session_file(pid)
    if body then
      return body:match('"sessionId"%s*:%s*"([^"]+)"'), body:match('"cwd"%s*:%s*"([^"]+)"')
    end
  end
end

return M
