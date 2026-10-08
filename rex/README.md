# Rex lab

Rex is Superlogical's multiplexer (private beta, macOS app `Rex Beta.app`,
CLI build `c50b257`). This package is an experiment in what Rex makes possible
for agent work, not a port of the tmux setup. tmux stays the daily driver; this
file is the notebook: what is here, what we learned, what is still open.

## What is here

| Path | Stows to | What it does |
|---|---|---|
| `.config/rex/init.lua` | `~/.config/rex/init.lua` | Actions `agents_next` (⌘⇧J) and `agents_board` (⌘⇧A) |
| `.config/rex/lua/rexkit.lua` | same | Shared helpers: calls, sessions, agent records |
| `.config/rex/scripts/board.lua` | same | Live agents board, event-driven |
| `.local/bin/rex` | `~/.local/bin/rex` | The app's bundled CLI on PATH (Stow refuses absolute symlinks, so a wrapper) |
| `.local/bin/rex-agent` | same | Publish agent state over OSC 7501; the Claude hooks call `rex-agent claude` |
| `.local/bin/rex-board` | same | Run the board here, or `--popup` in a floating layer |
| `.local/bin/rex-theme` | same | Called by `theme-set`: switches the app's theme by name; silent without a Rex server |

`~/.config/rex` is a real directory (Makefile `REAL_DIRS`, `.gitignore`
allow-list): Rex writes its own files there (`rex terminfo setup` adds
`ssh_config` and `terminfo-hosts`). Both machines stow it: the laptop takes
every package, and the mini lists it in `twin.toml`.

Wiring outside the package: `claude/.claude/settings.json` runs
`rex-agent claude` on SessionStart, UserPromptSubmit, PostToolUse,
Notification, Stop and SessionEnd, guarded by `$REX_BLOCK` so it is a no-op
outside Rex; `theme-set` step 6 calls `rex-theme`.

## Try it

1. Turn on **Show status badges** (Rex Settings, tab options): the app then
   draws a dot on a tab whose program reports a status. Without an agent,
   `rex-agent blocked --kind permission --app demo --title demo --msg hi` in
   a Rex tab shows one; `rex-agent clear` removes it.
2. In Rex, run a Claude session in two or three windows. Each publishes
   `idle → working → done`, `blocked` on a permission prompt, `clear` on exit.
   A Rex terminal does not inherit the account choice: launch with the `x*`
   launchers, or set `CLAUDE_CONFIG_DIR`.
3. ⌘⇧A opens the board over the current window; any key closes it.
   `rex-board` runs it in a pane.
4. ⌘⇧J jumps to the agent that has waited longest in the most urgent state.
5. `prefix t` (or `theme-set NAME`) also switches Rex's theme, once Remote
   Control is on and the theme is imported (Themes below).

Turning on **Remote Control** (Rex Settings → Rex Server) lets the CLI drive
the app: `rex-theme` needs it, and so does `rex do agents_next` run from
outside the app.

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
  hears, not what it may call.
- Block methods: `rex.call("com.superlogical.terminal.<method>",
  {session_id=, block_id=, args={}})`.
- `rex.action{ name=, title=, run=function(ctx, args) … end }`; `ctx.origin`
  is `api` from `rex do`. Try one before reloading with
  `rex do ~/.config/rex/init.lua --action NAME k=v`.
- `rex.bind("cmd+shift+j", "action")` takes one chord (no tmux-style
  sequences); a mode's keys are bound as `"mode/key"`, and only to named
  actions.
- `rex.client.queue(action, args)` asks the client that pressed the key to
  perform a client action (`session.select`, `pane.split`, …).
- `rex.on("block_event", fn(target, ev))` fires for `program_status_changed`,
  `title_changed`, `bell` across sessions; `ev.name` says which. Specific
  names (`program_status_changed`) register but never fire. Handlers only work
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
  `~/.config/ghostty/config`. Imports are stored in the app's defaults
  (`Workspace.customThemes`).
- `client.theme.change name=…` fuzzy-matches a theme name or ID, and needs
  Remote Control from outside the app. `rex-theme` passes the Ghostty theme
  name theme-set chose.

### Status badges

- The app draws OSC 7501 statuses itself: "Show status badges" puts a dot on
  the tab, and its strings include "Waiting for permission" and "Waiting for an
  answer", the `permission` and `question` kinds
  (`Workspace.showsProgramStatusInTabs`). The board is a second view across
  sessions, not the only one.

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

## Open questions

- The format of `Workspace.customThemes`, so all our themes can be generated
  in one go instead of imported by hand.
- What `ctx` an action gets from a key press (session? block? client?).
  `agents_next` logs `ctx.origin`; the board popup falls back to the first
  session when `ctx` names none.
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
