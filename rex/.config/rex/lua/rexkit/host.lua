-- rexkit.host: which machine an action's work happens on. A key in another
-- host's session runs the config of the app's own machine (ctx.server is
-- set): its rex calls travel through the app to that host, but its files,
-- processes, clipboard and `open` are this machine's. These helpers put each
-- piece of work on the right side (docs/rex.md, § Two machines).

local api = require("rexkit.api")
local feedback = require("rexkit.feedback")
local shell = require("rexkit.shell")

local M = {}

-- Whether a client runs on this machine: a remote app (the laptop's, over
-- Tailscale) reaches the server over the network, so `open` here would open
-- the URL on the wrong screen.
function M.client_is_local(client_id)
  if not client_id then return true end
  local r = api.try("client.inspect", { client_id = client_id })
  local transport = r and r.client and r.client.principal and r.client.principal.transport
  return transport == nil or transport == "unix"
end

-- Whether the app whose key ran an action is on this machine, so `open` and
-- the clipboard here are the ones you are looking at. On another host's
-- session the action runs from the config of the app's own machine (here);
-- otherwise the app may be another machine's, over Tailscale.
function M.app_is_here(ctx)
  return ctx.server ~= nil or M.client_is_local(ctx.client_id)
end

-- Put TEXT on the clipboard of the machine you are looking from: here with
-- pbcopy when the app is here and the block is another host's (no tty of
-- it here), else through the block's terminal (OSC 52). FG is the block's
-- front process when the caller has it.
function M.copy(ctx, session_id, block_id, text, fg)
  if ctx.server then
    -- Not io.popen(…, "w"): Rex's Lua never closes that pipe, so pbcopy
    -- waits for the end of its input forever.
    return shell.run("printf %s " .. shell.quote(text) .. " | pbcopy")
  end
  return feedback.osc52(session_id, block_id, text, fg)
end

-- The output of a shell command run on the host the session's calls go to,
-- in directory CWD (optional), or nil. SCRIPT is sh source; ARGS become $1,
-- $2, …. Here it is a plain shell. On another host's session a hidden block
-- in SESSION_ID runs it there, its screen is read back once the end mark
-- shows, and the block is closed.
local MARK = "--rex-lab-end--"

function M.run_there(ctx, session_id, script, args, cwd)
  args = args or {}
  if not ctx.server then
    local line = "PATH=" .. shell.quote(shell.PATH) .. " sh -c " .. shell.quote(script) .. " sh"
    for _, a in ipairs(args) do line = line .. " " .. shell.quote(a) end
    if cwd then line = "cd " .. shell.quote(cwd) .. " && " .. line end
    return shell.capture(line .. " 2>/dev/null")
  end
  local command = { "/bin/sh", "-c",
    'export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"; '
      .. 'mark=$1; shift; ( ' .. script .. ' ) 2>/dev/null; printf "\\n%s\\n" "$mark"; sleep 10',
    "run", MARK }
  for _, a in ipairs(args) do command[#command + 1] = a end
  local r = api.try("session.new_block", { session_id = session_id, flavor = api.SHELL,
    label = "rex-lab-run", options = { command = command, cwd = cwd } })
  if not (r and r.block_id) then return nil end
  -- Polled, since an action hears no events: quickly at first, for about
  -- five seconds in all.
  local text, wait = nil, 0.05
  for _ = 1, 15 do
    local out = api.block(session_id, r.block_id, "format", { format = "text", unwrap = true })
    out = out and out.content or ""
    local at = out:find(MARK, 1, true)
    if at then text = out:sub(1, at - 1); break end
    shell.pause(wait)
    wait = math.min(wait * 2, 0.4)
  end
  api.close(session_id, r.block_id)
  if text then text = text:gsub("%s+$", "") end
  return text ~= "" and text or nil
end

-- The text of a file in the lab's state directory (~/.local/state/rex-lab)
-- on the session's host, or nil.
function M.read_state(ctx, session_id, relpath)
  return M.run_there(ctx, session_id, 'cat "${XDG_STATE_HOME:-$HOME/.local/state}/rex-lab/$1"', { relpath })
end

return M
