-- Rex config. An experiment, not a tmux port: what Rex makes possible for
-- agent work. Lab notebook, findings and open questions:
-- ~/dotfiles/rex/README.md. Validate with `rex config check`, apply with
-- `rex config reload`.

local HOME = os.getenv("HOME")
local REX_DIR = HOME .. "/.config/rex"
package.path = REX_DIR .. "/lua/?.lua;" .. package.path
local kit = require("rexkit")

-- The session a key press came from, or the first session when the action was
-- run another way (rex do, the palette).
local function current_session(ctx)
  ctx = ctx or {}
  local sid = ctx.session_id or (ctx.session and ctx.session.session_id)
  if sid then return sid end
  local first = kit.sessions()[1]
  return first and first.session_id
end

-- What a key press hands an action is undocumented: each action records its
-- ctx here until we know (README, open questions).
local function log_ctx(name, ctx)
  local dir = (os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")) .. "/rex-lab"
  os.execute("mkdir -p '" .. dir .. "'")
  local f = io.open(dir .. "/ctx.log", "a")
  if f then
    f:write(os.date("%Y-%m-%d %H:%M:%S "), name, " ", kit.dump(ctx), "\n")
    f:close()
  end
end

-- The block a key press came from: the one ctx names, else the focused block
-- of the current session.
local function current_block(ctx)
  ctx = ctx or {}
  local sid = current_session(ctx)
  local bid = ctx.block_id or (ctx.block and ctx.block.block_id)
  return sid, bid or (sid and kit.focused_block(sid))
end

-- Jump to the agent that has waited longest in the most urgent state:
-- blocked, then errored, then finished. The server moves focus to its block;
-- the client is asked to show that session.
rex.action{
  name = "agents_next",
  title = "Jump to Agent Needing Attention",
  run = function(ctx)
    log_ctx("agents_next", ctx)
    local row = kit.most_urgent(kit.agents())
    if not row then return { jumped = false, reason = "no agent is waiting" } end
    kit.call("session.focus_block", { session_id = row.session_id, block_id = row.block_id })
    rex.client.queue("session.select", { session_id = row.session_id, window_id = row.window_id })
    return { jumped = true, session = row.session, block = row.block, state = row.record.state }
  end,
}

-- The agents board in a floating layer over the current window. Any key
-- closes it.
rex.action{
  name = "agents_board",
  title = "Agents Board",
  run = function(ctx)
    local sid = current_session(ctx)
    if not sid then return { opened = false, reason = "no session" } end
    kit.attach(sid)
    local r = kit.call("session.new_layer", {
      session_id = sid,
      bounds = { x = 0.08, y = 0.08, w = 0.84, h = 0.6 },
      layout = { block = {
        flavor = "com.superlogical.terminal.shell", label = "agents",
        options = { command = { HOME .. "/.local/bin/rex-board", "--popup" } },
      } },
      focus = true,
    })
    return { opened = true, layer = r.layer_id }
  end,
}

-- claude-steps as a live sidecar beside the focused agent (rex-steps): opens
-- it, or closes it when it is already open. From inside a sidecar, closes
-- that sidecar.
rex.action{
  name = "steps_sidecar",
  title = "Steps Sidecar",
  run = function(ctx)
    log_ctx("steps_sidecar", ctx)
    local sid, bid = current_block(ctx)
    if not (sid and bid) then return { opened = false, reason = "no focused block" } end
    local blocks = kit.terminals(sid)
    for _, b in ipairs(blocks) do
      if b.block_id == bid and (b.label or ""):find("^steps·") then
        kit.call("block.close", { session_id = sid, block_id = bid })
        return { closed = b.label }
      end
    end
    local label = "steps·" .. bid:sub(-6)
    for _, b in ipairs(blocks) do
      if b.label == label then
        kit.call("block.close", { session_id = sid, block_id = b.block_id })
        return { closed = label }
      end
    end
    local r = kit.call("session.new_split", {
      session_id = sid, anchor_block_id = bid,
      direction = "horizontal", side = "after", ratio = 0.62,
      layout = { block = {
        flavor = "com.superlogical.terminal.shell", label = label,
        options = { command = { HOME .. "/.local/bin/rex-steps", "watch", sid, bid } },
      } },
      focus = false,
    })
    return { opened = label, block = r.block_ids[1] }
  end,
}

rex.bind("cmd+shift+j", "agents_next")
rex.bind("cmd+shift+s", "steps_sidecar")
rex.bind("cmd+shift+a", "agents_board")
