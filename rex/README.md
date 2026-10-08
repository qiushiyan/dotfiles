# Rex lab

Rex is Superlogical's multiplexer (private beta, macOS app `Rex Beta.app`,
CLI build `c50b257`). This package is an experiment in what Rex makes possible
for agent work, not a port of the tmux setup. tmux stays the daily driver; this
file is the notebook: what is here, what we learned, what is still open.

## What is here

| Path | Stows to | What it does |
|---|---|---|
| `.config/rex/init.lua` | `~/.config/rex/init.lua` | The `ctrl+a` prefix mode (Keys below) and the actions it reaches: agents, steps, copy path, gopen, worktrees |
| `.config/rex/lua/rexkit.lua` | same | Shared helpers: calls, sessions, agent records, a block's Claude session |
| `.config/rex/scripts/board.lua` | same | Live agents board, event-driven; each Claude's claude-steps title and branch under its row |
| `.config/rex/scripts/rexd.lua` | same | The background watcher: numbers every session's tabs |
| `.config/rex/scripts/steps.lua` | same | The steps sidecar: `claude-steps show` for one agent, redrawn when it reports |
| `.local/bin/rex` | `~/.local/bin/rex` | The app's bundled CLI on PATH (Stow refuses absolute symlinks, so a wrapper) |
| `.local/bin/rex-agent` | same | Publish agent state over OSC 7501; the Claude hooks call `rex-agent claude` |
| `.local/bin/rex-board` | same | Run the board here, or `--popup` in a floating layer |
| `.local/bin/rex-demo` | same | A demo session: board, three simulated agents, a real Claude with its steps sidecar |
| `.local/bin/rex-steps` | same | Open a steps sidecar beside this terminal (or a named block) |
| `.local/bin/rex-worktree` | same | The worktree picker `prefix W` opens: go to a worktree's tab, or open it with Claude and its steps |
| `.local/bin/rex-toast` | same | A snacks-style toast at the top right of a window; the actions use it, and so can any script in Rex |
| `.local/bin/rexd` | same | Keeps `rexd.lua` running in a detached block; a Rex shell starts it |
| `.local/bin/rex-theme` | same | Called by `theme-set`: switches the app's theme by name; silent without a Rex server |

`~/.config/rex` is a real directory (Makefile `REAL_DIRS`, `.gitignore`
allow-list): Rex writes its own files there (`rex terminfo setup` adds
`ssh_config` and `terminfo-hosts`). Both machines stow it: the laptop takes
every package, and the mini lists it in `twin.toml`.

Wiring outside the package: `zsh/.config/zsh/rex.zsh` runs `rexd` when an
interactive shell starts inside Rex; `claude/.claude/settings.json` runs
`rex-agent claude` on SessionStart, UserPromptSubmit, PostToolUse,
Notification, Stop and SessionEnd, guarded by `$REX_BLOCK` so it is a no-op
outside Rex; `theme-set` step 6 calls `rex-theme`.

## Try it

`rex-demo` builds an `agents-demo` session: a board window, three simulated
agents that work, stop for permission (press `y` in their tab) and finish,
publishing each state, and a real Claude (started with `x` in this
repository, idle until you type) with its steps sidecar. `rex-demo stop`
removes it. With your own agents:

1. Turn on **Show status badges** (Rex Settings, tab options): the app then
   draws a dot on a tab whose program reports a status. Without an agent,
   `rex-agent blocked --kind permission --app demo --title demo --msg hi` in
   a Rex tab shows one; `rex-agent clear` removes it.
2. In Rex, run a Claude session in two or three windows. Each publishes
   `idle → working → done`, `blocked` on a permission prompt, `clear` on exit.
   A Rex terminal does not inherit the account choice: launch with the `x*`
   launchers, or set `CLAUDE_CONFIG_DIR`.
3. ⌘⇧A opens the board over the current window; ⌘⇧A again closes it.
   `rex-board` runs it in a pane.
4. ⌘⇧J jumps to the agent that has waited longest in the most urgent state.
5. ⌘⇧S in a Claude's terminal opens its steps sidecar, ⌘⇧S again closes it;
   `rex-steps` does the same from the shell.
