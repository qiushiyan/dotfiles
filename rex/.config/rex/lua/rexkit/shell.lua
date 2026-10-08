-- rexkit.shell: commands on this machine, from an action or a `rex do`
-- script. Every helper here forks, so the hot paths (a key press) call none
-- of them; docs/rex.md has what each fork costs.

local M = {}

local HOME = os.getenv("HOME")

-- Actions and the panes they start inherit the server's bare system PATH.
M.PATH = HOME .. "/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

function M.quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

-- The command line for one of the lab's tools in a pane the server starts.
-- The path is resolved by the pane's own shell, on the host it runs on: an
-- action that runs from the laptop's config on the mini's session would
-- otherwise name the laptop's home directory there.
function M.bin(name, ...)
  return { "/bin/sh", "-c", 'exec "$HOME/.local/bin/' .. name .. '" "$@"', name, ... }
end

-- A shell command's output with trailing white space removed, or nil when
-- it printed nothing.
function M.capture(cmd)
  local p = io.popen(cmd)
  local out = p and p:read("*a") or ""
  if p then p:close() end
  out = out:gsub("%s+$", "")
  return out ~= "" and out or nil
end

function M.run(cmd) return os.execute(cmd) == 0 end

-- CMD in the background, its output discarded.
function M.spawn(cmd) os.execute("(" .. cmd .. ") >/dev/null 2>&1 &") end

-- Open a URL or file with macOS `open`, on this machine.
function M.open(target) M.spawn("open " .. M.quote(target)) end

-- Wait SECONDS. A `rex do` script has rex.sleep; an action has none (nor
-- rex.wait), so there it is a shell sleep.
function M.pause(seconds)
  if rex.sleep then return rex.sleep(seconds) end
  os.execute("sleep " .. tonumber(seconds))
end

-- Replace the home directory at the start of PATH with ~.
function M.tilde(path)
  if path:sub(1, #HOME) == HOME then return "~" .. path:sub(#HOME + 1) end
  return path
end

return M
