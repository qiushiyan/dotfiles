-- lab.panes: tmux's pane keys that Rex's own pane.* actions do not cover:
-- vim-aware focus, the side-by-side or stacked toggle, pane mode's push,
-- hold, put and pick, a scratch shell, clear with scrollback, and renaming.

local action = require("lab.action")
local api = require("rexkit.api")
local feedback = require("rexkit.feedback")
local host = require("rexkit.host")
local layout = require("rexkit.layout")
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

-- prefix | and -: a shell split that way, in the directory the pane works in
-- (tmux's split-window -c '#{pane_current_path}'). The app's own pane.split
-- starts in the directory the pane's shell last reported, which in a Claude
-- pane is where Claude was launched (api.cwd says why). command is the argv
-- to run instead of a login shell (the tests' stand-in).
define{
  name = "split_here",
  title = "Split Pane, Here",
  args = action.schema({ direction = action.args.direction,
    command = { type = "array", items = { type = "string" } } }, { "direction" }),
  run = function(ctx, args)
    local how = MOVE[args.direction]
    local sid, bid = action.block(ctx, args)
    if not (how and sid and bid) then return { opened = false } end
    local block = api.split(sid, bid, { direction = how.direction, side = how.side, ratio = 0.5,
      cwd = api.cwd(sid, bid), command = args.command, login = args.command and false or nil, focus = true })
    return { opened = block }
  end,
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

-- prefix Space (and Space in pane mode), as tmux's: panes all side by side
-- become stacked, any other layout becomes side by side, evenly sized and in
-- layout order. Rex has no layout presets, so each pane after the first is
-- moved beside the one before it, taking its share of what is left.
define{
  name = "layout_toggle",
  title = "Toggle Stacked",
  args = action.schema({}),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    if not (sid and bid) then return { toggled = false } end
    local blocks = layout.tiled(layout.window_of(api.call("session.view", { session_id = sid }), bid))
    if #blocks < 2 then return { toggled = false, reason = "one pane" } end
    local one_row = true
    for _, b in ipairs(blocks) do
      if math.abs(b.rect.y - blocks[1].rect.y) > 1e-3 then one_row = false end
    end
    local direction = one_row and "vertical" or "horizontal"
    for i = 2, #blocks do
      api.call("session.move_block", { session_id = sid, block_id = blocks[i].block_id,
        anchor_block_id = blocks[i - 1].block_id, direction = direction, side = "after",
        ratio = 1 / (#blocks - i + 2) })
    end
    api.try("session.focus_block", { session_id = sid, block_id = bid })
    return { layout = one_row and "stacked" or "side by side" }
  end,
}

-- Every move of a pane into another tab lands the same way: to the right of
-- ANCHOR, and focused. Rex splits only beside a pane, not the whole window,
-- so this is tmux's full-height right column only when the tab has one pane;
-- hjkl in pane mode places it from there.
local function land(sid, bid, anchor)
  api.call("session.move_block", { session_id = sid, block_id = bid, anchor_block_id = anchor,
    direction = "horizontal", side = "after" })
  api.try("session.focus_block", { session_id = sid, block_id = bid })
end

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
    land(sid, hbid, bid)
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

-- Pane mode w: pick another tab of the session in the command palette and
-- move the pane there, beside that tab's focused pane, as tmux's pick does,
-- without walking to it with a hold. The tab is shown and pane mode stays on,
-- so hjkl places the pane, as after a put. window_id, given as an arg, skips
-- the question (`rex do`, the tests). A floating pane, or a session with one
-- tab, is refused before asking, and the app reports why.

-- The pane a move into window W lands beside: its focused pane when that is
-- tiled, else its first tiled one.
local function landing(w)
  local tiled = layout.tiled(w)
  for _, b in ipairs(tiled) do
    if b.block_id == w.focused_block_id then return b.block_id end
  end
  return tiled[1] and tiled[1].block_id
end

define{
  name = "pane_pick",
  title = "Move Pane to a Tab…",
  args = action.schema({ window_id = { type = "string" } }),
  ask = function(ctx, args)
    if args.window_id then return args.window_id end
    local sid, bid = action.block(ctx, args)
    if not (sid and bid) then return nil, "no focused block" end
    local view = api.call("session.view", { session_id = sid })
    local here = layout.window_of(view, bid)
    if not here then error("a floating pane cannot move between tabs", 0) end
    local items = {}
    for _, w in ipairs(view.windows or {}) do
      if w.window_id ~= here.window_id then
        local n = #layout.tiled(w)
        items[#items + 1] = { id = w.window_id, title = w.label, icon = "terminal",
          detail = n .. (n == 1 and " pane" or " panes") }
      end
    end
    if #items == 0 then error("no other tab in this session (b breaks the pane into a new one)", 0) end
    return action.pick{ title = "Move pane to", placeholder = "Filter tabs", items = items }
  end,
  run = function(ctx, args, window_id)
    local sid, bid = action.block(ctx, args)
    if not (sid and bid) then return { placed = false } end
    local view = api.call("session.view", { session_id = sid })
    local target
    for _, w in ipairs(view.windows or {}) do
      if w.window_id == window_id then target = w end
    end
    local here = layout.window_of(view, bid)
    local anchor = target and landing(target)
    local reason = (not here and "not tiled") or (not anchor and "no such tab")
      or (here.window_id == target.window_id and "same tab")
    if reason then return { placed = false, reason = reason } end
    api.call("session.focus_window", { session_id = sid, window_id = target.window_id })
    land(sid, bid, anchor)
    return { placed = bid, window = target.window_id }
  end,
}

-- ctrl+` (or prefix Z, as tmux's popup was): a throwaway shell floating over
-- the tab, in the pane's directory. One per tab, toggled: pressed inside it, it
-- hides (minimized, still running, so an nvim or a pull survives); pressed
-- from a pane, it comes back focused. A shell idle at its prompt in another
-- directory than the pane's is replaced by a fresh one there, since being
-- in the pane's directory is the point; one running a program comes back as
-- it is. Exiting the shell closes it.
local SCRATCH = "scratch"
local SCRATCH_BOUNDS = { x = 0.125, y = 0.125, w = 0.75, h = 0.75 }
local SHELLS = { zsh = true, bash = true, sh = true, fish = true, login = true }

-- The scratch float's layer in WINDOW and its block, else nil.
local function scratch_of(window)
  for _, layer in ipairs((window and window.layers) or {}) do
    if layer.kind ~= "tiled" then
      for _, b in ipairs(layer.blocks or {}) do
        if b.label == SCRATCH then return layer, b.block_id end
      end
    end
  end
end

define{
  name = "scratch",
  title = "Scratch Shell, Floating",
  -- command: the argv to run instead of a login shell (the tests' stand-in).
  args = action.schema({ command = { type = "array", items = { type = "string" } } }),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    if not (sid and bid) then return { opened = false } end
    local window = layout.placement(api.view(sid), bid)
    if not window then return { opened = false, reason = "the pane is in no tab" } end
    local layer, float = scratch_of(window)
    if float == bid then
      api.call("session.set_layer_state", { session_id = sid, layer_id = layer.layer_id, state = "minimized" })
      return { hidden = float }
    end
    local cwd = api.cwd(sid, bid)
    if float then
      local fg = api.foreground(sid, float)
      local idle = fg and SHELLS[(fg.name or ""):gsub("^.*/", ""):gsub("^%-", "")]
      if not (idle and cwd and fg.cwd and fg.cwd ~= cwd) then
        api.call("session.set_layer_state", { session_id = sid, layer_id = layer.layer_id,
          state = "normal", focus = true })
        return { shown = float }
      end
      api.close(sid, float)
    end
    local r = api.call("session.new_layer", {
      session_id = sid, window_id = window.window_id, bounds = SCRATCH_BOUNDS,
      layout = rex.layout.block{ flavor = api.SHELL, label = SCRATCH,
        options = { cwd = cwd, command = args.command, login = args.command and false or nil } },
      focus = true,
    })
    return { opened = r.block_ids and r.block_ids[1], layer = r.layer_id, replaced = float }
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

-- prefix M: name the pane in the command palette, in an empty field. The name
-- shows in the pane header and names the tab (rexd); an empty one gives the
-- pane the name "shell". A pane wearing a Claude status chip
-- has the chip as its label, so its own name is rex-chip's to keep: the
-- rename goes through rex-chip on the pane's host, which draws the chip
-- again after it. label, given as an arg, skips the question.
local function chip_base(ctx, sid, bid)
  return host.read_state(ctx, sid, "chip/" .. bid:gsub(":", "_") .. ".base")
end

define{
  name = "label_pane",
  title = "Rename Pane…",
  args = action.schema({ label = { type = "string" } }),
  ask = function(ctx, args)
    if args.label then return args.label end
    return action.input{ title = "Rename pane", placeholder = "New name (empty: shell)", confirm = "Rename" }
  end,
  run = function(ctx, args, label)
    local sid, bid = action.block(ctx, args)
    if not (sid and bid) then return { renamed = false } end
    label = label:gsub("^%s+", ""):gsub("%s+$", "")
    if label == "" then label = "shell" end
    if chip_base(ctx, sid, bid) then
      host.run_there(ctx, sid, 'REX_SESSION="$1" rex-chip rename "$2" "$3" >/dev/null 2>&1; echo done',
        { sid, bid, label })
      return { renamed = label, chip = true }
    end
    api.call("session.set_block_label", { session_id = sid, block_id = bid, label = label })
    return { renamed = label }
  end,
}
