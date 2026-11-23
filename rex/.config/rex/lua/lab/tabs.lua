-- lab.tabs: tmux's window keys over Rex's tabs. Each session's tabs are
-- numbered from 1 as rexd labels them, and every move stays in the session
-- the key was pressed in (lab.client).

local action = require("lab.action")
local client = require("lab.client")
local api = require("rexkit.api")
local shell = require("rexkit.shell")

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

-- prefix S-Tab: the session you were in before this one, as tmux's
-- switch-client -l. The app's session.recent says it "isn't available here"
-- yet; the server keeps each user's focus history (focus_history.reverse,
-- preview.22), which moves focus back to the last block of another session
-- and names it, and the app is then asked to show that session. Only for this
-- host's sessions, which the app can select.
define{
  name = "session_back",
  title = "Back to the Last Session",
  args = action.schema({}),
  run = function(ctx, args)
    local sid = action.session(ctx, args)
    if ctx.server or not sid then return { moved = false, reason = "another host's session" } end
    local r = api.try("focus_history.reverse", { not_session_id = sid })
    if not (r and r.reversed and r.session_id) then return { moved = false, reason = "no earlier session" } end
    client.show(ctx, r.session_id, r.window_id)
    return { moved = r.session_id }
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
