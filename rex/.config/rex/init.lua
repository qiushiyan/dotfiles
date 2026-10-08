-- Rex config. An experiment, not a tmux port: what Rex makes possible for
-- agent work. Lab notebook, findings and open questions:
-- ~/dotfiles/docs/rex.md. Validate with `rex config check`, apply with
-- `rex config reload`.

local HOME = os.getenv("HOME")
local REX_DIR = HOME .. "/.config/rex"
package.path = REX_DIR .. "/lua/?.lua;" .. package.path
local kit = require("rexkit")
local STATE = kit.STATE

-- Every action a key runs first notes where the key was pressed (kit.here):
-- the app does not tell the server which session it shows, and the out-of-view
-- notifications and prefix Tab need to know. An action that fails also
-- writes its error, with the ctx it ran under and a traceback, to
-- STATE/actions.log before the app reports it: the app's own report is all
-- that is left otherwise. ctx.server is set when the session belongs to
-- another host (the mini's, shown in the laptop's app); every call the action
-- makes then travels through the app to that host.
local function log_error(name, ctx, err)
  os.execute("mkdir -p '" .. STATE .. "'")
  local f = io.open(STATE .. "/actions.log", "a")
  if f then
    f:write(os.date("%Y-%m-%d %H:%M:%S "), name, " failed: ", tostring(err), "\n  ctx ", kit.dump(ctx), "\n")
    f:close()
  end
end

local define = rex.action
rex.action = function(spec)
  local run = spec.run
  spec.run = function(ctx, args)
    if ctx and ctx.origin == "key" and not ctx.server then kit.note_here(ctx.session_id, ctx.client_id) end
    local result = { xpcall(function() return run(ctx, args) end, debug and debug.traceback or tostring) }
    if not result[1] then
      log_error(spec.name, ctx, result[2])
      error(result[2], 0)
    end
    return unpack(result, 2)
  end
  return define(spec)
end

-- The session a key press came from, or the first session when the action was
-- run another way (rex do, the palette).
local function current_session(ctx)
  ctx = ctx or {}
  local sid = ctx.session_id or (ctx.session and ctx.session.session_id) or kit.here()
  if sid then return sid end
  local first = kit.sessions()[1]
  return first and first.session_id
end

-- What a key press hands an action is undocumented: each action records its
-- ctx here until we know (README, open questions).
local function log_ctx(name, ctx)
  os.execute("mkdir -p '" .. STATE .. "'")
  local f = io.open(STATE .. "/ctx.log", "a")
  if f then
    f:write(os.date("%Y-%m-%d %H:%M:%S "), name, " ", kit.dump(ctx), "\n")
    f:close()
  end
end

-- The block a key press came from: the one args or ctx names, else the
-- focused block of the current session. Args let a script or `rex do ACTION
-- session_id=… block_id=…` aim an action, which a key press does through ctx.
local function current_block(ctx, args)
  ctx, args = ctx or {}, args or {}
  local sid = args.session_id or current_session(ctx)
  local bid = args.block_id or ctx.block_id or (ctx.block and ctx.block.block_id)
  return sid, bid or (sid and kit.focused_block(sid))
end

-- Show tab WINDOW_ID of SESSION_ID in the app whose key ran the action: the
-- server activates the window, which the app follows in the session it
-- shows, and the app is asked to show that session. When the session is
-- another host's (ctx.server: the laptop's app on the mini's session), the
-- app's session.select cannot place it and gives up after 5 seconds ("no
-- host lists it" in its log), so there a move to another session is the
-- app's own session.next or session.previous, by the sign of STEP, and
-- without a STEP the session stays as it is. K is the server to call (kit,
-- or kit.remote for an agent on another host).
local function show(ctx, session_id, window_id, step, K)
  K = K or kit
  K.call("session.focus_window", { session_id = session_id, window_id = window_id })
  if not (ctx and ctx.server) then
    rex.client.queue("session.select", { session_id = session_id, window_id = window_id })
  elseif session_id ~= ctx.session_id and step then
    rex.client.queue(step < 0 and "session.previous" or "session.next", {})
  end
end

