-- Rex config. An experiment, not a tmux port: what Rex makes possible for
-- agent work. Lab notebook, findings and open questions:
-- ~/dotfiles/docs/rex.md. Validate with `rex config check`, apply with
-- `rex config reload`.

local HOME = os.getenv("HOME")
local REX_DIR = HOME .. "/.config/rex"
package.path = REX_DIR .. "/lua/?.lua;" .. package.path
local kit = require("rexkit")
local STATE = (os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")) .. "/rex-lab"

-- The session a key press came from, or the first session when the action was
-- run another way (rex do, the palette).
local function current_session(ctx)
  ctx = ctx or {}
  local sid = ctx.session_id or (ctx.session and ctx.session.session_id)
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

-- Jump to the agent that has waited longest in the most urgent state:
-- blocked, then errored, then finished. The server moves focus to its block;
-- the client is asked to show that session.
rex.action{
  name = "agents_next",
  title = "Jump to Agent Needing Attention",
  run = function(ctx)
    log_ctx("agents_next", ctx)
    local row = kit.most_urgent(kit.agents())
    if not row then return { jumped = false, reason = "no agent is waiting" } end
    kit.call("session.focus_block", { session_id = row.session_id, block_id = row.block_id })
    rex.client.queue("session.select", { session_id = row.session_id, window_id = row.window_id })
    return { jumped = true, session = row.session, block = row.block, state = row.record.state }
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
    kit.call("session.focus_window", { session_id = sid, window_id = w.window_id })
    rex.client.queue("session.select", { session_id = sid, window_id = w.window_id })
    return { moved = w.label }
  end,
}

-- ctrl+shift+down / up: the next or previous tab in the sidebar's order,
-- crossing into the next session at the end of one and wrapping at the ends.
-- The sidebar lists sessions as session.list does, each with its windows in
-- order.
rex.action{
  name = "window_step",
  title = "Next or Previous Tab, Across Sessions",
  run = function(ctx, args)
    local step = tonumber(args and args.step) or 1
    local here = (args and args.session_id) or current_session(ctx)
    local tabs, at = {}, nil
    for _, s in ipairs(kit.sessions()) do
      local view = kit.try("session.view", { session_id = s.session_id })
      for _, w in ipairs((view and view.windows) or {}) do
        tabs[#tabs + 1] = { session_id = s.session_id, window_id = w.window_id, label = w.label }
        if s.session_id == here and w.window_id == view.active_window_id then at = #tabs end
      end
    end
    if #tabs == 0 then return { moved = false } end
    local to = tabs[((at or 1) - 1 + step) % #tabs + 1]
    kit.call("session.focus_window", { session_id = to.session_id, window_id = to.window_id })
    rex.client.queue("session.select", { session_id = to.session_id, window_id = to.window_id })
    return { moved = to.label }
  end,
}
rex.bind("ctrl+shift+down", "window_step", { step = 1 })
rex.bind("ctrl+shift+up", "window_step", { step = -1 })

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
  { "b", "pane.move_to_new_tab" },
  -- tabs (tmux windows) and sessions
  -- moving between tabs is ctrl+shift+up/down (window_step), not prefix n/p
  { "c", "client.tab.new" }, { "n", "client.tab.new" },
  { "x", "client.tab.close" }, { "m", "client.tab.rename" },
  { "shift+t", "session.switch" }, { "shift+9", "session.previous" }, { "shift+0", "session.next" },
  -- tools
  { "y", "copy_path" }, { "shift+y", "copy_path", { rel = true } },
  { "g", "gopen" }, { "shift+w", "worktrees" },
  { "shift+s", "steps_sidecar" }, { "shift+a", "agents_board" }, { "shift+j", "agents_next" },
  { "t", "client.theme.change" }, { "r", "client.config.reload" }, { "/", "client.find.open" },
}
for i = 1, 9 do prefix[#prefix + 1] = { tostring(i), "window_goto", { index = i } } end
for _, b in ipairs(prefix) do rex.bind("prefix/" .. b[1], b[2], b[3]) end

rex.bind("cmd+shift+j", "agents_next")
rex.bind("cmd+shift+s", "steps_sidecar")
rex.bind("cmd+shift+a", "agents_board")
