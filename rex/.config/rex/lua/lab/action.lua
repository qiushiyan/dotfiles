-- lab.action: how the lab defines an action, and where an action acts.
--
-- Every action is defined through define (or a group of it), which wraps
-- rex.action:
--   - A key press first notes where it was pressed (rexkit.state's here and
--     keys): the app does not tell the server which session it shows, and
--     the out-of-view notifications and prefix Tab need to know.
--   - A failure is written, with the ctx it ran under and a traceback, to
--     actions.log before the app reports it: the app's own report is all that
--     is left otherwise.
--   - On another host's session (ctx.server: the mini's, shown in the
--     laptop's app) every call travels through the app to that host, so the
--     result is logged too, as the only view of what the action did.
--   - ctx and args are never nil inside run.
--
-- ctx carries origin ("key", "palette", "api", "cli"), session_id, block_id,
-- client_id, and server when the session is another host's (llms.txt,
-- client.action). An action meant to be scripted also takes session_id and
-- block_id as args, so `rex do ACTION session_id=… block_id=…` can aim it.

local api = require("rexkit.api")
local state = require("rexkit.state")

local M = {}

function M.define(spec)
  local run, name = spec.run, spec.name
  spec.run = function(ctx, args)
    ctx, args = ctx or {}, args or {}
    if ctx.origin == "key" then
      if not ctx.server then state.note_here(ctx.session_id, ctx.client_id) end
      state.note_key(ctx)
    end
    local started = os.clock() -- wall time in Rex's Lua (gopher-lua)
    local result = { xpcall(function() return run(ctx, args) end, debug.traceback) }
    if not result[1] then
      state.log(name .. " failed: " .. tostring(result[2]) .. "\n  ctx " .. state.dump(ctx))
      error(result[2], 0)
    end
    if ctx.server then
      state.log(string.format("%s on %s args %s -> %s (%.0f ms)", name, tostring(ctx.server),
        state.dump(args), state.dump(result[2]), (os.clock() - started) * 1000))
    end
    return unpack(result, 2)
  end
  return rex.action(spec)
end

-- define for one domain: its actions share a palette category.
function M.group(category)
  return function(spec)
    spec.category = spec.category or category
    return M.define(spec)
  end
end

-- JSON Schemas for args. Rex checks each binding's args against them when it
-- resolves the keymap, so a typo in keys.lua shows in `rex keymap`.
M.args = {
  direction = { type = "string", enum = { "left", "right", "up", "down" } },
}

function M.schema(properties, required)
  properties.session_id = properties.session_id or { type = "string" }
  properties.block_id = properties.block_id or { type = "string" }
  return { type = "object", properties = properties, required = required }
end

-- The session an action is about: args', the key's, else where you are, else
-- the first session.
function M.session(ctx, args)
  local sid = args.session_id or ctx.session_id or state.here()
  if sid then return sid end
  local first = api.sessions()[1]
  return first and first.session_id
end

-- The session and block an action is about: args', the key's, else the
-- focused block of the session.
function M.block(ctx, args)
  local sid = M.session(ctx, args)
  local bid = args.block_id or ctx.block_id
  return sid, bid or (sid and api.focused_block(sid))
end

return M
