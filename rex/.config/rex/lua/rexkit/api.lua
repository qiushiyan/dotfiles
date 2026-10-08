-- rexkit.api: calls to one Rex server, this one or another host's.
--
-- Rex hands Lua the same helpers for each server: `rex` for this one,
-- `rex.server(label)` for a host in `rex hosts` (the mini, seen from the
-- laptop). bind wraps one of them in the guards the lab relies on; the module
-- is this server's, and api.remote(label) another's. The wire reference is
-- the server's own /llms.txt (docs/rex.md, § Where Rex's truth lives).

local M = {}

M.TERMINAL = "com.superlogical.terminal"
M.SHELL = M.TERMINAL .. ".shell"

-- A call refused because the connection is not attached. llms.txt says to
-- branch on the error code, and a `rex do` script's message ends with it
-- ("(status=409 code=conflict)"), but inside an action the message is bare
-- ("stream is not attached to session …"), so that wording counts too.
local function conflict(err)
  err = tostring(err)
  return err:find("code=conflict", 1, true) ~= nil or err:find("not attached", 1, true) ~= nil
end

local function bind(K, server, label)
  K.label = label

  -- A connection must attach to a session before calling into it, and what
  -- it is attached to outlives any record kept here (init.lua's state
  -- outlives the connection an action runs on). So nothing is recorded: a
  -- call refused with `conflict` attaches and tries once more. An action
  -- runs on the app's connection, already attached to the sessions it shows,
  -- so a key press pays nothing for this.
  local function attached(session_id, f)
    local result, err = f()
    if result == nil and session_id and conflict(err) then
      server.call("session.attach", { session_id = session_id })
      result, err = f()
    end
    return result, err
  end

  -- rex.call returns nil plus a message on failure instead of raising: try
  -- keeps that, call raises for the paths that must not continue.
  function K.try(method, payload)
    payload = payload or {}
    return attached(payload.session_id, function() return server.call(method, payload) end)
  end

  function K.call(method, payload)
    local result, err = K.try(method, payload)
    if result == nil and err ~= nil then error(method .. ": " .. tostring(err), 2) end
    return result
  end

  -- Attach explicitly: only a `rex do` script that wants a session's events
  -- needs it, since every call attaches on demand.
  function K.attach(session_id) return K.call("session.attach", { session_id = session_id }) end

  -- A terminal block's method (llms.txt, § com.superlogical.terminal block
  -- methods): process, program_status, format, size, title, clear, ….
  function K.block(session_id, block_id, method, args)
    local payload = { session_id = session_id, block_id = block_id, args = args or {} }
    return attached(session_id, function() return server.block.call(M.TERMINAL, method, payload) end)
  end

  function K.sessions() return K.call("session.list").sessions or {} end

  function K.view(session_id) return K.try("session.view", { session_id = session_id }) end

  function K.close(session_id, block_id) return K.try("block.close", { session_id = session_id, block_id = block_id }) end

  -- Every terminal block of a session, placed or detached.
  function K.terminals(session_id)
    local out = {}
    for _, b in ipairs(K.call("session.list_blocks", { session_id = session_id }).blocks or {}) do
      if b.block_id and (b.creator_name == M.TERMINAL or (b.flavor or ""):find(M.TERMINAL, 1, true) == 1) then
        out[#out + 1] = b
      end
    end
    return out
  end

  -- The block that has focus in a session's active window.
  function K.focused_block(session_id)
    local view = K.view(session_id)
    return view and view.focused_window and view.focused_window.focused_block_id
  end

  -- The process in front in a block: the one a key press is about. Its cwd
  -- comes from the OS, so it is right while nvim or Claude runs.
  function K.foreground(session_id, block_id)
    local proc = K.block(session_id, block_id, "process")
    return proc and (proc.foreground or proc.child)
  end

  function K.cwd(session_id, block_id)
    local fg = K.foreground(session_id, block_id)
    return fg and fg.cwd
  end

  -- A terminal split beside ANCHOR: spec has direction ("horizontal" side
  -- by side, "vertical" stacked), side ("after" by default), ratio, focus,
  -- and the new block's label, cwd and command. Returns its block id.
  function K.split(session_id, anchor, spec)
    local r = K.call("session.new_split", {
      session_id = session_id, anchor_block_id = anchor,
      direction = spec.direction, side = spec.side or "after", ratio = spec.ratio,
      layout = rex.layout.block{ flavor = M.SHELL, label = spec.label,
        options = { cwd = spec.cwd, command = spec.command } },
      focus = spec.focus or false,
    })
    return r.block_ids[1]
  end

  return K
end

bind(M, rex, nil)

-- Another host's server, by its label in `rex hosts`.
function M.remote(label) return bind({}, rex.server(label), label) end

-- Every other host's server this one can reach, as M.remote gives them,
-- leaving out a host that is this server under another name. A host that
-- does not answer is left out, so a sleeping laptop costs one failed call.
function M.remotes()
  local out = {}
  if not rex.servers then return out end
  local me = M.try("server.status")
  me = me and me.instance_id
  for _, label in ipairs(rex.servers() or {}) do
    local ok, K = pcall(M.remote, label)
    local status = ok and K.try("server.status")
    if status and status.instance_id and status.instance_id ~= me then out[#out + 1] = K end
  end
  return out
end

return M