-- Jump to the agent that has waited longest in the most urgent state:
-- blocked, then errored, then finished, on this server or another host's (the
-- mini's, seen from the laptop). The server moves focus to its block; the
-- client is asked to show that session.
rex.action{
  name = "agents_next",
  title = "Jump to Agent Needing Attention",
  run = function(ctx)
    log_ctx("agents_next", ctx)
    local row = kit.most_urgent(kit.agents_everywhere())
    if not row then return { jumped = false, reason = "no agent is waiting" } end
    local K = row.server and kit.remote(row.server) or kit
    K.call("session.focus_block", { session_id = row.session_id, block_id = row.block_id })
    show(ctx, row.session_id, row.window_id, nil, K)
    if not row.server then kit.note_here(row.session_id, ctx and ctx.client_id) end
    return { jumped = true, server = row.server, session = row.session, block = row.block, state = row.record.state }
  end,
}

-- The agents board in a floating layer over the current window; ⌘⇧A again
-- closes it. The app does not send keystrokes to a floating layer yet, so the
-- key that opened the board is the one that closes it.
rex.action{
  name = "agents_board",
  title = "Agents Board",
  run = function(ctx)
    log_ctx("agents_board", ctx)
    local sid = current_session(ctx)
    if not sid then return { opened = false, reason = "no session" } end
    local closed = 0
    for _, b in ipairs(kit.terminals(sid)) do
      if b.label == "agents-popup" then
        kit.call("block.close", { session_id = sid, block_id = b.block_id })
        closed = closed + 1
      end
    end
    if closed > 0 then return { closed = closed } end
    local r = kit.call("session.new_layer", {
      session_id = sid,
      bounds = { x = 0.08, y = 0.08, w = 0.84, h = 0.6 },
      layout = { block = {
        flavor = "com.superlogical.terminal.shell", label = "agents-popup",
        options = { command = { HOME .. "/.local/bin/rex-board", "--popup" } },
      } },
      focus = true,
    })
    return { opened = true, layer = r.layer_id }
  end,
}

-- claude-steps as a live sidecar beside the focused agent (rex-steps): opens
-- it, or closes it when it is already open. From inside a sidecar, closes
-- that sidecar.
rex.action{
  name = "steps_sidecar",
  title = "Steps Sidecar",
  run = function(ctx, args)
    log_ctx("steps_sidecar", ctx)
    local sid, bid = current_block(ctx, args)
    if not (sid and bid) then return { opened = false, reason = "no focused block" } end
    local blocks = kit.terminals(sid)
    for _, b in ipairs(blocks) do
      if b.block_id == bid and (b.label or ""):find("^steps·") then
        kit.call("block.close", { session_id = sid, block_id = bid })
        return { closed = b.label }
      end
    end
    local label = "steps·" .. bid:sub(-6)
    for _, b in ipairs(blocks) do
      if b.label == label then
        kit.call("block.close", { session_id = sid, block_id = b.block_id })
        return { closed = label }
      end
    end
    local r = kit.call("session.new_split", {
      session_id = sid, anchor_block_id = bid,
      direction = "horizontal", side = "after", ratio = 0.62,
      layout = { block = {
        flavor = "com.superlogical.terminal.shell", label = label,
        options = { command = { HOME .. "/.local/bin/rex-steps", "watch", sid, bid } },
      } },
      focus = false,
    })
    return { opened = label, block = r.block_ids[1] }
  end,
}

-- prefix y / Y: copy the focused file's path when nvim runs in the block
-- (nvim writes it to a file named for the block, config/autocmds.lua), else
-- the directory the block's front process runs in. rel = true gives the
-- path relative to nvim's cwd. The copy goes through the block's terminal
-- (OSC 52), so it lands on the clipboard of the machine you are looking from.
rex.action{
  name = "copy_path",
  title = "Copy Path",
  run = function(ctx, args)
    log_ctx("copy_path", ctx)
    local sid, bid = current_block(ctx, args)
    if not (sid and bid) then return { copied = false, reason = "no focused block" } end
    local path
    local fg = kit.foreground(sid, bid)
    if fg and fg.name == "nvim" then
      local f = io.open(STATE .. "/yank/" .. bid:gsub(":", "_"), "r")
      if f then
        local abs, rel = f:read("*l"), f:read("*l")
        f:close()
        path = (args and args.rel) and rel or abs
      end
    end
    path = path or (fg and fg.cwd)
    if not path then
      kit.toast(sid, bid, "warn", "Copy path", "nothing to copy here")
      return { copied = false, reason = "no path" }
    end
    if not kit.osc52(sid, bid, path) then
      kit.toast(sid, bid, "error", "Copy path", "could not reach the terminal")
      return { copied = false, reason = "no tty" }
    end
    kit.toast(sid, bid, "ok", "Copied", (path:gsub("^" .. HOME:gsub("%p", "%%%0"), "~")))
    return { copied = path }
  end,
}

