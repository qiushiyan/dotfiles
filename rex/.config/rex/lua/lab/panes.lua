-- lab.panes: tmux's pane keys that Rex's own pane.* actions do not cover:
-- vim-aware focus, pane mode's push, hold and put, a scratch shell, clear
-- with scrollback, and renaming.

local action = require("lab.action")
local api = require("rexkit.api")
local feedback = require("rexkit.feedback")
local layout = require("rexkit.layout")
local shell = require("rexkit.shell")
local state = require("rexkit.state")

local define = action.group("Panes")

-- ctrl+h/j/k/l, as vim-tmux-navigator did in tmux: in nvim, vim or fzf the key
-- goes to the program (LazyVim moves between its splits with it); elsewhere
-- it focuses the pane that way. At the right edge ctrl+l reaches the program,
-- so it still clears the screen; at the other edges the key does nothing.
local NAV_KEY = { left = "ctrl+h", down = "ctrl+j", up = "ctrl+k", right = "ctrl+l" }
local NAV_PASS = { nvim = true, vim = true, vi = true, view = true, fzf = true }

define{
  name = "nav",
  title = "Focus Pane, Vim-Aware",
  args = action.schema({ direction = action.args.direction }, { "direction" }),
  run = function(ctx, args)
    local dir = args.direction
    local sid, bid = action.block(ctx, args)
    if not (NAV_KEY[dir] and sid and bid) then return { moved = false } end
    local fg = api.foreground(sid, bid)
    local name = fg and (fg.name or ""):match("[^/]+$") or ""
    if NAV_PASS[name] then
      rex.client.queue("pane.send_key", { key = NAV_KEY[dir] })
      return { passed = name }
    end
    if layout.neighbor(api.view(sid), bid, dir) then
      rex.client.queue("pane.focus", { direction = dir })
      return { moved = dir }
    end
    if dir == "right" then rex.client.queue("pane.send_key", { key = "ctrl+l" }) end
    return { moved = false }
  end,
}

-- Pane mode (prefix p), as tmux's: hjkl push the pane that way, trading
-- places with the pane there. With nothing there and one other pane in the
-- window, it becomes that side's wall (stacked turns side by side); with
-- more, Rex can only split beside a pane, not the whole window, so it stays.
local MOVE = {
  left = { direction = "horizontal", side = "before" }, right = { direction = "horizontal", side = "after" },
  up = { direction = "vertical", side = "before" }, down = { direction = "vertical", side = "after" },
}

define{
  name = "pane_push",
  title = "Push Pane",
  args = action.schema({ direction = action.args.direction }, { "direction" }),
  run = function(ctx, args)
    local dir = args.direction
    local sid, bid = action.block(ctx, args)
    if not (MOVE[dir] and sid and bid) then return { moved = false } end
    local view = api.call("session.view", { session_id = sid })
    local other = layout.neighbor(view, bid, dir)
    if other then
      api.call("session.swap_blocks", { session_id = sid, block_id = bid, other_block_id = other })
      return { swapped = other }
    end
    local rest = {}
    for _, b in ipairs(layout.tiled(layout.window_of(view, bid))) do
      if b.block_id ~= bid then rest[#rest + 1] = b.block_id end
    end
    if #rest ~= 1 then return { moved = false, reason = "at the edge" } end
    api.call("session.move_block", { session_id = sid, block_id = bid, anchor_block_id = rest[1],
      direction = MOVE[dir].direction, side = MOVE[dir].side })
    api.try("session.focus_block", { session_id = sid, block_id = bid })
    return { walled = dir }
  end,
}

-- Pane mode g / p / G: hold a pane, walk to any tab of the session, and put
-- it beside the pane there (Rex moves a live block between windows, so
-- nothing restarts). The hold is a state file, so it survives a reload.
define{
  name = "pane_hold",
  title = "Hold Pane",
  args = action.schema({}),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    if not (sid and bid) then return { held = false } end
    assert(state.hold(sid, bid), "cannot write the held pane")
    rex.client.queue("client.mode.exit", {})
    feedback.toast(sid, bid, "info", "Holding pane", "walk to a tab, then prefix p p", 2)
    return { held = bid }
  end,
}

define{
  name = "pane_put",
  title = "Put Held Pane Here",
  args = action.schema({}),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    local hsid, hbid = state.held()
    if not (sid and bid and hbid) then return { put = false, reason = "nothing held" } end
    if hsid ~= sid then
      feedback.toast(sid, bid, "warn", "Put pane", "the held pane is in another session", 2)
      return { put = false, reason = "other session" }
    end
    state.release()
    if hbid == bid then return { put = false, reason = "same pane" } end
    api.call("session.move_block", { session_id = sid, block_id = hbid, anchor_block_id = bid,
      direction = "horizontal", side = "after" })
    api.try("session.focus_block", { session_id = sid, block_id = hbid })
    return { put = hbid }
  end,
}

define{
  name = "pane_release",
  title = "Release Held Pane",
  run = function()
    state.release()
    return { released = true }
  end,
}

-- prefix Z: a throwaway shell below the pane, in its directory; prefix Z
-- again (or exiting the shell) closes it. A split, since floating layers do
-- not take keys yet.
define{
  name = "scratch",
  title = "Scratch Shell",
  args = action.schema({}),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    if not (sid and bid) then return { opened = false } end
    local view = api.call("session.view", { session_id = sid })
    for _, b in ipairs(layout.blocks(layout.window_of(view, bid))) do
      if b.label == "scratch" then
        api.call("block.close", { session_id = sid, block_id = b.block_id })
        return { closed = b.block_id }
      end
    end
    local block = api.split(sid, bid, { direction = "vertical", ratio = 0.65, label = "scratch",
      cwd = api.cwd(sid, bid), focus = true })
    return { opened = block }
  end,
}

-- prefix C-k: clear the screen and the scrollback (tmux's send C-l plus
-- clear-history); ctrl+l after it has the shell redraw its prompt.
define{
  name = "clear_all",
  title = "Clear Screen and Scrollback",
  args = action.schema({}),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    if not (sid and bid) then return { cleared = false } end
    api.block(sid, bid, "clear")
    rex.client.queue("pane.send_key", { key = "ctrl+l" })
    return { cleared = bid }
  end,
}

-- prefix M: name the pane (rex-label) in a small prompt below it. The label
-- shows in the pane header and on the board; an empty name clears it.
define{
  name = "label_pane",
  title = "Rename Pane",
  args = action.schema({}),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    if not (sid and bid) then return { opened = false } end
    local block = api.split(sid, bid, { direction = "vertical", ratio = 0.85, label = "rename",
      cwd = api.cwd(sid, bid), command = shell.bin("rex-label", sid, bid), focus = true })
    return { opened = block }
  end,
}
