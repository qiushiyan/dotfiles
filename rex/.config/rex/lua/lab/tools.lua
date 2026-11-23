-- lab.tools: actions that hand a pane's context to another tool: its path
-- to the clipboard, its repository to GitHub, its worktrees, its URLs, its
-- scrollback to a page. Pasting is the app's own (ctrl+v is pane.paste,
-- lab.keys), which uploads files and screenshots to another host's pane. Each puts its work on the right machine when the
-- session is another host's (rexkit.host).

local action = require("lab.action")
local client = require("lab.client")
local api = require("rexkit.api")
local feedback = require("rexkit.feedback")
local host = require("rexkit.host")
local shell = require("rexkit.shell")

local define = action.group("Tools")

-- prefix y / Y: copy the focused file's path when nvim runs in the block
-- (nvim writes it to a file named for the block, config/autocmds.lua), else
-- the directory the block works in (api.cwd: for Claude Code, the checkout
-- its agent works in). rel = true gives the
-- path relative to nvim's cwd. The copy lands on the clipboard of the
-- machine you are looking from (host.copy).
define{
  name = "copy_path",
  title = "Copy Path",
  args = action.schema({ rel = { type = "boolean" } }),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    if not (sid and bid) then return { copied = false, reason = "no focused block" } end
    local path
    local fg = api.foreground(sid, bid)
    if fg and fg.name == "nvim" then
      local body = host.read_state(ctx, sid, "yank/" .. bid:gsub(":", "_"))
      local abs, rel = (body or ""):match("^([^\n]+)\n?([^\n]*)")
      path = args.rel and rel ~= "" and rel or abs
    end
    path = path or (fg and api.cwd(sid, bid, fg))
    if not path then
      feedback.toast(sid, bid, "warn", "Copy path", "nothing to copy here")
      return { copied = false, reason = "no path" }
    end
    if not host.copy(ctx, sid, bid, path, fg) then
      feedback.toast(sid, bid, "error", "Copy path", "could not reach the terminal")
      return { copied = false, reason = "no tty" }
    end
    feedback.toast(sid, bid, "ok", "Copied", shell.tilde(path))
    return { copied = path }
  end,
}

-- The URL gopen would open for the checkout in DIR, run on the session's
-- host, or nil.
local function gopen_url(ctx, sid, dir)
  local url = host.run_there(ctx, sid, "gopen --print </dev/null", {}, dir)
  return url and url:match("https?://%S+")
end

-- prefix g: open the block's repo on GitHub with gopen (~/dev/gopen): the
-- PR when the branch has one, else the branch. In the background, since the
-- PR lookup can take a network call; a toast says what it opened.
define{
  name = "gopen",
  title = "Open on GitHub",
  args = action.schema({}),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    local dir = sid and bid and api.cwd(sid, bid)
    if not dir then return { opened = false, reason = "no directory" } end
    feedback.toast(sid, bid, "info", "GitHub", "opening " .. dir:match("[^/]+$") .. "…", 1.5)
    -- On another host's session gopen runs there, in the block's checkout,
    -- and the URL opens here, where the app is.
    if ctx.server then
      local url = gopen_url(ctx, sid, dir)
      if not url then
        feedback.notify("GitHub", "gopen found no URL: is the branch on origin?")
        return { opened = false, reason = "gopen found no URL" }
      end
      shell.open(url)
      return { opened = url }
    end
    -- A key pressed in the laptop's app would open the browser on this
    -- machine: there the URL goes to that app's clipboard instead (OSC 52).
    if not host.client_is_local(ctx.client_id) then
      local url = gopen_url(ctx, sid, dir)
      if not url then return { opened = false, reason = "gopen found no URL" } end
      feedback.osc52(sid, bid, url)
      feedback.toast(sid, bid, "ok", "Copied GitHub URL", url)
      return { copied = url }
    end
    -- gopen prints the URL it opened; exit 3 means the branch is not on origin.
    local toast = "REX_SESSION=" .. shell.quote(sid) .. " REX_BLOCK=" .. shell.quote(bid) .. " rex-toast"
    shell.spawn("cd " .. shell.quote(dir) .. " && export PATH=" .. shell.quote(shell.PATH)
      .. " && url=$(gopen </dev/null 2>/dev/null); rc=$?;"
      .. " case $rc in 0) " .. toast .. " ok 'Opened on GitHub' \"$url\" ;;"
      .. " 3) " .. toast .. " warn GitHub 'branch not on origin: run gopen in the pane to push' ;;"
      .. " *) " .. toast .. " error GitHub \"gopen failed ($rc)\" ;; esac")
    return { opening = dir }
  end,
}

