-- rex-lab-actions.lua: press the lab's actions on a scratch server as a key
-- would (client.action, origin = "key") and check what each did to the server
-- and what it queued for the app. test-rex-lab.sh runs it with `rex do` and
-- reads its lines: "  ok   NAME", "  FAIL NAME  -- DETAIL", then RESULT.
--
-- Every pane it opens runs a command with login = false. A pane with no
-- command is the account's real login shell under the real HOME, whose
-- rex.zsh reaches the live server. So `window_new_here`, which starts one, is
-- not pressed here, and `scratch` is pressed with a stand-in command.
local SHELL = "com.superlogical.terminal.shell"
local OSC = string.char(27) .. "]7501;state=blocked:kind=permission:id=claude:app=claude" .. string.char(27) .. "\\"
local function blk(label, cmd)
  return { block = { flavor = SHELL, label = label, options = { command = cmd or { "/bin/sleep", "3600" }, login = false, cwd = "/tmp" } } }
end
local function must(m, p) local r, e = rex.call(m, p); if r == nil then error(m .. ": " .. tostring(e)) end; return r end
local pass, fail = 0, 0
local function ok(name, cond, detail)
  if cond then pass = pass + 1 else fail = fail + 1 end
  print((cond and "  ok   " or "  FAIL ") .. name .. (cond and "" or ("  -- " .. tostring(detail))))
end
local function dump(v, d)
  d = d or 0
  if type(v) ~= "table" or d > 5 then return tostring(v) end
  local parts = {}
  for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. dump(x, d + 1) end
  table.sort(parts)
  return "{" .. table.concat(parts, ",") .. "}"
end

local S = must("session.create", { label = "smoke" }).session_id
must("session.attach", { session_id = S })
local w1 = must("session.new_window", { session_id = S, layout = { split = { direction = "horizontal", before = blk("a"), after = blk("b") } } })
local w2 = must("session.new_window", { session_id = S, layout = blk("c") })
local w3 = must("session.new_window", { session_id = S, layout = blk("agent", { "/bin/sh", "-c", "printf '%s' \"$1\"; exec sleep 3600", "sh", OSC }) })
local A, B, C, AG = w1.block_ids[1], w1.block_ids[2], w2.block_ids[1], w3.block_ids[1]
-- The server's active window is tab 2 while keys are pressed in tab 1: what a
-- second app looking at another tab, or a script, leaves behind.
must("session.focus_window", { session_id = S, window_id = w2.window_id })

local function press(action, block, args)
  local t = os.clock()
  local r, e = rex.call("client.action", { action = action, origin = "key", session_id = S, block_id = block, args = args })
  return (r and r.result) or {}, (r and r.client_actions) or {}, e, (os.clock() - t) * 1000
end
local function window_of(block)
  for _, b in ipairs(must("session.list_blocks", { session_id = S }).blocks) do
    if b.block_id == block then return b.window_id, b.label end
  end
