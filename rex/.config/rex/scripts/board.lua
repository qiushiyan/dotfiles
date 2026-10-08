-- rex do ~/.config/rex/scripts/board.lua --all
--
-- A live board of every agent on this Rex server and on every other host it
-- knows (`rex hosts`: the mini, seen from the laptop), most urgent first. It
-- reads the OSC 7501 records agents publish (rex-agent). This server's agents
-- redraw it on each program_status_changed or title_changed block event;
-- another host's are polled every few seconds, since events reach a script
-- only from its own server. `rex-board` runs it; the agents_board action
-- opens it in a floating layer.

package.path = os.getenv("HOME") .. "/.config/rex/lua/?.lua;" .. package.path
local kit = require("rexkit")

local ESC = string.char(27)
-- Resets bold and colour only, so a popup's background survives.
local function sgr(code, s) return ESC .. "[" .. code .. "m" .. s .. ESC .. "[22;39m" end

-- The app draws a floating layer's default background see-through, so the
-- popup paints its own: palette slot 0, the theme's darkest.
local BG = rex.args.popup and (ESC .. "[40m") or ""

-- ANSI slots, so the board follows whatever theme the terminal has.
local STYLE = {
  blocked = "1;31", error = "1;35", done = "1;32", working = "33", idle = "90",
}
local ICON = { blocked = "●", error = "✖", done = "✔", working = "◐", idle = "○" }

local rows = {}          -- key -> row (see kit.agents)
local labels = {}        -- session_id -> label
local last_seed = 0

local function key(row) return (row.server or "") .. "|" .. row.block_id .. "/" .. (row.record.id or "") end

local POLL = 3           -- seconds between polls of other hosts
local remotes = kit.remotes()
local last_remotes = os.time()

-- What claude-steps knows of an agent's Claude session: its title and branch,
-- shown under the agent's row. Read again only when the agent changes state.
local STEPS = os.getenv("HOME") .. "/.local/bin/claude-steps"
local about = {}         -- block_id -> { state = …, text = … }

local function steps_about(row)
  -- claude-steps reads this machine's transcripts only.
  if row.server then return nil end
  local cached = about[row.block_id]
  if cached and cached.state == row.record.state then return cached.text end
  local text
  local sid = kit.claude_session(row.session_id, row.block_id)
  if sid then
    local p = io.popen("CLICOLOR=0 " .. STEPS .. " show '" .. sid .. "' --json 2>/dev/null")
    local body = p and p:read("*a") or ""
    if p then p:close() end
    local title = body:match('"title"%s*:%s*"(.-)"')
    local branch = body:match('"branch"%s*:%s*"(.-)"')
    if title then text = title .. (branch and branch ~= "" and ("  ⎇ " .. branch) or "") end
  end
  about[row.block_id] = { state = row.record.state, text = text }
  return text
end

-- Another host's rows, replacing the last poll's. A host that stops
-- answering keeps its rows off the board until it answers again.
local function poll_remotes()
  for k, row in pairs(rows) do
    if row.server then rows[k] = nil end
  end
  for _, K in ipairs(remotes) do
    local ok, list = pcall(K.agents)
    for _, row in ipairs(ok and list or {}) do rows[key(row)] = row end
    local ok2, sessions = pcall(K.sessions)
    for _, s in ipairs(ok2 and sessions or {}) do labels[K.label .. "|" .. s.session_id] = s.label end
  end
end

local function seed()
  rows = {}
  for _, s in ipairs(kit.sessions()) do labels[s.session_id] = s.label end
  for _, row in ipairs(kit.agents()) do rows[key(row)] = row end
  poll_remotes()
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
  local out = { BG .. ESC .. "[H" .. ESC .. "[2J" }
  local head = sgr("1", " AGENTS ") .. (#remotes > 0 and sgr("90", "+ " .. #remotes .. " host ") or "") .. "  "
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
    local session = labels[(row.server and (row.server .. "|") or "") .. row.session_id] or row.session or "?"
    local where = (row.server and (row.server .. ":") or "") .. session .. " › " .. (row.block or "")
    local line = "  " .. sgr(STYLE[r.state] or "0", (ICON[r.state] or "?") .. " " .. fit(r.state, 8))
      .. " " .. fit(r.kind or "", 10)
      .. " " .. sgr("1", fit(r.title or r.effective_app or r.app or "", 14))
      .. " " .. sgr("90", fit(where, 18))
      .. " " .. fit(r.msg or row.term_title or "", msg_w)
      .. " " .. sgr("90", kit.age(r.updated_at))
    out[#out + 1] = line
    local text = steps_about(row)
    if text then out[#out + 1] = "    " .. sgr("90", fit(text, width - 6)) end
  end
  -- Erase-in-line fills each line's rest with the background (bce).
  io.write(table.concat(out, ESC .. "[K\n"), ESC .. "[K\n")
  io.stdout:flush()
end

-- One block event from this server; true when the board changed.
local function apply(target, ev)
  if ev.name == "program_status_changed" then
    local id = ev.id or (ev.record and ev.record.id) or ""
    local k = "|" .. target.block_id .. "/" .. id
    if ev.record and ev.record.state ~= "clear" then
      -- A row first seen here lacks its labels; the next render re-seeds them.
      if not rows[k] then last_seed = 0 end
      local row = rows[k] or { session_id = target.session_id, block_id = target.block_id }
      row.record = ev.record
      rows[k] = row
    else
      rows[k] = nil
    end
    return true
  elseif ev.name == "program_status_removed" then
    for _, id in ipairs(ev.ids or {}) do rows["|" .. target.block_id .. "/" .. id] = nil end
    return true
  elseif ev.name == "title_changed" then
    for _, row in pairs(rows) do
      if not row.server and row.block_id == target.block_id then row.term_title = ev.title; return true end
    end
  end
  return false
end

-- A loop rather than rex.on handlers: rex.wait hands over this server's
-- events as they come (keeping any that arrive between waits), and its
-- timeout is the clock that polls the other hosts and ages the rows.
seed()
render()
local last_render, last_poll = os.time(), os.time()
while true do
  local ev, target = rex.wait("block_event", 1)
  local dirty = type(ev) == "table" and apply(target or ev, ev) or false
  if os.time() - last_remotes >= 60 then remotes, last_remotes = kit.remotes(), os.time() end
  if #remotes > 0 and os.time() - last_poll >= POLL then
    poll_remotes()
    last_poll, dirty = os.time(), true
  end
  if dirty or os.time() - last_render >= 5 then
    render()
    last_render = os.time()
  end
end