-- prefix g: open the block's repo on GitHub with gopen (~/dev/gopen): the
-- PR when the branch has one, else the branch. In the background, since the
-- PR lookup can take a network call; a toast says what it opened.
rex.action{
  name = "gopen",
  title = "Open on GitHub",
  run = function(ctx, args)
    log_ctx("gopen", ctx)
    local sid, bid = current_block(ctx, args)
    local dir = sid and bid and kit.cwd(sid, bid)
    if not dir then return { opened = false, reason = "no directory" } end
    kit.toast(sid, bid, "info", "GitHub", "opening " .. dir:match("[^/]+$") .. "…", 1.5)
    -- A key pressed in the laptop's app would open the browser on this
    -- machine: there the URL goes to that app's clipboard instead (OSC 52).
    if not kit.client_is_local(ctx and ctx.client_id) then
      local p = io.popen("cd " .. kit.sh_quote(dir) .. " && PATH=" .. kit.sh_quote(kit.PATH) .. " gopen --print </dev/null 2>/dev/null")
      local url = p and p:read("*l")
      if p then p:close() end
      if not url or url == "" then return { opened = false, reason = "gopen found no URL" } end
      kit.osc52(sid, bid, url)
      kit.toast(sid, bid, "ok", "Copied GitHub URL", url)
      return { copied = url }
    end
    -- gopen prints the URL it opened; exit 3 means the branch is not on origin.
    local toast = "REX_SESSION=" .. kit.sh_quote(sid) .. " REX_BLOCK=" .. kit.sh_quote(bid) .. " rex-toast"
    os.execute("(cd " .. kit.sh_quote(dir) .. " && export PATH=" .. kit.sh_quote(kit.PATH)
      .. " && url=$(gopen </dev/null 2>/dev/null); rc=$?;"
      .. " case $rc in 0) " .. toast .. " ok 'Opened on GitHub' \"$url\" ;;"
      .. " 3) " .. toast .. " warn GitHub 'branch not on origin: run gopen in the pane to push' ;;"
      .. " *) " .. toast .. " error GitHub \"gopen failed ($rc)\" ;; esac) >/dev/null 2>&1 &")
    return { opening = dir }
  end,
}

-- prefix W: the worktree picker (rex-worktree) in a split beside the block.
-- Not a floating layer: the app does not send keys to one yet.
rex.action{
  name = "worktrees",
  title = "Worktrees",
  run = function(ctx, args)
    log_ctx("worktrees", ctx)
    local sid, bid = current_block(ctx, args)
    local dir = sid and bid and kit.cwd(sid, bid)
    if not dir then return { opened = false, reason = "no directory" } end
    local r = kit.call("session.new_split", {
      session_id = sid, anchor_block_id = bid,
      direction = "vertical", side = "after", ratio = 0.5,
      layout = { block = {
        flavor = "com.superlogical.terminal.shell", label = "worktrees",
        options = { cwd = dir, command = { HOME .. "/.local/bin/rex-worktree", sid } },
      } },
      focus = true,
    })
    return { opened = r.block_ids[1] }
  end,
}

-- prefix 1–9: tab N of the session the key was pressed in, as tmux counts
-- windows and as rexd numbers the tabs. The app's client.tab.goto counts
-- every session's tabs in the sidebar together. The server activates the
-- window, and the app is asked to show it.
rex.action{
  name = "window_goto",
  title = "Go to Tab in This Session",
  run = function(ctx, args)
    local sid = (args and args.session_id) or current_session(ctx)
    local index = tonumber(args and args.index)
    local view = sid and index and kit.try("session.view", { session_id = sid })
    local w = view and view.windows and view.windows[index]
    if not w then return { moved = false, reason = "no tab " .. tostring(index) } end
    show(ctx, sid, w.window_id)
    return { moved = w.label }
  end,
}

-- ctrl+shift+down / up: the next or previous tab in the sidebar, crossing
-- sessions and hosts (the laptop's and the mini's) and wrapping at the
-- ends. The app's own actions, since only the app knows the sidebar: a
-- server action sees one host's sessions, and the app cannot select another
-- host's session for it.
rex.bind("ctrl+shift+down", "client.tab.next")
rex.bind("ctrl+shift+up", "client.tab.previous")

