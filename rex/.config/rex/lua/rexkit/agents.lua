-- rexkit.agents: the Claude session behind a block, found through the OSC
-- 7501 program-status record its hooks publish (rex-agent) or the block's
-- foreground process.

local api = require("rexkit.api")
local shell = require("rexkit.shell")

local M = {}

-- Claude sessions ----------------------------------------------------------------

-- Claude Code writes <config dir>/sessions/<pid>.json for each running
-- process, naming its session id. The config dirs are ~/.claude, any
-- CLAUDE_CONFIG_DIR, and each account of the x launchers. Listing the
-- accounts takes a shell, so the list is kept for a minute.
local dirs, dirs_at = nil, 0

local function config_dirs()
  if dirs and os.time() - dirs_at < 60 then return dirs end
  local home = os.getenv("HOME")
  dirs = { home .. "/.claude" }
  -- Not in the constructor: a nil there would end ipairs before ~/.claude.
  if os.getenv("CLAUDE_CONFIG_DIR") then table.insert(dirs, 1, os.getenv("CLAUDE_CONFIG_DIR")) end
  local listed = shell.capture("ls -d " .. shell.quote(home) .. "/.claude-accounts/*/ 2>/dev/null") or ""
  for d in listed:gmatch("[^\n]+") do dirs[#dirs + 1] = (d:gsub("/$", "")) end
  dirs_at = os.time()
  return dirs
end

local function session_file(pid)
  for _, dir in ipairs(config_dirs()) do
    local f = io.open(dir .. "/sessions/" .. pid .. ".json", "r")
    if f then
      local body = f:read("*a")
      f:close()
      return body
    end
  end
end

-- The Claude session running in a block of this server: its id and
-- directory, or nil. The pid comes from the block's status record (its
-- owner is the process that reported) or, failing that, the block's
-- foreground process.
function M.claude_session(session_id, block_id)
  local pids = {}
  local status = api.block(session_id, block_id, "program_status")
  for _, r in ipairs((status and status.records) or {}) do
    if r.owner and r.owner.pid then pids[#pids + 1] = r.owner.pid end
  end
  local fg = api.foreground(session_id, block_id)
  if fg then pids[#pids + 1] = fg.pid end
  for _, pid in ipairs(pids) do
    local body = session_file(pid)
    if body then
      return body:match('"sessionId"%s*:%s*"([^"]+)"'), body:match('"cwd"%s*:%s*"([^"]+)"')
    end
  end
end

return M
