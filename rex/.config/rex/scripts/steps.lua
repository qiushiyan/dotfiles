-- rex do ~/.config/rex/scripts/steps.lua -s SESSION session=SESSION block=BLOCK [sid=CLAUDE_SESSION] [bin=claude-steps]
--
-- A steps sidecar: `claude-steps show` for the Claude session in one agent
-- block, redrawn each time that block reports a status (rex-agent publishes
-- on every prompt, tool call and stop), so it is current after every turn
-- without polling. The block's Claude session is found again on each redraw,
-- so /clear and /resume carry it to the new session. It stops, closing its
-- pane, when the agent block is gone. `rex-steps` and the steps_sidecar action (⌘⇧S) open it.

package.path = os.getenv("HOME") .. "/.config/rex/lua/?.lua;" .. package.path
local kit = require("rexkit")

local SESSION, BLOCK = rex.args.session, rex.args.block
local BIN = rex.args.bin or "claude-steps"
if not (SESSION and BLOCK) then error("steps.lua needs session= and block=") end

local ESC = string.char(27)
local function dim(s) return ESC .. "[90m" .. s .. ESC .. "[0m" end

local function size()
  local p = io.popen("stty size < /dev/tty 2>/dev/null")
  local out = p and p:read("*l") or ""
  if p then p:close() end
  local rows, cols = out:match("(%d+) (%d+)")
  return tonumber(rows) or 40, tonumber(cols) or 80
end

local function sh_quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

local function agent_label()
  for _, b in ipairs(kit.terminals(SESSION)) do
    if b.block_id == BLOCK then return b.label end
  end
end

local state = ""

local function render()
  local label = agent_label()
  if not label then rex.stop(0) return end
  local sid = rex.args.sid
  -- Claude reports at SessionStart before it writes its sessions file, so a
  -- first look can come up empty: give it a few seconds.
  for _ = 1, 6 do
    if sid then break end
    sid = kit.claude_session(SESSION, BLOCK)
    if not sid and state ~= "" then rex.sleep(1) else break end
  end
  local rows, cols = size()

  local lines = {}
  local head = ESC .. "[1msteps" .. ESC .. "[0m " .. dim("· " .. label .. (state ~= "" and " · " .. state or "")
    .. (sid and " · " .. sid:sub(1, 8) or "") .. " · " .. os.date("%H:%M:%S"))
  lines[1] = head
  lines[2] = ""
  if not sid then
    lines[3] = dim("No Claude session in this block yet; the steps appear")
    lines[4] = dim("once Claude starts here and reports.")
  else
    local p = io.popen(string.format("CLICOLOR_FORCE=1 COLUMNS=%d %s show %s 2>&1", cols, sh_quote(BIN), sh_quote(sid)))
    local body = p:read("*a")
    p:close()
    if body:find("no transcript", 1, true) then
      body = dim("A new session: its steps appear after the first prompt.")
    end
    -- Through a local: `for … in (s:gsub(…) .. x):gmatch(…)` crashes Rex's Lua
    -- (README, Gotchas).
    body = body:gsub("\n$", "") .. "\n"
    for line in body:gmatch("(.-)\n") do
      if #lines >= rows - 1 then break end
      lines[#lines + 1] = line
    end
  end
  io.write(ESC .. "[H" .. ESC .. "[2J" .. table.concat(lines, "\n"))
  io.stdout:flush()
end

rex.on("block_event", function(target, ev)
  if target.block_id ~= BLOCK then return end
  if ev.name == "program_status_changed" then
    state = (ev.record and ev.record.state) or ""
    render()
  end
end)

-- A closed agent block reports nothing more, so the layout changes are
-- where its sidecar learns it is gone.
rex.on("session_view_changed", function()
  if not agent_label() then rex.stop(0) end
end)

kit.attach(SESSION)
render()
