-- lab.agents: the actions over agents (Claude sessions publishing OSC 7501
-- status, rex-agent): jump to the one that waits, the board, the
-- claude-steps sidecar, and the guard on ctrl+c that quits a tab's last
-- Claude.

local action = require("lab.action")
local client = require("lab.client")
local agents = require("rexkit.agents")
local api = require("rexkit.api")
local feedback = require("rexkit.feedback")
local layout = require("rexkit.layout")
local shell = require("rexkit.shell")
local state = require("rexkit.state")

local define = action.group("Agents")

local function where(row)
  return (row.server and (row.server .. ": ") or "") .. (row.session or "?") .. " › " .. (row.block or "?")
    .. " is " .. row.record.state
end

local function jumped(row)
  return { jumped = true, session = row.session, block = row.block, state = row.record.state }
end

-- Jump to the agent that has waited longest in the most urgent state:
-- blocked, then errored, then finished, among the agents on the host of the
-- session the key was pressed in. The app cannot be sent to another host's
-- session from an action ("no host lists it"), so an agent elsewhere is
-- named in a notification instead: on another host, or, while you work in
-- another host's session, in a different session of it.
define{
  name = "agents_next",
  title = "Jump to Agent Needing Attention",
  run = function(ctx)
    local row = agents.most_urgent(agents.rows())
    if row and not ctx.server then
      api.call("session.focus_block", { session_id = row.session_id, block_id = row.block_id })
      client.show(ctx, row.session_id, row.window_id)
      state.note_here(row.session_id, ctx.client_id)
      return jumped(row)
    end
    if row and row.session_id == ctx.session_id then
      local view = api.call("session.view", { session_id = row.session_id })
      local from, to = client.tab_index(ctx, view), layout.index_of(view, row.window_id)
      api.call("session.focus_block", { session_id = row.session_id, block_id = row.block_id })
      if from and to then client.step_tabs(from, to) end
      return jumped(row)
    end
    if not row and not ctx.server then row = agents.most_urgent(agents.remote_rows()) end
    if not row then
      feedback.notify("Agents", "no agent is waiting")
      return { jumped = false, reason = "no agent is waiting" }
    end
    feedback.notify("Agent waiting", where(row))
    return { jumped = false, elsewhere = where(row) }
  end,
}

-- The agents board in a floating layer over the current window; ⌘⇧A again
-- closes it. The app does not send keystrokes to a floating layer yet, so the
-- key that opened the board is the one that closes it.
define{
  name = "agents_board",
  title = "Agents Board",
  args = action.schema({}),
  run = function(ctx, args)
    local sid = action.session(ctx, args)
    if not sid then return { opened = false, reason = "no session" } end
    local closed = 0
    for _, b in ipairs(api.terminals(sid)) do
      if b.label == "agents-popup" then
        api.call("block.close", { session_id = sid, block_id = b.block_id })
        closed = closed + 1
      end
    end
    if closed > 0 then return { closed = closed } end
    local r = api.call("session.new_layer", {
      session_id = sid,
      bounds = { x = 0.08, y = 0.08, w = 0.84, h = 0.6 },
      layout = rex.layout.block{ flavor = api.SHELL, label = "agents-popup",
        options = { command = shell.bin("rex-board", "--popup") } },
      focus = true,
    })
    return { opened = true, layer = r.layer_id }
  end,
}

-- claude-steps as a live sidecar beside the focused agent (rex-steps): opens
-- it, or closes it when it is already open. From inside a sidecar, closes
-- that sidecar; with a sidecar open whose agent is gone, closes that.
local SIDECAR = "^steps·"

define{
  name = "steps_sidecar",
  title = "Steps Sidecar",
  args = action.schema({}),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    if not (sid and bid) then return { opened = false, reason = "no focused block" } end
    local blocks = api.terminals(sid)
    local label = "steps·" .. bid:sub(-6)
    for _, b in ipairs(blocks) do
      if (b.block_id == bid and (b.label or ""):find(SIDECAR)) or b.label == label then
        api.call("block.close", { session_id = sid, block_id = b.block_id })
        return { closed = b.label }
      end
    end
    -- A sidecar whose agent block is gone is closed instead of opening one
    -- more beside it (a sidecar also closes itself then, steps.lua).
    local alive, orphans = {}, {}
    for _, b in ipairs(blocks) do alive[b.block_id:sub(-6)] = true end
    for _, b in ipairs(blocks) do
      local of = (b.label or ""):match("^steps·(%w+)$")
      if of and not alive[of] then
        api.close(sid, b.block_id)
        orphans[#orphans + 1] = b.label
      end
    end
    if #orphans > 0 then return { closed = orphans } end
    local block = api.split(sid, bid, { direction = "horizontal", ratio = 0.62, label = label,
      command = shell.bin("rex-steps", "watch", sid, bid) })
    return { opened = label, block = block }
  end,
}

-- ctrl+c on a tab's last pane, while the Claude in it waits on you (idle,
-- done or blocked, not working), asks first: it enters the quit-claude mode,
-- whose panel is the prompt (y quits Claude, n or escape keeps it). Anywhere
-- else the key goes to the program, as nav passes its keys. Claude's own
-- record (rex-agent's id=claude) says whether it waits, falling back to the
-- one Claude Code publishes itself; its owner must still be the pane's
-- foreground process, so a record a crashed Claude left behind guards
-- nothing. An interrupted turn reports no Stop, so after one ctrl+c stops a
-- turn the next passes through until Claude finishes a turn again.
local PENDING = { idle = true, done = true, blocked = true }

local function claude_record(records)
  local native
  for _, r in ipairs(records or {}) do
    if r.id == "claude" then return r end
    if r.app == "claude-code" then native = native or r end
  end
  return native
end

local function guards(sid, bid)
  local status = api.block(sid, bid, "program_status")
  local r = claude_record(status and status.records)
  if not (r and PENDING[r.state] and r.owner and r.owner.pid) then return false end
  local fg = api.foreground(sid, bid)
  if not (fg and fg.pid == r.owner.pid) then return false end
  return #layout.tiled(layout.window_of(api.view(sid), bid)) == 1, r.state
end

define{
  name = "claude_ctrl_c",
  title = "Ctrl+C, Asking Before Quitting a Tab's Last Claude",
  args = action.schema({}),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    local ok, guarded, waiting = pcall(guards, sid, bid)
    if ok and guarded then
      rex.client.queue("client.mode.enter", { name = "quit-claude", once = true })
      return { asked = waiting }
    end
    rex.client.queue("pane.send_key", { key = "ctrl+c" })
    return { passed = true }
  end,
}

-- quit-claude's y: two ctrl+c in one write, which Claude takes as the
-- double press that exits, a draft in its prompt or not.
define{
  name = "claude_quit",
  title = "Quit Claude",
  args = action.schema({}),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    if not (sid and bid) then return { quit = false, reason = "no focused block" } end
    local _, err = api.block(sid, bid, "write", { data = "\3\3" })
    if err then error("write: " .. tostring(err), 0) end
    return { quit = bid }
  end,
}
