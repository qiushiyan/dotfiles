-- lab.tools: actions that hand a pane's context to another tool: its path
-- to the clipboard, its repository to GitHub, its worktrees, its URLs, its
-- scrollback to a page. Each puts its work on the right machine when the
-- session is another host's (rexkit.host).

local action = require("lab.action")
local api = require("rexkit.api")
local feedback = require("rexkit.feedback")
local host = require("rexkit.host")
local shell = require("rexkit.shell")

local define = action.group("Tools")

-- prefix y / Y: copy the focused file's path when nvim runs in the block
-- (nvim writes it to a file named for the block, config/autocmds.lua), else
-- the directory the block's front process runs in. rel = true gives the
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
    path = path or (fg and fg.cwd)
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

-- prefix W: the worktree picker (rex-worktree) in a split beside the block.
-- Not a floating layer: the app does not send keys to one yet.
define{
  name = "worktrees",
  title = "Worktrees",
  args = action.schema({}),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    local dir = sid and bid and api.cwd(sid, bid)
    if not dir then return { opened = false, reason = "no directory" } end
    local block = api.split(sid, bid, { direction = "vertical", ratio = 0.5, label = "worktrees",
      cwd = dir, command = shell.bin("rex-worktree", sid), focus = true })
    return { opened = block }
  end,
}

-- prefix u: pick a URL from the block's screen and scrollback and open it
-- (rex-urls), in a split below it. Rex hands over the whole scrollback as
-- text (`format`), so no copy mode is involved.
define{
  name = "urls",
  title = "Open a URL from This Pane",
  args = action.schema({}),
  run = function(ctx, args)
    local sid, bid = action.block(ctx, args)
    if not (sid and bid) then return { opened = false } end
    -- The picker runs on the session's host; it opens a URL only when the
    -- app is there too, and copies it (OSC 52, to the app) otherwise.
    local where = (not ctx.server and host.client_is_local(ctx.client_id)) and "here" or "away"
    local block = api.split(sid, bid, { direction = "vertical", ratio = 0.6, label = "urls",
      cwd = api.cwd(sid, bid), command = shell.bin("rex-urls", sid, bid, where), focus = true })
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
    local path = shell.capture(server .. "PATH=" .. shell.quote(shell.PATH) .. " "
      .. shell.quote(os.getenv("HOME") .. "/.local/bin/rex-export") .. " "
      .. shell.quote(sid) .. " " .. shell.quote(bid) .. " 2>/dev/null")
    if not path then
      feedback.toast(sid, bid, "error", "Export", "could not read the pane")
      return { exported = false }
    end
    if host.app_is_here(ctx) then
      shell.open(path)
    else
      feedback.osc52(sid, bid, path)
    end
    feedback.toast(sid, bid, "ok", "Exported", shell.tilde(path))
    return { exported = path }
  end,
}