-- tmux ports on Rex's own API ---------------------------------------------------

-- ctrl+h/j/k/l, as vim-tmux-navigator did in tmux: in nvim, vim or fzf the key
-- goes to the program (LazyVim moves between its splits with it); elsewhere
-- it focuses the pane that way. At the right edge ctrl+l reaches the program,
-- so it still clears the screen; at the other edges the key does nothing.
local NAV_KEY = { left = "ctrl+h", down = "ctrl+j", up = "ctrl+k", right = "ctrl+l" }
local NAV_PASS = { nvim = true, vim = true, vi = true, view = true, fzf = true }
rex.action{
  name = "nav",
  title = "Focus Pane, Vim-Aware",
  run = function(ctx, args)
    local dir = args and args.direction
    local sid, bid = current_block(ctx, args)
    if not (NAV_KEY[dir] and sid and bid) then return { moved = false } end
    local fg = kit.foreground(sid, bid)
    local name = fg and (fg.name or ""):match("[^/]+$") or ""
    if NAV_PASS[name] then
      rex.client.queue("pane.send_key", { key = NAV_KEY[dir] })
      return { passed = name }
    end
    if kit.neighbor(kit.try("session.view", { session_id = sid }), bid, dir) then
      rex.client.queue("pane.focus", { direction = dir })
      return { moved = dir }
    end
    if dir == "right" then rex.client.queue("pane.send_key", { key = "ctrl+l" }) end
    return { moved = false }
  end,
}
for dir, key in pairs(NAV_KEY) do rex.bind(key, "nav", { direction = dir }) end

