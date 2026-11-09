-- rex-lab-actions.lua: press the lab's actions on a scratch server as a key
-- would (client.action, origin = "key") and check what each did to the server
-- and what it queued for the app. test-rex-lab.sh runs it with `rex do` and
-- reads its lines: "  ok   NAME", "  FAIL NAME  -- DETAIL", then RESULT.
--
-- Every pane it opens runs a command with login = false. A pane with no
-- command is the account's real login shell under the real HOME, whose
-- rex.zsh reaches the live server. So `scratch` and `window_new_here`, which
-- start one, are not pressed here.
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

-- Splits land beside the pane the key was pressed in, whatever tab is active.
for _, case in ipairs({ { "label_pane", "rename" }, { "urls", "urls" }, { "worktrees", "worktrees" } }) do
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

r = press("pane_push", A, { direction = "right" }); ok("pane_push right swaps with the neighbour", r.swapped == B, dump(r))
r = press("layout_toggle", A, {});                  ok("layout_toggle stacks a side-by-side tab", r.layout == "stacked", dump(r))
r = press("layout_toggle", A, {});                  ok("layout_toggle again puts it side by side", r.layout == "side by side", dump(r))
r, q = press("pane_hold", A, {});                   ok("pane_hold holds and leaves pane mode", r.held == A and steps(q) == "client.mode.exit", dump(r))
r = press("pane_put", C, {});                       ok("pane_put moves the held pane to the other tab", r.put == A and window_of(A) == w2.window_id, dump(r))

-- Pane mode w: the picker opens below the pressed pane after leaving the
-- mode, and its enter (pane_place) moves the pane into the picked tab, shows
-- that tab, and with reenter queues pane mode again.
r, q, e = press("pane_pick", B, {})
ok("pane_pick leaves pane mode and opens the picker in the pressed pane's tab",
  steps(q) == "client.mode.exit" and select(2, window_of(r.opened)) == "move pane" and window_of(r.opened) == w1.window_id, e or dump(r))
if r.opened then rex.call("block.close", { session_id = S, block_id = r.opened }) end
r, q = press("pane_place", B, { window_id = w2.window_id, reenter = true })
local active = must("session.view", { session_id = S }).active_window_id
ok("pane_place moves the pane to the picked tab and shows it",
  r.placed == B and window_of(B) == w2.window_id and active == w2.window_id, dump(r))
ok("pane_place with reenter queues pane mode", steps(q) == "client.mode.enter", dump(q))
r, q = press("pane_place", B, { window_id = w2.window_id })
ok("pane_place into the pane's own tab moves nothing", r.reason == "same tab" and #q == 0, dump(r))
local lone = must("session.create", { label = "lone" }).session_id
must("session.attach", { session_id = lone })
local lw = must("session.new_window", { session_id = lone, layout = blk("solo") })
r, q = rex.call("client.action", { action = "pane_pick", origin = "key", session_id = lone, block_id = lw.block_ids[1] })
r, q = (r and r.result) or {}, (r and r.client_actions) or {}
ok("pane_pick in a one-tab session opens nothing and stays in the mode", r.reason == "one tab" and #q == 0, dump(r))
rex.call("session.destroy", { session_id = lone })

rex.sleep(0.3)
r, q = press("agents_next", C, {})
ok("agents_next jumps to the blocked agent", r.jumped == true and r.state == "blocked" and steps(q) == "session.select", dump(r))

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