6. tmux's `prefix t` (or `theme-set NAME`) also switches Rex's theme, once Remote
   Control is on and the theme is imported (Themes below).

Turning on **Remote Control** (Rex Settings → Rex Server) lets the CLI drive
the app: `rex-theme` needs it, and so does `rex do agents_next` run from
outside the app.

## Keys

`ctrl+a` enters the `prefix` mode for one key, as tmux's prefix does;
`escape` leaves it, `ctrl+a` again sends a literal `ctrl+a`, and a key the
mode does not bind does nothing. `rex keymap` lists the whole map.

| Key | Does | |
|---|---|---|
| `\|` `\` / `-` | split right / down | app |
| `h j k l` / `H J K L` | focus / resize | app |
| `z` `X` `space` `b` | zoom, close pane, balance, pane to its own tab | app |
| `c` `n` `p` `x` `m` `1`–`9` | new, next, previous, close, rename tab; go to tab | app |
| `T` `(` `)` | pick a session; previous / next session | app |
| `y` / `Y` | copy the file nvim has open (absolute / relative), else the pane's directory | `copy_path` |
| `g` | open the pane's repo on GitHub (gopen) | `gopen` |
| `W` | worktree picker in a split: enter goes to the worktree's tab or opens one; ctrl-x opens it with Claude and its steps; a new name creates the branch (gwt) | `worktrees` |
| `S` `A` `J` | steps sidecar, agents board, jump to the agent that needs you (also ⌘⇧S, ⌘⇧A, ⌘⇧J) | ours |
| `t` `r` `/` | theme picker, reload config, find | app |

Tabs are numbered: `rexd` labels every window `<position> <name>` and keeps
the numbers right as tabs open, close and move, so `prefix 1`–`9` goes where
the vertical list says. A name is set once and kept, as tmux's were: the one
you give (`prefix m`), else the pane's label when it says something (`api`,
`claude`), else the directory the pane started in. `y`, `g` and a new
worktree confirm with a toast at the top right.

The actions take `session_id=` and `block_id=` too, so a script can aim them:
`rex do copy_path session_id=… block_id=… rel=true`.

## Findings

### Where the API is

- The server serves its own reference: `GET /llms.txt` (and `/llms.html`,
  `/api/help`) on its socket:
  `curl --unix-socket ~/Library/Application\ Support/rex/server.sock http://rex/llms.txt`.
  It covers the wire API (67 methods, the terminal block's methods,
  WebSocket control protocol), not the Lua API.
- `rex api list`, `rex api describe METHOD`, `rex actions`, `rex -C CLIENT
  actions --json` (client actions with schemas) and `rex config check` cover
  the rest. Lua names were mapped by experiment; what follows is the result.
- Every terminal gets `REX_SESSION`, `REX_BLOCK`, `REX_SERVER`,
  `TERM_PROGRAM=rex`: a program can find itself, as with `$TMUX_PANE`.

### Lua (init.lua and `rex do`)

- Lua 5.1 with full `io`, `os`, `require`; `package.path` can point at
  `~/.config/rex/lua`.
- `rex.call(method, payload)` returns `nil, message` on failure; it does not
  raise. A connection must `rex.call("session.attach", {session_id=…})` before
  calling into a session; `rex.session.attach` changes which events a script
  hears, not what it may call. init.lua's Lua state outlives the connection
  an action runs on, so a remembered attach goes stale: `rexkit` attaches
  again when a call is refused as not attached.
- Actions, and panes the server starts, get the server's bare PATH
  (`/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`); `rexkit.PATH` and
  `rex-worktree` set their own.
- Block methods: `rex.call("com.superlogical.terminal.<method>",
  {session_id=, block_id=, args={}})`.
- `rex.action{ name=, title=, run=function(ctx, args) … end }`. A key press
  gives `ctx = {origin = "key", session_id, block_id, client_id}`: the
  session and block it was pressed in. From `rex do`, `ctx.origin` is `api`
  and nothing else, so the actions fall back to the first session. Each
  action appends its ctx to `~/.local/state/rex-lab/ctx.log`. Try one before reloading with
  `rex do ~/.config/rex/init.lua --action NAME k=v`.
