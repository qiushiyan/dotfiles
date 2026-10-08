-- lab.client: moving the app that pressed a key. A server action changes the
-- server's state; what the app shows changes only through the client steps
-- it queues (rex.client.queue), which the app performs after the action
-- returns (docs/rex.md, § Lessons).

local api = require("rexkit.api")
local layout = require("rexkit.layout")

local M = {}

-- The position of the tab a key was pressed in, in VIEW's tab order: the tab
-- holding ctx's block, else the session's active tab.
function M.tab_index(ctx, view)
  local here = ctx.block_id and layout.window_of(view, ctx.block_id)
  return layout.index_of(view, here and here.window_id or view.active_window_id)
end

-- Moving to another tab of the session a key was pressed in is the app's
-- own client.tab.next / previous, repeated: they walk the sidebar, where a
-- session's tabs sit together, so the steps from tab FROM to tab TO never
-- leave the session. They work on any host's session; session.select from
-- an action does not on another host's (show), and client.tab.goto counts
-- every session's tabs together.
function M.step_tabs(from, to)
  local action = to > from and "client.tab.next" or "client.tab.previous"
  for _ = 1, math.abs(to - from) do rex.client.queue(action, {}) end
end

-- Show tab WINDOW_ID of SESSION_ID in the app whose key ran the action: the
-- server activates the window, which the app follows in the session it
-- shows, and the app is asked to show that session. When the session is
-- another host's (ctx.server: the laptop's app on the mini's session), the
-- app's session.select cannot place it and gives up after 5 seconds ("no
-- host lists it" in its log), so there a move to another session is the
-- app's own session.next or session.previous, by the sign of STEP, and
-- without a STEP the session stays as it is.
function M.show(ctx, session_id, window_id, step)
  api.call("session.focus_window", { session_id = session_id, window_id = window_id })
  if not ctx.server then
    rex.client.queue("session.select", { session_id = session_id, window_id = window_id })
  elseif session_id ~= ctx.session_id and step then
    rex.client.queue(step < 0 and "session.previous" or "session.next", {})
  end
end

-- Go to tab INDEX of the session in VIEW: by steps from the tab a key was
-- pressed in, which works on any host's session, else by show.
function M.go_to_tab(ctx, session_id, view, index)
  local at = ctx.origin == "key" and M.tab_index(ctx, view)
  if at then
    M.step_tabs(at, index)
  else
    M.show(ctx, session_id, view.windows[index].window_id)
  end
end

return M
