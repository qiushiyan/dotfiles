-- rex do ~/.config/rex/scripts/rexd.lua --all
--
-- The lab's background watcher, one per server, run by `rexd` in a detached
-- block (a session-owned block placed in no layout, so it shows nowhere).
--
-- Numbered tabs: every window's label is "<position> <name>", kept right as
-- windows open, close, move or are renamed, so the vertical tab list reads as
-- tmux's status line did and prefix 1–9 (client.tab.goto) goes where the
-- number says. A name is set once and then kept, as tmux's were: the name you
-- give a tab (prefix m), else its pane's label when it has a telling one
-- (api, claude), else the directory its pane started in.
--
-- Where you are: the app does not say which session it shows, so the lab
-- keeps its own record (rexkit.state's here): the actions note the session of
-- each key they take, and this watcher the session whose active tab changed.
--
-- Out of view: when an agent turns blocked, errored or done (OSC 7501) away
-- from the tab you are on, its terminal sends a desktop notification (OSC 9),
-- which the app shows as one.

package.path = os.getenv("HOME") .. "/.config/rex/lua/?.lua;" .. package.path
local api = require("rexkit.api")
local feedback = require("rexkit.feedback")
local layout = require("rexkit.layout")
local state = require("rexkit.state")

local DEFAULT = "^Window %x+$" -- the label Rex gives a window nobody named

local function strip_number(label)
  local name = (label or ""):gsub("^%d+%s+", "")
  return name
end

-- Labels that say nothing about a pane: Rex's default and our own helpers'.
local GENERIC = { shell = true, rexd = true, toast = true, worktrees = true }

-- LABELS maps block id to label, listed once per renumber and only when a
-- tab still needs a name.
local function name_for(session_id, w, labels)
  local name = strip_number(w.label)
  if name ~= "" and not name:match(DEFAULT) then return name end
  local block = w.focused_block_id
  if not block then return name end
  local label = labels()[block]
  if label and not GENERIC[label] and not label:find("^steps·") then return label end
  local cwd = api.cwd(session_id, block)
  return (cwd and cwd:match("[^/]+$")) or name
end

local function renumber(session_id)
  if not session_id then return end
  local view = api.view(session_id)
  local listed
  local function labels()
    if not listed then
      listed = {}
      for _, b in ipairs(api.terminals(session_id)) do listed[b.block_id] = b.label end
    end
    return listed
  end
  for i, w in ipairs((view and view.windows) or {}) do
    local want = i .. " " .. name_for(session_id, w, labels)
    if w.label ~= want then
      api.try("session.set_window_label", { session_id = session_id, window_id = w.window_id, label = want })
    end
  end
end

local function on_session(_, ev) renumber(ev.session_id) end
for _, name in ipairs({ "window_created", "window_closed", "window_label_changed",
                        "session_view_changed", "session_created" }) do
  rex.on(name, on_session)
end

-- A tab you switch to is where you are. Not every view change: rexd's own
-- renumbering and agents' splits change views in sessions you are not in.
rex.on("active_window_changed", function(target, ev)
  local sid = (ev and ev.session_id) or (target and target.session_id)
  if sid then state.note_here(sid, select(2, state.here())) end
end)

-- Out of view ----------------------------------------------------------------

local NOTIFY = { blocked = true, error = true, done = true }
local last_state = {}    -- block/id -> the state last seen

-- Whether BLOCK_ID is in the tab you are on: the active tab of the session
-- you are in (rexkit.state's here).
local function in_view(session_id, block_id)
  if state.here() ~= session_id then return false end
  local view = api.view(session_id)
  local w = view and layout.window_of(view, block_id)
  return w ~= nil and w.window_id == view.active_window_id
end

rex.on("block_event", function(target, ev)
  if ev.name ~= "program_status_changed" or not ev.record then return end
  local r = ev.record
  local k = target.block_id .. "/" .. (r.id or "")
  local before = last_state[k]
  last_state[k] = r.state
  if not NOTIFY[r.state] or before == r.state then return end
  if in_view(target.session_id, target.block_id) then return end
  local what = r.state == "blocked" and ("needs you" .. (r.kind and (" (" .. r.kind .. ")") or ""))
    or (r.state == "error" and "failed" or "finished")
  local text = (r.title or r.app or "agent") .. " " .. what .. ((r.msg and r.msg ~= "") and (": " .. r.msg) or "")
  feedback.osc9(target.session_id, target.block_id, text)
end)

for _, s in ipairs(api.sessions()) do renumber(s.session_id) end
