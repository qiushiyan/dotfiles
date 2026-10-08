# Rex lab

Rex is Superlogical's multiplexer (private beta, macOS app `Rex Beta.app`,
CLI build `c50b257`). This package is an experiment in what Rex makes possible
for agent work, not a port of the tmux setup. tmux stays the daily driver; this
file is the notebook: what is here, what we learned, what is still open.

## What is here

| Path | Stows to | What it does |
|---|---|---|
| `.config/rex/init.lua` | `~/.config/rex/init.lua` | Actions `agents_next` (⌘⇧J), `agents_board` (⌘⇧A), `theme_sync` |
| `.config/rex/lua/rexkit.lua` | same | Shared helpers: calls, sessions, agent records, Ghostty theme parsing |
| `.config/rex/scripts/board.lua` | same | Live agents board, event-driven |
| `.config/rex/scripts/theme.lua` | same | Push the current terminal theme to every Rex terminal |
| `.local/bin/rex` | `~/.local/bin/rex` | The app's bundled CLI on PATH (Stow refuses absolute symlinks, so a wrapper) |
| `.local/bin/rex-agent` | same | Publish agent state over OSC 7501; the Claude hooks call `rex-agent claude` |
| `.local/bin/rex-board` | same | Run the board here, or `--popup` in a floating layer |
| `.local/bin/rex-theme` | same | Called by `theme-set`; silent without a Rex server |

`~/.config/rex` is a real directory (Makefile `REAL_DIRS`, `.gitignore`
allow-list): Rex writes its own files there (`rex terminfo setup` adds
`ssh_config` and `terminfo-hosts`). Both machines stow it: the laptop takes
every package, and the mini lists it in `twin.toml`.

Wiring outside the package: `claude/.claude/settings.json` runs
`rex-agent claude` on SessionStart, UserPromptSubmit, PostToolUse,
Notification, Stop and SessionEnd, guarded by `$REX_BLOCK` so it is a no-op
outside Rex; `theme-set` step 6 calls `rex-theme`.

## Try it

1. In Rex, run a Claude session in two or three windows. Each publishes
   `idle → working → done`, `blocked` on a permission prompt, `clear` on exit.
   A Rex terminal does not inherit the account choice: launch with the `x*`
   launchers, or set `CLAUDE_CONFIG_DIR`.
2. ⌘⇧A opens the board over the current window; any key closes it.
   `rex-board` runs it in a pane.
3. ⌘⇧J jumps to the agent that has waited longest in the most urgent state.
4. `prefix t` (or `theme-set NAME`) now also recolours Rex terminals.

Turning on **Remote Control** (Rex Settings → Rex Server) lets the CLI drive
the app as well: `rex-theme` then switches the app's own theme, and
`rex do agents_next` can switch the app's session from outside.

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

- The app owns its look: a light/dark pair of named themes, plus custom themes
  imported from Ghostty or iTerm files (our `ghostty/.config/ghostty/themes/*`
  are importable as they are). Its Ghostty migration only looks in
  `~/Library/Application Support/com.mitchellh.ghostty/config`, not our XDG
  `~/.config/ghostty/config`.
- `client.theme.change name=…` fuzzy-matches a theme name or ID; it needs
  Remote Control when sent from outside the app.
- The server keeps each terminal's default colours (`set_theme`, or `theme` in
  a block's creation options): what programs see when they query colours, and
  the light/dark report. Palette entries are `"N=#rrggbb"`; `scheme` is
  `light` or `dark`. `rex-theme` sets all of it from our Ghostty theme files.

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

- Does the app paint with the server-side colours `set_theme` sets, or only
  with its own theme? Check visually: after `rex-theme`, Rex terminals should
  show TokyoNight Moon while the app theme is still Merino.
- What `ctx` an action gets from a key press (session? block? client?).
  `agents_next` logs `ctx.origin`; the board popup falls back to the first
  session when `ctx` names none.
- Does the app surface OSC 7501 records itself (sidebar badges,
  notifications)? If so the board is a second view, not the only one.
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
