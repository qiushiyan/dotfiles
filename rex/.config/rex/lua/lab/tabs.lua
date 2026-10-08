-- lab.tabs: tmux's window keys over Rex's tabs. Each session's tabs are
-- numbered from 1 as rexd labels them, and every move stays in the session
-- the key was pressed in (lab.client).

local action = require("lab.action")
local client = require("lab.client")
local api = require("rexkit.api")
local feedback = require("rexkit.feedback")
local layout = require("rexkit.layout")
local shell = require("rexkit.shell")
local state = require("rexkit.state")

local define = action.group("Tabs")

-- prefix 1–9: tab N of the session the key was pressed in, as tmux counts
-- windows and as rexd numbers the tabs.
define{
  name = "window_goto",
  title = "Go to Tab in This Session",
  args = action.schema({ index = { type = "integer", minimum = 1 } }, { "index" }),
  run = function(ctx, args)
    local sid = action.session(ctx, args)
    local index = tonumber(args.index)
    local view = sid and index and api.view(sid)
    local w = view and view.windows and view.windows[index]
    if not w then return { moved = false, reason = "no tab " .. tostring(index) } end
    client.go_to_tab(ctx, sid, view, index)
    return { moved = w.label }
  end,
}

-- prefix C-h / C-l (C-p / C-n): the previous or next tab of this session,
-- wrapping, as tmux's previous-window and next-window
-- (session.focus_next_window stops at the last tab).
define{
  name = "window_cycle",
  title = "Next or Previous Tab in This Session",
  args = action.schema({ step = { type = "integer" } }),
  run = function(ctx, args)
    local sid = action.session(ctx, args)
    local view = sid and api.view(sid)
    local windows = (view and view.windows) or {}
    if #windows == 0 then return { moved = false } end
    local at = client.tab_index(ctx, view) or 1
    local to = (at - 1 + (tonumber(args.step) or 1)) % #windows + 1
    client.go_to_tab(ctx, sid, view, to)
    return { moved = windows[to].label }
  end,
}

-- prefix Tab: the tab of this session a key was last pressed in before this
-- one, as tmux's last-window, stepped to with the app's own tab actions so it
-- works on any host's session. prefix shift+Tab (session = true): the
-- session a key was last pressed in before this one, as tmux's
-- switch-client -l; the app selects it, which it does only for this host's
-- sessions.
local function last_session(ctx, sid, keys)
  for i = #keys, 1, -1 do
    local k = keys[i]
    if k.server == nil and k.session_id ~= sid then
      local other = api.view(k.session_id)
      if other then
        client.show(ctx, k.session_id, other.active_window_id)
        return { moved = k.session_id }
      end
    end
  end
end

local function last_tab(ctx, sid, view, keys)
  local at = client.tab_index(ctx, view)
  for i = #keys, 1, -1 do
    local k = keys[i]
    if k.server == ctx.server and k.session_id == sid then
      local w = layout.window_of(view, k.block_id)
      local to = w and layout.index_of(view, w.window_id)
      if to and at and to ~= at then
        client.step_tabs(at, to)
        return { moved = view.windows[to].label }
      end
    end
  end
end

define{
  name = "window_last",
  title = "Last Tab or Last Session",
  args = action.schema({ session = { type = "boolean" } }),
  run = function(ctx, args)
    local sid = action.session(ctx, args)
    local view = sid and api.view(sid)
    if not view then return { moved = false } end
    local keys = state.keys()
    local moved
    if args.session then
      moved = not ctx.server and last_session(ctx, sid, keys)
    else
      moved = last_tab(ctx, sid, view, keys)
    end
    if moved then return moved end
    feedback.toast(sid, ctx.block_id or api.focused_block(sid), "info",
      args.session and "Last session" or "Last tab", "nothing earlier yet", 1.5)
    return { moved = false }
  end,
}

-- prefix N: a new tab right after this one, in the directory of the pane the
-- key was pressed in (tmux's new-window -a -c).
define{
  name = "window_new_here",
  title = "New Tab After This One, Here",
  args = action.schema({}),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    if not sid then return { opened = false } end
    local view = api.call("session.view", { session_id = sid })
    local at = client.tab_index(ctx, view)
    local after = at and view.windows[at + 1]
    local key = ctx.origin == "key"
    local r = api.call("session.new_window", { session_id = sid, focus = not (key and ctx.server),
      layout = rex.layout.block{ flavor = api.SHELL, options = { cwd = bid and api.cwd(sid, bid) } } })
    if after then
      api.call("session.move_window", { session_id = sid, window_id = r.window_id, before_window_id = after.window_id })
    end
    -- On this host the app selects the new tab directly. On another host's
    -- session it can only step to it, and a step sent at once lands before
    -- the app has put the new tab in its sidebar, one tab too far: the
    -- action waits for the app to catch up first.
    if key and at and ctx.server then
      shell.pause(0.5)
      client.step_tabs(at, at + 1)
    else
      client.show(ctx, sid, r.window_id)
    end
    return { opened = r.window_id }
  end,
}
