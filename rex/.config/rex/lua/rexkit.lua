-- rexkit: helpers shared by init.lua and the scripts under ../scripts.
--
-- Everything here runs inside Rex's Lua 5.1 (init.lua actions on the server,
-- or `rex do` scripts), so the only API is the `rex` global. Lab notes on how
-- that API behaves live in ~/dotfiles/rex/README.md.

local M = {}

M.TERMINAL = "com.superlogical.terminal"

-- rex.call returns nil plus a message on failure instead of raising.
function M.call(method, payload)
  local result, err = rex.call(method, payload or {})
  if result == nil and err ~= nil then error(method .. ": " .. tostring(err), 2) end
  return result
end

function M.try(method, payload)
  return rex.call(method, payload or {})
end

-- A control connection must attach to a session before calling into it.
local attached = {}
function M.attach(session_id)
  if attached[session_id] then return end
  M.call("session.attach", { session_id = session_id })
  attached[session_id] = true
end

function M.sessions()
  return M.call("session.list").sessions or {}
end

function M.terminals(session_id)
  M.attach(session_id)
  local out = {}
  for _, b in ipairs(M.call("session.list_blocks", { session_id = session_id }).blocks or {}) do
    if b.block_id and (b.creator_name == M.TERMINAL or (b.flavor or ""):find(M.TERMINAL, 1, true) == 1) then
      out[#out + 1] = b
    end
  end
  return out
end

function M.block(session_id, block_id, method, args)
  return M.try(M.TERMINAL .. "." .. method, { session_id = session_id, block_id = block_id, args = args or {} })
end

-- Agent records (OSC 7501) ------------------------------------------------------

-- Lower ranks need the human sooner. `clear` never reaches a record list.
M.RANK = { blocked = 1, error = 2, done = 3, working = 4, idle = 5 }

-- "2026-10-08T13:55:29.96152+01:00" -> epoch seconds.
local utc_offset = os.time() - os.time(os.date("!*t"))
function M.epoch(iso)
  if not iso then return nil end
  local y, mo, d, h, mi, s, rest = iso:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)[%.%d]*(.*)$")
  if not y then return nil end
  local t = os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = s }) + utc_offset
  local sign, oh, om = rest:match("^([%+%-])(%d+):(%d+)$")
  if sign then
    local off = tonumber(oh) * 3600 + tonumber(om) * 60
    t = sign == "+" and t - off or t + off
  end
  return t
end

function M.age(iso)
  local t = M.epoch(iso)
  if not t then return "" end
  local s = os.time() - t
  if s < 60 then return s .. "s" end
  if s < 3600 then return math.floor(s / 60) .. "m" end
  if s < 86400 then return math.floor(s / 3600) .. "h" end
  return math.floor(s / 86400) .. "d"
end

-- One row per agent record across every session on this server.
function M.agents()
  local rows = {}
  for _, s in ipairs(M.sessions()) do
    for _, b in ipairs(M.terminals(s.session_id)) do
      local status = M.block(s.session_id, b.block_id, "program_status")
      local title = M.block(s.session_id, b.block_id, "title")
      for _, r in ipairs((status and status.records) or {}) do
        rows[#rows + 1] = {
          session_id = s.session_id, session = s.label or s.session_id,
          block_id = b.block_id, block = b.label, window_id = b.window_id,
          term_title = title and title.title or nil, record = r,
        }
      end
    end
  end
  M.sort(rows)
  return rows
end

function M.sort(rows)
  table.sort(rows, function(a, b)
    local ra, rb = M.RANK[a.record.state] or 9, M.RANK[b.record.state] or 9
    if ra ~= rb then return ra < rb end
    return (a.record.updated_at or "") < (b.record.updated_at or "")
  end)
end

-- The agent that has waited longest in the most urgent state, skipping
-- `working` and `idle`, which need nobody.
function M.most_urgent(rows)
  for _, row in ipairs(rows) do
    if (M.RANK[row.record.state] or 9) <= M.RANK.done then return row end
  end
end

-- Ghostty theme files ------------------------------------------------------------

local HOME = os.getenv("HOME")
M.GHOSTTY_THEME_DIRS = {
  HOME .. "/.config/ghostty/themes",
  "/Applications/Ghostty.app/Contents/Resources/ghostty/themes",
}

local function read_lines(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local lines = {}
  for line in f:lines() do lines[#lines + 1] = line end
  f:close()
  return lines
end

local function parse_ghostty(lines, into)
  for _, line in ipairs(lines) do
    local k, v = line:match("^%s*([%w%-]+)%s*=%s*(.-)%s*$")
    if k == "palette" then
      local i, c = v:match("^(%d+)%s*=%s*(#?%x+)$")
      if i then into.palette[tonumber(i)] = c end
    elseif k then
      into[k] = v
    end
  end
  return into
end

-- Resolve the theme the Ghostty include selects, then layer the include's own
-- overrides (background, foreground) on top, exactly as Ghostty does.
function M.ghostty_theme(include)
  include = include or (HOME .. "/.config/ghostty/auto/theme.ghostty")
  local inc = read_lines(include)
  if not inc then return nil, "no ghostty include at " .. include end
  local overrides = parse_ghostty(inc, { palette = {} })
  local name = overrides.theme
  if not name then return nil, "the include names no theme" end
  for _, dir in ipairs(M.GHOSTTY_THEME_DIRS) do
    local lines = read_lines(dir .. "/" .. name)
    if lines then
      local t = parse_ghostty(lines, { palette = {} })
      for k, v in pairs(overrides) do if k ~= "palette" and k ~= "theme" then t[k] = v end end
      for i, c in pairs(overrides.palette) do t.palette[i] = c end
      t.name = name
      return t
    end
  end
  return nil, "theme file not found: " .. name
end

local function luminance(hex)
  local r, g, b = hex:match("#?(%x%x)(%x%x)(%x%x)")
  if not r then return 0 end
  return (0.2126 * tonumber(r, 16) + 0.7152 * tonumber(g, 16) + 0.0722 * tonumber(b, 16)) / 255
end

-- Ghostty theme -> the args of com.superlogical.terminal.set_theme.
function M.set_theme_args(t)
  local palette = {}
  for i = 0, 255 do
    if t.palette[i] then palette[#palette + 1] = i .. "=" .. t.palette[i] end
  end
  return {
    foreground = t.foreground, background = t.background,
    cursor = t["cursor-color"], palette = palette,
    scheme = luminance(t.background or "#000000") > 0.5 and "light" or "dark",
  }
end

-- set_theme sets the server's idea of each terminal's default colours: what a
-- program's OSC 10/11/4 query and the light/dark report answer. Whether the
-- app also paints with it is an open question in ~/dotfiles/rex/README.md.
function M.apply_theme(include)
  local theme, err = M.ghostty_theme(include)
  if not theme then error(err) end
  local args = M.set_theme_args(theme)
  local applied, failed = 0, {}
  for _, s in ipairs(M.sessions()) do
    for _, b in ipairs(M.terminals(s.session_id)) do
      local ok, e = M.block(s.session_id, b.block_id, "set_theme", args)
      if ok then applied = applied + 1 else failed[#failed + 1] = (s.label or "?") .. ": " .. tostring(e) end
    end
  end
  return { theme = theme.name, scheme = args.scheme, background = args.background, terminals = applied, failed = failed }
end

return M