end
local function steps(q) local out = {}; for _, s in ipairs(q) do out[#out + 1] = s.action end; return table.concat(out, ",") end

local r, q, e
r, q = press("nav", A, { direction = "right" });  ok("nav right from a queues pane.focus", steps(q) == "pane.focus", dump(q))
r, q = press("nav", A, { direction = "left" });   ok("nav left at the edge queues nothing", #q == 0 and r.moved == false, dump(q))
r, q = press("nav", B, { direction = "right" });  ok("nav right at the right edge passes ctrl+l", steps(q) == "pane.send_key", dump(q))
r, q = press("window_goto", A, { index = 3 });    ok("window_goto 3 from tab 1 steps twice", steps(q) == "client.tab.next,client.tab.next", dump(q))
r, q = press("window_cycle", A, { step = -1 });   ok("window_cycle -1 from tab 1 wraps to tab 3", steps(q) == "client.tab.next,client.tab.next", dump(q))
r, q = press("window_goto", A, { index = 9 });    ok("window_goto past the last tab moves nothing", r.moved == false and #q == 0, dump(r))
r, q = press("clear_all", A, {});                 ok("clear_all clears and queues ctrl+l", r.cleared == A and steps(q) == "pane.send_key", dump(r))
r, q = press("copy_path", A, {});                 ok("copy_path copies the pane's directory", r.copied == "/tmp" or r.copied == "/private/tmp", dump(r))

-- A pane whose front process reported a directory (OSC 7, as rex-agent does
-- for Claude Code) works there, not where the process sits; a report whose
-- process is no longer in front counts for nothing. The reporters sit in
-- /tmp and report /usr/lib, one character percent-encoded.
local function proc_cwd(block)
  local p = block and rex.block.call("com.superlogical.terminal", "process", { session_id = S, block_id = block, args = {} })
  return p and (p.foreground or p.child or {}).cwd
end
local OSC7 = string.char(27) .. "]7;file://h/usr/%6Cib" .. string.char(27) .. "\\"
local w4 = must("session.new_window", { session_id = S, layout = { split = { direction = "horizontal",
  before = blk("reporter", { "/bin/sh", "-c", "printf '%s' \"$1\"; /bin/sleep 3600; :", "sh", OSC7 }),
  after = blk("stale", { "/bin/sh", "-c", "printf '%s' \"$1\"; exec /bin/sleep 3600", "sh", OSC7 }) } } })
must("session.focus_window", { session_id = S, window_id = w2.window_id })
local REP, STALE = w4.block_ids[1], w4.block_ids[2]
rex.sleep(0.3)
r = press("copy_path", REP, {});    ok("copy_path copies the directory the front process reported", r.copied == "/usr/lib", dump(r))
r = press("copy_path", STALE, {});  ok("copy_path ignores a report from a process no longer in front", r.copied == "/tmp" or r.copied == "/private/tmp", dump(r))
r, q, e = press("split_here", REP, { direction = "right", command = { "/bin/sleep", "3600" } })
ok("split_here opens in the pressed pane's tab, in the reported directory", r.opened ~= nil
  and window_of(r.opened) == w4.window_id and proc_cwd(r.opened) == "/usr/lib", e or (dump(r) .. " cwd " .. tostring(proc_cwd(r.opened))))
if r.opened then rex.call("block.close", { session_id = S, block_id = r.opened }) end
r, q, e = press("split_here", A, { direction = "down", command = { "/bin/sleep", "3600" } })
local acwd = proc_cwd(r.opened)
ok("split_here down from a plain pane opens beside it, in its directory", r.opened ~= nil
  and window_of(r.opened) == w1.window_id and (acwd == "/tmp" or acwd == "/private/tmp"), e or (dump(r) .. " cwd " .. tostring(acwd)))
if r.opened then rex.call("block.close", { session_id = S, block_id = r.opened }) end
must("session.close_window", { session_id = S, window_id = w4.window_id })

-- Splits land beside the pane the key was pressed in, whatever tab is active.
for _, case in ipairs({ { "urls", "urls" } }) do
  r, q, e = press(case[1], A, {})
  local win, label = window_of(r.opened)
  ok(case[1] .. " opens its split in the pressed pane's tab", win == w1.window_id and label == case[2], e or ("landed in " .. tostring(win == w2.window_id and "the ACTIVE tab instead" or win)))
  if r.opened then rex.call("block.close", { session_id = S, block_id = r.opened }) end
end
r, q, e = press("steps_sidecar", A, {})
ok("steps_sidecar opens beside the pressed pane", window_of(r.block) == w1.window_id, e or "landed in another tab")
local side = r.block
r = press("steps_sidecar", A, {})
ok("steps_sidecar again closes it", r.closed ~= nil and window_of(side) == nil, dump(r))
if side then rex.call("block.close", { session_id = S, block_id = side }) end

-- The floating status chip: a layer in the pressed pane's tab, placed inside
-- the window, and the same key takes it away.
local function layer_of(label)
  for _, w in ipairs(must("session.view", { session_id = S }).windows) do
    for _, layer in ipairs(w.layers or {}) do
      for _, b in ipairs(layer.blocks or {}) do
        if b.label == label then return w.window_id, layer.kind, layer.bounds end
      end
    end
  end
end
local chip = "chip·" .. A:sub(-6)
r, q, e = press("chip_toggle", A, {})
local cw, kind, bounds = layer_of(chip)
ok("chip_toggle floats the chip in the pressed pane's tab", r.opened == chip and cw == w1.window_id and kind == "floating", e or dump(r))
ok("chip_toggle keeps the chip inside the window", bounds ~= nil and bounds[1] >= 0 and bounds[2] >= 0
  and bounds[1] + bounds[3] <= 1.0001 and bounds[2] + bounds[4] <= 1.0001, dump(bounds))
r = press("chip_toggle", A, {})
ok("chip_toggle again closes it", r.closed == chip and layer_of(chip) == nil, dump(r))

-- The scratch float: a layer in the pressed pane's tab, in its directory;
-- pressed inside, it hides; pressed from the pane, it comes back focused.
-- The stand-in is no shell, so it counts as busy and is never replaced.
local function scratch_layer()
  for _, w in ipairs(must("session.view", { session_id = S }).windows) do
    for _, layer in ipairs(w.layers or {}) do
      for _, b in ipairs(layer.blocks or {}) do
        if b.label == "scratch" then return w.window_id, layer, b.block_id end
      end
    end
  end
end
local SLEEP = { command = { "/bin/sleep", "3600" } }
r, q, e = press("scratch", A, SLEEP)
local sw, sl, sb = scratch_layer()
ok("scratch floats a shell in the pressed pane's tab", sb ~= nil and r.opened == sb and sw == w1.window_id
  and sl.kind ~= "tiled" and sl.state ~= "minimized", e or dump(r))
ok("scratch floats it centred, three quarters of the tab", sl and sl.bounds and sl.bounds[1] == 0.125
  and sl.bounds[2] == 0.125 and sl.bounds[3] == 0.75 and sl.bounds[4] == 0.75, dump(sl and sl.bounds))
local proc = sb and rex.block.call("com.superlogical.terminal", "process", { session_id = S, block_id = sb, args = {} })
local scwd = proc and (proc.foreground or proc.child or {}).cwd
ok("scratch starts in the pane's directory", scwd == "/tmp" or scwd == "/private/tmp", dump(proc))
r = press("scratch", sb, SLEEP)
sw, sl = scratch_layer()
ok("scratch pressed inside the float hides it", r.hidden == sb and sl and sl.state == "minimized", dump(r))
r = press("scratch", A, SLEEP)
sw, sl = scratch_layer()
ok("scratch from the pane brings the same float back", r.shown == sb and sl and sl.state ~= "minimized", dump(r))
if sb then rex.call("block.close", { session_id = S, block_id = sb }) end
ok("closing the float's block removes its layer", scratch_layer() == nil, "layer stayed")
-- A float whose shell sits idle in another directory is replaced from a pane
-- elsewhere; in its own session, so the tabs above keep their panes.
local fs = must("session.create", { label = "float" }).session_id
must("session.attach", { session_id = fs })
local root = blk("root"); root.block.options.cwd = "/"
local fw = must("session.new_window", { session_id = fs, layout = { split = { direction = "horizontal", before = blk("x"), after = root } } })
local function fpress(block, args)
  local res = rex.call("client.action", { action = "scratch", origin = "key", session_id = fs, block_id = block, args = args })
  return (res and res.result) or {}
end
local first = fpress(fw.block_ids[1], { command = { "/bin/sh" } }).opened
rex.sleep(0.3)
r = fpress(fw.block_ids[2], { command = { "/bin/sh" } })
ok("scratch replaces an idle float in another directory", first ~= nil and r.replaced == first and r.opened ~= first, dump(r))
rex.call("session.destroy", { session_id = fs })

r = press("pane_push", A, { direction = "right" }); ok("pane_push right swaps with the neighbour", r.swapped == B, dump(r))
r = press("layout_toggle", A, {});                  ok("layout_toggle stacks a side-by-side tab", r.layout == "stacked", dump(r))
r = press("layout_toggle", A, {});                  ok("layout_toggle again puts it side by side", r.layout == "side by side", dump(r))
r, q = press("pane_hold", A, {});                   ok("pane_hold holds and leaves pane mode", r.held == A and steps(q) == "client.mode.exit", dump(r))
r = press("pane_put", C, {});                       ok("pane_put moves the held pane to the other tab", r.put == A and window_of(A) == w2.window_id, dump(r))

-- Pane mode w asks in the command palette. No app is connected here, so the
-- question comes back unanswered and the action ends cancelled, moving
-- nothing; given window_id, as the answer, it moves the pane into that tab
-- and shows it, leaving pane mode on.
r, q, e = press("pane_pick", B, {})
ok("pane_pick with no app to ask moves nothing", r.cancelled == true and window_of(B) == w1.window_id and #q == 0, e or dump(r))
r, q = press("pane_pick", B, { window_id = w2.window_id })
local active = must("session.view", { session_id = S }).active_window_id
ok("pane_pick moves the pane to the picked tab and shows it",
  r.placed == B and window_of(B) == w2.window_id and active == w2.window_id and #q == 0, dump(r))
r, q = press("pane_pick", B, { window_id = w2.window_id })
ok("pane_pick into the pane's own tab moves nothing", r.reason == "same tab" and #q == 0, dump(r))
local lone = must("session.create", { label = "lone" }).session_id
must("session.attach", { session_id = lone })
local lw = must("session.new_window", { session_id = lone, layout = blk("solo") })
r, e = rex.call("client.action", { action = "pane_pick", origin = "key", session_id = lone, block_id = lw.block_ids[1] })
ok("pane_pick in a one-tab session refuses, saying why", r == nil and tostring(e):find("no other tab", 1, true) ~= nil, dump(r) .. " " .. tostring(e))
rex.call("session.destroy", { session_id = lone })

-- prefix M asks too; given label, it names the pane, and an empty name is "shell".
r, q, e = press("label_pane", C, {})
ok("label_pane with no app to ask renames nothing", r.cancelled == true and select(2, window_of(C)) == "c", e or dump(r))
r = press("label_pane", C, { label = "  build  " })
ok("label_pane names the pane, trimmed", r.renamed == "build" and select(2, window_of(C)) == "build", dump(r))
r = press("label_pane", C, { label = "" })
ok("label_pane with an empty name gives it shell", select(2, window_of(C)) == "shell", dump(r))

-- ctrl+v: the app's paste, unless the pane's Neovim left its file (the
-- nvim config writes it while it runs); then the key goes to Neovim.
local mark = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/rex-lab/nvim/" .. A:gsub(":", "_")
r, q = press("paste", A, {})
ok("paste without Neovim is the app's paste", r.pasted == true and steps(q) == "pane.paste", dump(q))
rex.exec({ "/bin/mkdir", "-p", (mark:gsub("/[^/]+$", "")) })
local f = io.open(mark, "w")
if f then f:write("1\n"); f:close() end
r, q = press("paste", A, {})
ok("paste with Neovim in front passes ctrl+v to it", f ~= nil and r.passed == "nvim" and steps(q) == "pane.send_key", dump(q))
os.remove(mark)

-- prefix S-Tab: back to the session focus was last in, from the server's
-- focus history; in a session with no other to go back to, nothing.
local back = must("session.create", { label = "back" }).session_id
must("session.attach", { session_id = back })
local bw = must("session.new_window", { session_id = back, layout = blk("other") })
must("session.focus_block", { session_id = back, block_id = bw.block_ids[1] })
must("session.focus_block", { session_id = S, block_id = A })
r, q = press("session_back", A, {})
ok("session_back goes to the session focus was in before", r.moved == back and steps(q) == "session.select", dump(r) .. " " .. dump(q))
rex.call("session.destroy", { session_id = back })

-- prefix Tab: back to the tab of this session focus was last in, from the
-- server's focus history, never to another session's. A session of its own,
-- since the cases above move panes between S's tabs; each focus_block changes
-- the tab, as one that changes nothing is not history.
local ts = must("session.create", { label = "tabs" }).session_id
must("session.attach", { session_id = ts })
local t1 = must("session.new_window", { session_id = ts, layout = blk("t1") })
local t2 = must("session.new_window", { session_id = ts, layout = blk("t2") })
local t3 = must("session.new_window", { session_id = ts, layout = blk("t3") })
local T1, T2, T3 = t1.block_ids[1], t2.block_ids[1], t3.block_ids[1]
local function press_in(block)
  local x = rex.call("client.action", { action = "tab_back", origin = "key", session_id = ts, block_id = block, args = {} })
  return (x and x.result) or {}, (x and x.client_actions) or {}
end
must("session.focus_block", { session_id = ts, block_id = T3 })
must("session.focus_block", { session_id = ts, block_id = T2 })
must("session.focus_block", { session_id = ts, block_id = T1 })
r, q = press_in(T1)
ok("tab_back goes to the tab focus was in before", r.moved == t2.window_id and steps(q) == "session.select", dump(r) .. " " .. dump(q))
must("session.focus_block", { session_id = S, block_id = AG })
must("session.focus_block", { session_id = ts, block_id = T2 })
r, q = press_in(T2)
ok("tab_back never leaves the session", r.moved == t1.window_id, dump(r) .. " " .. dump(q))
rex.call("session.destroy", { session_id = ts })

-- An action run with no block (rex do NAME, the palette) acts on the focused one.
local r2 = rex.call("client.action", { action = "copy_path", origin = "api", args = { session_id = S } })
ok("an action given no block finds the focused one", r2 and r2.result and r2.result.reason ~= "no focused block", dump(r2 and r2.result))

-- Timing: the hot keys, 50 presses each.
local function time(action, block, args)
  local t = os.clock()
  for _ = 1, 50 do press(action, block, args) end
  return (os.clock() - t) * 1000 / 50
end
print(string.format("  time  nav %.2f ms  window_goto %.2f ms  window_cycle %.2f ms  (per press, round trip included)",
  time("nav", B, { direction = "left" }), time("window_goto", B, { index = 2 }), time("window_cycle", B, { step = 1 })))
print(string.format("RESULT %d passed, %d failed", pass, fail))
rex.stop(fail == 0 and 0 or 1)