-- prefix W: the worktrees of the pane's repository in the command palette,
-- from gwt (~/dev/gwt, which owns listing, creation and every verdict; this
-- only picks and places). Picking one goes to the tab already working in it,
-- else opens a tab there; a name that matches none becomes a new branch, which
-- `gwt create` checks out in the new tab, where its output shows. prefix C-w
-- (claude = true) opens a tab running Claude there instead, with its
-- claude-steps sidecar beside it. gwt runs on the session's host
-- (host.run_there), so this works on another host's session too.
-- path or branch, given as an arg, skips the question (`rex do`, the tests).

-- gwt list's worktrees of the checkout DIR, as rex.ui.pick items (the id is
-- the path), the current checkout first; raises when DIR is in no repository,
-- which the app reports.
local function worktree_items(ctx, sid, dir)
  local out = host.run_there(ctx, sid, "gwt list --json </dev/null", {}, dir)
  local list = out and rex.json.decode(out)
  if not (list and list.worktrees) then error("gwt list: " .. dir .. " is not in a Git repository", 0) end
  table.sort(list.worktrees, function(a, b) return a.current and not b.current end)
  local items = {}
  for _, w in ipairs(list.worktrees) do
    local marks = {}
    if w.main then marks[#marks + 1] = "main" end
    if w.dirty then marks[#marks + 1] = "dirty" end
    if w.merged and not w.main then marks[#marks + 1] = "merged" end
    items[#items + 1] = { id = w.path, title = w.branch or "(detached)", subtitle = shell.tilde(w.path),
      icon = "branch", detail = table.concat(marks, " ") }
  end
  return items
end

-- The terminal of SID whose foreground process works in PATH, else nil.
local function terminal_in(sid, path)
  for _, b in ipairs(api.terminals(sid)) do
    if api.cwd(sid, b.block_id) == path then return b end
  end
end

-- A new tab of SID at the end, running COMMAND (an argv, or nil for a login
-- shell) in CWD, shown in the app whose key opened it (as prefix N does).
local function open_tab(ctx, sid, cwd, label, command)
  local view = api.call("session.view", { session_id = sid })
  local key = ctx.origin == "key"
  local r = api.call("session.new_window", { session_id = sid, focus = not (key and ctx.server),
    layout = rex.layout.block{ flavor = api.SHELL, label = label,
      options = { cwd = cwd, command = command, login = command and false or nil } } })
  local at = client.tab_index(ctx, view)
  if key and at and ctx.server then
    shell.pause(0.5)
    client.step_tabs(at, #view.windows + 1)
  else
    client.show(ctx, sid, r.window_id)
  end
  return r
end

-- The shell line a new worktree tab runs: create BRANCH when given, go into
-- the checkout, then Claude (claude = true) or a login shell. A failed create
-- stays on screen until a key is pressed. zsh -i, for the x launcher.
local CREATE = 'p=$(gwt create --non-interactive "$1" | tail -1) && [ -d "$p" ] && cd "$p"'
  .. ' || { printf "\\n  gwt create failed: press a key to close"; read -rsk1; exit 1; }; '

define{
  name = "worktrees",
  title = "Worktrees…",
  args = action.schema({ claude = { type = "boolean" }, path = { type = "string" }, branch = { type = "string" } }),
  ask = function(ctx, args)
    if args.path then return { path = args.path } end
    if args.branch then return { branch = args.branch } end
    local sid, bid = action.block(ctx, args)
    local dir = sid and bid and api.cwd(sid, bid)
    if not dir then return nil, "no directory" end
    local pick, why = action.pick{
      title = args.claude and "Open Claude in a worktree" or "Go to a worktree",
      placeholder = "Filter, or name a new branch",
      items = worktree_items(ctx, sid, dir),
      allow_other = true,
    }
    if pick == nil then return nil, why end
    if type(pick) == "table" then
      local branch = pick.text:gsub("^%s+", ""):gsub("%s+$", "")
      if branch == "" then return nil, "no branch named" end
      return { branch = branch, dir = dir }
    end
    return { path = pick }
  end,
  run = function(ctx, args, pick)
    local sid, bid = action.block(ctx, args)
    if not sid then return { opened = false, reason = "no session" } end
    local name = (pick.branch or pick.path):match("[^/]+$")
    if pick.path and not args.claude then
      local there = terminal_in(sid, pick.path)
      if there then
        api.call("session.focus_block", { session_id = sid, block_id = there.block_id })
        client.show(ctx, sid, there.window_id)
        return { focused = there.block_id }
      end
      return { opened = open_tab(ctx, sid, pick.path, name).window_id }
    end
    local line = args.claude and "x; exec zsh -l" or "exec zsh -l"
    local command, cwd = { "/bin/zsh", "-lic", line }, pick.path
    if pick.branch then
      command = { "/bin/zsh", "-lic", CREATE .. line, "worktree", pick.branch }
      cwd = pick.dir or (bid and api.cwd(sid, bid))
    end
    local r = open_tab(ctx, sid, cwd, name, command)
    local block = r.block_ids and r.block_ids[1]
    if args.claude and block then
      api.split(sid, block, { direction = "horizontal", ratio = 0.62, label = "steps·" .. block:sub(-6),
        command = shell.bin("rex-steps", "watch", sid, block) })
    end
    return { opened = r.window_id, block = block, created = pick.branch }
  end,
}

-- prefix u: pick a URL or file from the block's screen and scrollback and open
-- it (rex-urls), in a split below it. Rex hands over the whole scrollback as
-- text (`format`), so no copy mode is involved.
define{
  name = "urls",
  title = "Open a URL or File from This Pane",
  args = action.schema({}),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    if not (sid and bid) then return { opened = false } end
    -- The picker runs on the session's host and opens the pick on the machine
    -- the key was pressed on, which only this action can name.
    local block = api.split(sid, bid, { direction = "vertical", ratio = 0.6, label = "urls",
      cwd = api.cwd(sid, bid), command = shell.bin("rex-urls", sid, bid, host.viewer(ctx)), focus = true })
    return { opened = block }
  end,
}

-- prefix e: the pane's screen and scrollback, colours kept, as an HTML page
-- (rex-export), opened in the browser of the machine the key was pressed on:
-- here, or, from the laptop's app, the path goes to its clipboard.
define{
  name = "export_pane",
  title = "Export Pane as HTML",
  args = action.schema({}),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    if not (sid and bid) then return { exported = false } end
    -- rex-export runs here; on another host's session its rex calls go there.
    local server = ctx.server and ("REX_SERVER=" .. shell.quote(ctx.server) .. " ") or ""
    -- It prints the page's path, or why it could not: raised, so the log and
    -- the app say it while toasts are off.
    local out = shell.capture(server .. "PATH=" .. shell.quote(shell.PATH) .. " "
      .. shell.quote(os.getenv("HOME") .. "/.local/bin/rex-export") .. " "
      .. shell.quote(sid) .. " " .. shell.quote(bid) .. " 2>&1")
    local path = out and out:match("^/[^\n]+%.html$")
    if not path then error(out or "rex-export printed nothing", 0) end
    if host.app_is_here(ctx) then
      shell.open(path)
    else
      feedback.osc52(sid, bid, path)
    end
    feedback.toast(sid, bid, "ok", "Exported", shell.tilde(path))
    return { exported = path }
  end,
}
