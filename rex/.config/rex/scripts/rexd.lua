-- rex do ~/.config/rex/scripts/rexd.lua --all
--
-- The lab's background watcher, one per server, run by `rexd` in a detached
-- block (a session-owned block placed in no layout, so it shows nowhere).
--
-- Numbered tabs: every window's label is "<position> <name>", kept right as
-- windows open, close, move or are renamed, so the vertical tab list reads as
-- tmux's status line did and prefix 1–9 (client.tab.goto) goes where the
-- number says. The name you give a tab (prefix m) is kept; any other tab is
-- named for its focused pane and follows it: the pane's label when it has a
-- telling one (api, claude), else the directory its foreground process is
-- in, renamed as you cd. rexd remembers the names it gave (the tab-names
-- state file), so a label it did not give is yours; clearing it, or leaving
-- only the number, hands the tab back.
--
-- Where you are: the app does not say which session it shows, so the lab
-- keeps its own record (rexkit.state's here): the actions note the session of
-- each key they take, and this watcher the session whose active tab changed.
--
-- Out of view: when an agent turns blocked, errored or done (OSC 7501) away
-- from the tab you are on, its terminal sends a desktop notification (OSC 9),
-- which the app shows as one.
--
-- The host's pasteboard: a terminal's clipboard write (OSC 52, such as
-- Claude Code's copy on selection) reaches only the clipboard of the app
-- showing the pane, the laptop's when you look from there. Nvim's p in a
-- Rex pane reads this host's pbpaste, so the text goes here too.

package.path = os.getenv("HOME") .. "/.config/rex/lua/?.lua;" .. package.path
local api = require("rexkit.api")
local feedback = require("rexkit.feedback")
local layout = require("rexkit.layout")
local shell = require("rexkit.shell")
local state = require("rexkit.state")

local DEFAULT = "^Window %x+$" -- the label Rex gives a window nobody named

local function strip_number(label)
  local name = (label or ""):gsub("^%d+%s+", ""):gsub("^%d+$", "")
  return name
end

-- Labels that say nothing about a pane: Rex's default and our own helpers'.
local GENERIC = { shell = true, rexd = true, toast = true, worktrees = true }

-- AUTO maps window id to the name rexd gave that tab, kept across restarts.
-- On the first run there is no record, so a name that already matches its
-- pane counts as rexd's and every other as yours.
local NAMES = "tab-names"
local auto = {}
local recorded = state.read(NAMES)
for id, name in (recorded or ""):gmatch("([^\t\n]+)\t([^\n]*)") do auto[id] = name end

local function save()
  local lines = {}
  for id, name in pairs(auto) do lines[#lines + 1] = id .. "\t" .. name .. "\n" end
  table.sort(lines)
  state.write(NAMES, table.concat(lines))
end

-- CWDS maps block id to its foreground process's directory, as the last
-- process_changed event reported it, so a renumber asks the OS only for a
-- block it has heard nothing of.
local cwds = {}

-- The name a tab's focused pane gives it, or nil. LABELS maps block id to
-- label, listed once per renumber.
local function pane_name(session_id, w, labels)
  local block = w.focused_block_id
  if not block then return nil end
  local label = labels()[block]
  if label and not GENERIC[label] and not label:find("^steps·") then return label end
  cwds[block] = cwds[block] or api.cwd(session_id, block)
  return cwds[block] and cwds[block]:match("[^/]+$")
end

-- A tab's name, and whether rexd gives it.
local function name_for(session_id, w, labels)
  local name = strip_number(w.label)
  if name ~= "" and not name:match(DEFAULT) and name ~= auto[w.window_id] then
    if recorded or name ~= pane_name(session_id, w, labels) then return name, false end
  end
  return pane_name(session_id, w, labels) or name, true
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
  local changed = false
  for i, w in ipairs((view and view.windows) or {}) do
    local name, mine = name_for(session_id, w, labels)
    local record = mine and name or nil
    if auto[w.window_id] ~= record then auto[w.window_id], changed = record, true end
    local want = i .. " " .. name
    if w.label ~= want then
      api.try("session.set_window_label", { session_id = session_id, window_id = w.window_id, label = want })
    end
  end
  if changed then save() end
end

local function on_session(_, ev) renumber(ev.session_id) end
for _, name in ipairs({ "window_created", "window_label_changed",
                        "session_view_changed", "session_created" }) do
  rex.on(name, on_session)
end

rex.on("window_closed", function(_, ev)
  if ev.window_id and auto[ev.window_id] then
    auto[ev.window_id] = nil
    save()
  end
  renumber(ev.session_id)
end)

-- A pane that changes directory renames its tab. Rex reports the foreground
-- process again when its directory changes, as well as when another process
-- takes the foreground.
local function on_process(target, ev)
  local fg = ev.foreground or (ev.payload and ev.payload.foreground)
  local cwd = fg and fg.cwd
  if cwd and cwd ~= cwds[target.block_id] then
    cwds[target.block_id] = cwd
    renumber(target.session_id)
  end
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

-- Through a file, not printf's argument: a copy can outgrow ARG_MAX.
local function to_pasteboard(text)
  local path = os.tmpname()
  local f = io.open(path, "w")
  if not f then return end
  f:write(text)
  f:close()
  os.execute("pbcopy <" .. shell.quote(path))
  os.remove(path)
end

rex.on("block_event", function(target, ev)
  if ev.name == "process_changed" then return on_process(target, ev) end
  if ev.name == "clipboard_written" then
    if type(ev.text) == "string" and ev.text ~= "" then to_pasteboard(ev.text) end
    return
  end
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

-- Number every tab, then forget the names of tabs that closed while rexd
-- was not running. The first run writes the record even when empty, so the
-- matching it did for lack of one happens once.
local alive = {}
for _, s in ipairs(api.sessions()) do
  renumber(s.session_id)
  local view = api.view(s.session_id)
  for _, w in ipairs((view and view.windows) or {}) do alive[w.window_id] = true end
end
local stale = not recorded
for id in pairs(auto) do
  if not alive[id] then auto[id], stale = nil, true end
end
recorded = recorded or ""
if stale then save() end