-- prefix C-h / C-l (C-p / C-n): the previous or next tab of this session,
-- wrapping, as tmux's previous-window and next-window.
rex.action{
  name = "window_cycle",
  title = "Next or Previous Tab in This Session",
  run = function(ctx, args)
    local sid = (args and args.session_id) or current_session(ctx)
    if not sid then return { moved = false } end
    kit.attach(sid)
    local step = tonumber(args and args.step) or 1
    -- session.focus_next_window stops at the last tab; tmux wraps.
    local view = kit.call("session.view", { session_id = sid })
    local windows, at = view.windows or {}, 1
    if #windows == 0 then return { moved = false } end
    for i, w in ipairs(windows) do if w.window_id == view.active_window_id then at = i end end
    local to = windows[(at - 1 + step) % #windows + 1].window_id
    show(ctx, sid, to)
    return { moved = to }
  end,
}

-- prefix Tab / shift+Tab: the tab, or the session, shown before this one, as
-- tmux's last-window and switch-client -l. rexd records every tab the app
-- shows, however it got there, in STATE/visits ("session window" per line,
-- newest last).
local function visits()
  local out, f = {}, io.open(STATE .. "/visits", "r")
  if not f then return out end
  for line in f:lines() do
    local s, w = line:match("^(%S+) (%S+)$")
    if s then out[#out + 1] = { session_id = s, window_id = w } end
  end
  f:close()
  return out
end

rex.action{
  name = "window_last",
  title = "Last Tab or Last Session",
  run = function(ctx, args)
    local sid = (args and args.session_id) or current_session(ctx)
    local here = sid and kit.try("session.view", { session_id = sid })
    if not here then return { moved = false } end
    local across = args and args.session
    local seen = {}
    local list = visits()
    for i = #list, 1, -1 do
      local v = list[i]
      local wanted
      if across then wanted = v.session_id ~= sid and not seen[v.session_id]
      else wanted = v.session_id == sid and v.window_id ~= here.active_window_id end
      seen[v.session_id] = true
      if wanted then
        kit.attach(v.session_id)
        local view = kit.try("session.view", { session_id = v.session_id })
        if view and view.windows and (across or kit.try("session.focus_window",
          { session_id = v.session_id, window_id = v.window_id })) then
          local window = across and view.active_window_id or v.window_id
          show(ctx, v.session_id, window)
          kit.note_here(v.session_id, ctx and ctx.client_id)
          return { moved = window }
        end
      end
    end
    kit.toast(sid, kit.focused_block(sid), "info", across and "Last session" or "Last tab", "nothing earlier yet", 1.5)
    return { moved = false }
  end,
}

-- prefix N: a new tab right after this one, in the directory of the pane the
-- key was pressed in (tmux's new-window -a -c).
rex.action{
  name = "window_new_here",
  title = "New Tab After This One, Here",
  run = function(ctx, args)
    local sid, bid = current_block(ctx, args)
    if not sid then return { opened = false } end
    local view = kit.call("session.view", { session_id = sid })
    local after
    for i, w in ipairs(view.windows or {}) do
      if w.window_id == view.active_window_id then after = view.windows[i + 1] end
    end
    local options = {}
    options.cwd = bid and kit.cwd(sid, bid)
    local r = kit.call("session.new_window", { session_id = sid,
      layout = { block = { flavor = "com.superlogical.terminal.shell", options = options } } })
    if after then
      kit.call("session.move_window", { session_id = sid, window_id = r.window_id, before_window_id = after.window_id })
    end
    show(ctx, sid, r.window_id)
    return { opened = r.window_id }
  end,
}

-- Pane mode (prefix p), as tmux's: hjkl push the pane that way, trading
-- places with the pane there. With nothing there and one other pane in the
-- window, it becomes that side's wall (stacked turns side by side); with
-- more, Rex can only split beside a pane, not the whole window, so it stays.
local MOVE = {
  left = { direction = "horizontal", side = "before" }, right = { direction = "horizontal", side = "after" },
  up = { direction = "vertical", side = "before" }, down = { direction = "vertical", side = "after" },
}
rex.action{
  name = "pane_push",
  title = "Push Pane",
  run = function(ctx, args)
    local dir = args and args.direction
    local sid, bid = current_block(ctx, args)
    if not (MOVE[dir] and sid and bid) then return { moved = false } end
    local view = kit.call("session.view", { session_id = sid })
    local other = kit.neighbor(view, bid, dir)
    if other then
      kit.call("session.swap_blocks", { session_id = sid, block_id = bid, other_block_id = other })
      return { swapped = other }
    end
    local w, rest = kit.window_of(view, bid), {}
    for _, layer in ipairs((w and w.layers) or {}) do
      for _, b in ipairs(layer.kind == "tiled" and layer.blocks or {}) do
        if b.block_id ~= bid then rest[#rest + 1] = b.block_id end
      end
    end
    if #rest ~= 1 then return { moved = false, reason = "at the edge" } end
    kit.call("session.move_block", { session_id = sid, block_id = bid, anchor_block_id = rest[1],
      direction = MOVE[dir].direction, side = MOVE[dir].side })
    kit.try("session.focus_block", { session_id = sid, block_id = bid })
    return { walled = dir }
  end,
}

-- Pane mode g / p / G: hold a pane, walk to any tab of the session, and put
-- it beside the pane there (Rex moves a live block between windows, so
-- nothing restarts). The hold is a file, so it survives a config reload.
local HELD = STATE .. "/held"
rex.action{
  name = "pane_hold",
  title = "Hold Pane",
  run = function(ctx, args)
    local sid, bid = current_block(ctx, args)
    if not (sid and bid) then return { held = false } end
    os.execute("mkdir -p '" .. STATE .. "'")
    local f = assert(io.open(HELD, "w"))
    f:write(sid, " ", bid, "\n")
    f:close()
    rex.client.queue("client.mode.exit", {})
    kit.toast(sid, bid, "info", "Holding pane", "walk to a tab, then prefix p p", 2)
    return { held = bid }
  end,
}

rex.action{
  name = "pane_put",
  title = "Put Held Pane Here",
  run = function(ctx, args)
    local sid, bid = current_block(ctx, args)
    local f = io.open(HELD, "r")
    local line = f and f:read("*l")
    if f then f:close() end
    local hsid, hbid = (line or ""):match("^(%S+) (%S+)$")
    if not (sid and bid and hbid) then return { put = false, reason = "nothing held" } end
    if hsid ~= sid then
      kit.toast(sid, bid, "warn", "Put pane", "the held pane is in another session", 2)
      return { put = false, reason = "other session" }
    end
    os.remove(HELD)
    if hbid == bid then return { put = false, reason = "same pane" } end
    kit.call("session.move_block", { session_id = sid, block_id = hbid, anchor_block_id = bid,
      direction = "horizontal", side = "after" })
    kit.try("session.focus_block", { session_id = sid, block_id = hbid })
    return { put = hbid }
  end,
}

rex.action{
  name = "pane_release",
  title = "Release Held Pane",
  run = function()
    os.remove(HELD)
    return { released = true }
  end,
}

-- prefix Z: a throwaway shell below the pane, in its directory; prefix Z
-- again (or exiting the shell) closes it. A split, since floating layers do
-- not take keys yet.
rex.action{
  name = "scratch",
  title = "Scratch Shell",
  run = function(ctx, args)
    local sid, bid = current_block(ctx, args)
    if not (sid and bid) then return { opened = false } end
    local view = kit.call("session.view", { session_id = sid })
    local w = kit.window_of(view, bid)
    for _, layer in ipairs((w and w.layers) or {}) do
      for _, b in ipairs(layer.blocks or {}) do
        if b.label == "scratch" then
          kit.call("block.close", { session_id = sid, block_id = b.block_id })
          return { closed = b.block_id }
        end
      end
    end
    local r = kit.call("session.new_split", {
      session_id = sid, anchor_block_id = bid,
      direction = "vertical", side = "after", ratio = 0.65,
      layout = { block = { flavor = "com.superlogical.terminal.shell", label = "scratch",
        options = { cwd = kit.cwd(sid, bid) } } },
      focus = true,
    })
    return { opened = r.block_ids[1] }
  end,
}

-- prefix C-k: clear the screen and the scrollback (tmux's send C-l plus
-- clear-history); ctrl+l after it has the shell redraw its prompt.
rex.action{
  name = "clear_all",
  title = "Clear Screen and Scrollback",
  run = function(ctx, args)
    local sid, bid = current_block(ctx, args)
    if not (sid and bid) then return { cleared = false } end
    kit.block(sid, bid, "clear")
    rex.client.queue("pane.send_key", { key = "ctrl+l" })
    return { cleared = bid }
  end,
}

-- A small helper in a split below the block, for the ports that need a
-- prompt or a picker: the app sends no keys to a floating layer yet.
local function helper_split(sid, bid, label, ratio, command)
  return kit.call("session.new_split", {
    session_id = sid, anchor_block_id = bid,
    direction = "vertical", side = "after", ratio = ratio,
    layout = { block = { flavor = "com.superlogical.terminal.shell", label = label,
      options = { cwd = kit.cwd(sid, bid), command = command } } },
    focus = true,
  })
end

-- prefix u: pick a URL from the block's screen and scrollback and open it
-- (rex-urls). Rex hands over the whole scrollback as text (`format`), so no
-- copy mode is involved.
rex.action{
  name = "urls",
  title = "Open a URL from This Pane",
  run = function(ctx, args)
    local sid, bid = current_block(ctx, args)
    if not (sid and bid) then return { opened = false } end
    local where = kit.client_is_local(ctx and ctx.client_id) and "here" or "away"
    local r = helper_split(sid, bid, "urls", 0.6, { HOME .. "/.local/bin/rex-urls", sid, bid, where })
    return { opened = r.block_ids[1] }
  end,
}

-- prefix M: name the pane (rex-label). The label shows in the pane header
-- and on the board; an empty name clears it.
rex.action{
  name = "label_pane",
  title = "Rename Pane",
  run = function(ctx, args)
    local sid, bid = current_block(ctx, args)
    if not (sid and bid) then return { opened = false } end
    local r = helper_split(sid, bid, "rename", 0.85, { HOME .. "/.local/bin/rex-label", sid, bid })
    return { opened = r.block_ids[1] }
  end,
}

-- prefix e: the pane's screen and scrollback, colours kept, as an HTML page
-- (rex-export), opened in the browser of the machine the key was pressed on:
-- here, or, from the laptop's app, the path goes to its clipboard.
rex.action{
  name = "export_pane",
  title = "Export Pane as HTML",
  run = function(ctx, args)
    local sid, bid = current_block(ctx, args)
    if not (sid and bid) then return { exported = false } end
    local p = io.popen("PATH=" .. kit.sh_quote(kit.PATH) .. " " .. HOME .. "/.local/bin/rex-export "
      .. kit.sh_quote(sid) .. " " .. kit.sh_quote(bid) .. " 2>/dev/null")
    local path = p and p:read("*l")
    if p then p:close() end
    if not path or path == "" then
      kit.toast(sid, bid, "error", "Export", "could not read the pane")
      return { exported = false }
    end
    if kit.client_is_local(ctx and ctx.client_id) then
      os.execute("open " .. kit.sh_quote(path) .. " >/dev/null 2>&1 &")
    else
      kit.osc52(sid, bid, path)
    end
    kit.toast(sid, bid, "ok", "Exported", (path:gsub("^" .. HOME:gsub("%p", "%%%0"), "~")))
    return { exported = path }
  end,
}

-- shift+up / shift+down slide the tab, as tmux's swap-window binding did
-- with shift+left/right: up and down, since the tabs are a vertical list.
rex.bind("shift+up", "client.tab.move.backward")
rex.bind("shift+down", "client.tab.move.forward")

rex.mode("panes", { exclusive = true })
local panes = {
  { "escape", "client.mode.exit" }, { "enter", "client.mode.exit" }, { "q", "client.mode.exit" },
  { "g", "pane_hold" }, { "p", "pane_put" }, { "shift+g", "pane_release" },
  { "b", "pane.move_to_new_tab" }, { "e", "pane.balance" }, { "z", "pane.zoom" },
}
for dir, key in pairs({ left = "h", down = "j", up = "k", right = "l" }) do
  panes[#panes + 1] = { key, "pane_push", { direction = dir } }
  panes[#panes + 1] = { "shift+" .. key, "pane.resize", { direction = dir } }
end
for _, dir in ipairs({ "left", "down", "up", "right" }) do
  panes[#panes + 1] = { dir, "pane.focus", { direction = dir } }
end
for _, b in ipairs(panes) do rex.bind("panes/" .. b[1], b[2], b[3]) end

-- The tmux prefix, as a Rex mode: ctrl+a enters it for one key, as tmux's
-- prefix does, and Escape leaves it. Exclusive, so a key it does not bind
-- does nothing rather than reach the shell. Most keys are the app's own
-- actions; the rest are defined above. ctrl+a twice sends a literal ctrl+a.
rex.mode("prefix", { exclusive = true })
rex.bind("ctrl+a", "client.mode.enter", { name = "prefix", once = true })
local prefix = {
  { "escape", "client.mode.exit" },
  { "ctrl+a", "pane.send_key", { key = "ctrl+a" } },
  -- panes
  { "shift+\\", "pane.split.right" }, { "\\", "pane.split.right" }, { "-", "pane.split.down" },
  { "h", "pane.focus.left" }, { "j", "pane.focus.down" }, { "k", "pane.focus.up" }, { "l", "pane.focus.right" },
  { "shift+h", "pane.resize", { direction = "left" } }, { "shift+j", "pane.resize", { direction = "down" } },
  { "shift+k", "pane.resize", { direction = "up" } }, { "shift+l", "pane.resize", { direction = "right" } },
  { "z", "pane.zoom" }, { "shift+x", "pane.close" }, { "space", "pane.balance" },
  { "b", "pane.move_to_new_tab" }, { "p", "client.mode.enter", { name = "panes" } },
  { "shift+z", "scratch" }, { "shift+m", "label_pane" }, { "ctrl+k", "clear_all" },
  -- tabs (tmux windows) and sessions; ctrl+shift+up/down also step through
  -- every tab in the sidebar, across sessions and hosts
  { "c", "client.tab.new" }, { "n", "client.tab.new" }, { "shift+n", "window_new_here" },
  { "ctrl+h", "window_cycle", { step = -1 } }, { "ctrl+l", "window_cycle", { step = 1 } },
  { "ctrl+p", "window_cycle", { step = -1 } }, { "ctrl+n", "window_cycle", { step = 1 } },
  { "tab", "window_last" }, { "shift+tab", "window_last", { session = true } },
  { "x", "client.tab.close" }, { "m", "client.tab.rename" }, { "shift+4", "session.rename" },
  { "shift+t", "session.switch" }, { "shift+9", "session.previous" }, { "shift+0", "session.next" },
  -- tools
  { "y", "copy_path" }, { "shift+y", "copy_path", { rel = true } },
  { "g", "gopen" }, { "shift+w", "worktrees" }, { "u", "urls" }, { "e", "export_pane" },
  { "w", "session.open_on_web" },
  { "shift+s", "steps_sidecar" }, { "shift+a", "agents_board" }, { "a", "agents_next" },
  { "t", "client.theme.change" }, { "r", "client.config.reload" }, { "/", "client.find.open" },
}
for i = 1, 9 do prefix[#prefix + 1] = { tostring(i), "window_goto", { index = i } } end
for _, b in ipairs(prefix) do rex.bind("prefix/" .. b[1], b[2], b[3]) end

rex.bind("cmd+shift+j", "agents_next")
rex.bind("cmd+shift+s", "steps_sidecar")
rex.bind("cmd+shift+a", "agents_board")
