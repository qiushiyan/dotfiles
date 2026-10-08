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

-- Jump to the agent that has waited longest in the most urgent state:
-- blocked, then errored, then finished. The server moves focus to its block;
-- the client is asked to show that session.
rex.action{
  name = "agents_next",
  title = "Jump to Agent Needing Attention",
  run = function(ctx)
    rex.log("info", "agents_next ctx: " .. tostring(ctx and ctx.origin))
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

-- Re-push the terminal theme theme-set selected to every terminal.
rex.action{
  name = "theme_sync",
  title = "Sync Terminal Theme",
  run = function() return kit.apply_theme() end,
}

rex.bind("cmd+shift+j", "agents_next")
rex.bind("cmd+shift+a", "agents_board")
