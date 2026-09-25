-- Reads the Claude Code conversation behind a Ctrl+G prompt buffer and
-- returns its assistant replies. Everything here leans on Claude Code's
-- internal on-disk state (sessions/<pid>.json, projects/*/<sid>.jsonl), so
-- every failure is a reason string, never an error: docs/claude-prompt-reference.md.

local M = {}

-- Transcripts reach 80MB; only the tail is decoded. The newest reply is
-- always inside it, and history simply stops where the window does.
local TAIL_BYTES = 32 * 1024 * 1024

local function config_dir()
  -- non-default accounts run with CLAUDE_CONFIG_DIR, which the editor inherits
  return vim.env.CLAUDE_CONFIG_DIR or vim.fs.joinpath(vim.uv.os_homedir(), ".claude")
end

local function parent_pid(pid)
  local out = vim.fn.system({ "ps", "-o", "ppid=", "-p", tostring(pid) })
  return tonumber(vim.trim(out))
end

local function read_json(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local ok, value = pcall(vim.json.decode, f:read("*a"), { luanil = { object = true } })
  f:close()
  return ok and type(value) == "table" and value or nil
end

-- The claude process that owns this editor is its nearest ancestor with a
-- sessions/<pid>.json. Claude spawns $EDITOR directly, but a wrapper shell in
-- between must not break the walk, so it goes a few levels up.
local function session_from_ancestors()
  local pid = vim.uv.os_getppid()
  for _ = 1, 8 do
    if not pid or pid <= 1 then
      return nil
    end
    local info = read_json(vim.fs.joinpath(config_dir(), "sessions", pid .. ".json"))
    if info and info.pid == pid and info.sessionId then
      return info.sessionId
    end
    pid = parent_pid(pid)
  end
end

-- Fallback when no ancestor is a claude process: the session id the context
-- chip published on this pane (tmux/.config/tmux/scripts/context-chip.md).
local function session_from_pane()
  local pane = vim.env.TMUX_PANE
  if not pane or vim.fn.executable("tmux") == 0 then
    return nil
  end
  local sid = vim.trim(vim.fn.system({ "tmux", "show-options", "-pqv", "-t", pane, "@claude_ctx_sid" }))
  return sid ~= "" and sid or nil
end

function M.find()
  local sid = session_from_ancestors() or session_from_pane()
  if not sid then
    return nil, "no Claude session found for this editor"
  end
  local path = vim.fn.glob(vim.fs.joinpath(config_dir(), "projects", "*", sid .. ".jsonl"), true, true)[1]
  if not path then
    return nil, "session " .. sid .. " has no transcript yet"
  end
  return path
end

local function read_tail(path)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local size = f:seek("end")
  local start = math.max(0, size - TAIL_BYTES)
  f:seek("set", start)
  local data = f:read("*a")
  f:close()
  if start > 0 then
    data = data:sub((data:find("\n", 1, true) or #data) + 1) -- drop the cut line
  end
  return data
end

-- A user record opens a new turn unless it is metadata (reminders, image
-- captions) or carries tool results, which continue the assistant's turn.
local function opens_turn(rec)
  if rec.isMeta then
    return false
  end
  local content = rec.message and rec.message.content
  if type(content) ~= "table" then
    return true
  end
  for _, block in ipairs(content) do
    if block.type == "tool_result" then
      return false
    end
  end
  return true
end

-- Returns the replies on the active branch, oldest first. Each reply is
-- { final = <text after its last tool call>, full = <all its text> }.
function M.replies(path)
  local data = read_tail(path)
  if not data then
    return nil, "cannot read " .. path
  end

  local by_uuid, last = {}, nil
  for line in data:gmatch("[^\n]+") do
    -- a trailing line mid-write fails to decode and is skipped
    local ok, rec = pcall(vim.json.decode, line, { luanil = { object = true } })
    if ok and type(rec) == "table" and rec.uuid and not rec.isSidechain then
      by_uuid[rec.uuid] = rec
      last = rec
    end
  end

  -- /rewind leaves abandoned branches in the file; the active one is the
  -- parent chain of the newest record.
  local chain, seen, rec = {}, {}, last
  while rec and not seen[rec.uuid] do
    seen[rec.uuid] = true
    table.insert(chain, 1, rec)
    rec = by_uuid[rec.parentUuid or rec.logicalParentUuid]
  end

  local replies, turn = {}, nil
  local function close()
    if turn and #turn.texts > 0 then
      local final = {}
      for i = turn.last_tool + 1, #turn.texts do
        final[#final + 1] = turn.texts[i]
      end
      if #final == 0 then -- turn ended on a tool call: show its last words
        final = { turn.texts[#turn.texts] }
      end
      replies[#replies + 1] = {
        final = table.concat(final, "\n\n"),
        full = table.concat(turn.texts, "\n\n"),
      }
    end
    turn = { texts = {}, last_tool = 0 }
  end

  -- open a turn up front: when the tail window starts mid-turn, the records
  -- before the next prompt are still the newest reply
  close()
  for _, r in ipairs(chain) do
    if r.type == "user" and opens_turn(r) then
      close()
    elseif r.type == "assistant" and r.message and type(r.message.content) == "table" then
      for _, block in ipairs(r.message.content) do
        if block.type == "text" and block.text and block.text:match("%S") then
          turn.texts[#turn.texts + 1] = vim.trim(block.text)
        elseif block.type == "tool_use" then
          turn.last_tool = #turn.texts
        end
      end
    end
  end
  close()

  if #replies == 0 then
    return nil, "no assistant reply in this session yet"
  end
  return replies
end

return M