- `rex.bind(key, action, args)` takes one chord (no tmux-style sequences)
  and an optional args table. A mode is declared with `rex.mode(name,
  {exclusive=, blocked=})` and its keys bound as `"mode/key"`, only to named
  actions; `client.mode.enter {name=, once=true}` makes a tmux-style prefix.
  The client keeps the mode, the server only checks the map. Key names:
  letters, digits, `-`, `/`, `space`, `tab`, `escape`, `\\` (backslash),
  `shift+\\` (`|`), `shift+9`; not `|`, `(`, `%`, `minus` or `backslash`.
  The app's actions say which repeat (`repeats` in `rex -C … actions
  --json`): focus, resize, tab next/previous.
- `rex.client.queue(action, args)` asks the client that pressed the key to
  perform a client action (`session.select`, `pane.split`, …).
- `rex.on("block_event", fn(target, ev))` fires for every block event across
  sessions, `ev.name` saying which: `program_status_changed`, `title_changed`,
  `bell`, `process_changed` (the foreground process), `clipboard_written`,
  `desktop_notification`. A block event's own name (`program_status_changed`)
  registers but never fires. Session-level events do fire under their own
  names: `session_created`, `session_destroyed`, `window_created`,
  `window_closed`, `window_label_changed`, `active_window_changed`,
  `session_view_changed` (any layout change, moves included). Handlers only work
  in `rex do` scripts: in init.lua they are reserved for "a later version".

### Agent status: OSC 7501, the Program Status Protocol

Rex parses it in libghostty and keeps records per block. Wire format, worked
out by experiment:

```
ESC ] 7501 ; state=S[:kind=K][:id=ID][:app=A][:progress=N][:title=B64][:msg=B64] ESC \
```

- `state`: `idle working done blocked error clear`; `kind`: `permission
  question auth`; `progress` 0–255; `title` and `msg` are base64.
- Records are keyed by `id`. A malformed report is dropped whole, silently.
- Read back: `rex block call program_status`; pushed as the block event
  `program_status_changed` with `reason` and the full record, including the
  owning process.
- The terminfo entry advertises it as `Pst`; `OSC 7501;?` is a query.
- A Claude hook's stdout is captured, so `rex-agent` writes to `/dev/tty`
  (falling back to an ancestor's tty). Verified end to end with a real
  `claude -p` inside Rex: idle → working → done → cleared.

### Themes

- The app owns Rex's colours. It pushes its theme to every terminal on the
  server, so a server-side `set_theme` is overwritten: tried, verified, and
  dropped. (`set_theme` and a block's `theme` option set what programs see
  when they query colours; palette entries are `"N=#rrggbb"`, `scheme` is
  `light` or `dark`.)
- The app's built-in themes are few (Merino, Buttercream Diner, Silver
  Point…). It knows Ghostty themes only through import: one file at a time
  (command palette, Import Theme File; ours in `ghostty/.config/ghostty/themes/`
  and Ghostty.app's bundled ones both work), or a migration that reads only
  `~/Library/Application Support/com.mitchellh.ghostty/config`, not our XDG
  `~/.config/ghostty/config`. Imports are stored in the app's defaults as
  `Workspace.customThemes`, JSON data: a list of `{id: "custom-<UUID>", name,
  appearance: "dark"|"light", createdAt, palette: {background, foreground,
  cursor, cursorText, selectionBackground, selectionForeground, ansi: [16]},
  source: {ghosttyMigration: {themeName}}}`; the dark and light picks are
  `Workspace.darkThemeID` and `Workspace.lightThemeID`. Enough to generate our
  themes rather than import them one by one.
- `client.theme.change name=…` fuzzy-matches a theme name or ID, and needs
  Remote Control from outside the app. `rex-theme` passes the Ghostty theme
  name theme-set chose.

### Status badges

- The app draws OSC 7501 statuses itself: "Show status badges" puts a dot on
  the tab, and its strings include "Waiting for permission" and "Waiting for an
  answer", the `permission` and `question` kinds
  (`Workspace.showsProgramStatusInTabs`). The board is a second view across
  sessions, not the only one.

### claude-steps in Rex

- tmux's `prefix S` is a popup you open to read a session. In Rex the steps
  live beside the agent: a sidecar split runs `claude-steps show` for that
  agent's session and redraws on its `program_status_changed` events, so it
  is current after every prompt, tool call and stop, with no polling.
- The board puts each Claude session's claude-steps title and branch under
  its row, read again only when that agent changes state.
- No `@claude_ctx_sid` is needed. The status record names the process that
  reported (`owner.pid`, Claude itself), and Claude writes
  `<config dir>/sessions/<pid>.json` with its `sessionId` and `cwd`, so block
  → session needs no extra plumbing, and /clear or /resume is followed on the
  next redraw. Claude reports SessionStart before that file exists, so the
  first lookup retries; a new session has no transcript until its first
  prompt.

### Paths and the clipboard

- `process` gives a block's child and foreground process with their `cwd`
  from the OS, right while nvim or Claude runs: tmux's `pane_current_path`.
- nvim writes the focused file's absolute and relative paths to
  `~/.local/state/rex-lab/yank/<block id>` (`config/autocmds.lua`, beside
  the tmux options it sets), and removes the file on exit or suspend.
- OSC 52 written to a block's terminal becomes a `clipboard_written` block
  event, and the app showing the session copies it: the clipboard of the
  machine you look from, with no pbcopy or toclip. An action writes it to the
  tty of the block's foreground process.

### Feedback and background work

- The app has its own floating notices but no API to post one. OSC 9 and
  OSC 777 from a terminal become `desktop_notification` block events, which
  the app presumably shows as system notifications: not the in-terminal look
  wanted here. `rex-toast` draws one instead, in a small floating layer that
  takes no focus, sized in cells from the block's grid and rect, painting its
  own background, redrawing on resize, and closing when its process exits.
- A detached block (`session.new_block`: owned by a session, placed in no
  layout) is a background process that shows nowhere: `rexd` hosts its
  watcher in one. It lives as long as its session; a Rex shell starting
  brings it back. Window labels are what `session.set_window_label` sets and
  what a tab rename changes.

### Popups, layouts, blocks

- `session.new_layer` makes a floating layer with any command:
  `layout = { block = { flavor = "com.superlogical.terminal.shell",
  options = { command = {…} } } }`. Options also take `cwd`, `initial_input`,
  `theme`, and `exit.on_completion`.
- `rex run --wait`, `rex wait`, `rex capture --format text|html|vt`, and
  `rex block call process` (child and foreground process, cwd, last exit
  code) give agents what tmux needed `send-keys` and `capture-pane` polling
  for.

### Gotchas

- The `rex` CLI probes the terminal when its stderr is one, even with
  `--color never`; the reply lands on stdin as input. A wrapper that reads keys
  must send rex's stderr elsewhere (`rex-board --popup` does).
- Client actions from the CLI (`rex -C … do client.*`, `session.select`) are
  refused until Remote Control is on; server methods are not.
- Stow will not stow an absolute symlink, hence the `rex` wrapper script.
- The app does not send keystrokes to a floating layer yet (keys sent through
  the server, `rex send`, do arrive), and draws a layer's default background
  see-through. A popup paints its own background and closes from the key that
  opened it. Closing a layer's only block removes the layer.
- Rex's Lua crashes the whole `rex do` with a Go nil-pointer error on
  `for l in (("a"):gsub("a","b") .. ""):gmatch("b") do end`; through a local
  it works. Worth reporting.

## Open questions

- What else the app does with a status (notifications? the sidebar?).
- Do sessions survive quitting the app (the server is `run-mode bundled`)?
  That decides whether resurrect-style persistence is needed at all.

## Next experiments

- Notify on `blocked` or `done` when the agent's block is not focused, from a
  long-running `rex do` watcher; clear `done` to `idle` once its block gains
  focus.
- An agent launcher action: new window, worktree from gwt, Claude started in
  it with `initial_input`, labelled for the board.
- A multi-host board: `rex.servers()` and `rex.server(label)` reach the other
  machine's Rex over Tailscale, so one board can cover the laptop and the mini.
- Agents driving Rex: `rex run --wait` plus `program_status` as a typed,
  event-driven replacement for `send-keys` polling; record lessons here.
