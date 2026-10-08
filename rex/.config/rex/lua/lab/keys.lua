-- lab.keys: every key binding, in one place. `rex keymap` is the authority
-- on what each key does; docs/rex.md § Keys has the shape. A binding names
-- an action of lab.* (checked against its args schema when Rex resolves the
-- keymap), the app's own (pane.*, client.*, session.*), or a block method.

local function bind_all(mode, list)
  local prefix = mode and (mode .. "/") or ""
  for _, b in ipairs(list) do rex.bind(prefix .. b[1], b[2], b[3]) end
end

local HJKL = { left = "h", down = "j", up = "k", right = "l" }
local DIRECTIONS = { "left", "down", "up", "right" }

-- Without the prefix ----------------------------------------------------------------

local root = {
  -- ctrl+shift+down / up: the next or previous tab in the sidebar, crossing
  -- sessions and hosts (the laptop's and the mini's) and wrapping at the
  -- ends. The app's own actions, since only the app knows the sidebar: a
  -- server action sees one host's sessions, and the app cannot select
  -- another host's session for it.
  { "ctrl+shift+down", "client.tab.next" }, { "ctrl+shift+up", "client.tab.previous" },
  -- shift+up / shift+down slide the tab, as tmux's swap-window binding did
  -- with shift+left/right: up and down, since the tabs are a vertical list.
  { "shift+up", "client.tab.move.backward" }, { "shift+down", "client.tab.move.forward" },
  { "cmd+shift+j", "agents_next" }, { "cmd+shift+s", "steps_sidecar" }, { "cmd+shift+a", "agents_board" },
}
-- ctrl+h/j/k/l: pane focus that passes the key to nvim and fzf (lab.panes nav).
for _, dir in ipairs(DIRECTIONS) do root[#root + 1] = { "ctrl+" .. HJKL[dir], "nav", { direction = dir } } end
bind_all(nil, root)

-- Pane mode (prefix p) ------------------------------------------------------------------

rex.mode("panes", { exclusive = true })
local panes = {
  { "escape", "client.mode.exit" }, { "enter", "client.mode.exit" }, { "q", "client.mode.exit" },
  { "g", "pane_hold" }, { "p", "pane_put" }, { "shift+g", "pane_release" },
  { "b", "pane.move_to_new_tab" }, { "e", "pane.balance" }, { "z", "pane.zoom" },
}
for _, dir in ipairs(DIRECTIONS) do
  panes[#panes + 1] = { HJKL[dir], "pane_push", { direction = dir } }
  panes[#panes + 1] = { "shift+" .. HJKL[dir], "pane.resize", { direction = dir } }
  panes[#panes + 1] = { dir, "pane.focus", { direction = dir } }
end
bind_all("panes", panes)

-- The prefix --------------------------------------------------------------------------

-- The tmux prefix, as a Rex mode: ctrl+a enters it for one key, as tmux's
-- prefix does, and Escape leaves it. Exclusive, so a key it does not bind
-- does nothing rather than reach the shell. ctrl+a twice sends a literal
-- ctrl+a.
rex.mode("prefix", { exclusive = true })
rex.bind("ctrl+a", "client.mode.enter", { name = "prefix", once = true })
local prefix = {
  { "escape", "client.mode.exit" },
  { "ctrl+a", "pane.send_key", { key = "ctrl+a" } },
  -- panes
  { "shift+\\", "pane.split.right" }, { "\\", "pane.split.right" }, { "-", "pane.split.down" },
  { "h", "pane.focus.left" }, { "j", "pane.focus.down" }, { "k", "pane.focus.up" }, { "l", "pane.focus.right" },
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
  { "shift+s", "steps_sidecar" }, { "shift+a", "agents_board" }, { "a", "agents_next" },
  { "t", "client.theme.change" }, { "r", "client.config.reload" }, { "/", "client.find.open" },
}
for _, dir in ipairs(DIRECTIONS) do
  prefix[#prefix + 1] = { "shift+" .. HJKL[dir], "pane.resize", { direction = dir } }
end
for i = 1, 9 do prefix[#prefix + 1] = { tostring(i), "window_goto", { index = i } } end
bind_all("prefix", prefix)
