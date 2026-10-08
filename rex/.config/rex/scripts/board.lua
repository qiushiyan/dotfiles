-- rex do ~/.config/rex/scripts/board.lua --all
--
-- A live board of every agent on this Rex server, most urgent first. It reads
-- the OSC 7501 records agents publish (rex-agent), then redraws on each
-- program_status_changed or title_changed block event instead of polling.
-- `rex-board` runs it; the agents_board action opens it in a floating layer.

package.path = os.getenv("HOME") .. "/.config/rex/lua/?.lua;" .. package.path
local kit = require("rexkit")

local ESC = string.char(27)
local function sgr(code, s) return ESC .. "[" .. code .. "m" .. s .. ESC .. "[0m" end

-- ANSI slots, so the board follows whatever theme the terminal has.
local STYLE = {
  blocked = "1;31", error = "1;35", done = "1;32", working = "33", idle = "90",
}
local ICON = { blocked = "●", error = "✖", done = "✔", working = "◐", idle = "○" }

local rows = {}          -- key -> row (see kit.agents)
local labels = {}        -- session_id -> label
local last_seed = 0

local function key(row) return row.block_id .. "/" .. (row.record.id or "") end

local function seed()
  rows = {}
  for _, s in ipairs(kit.sessions()) do labels[s.session_id] = s.label end
  for _, row in ipairs(kit.agents()) do rows[key(row)] = row end
  last_seed = os.time()
end

local function columns()
  local p = io.popen("stty size < /dev/tty 2>/dev/null")
  local out = p and p:read("*l") or ""
  if p then p:close() end
  return tonumber(out:match("%d+ (%d+)")) or 100
end

local function fit(s, n)
  s = tostring(s or "")
  if #s <= n then return s .. string.rep(" ", n - #s) end
  return s:sub(1, math.max(n - 1, 0)) .. "…"
end

local function render()
  if os.time() - last_seed > 10 then seed() end
  local list = {}
  for _, row in pairs(rows) do list[#list + 1] = row end
  kit.sort(list)

  local need, busy = 0, 0
  for _, row in ipairs(list) do
    local r = kit.RANK[row.record.state] or 9
    if r <= kit.RANK.done then need = need + 1 elseif row.record.state == "working" then busy = busy + 1 end
  end

  local width = columns()
  local out = { ESC .. "[H" .. ESC .. "[2J" }
  local head = sgr("1", " AGENTS ") .. "  "
    .. (need > 0 and sgr("1;31", need .. " need you") or sgr("90", "nobody waiting"))
    .. sgr("90", "  ·  " .. busy .. " working  ·  " .. os.date("%H:%M:%S"))
  out[#out + 1] = head
  out[#out + 1] = ""
  if #list == 0 then
    out[#out + 1] = sgr("90", "  No agent has reported yet. Agents publish with rex-agent (OSC 7501).")
  end
  local msg_w = math.max(width - 62, 12)
  for _, row in ipairs(list) do
    local r = row.record
    local where = (labels[row.session_id] or row.session or "?") .. " › " .. (row.block or "")
    local line = "  " .. sgr(STYLE[r.state] or "0", (ICON[r.state] or "?") .. " " .. fit(r.state, 8))
      .. " " .. fit(r.kind or "", 10)
      .. " " .. sgr("1", fit(r.title or r.effective_app or r.app or "", 14))
      .. " " .. sgr("90", fit(where, 18))
      .. " " .. fit(r.msg or row.term_title or "", msg_w)
      .. " " .. sgr("90", kit.age(r.updated_at))
    out[#out + 1] = line
  end
  io.write(table.concat(out, "\n"), "\n")
  io.stdout:flush()
end

rex.on("block_event", function(target, ev)
  if ev.name == "program_status_changed" then
    local id = ev.id or (ev.record and ev.record.id) or ""
    local k = target.block_id .. "/" .. id
    if ev.record and ev.record.state ~= "clear" then
      -- A row first seen here lacks its labels; the next render re-seeds them.
      if not rows[k] then last_seed = 0 end
      local row = rows[k] or { session_id = target.session_id, block_id = target.block_id }
      row.record = ev.record
      rows[k] = row
    else
      rows[k] = nil
    end
    render()
  elseif ev.name == "title_changed" then
    for _, row in pairs(rows) do
      if row.block_id == target.block_id then row.term_title = ev.title; render(); break end
    end
  end
end)

rex.on("session_destroyed", function() last_seed = 0; render() end)

seed()
render()
