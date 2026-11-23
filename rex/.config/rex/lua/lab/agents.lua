-- lab.agents: the actions over agents (Claude sessions publishing OSC 7501
-- status, rex-agent): the claude-steps sidecar and the floating status chip.
-- The app's Activity sidebar (cmd+.) lists every agent by urgency.

local action = require("lab.action")
local api = require("rexkit.api")
local layout = require("rexkit.layout")
local shell = require("rexkit.shell")
local state = require("rexkit.state")

local define = action.group("Agents")

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

-- The focused agent's status chip as a floating layer at the top right of its
-- pane (rex-chip draw): the account, model and effort, the quota windows and
-- context, in the terminal's font and colours, which the pane header's plain
-- label cannot have. The key opens it, or closes it when it is open; it ends
-- by itself with the agent's session. A chip whose pane is gone is closed on
-- the way. The layer is as wide as the chip's text when it opens (rex-chip
-- keeps that width beside its state; on another host's session, where the
-- file is out of reach, a width that fits every field) and keeps the place
-- it opened at: after the pane moves or resizes, or the chip outgrows it,
-- the key twice puts it right. A chip too wide for its layer sheds fields.
local CHIP_COLS, CHIP_ROWS = 66, 4

define{
  name = "chip_toggle",
  title = "Toggle Status Chip",
  args = action.schema({}),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    if not (sid and bid) then return { opened = false, reason = "no focused block" } end
    local blocks = api.terminals(sid)
    local label = "chip·" .. bid:sub(-6)
    local alive, mine = {}, nil
    for _, b in ipairs(blocks) do alive[b.block_id:sub(-6)] = true end
    for _, b in ipairs(blocks) do
      local of = (b.label or ""):match("^chip·(%w+)$")
      if b.label == label then
        mine = b.block_id
      elseif of and not alive[of] then
        api.close(sid, b.block_id)
      end
    end
    if mine then
      api.call("block.close", { session_id = sid, block_id = mine })
      return { closed = label }
    end
    -- Sized in cells from the pane's own grid and rect, as a toast is: the
    -- app pads a layer by about a row and two columns.
    local window, rect = layout.placement(api.view(sid), bid)
    local size = api.block(sid, bid, "size")
    if not (window and rect and size and size.columns and size.columns > 0) then
      return { opened = false, reason = "the pane has no size yet" }
    end
    local cols, rows = size.columns / rect.w, size.rows / rect.h
    local text = not ctx.server and tonumber(state.read("chip/" .. bid:gsub(":", "_") .. ".width") or "")
    local width = math.min(text and (text + 2) or CHIP_COLS, CHIP_COLS, size.columns)
    local w = math.min((width + 2) / cols, rect.w)
    local h = math.min(CHIP_ROWS / rows, rect.h)
    local x = math.max(0, math.min(rect.x + rect.w - w - 1 / cols, 1 - w))
    local y = math.max(0, math.min(rect.y + 2 / rows, 1 - h))
    local r = api.call("session.new_layer", {
      session_id = sid, window_id = window.window_id,
      bounds = { x = x, y = y, w = w, h = h },
      layout = rex.layout.block{ flavor = api.SHELL, label = label,
        options = { command = shell.bin("rex-chip", "draw", bid) } },
      focus = false,
    })
    return { opened = label, layer = r.layer_id }
  end,
}
