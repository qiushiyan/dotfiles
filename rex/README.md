# Rex lab

Rex is Superlogical's terminal multiplexer, in private beta: a long-lived
server that owns every session, and clients (the macOS app, the `rex` CLI,
scripts) that connect to it, each rendering terminals with libghostty. The
`rex/` package is an experiment in what Rex makes possible for agent work, not
a port of the tmux setup; tmux stays the daily driver.

This doc carries what the experiment learned, so the next agent builds on it
instead of re-deriving it: how Rex is shaped, where its truth lives, which of
its protocols carry agent work, and the traps. The code under `rex/` is one way
to use all this; each tool explains itself in its header. Everything here was
established against CLI build `c50b257` and app build 1026, and Rex moves fast:
re-probe what matters after an update.

## Where Rex's truth lives

There are no published docs, but the server describes itself, and that beats
any notes kept here:

- **The wire API:** the server serves a full reference for agents at
  `/llms.txt` on its socket: every method with schemas and examples, the
  terminal block's methods, the WebSocket control and data protocols, the
  error codes. Read it before guessing a payload:

  ```bash
  curl -s --unix-socket ~/Library/Application\ Support/rex/server.sock http://rex/llms.txt
  ```

- **The live surface:** `rex api list` and `rex api describe METHOD`; `rex
  actions` (init.lua's and the blocks'); `rex -C <app client> actions --json`
  (the app's own actions with argument schemas, and which ones `repeats`);
  `rex keymap` (the resolved key map, modes included); `rex block inspect`.
- **The Lua API** (init.lua, `rex do` scripts) is documented nowhere. Learn it
  by probing: `rex do -e '<lua>'` prints what the chunk returns, and `rex
  config check FILE` loads a scratch file and names the field or type a call
  expected. What the probes found is under § The model and § Lessons.
- **The app is unseen.** No screen capture reaches it from here, and what the
  server holds is not always what the app paints (§ Lessons, floating
  layers). A claim about what the user sees is verified by the user.

## The model

- **The server owns the state:** sessions, each with windows (the tabs), each
  window with one tiled layer and any number of floating layers, and blocks
  (terminals) placed in layers or detached from all of them. It owns layout,
  focus, processes and every terminal's contents, and it outlives the app:
  quitting the app leaves every session, agent included, running, and the
  relaunched app reconnects.
- **The app owns the experience:** what is painted, the colours, key handling
  and modes, and the sidebar's order. The server only checks a key map; the
  client decides which mode is active.
- **A control connection attaches to a session before it may call into it.**
  `rex.session.attach` in a script changes which events it hears, not what it
  may call.
- **Actions come from init.lua, block types and the client, and a key binding
  can name any:** the account's `~/.config/rex/init.lua` (`rex.action`, run
  on the server), a block type's methods (`com.superlogical.terminal.*`), and
  the client's own (`pane.*`, `client.tab.*`, `session.select`). A server action reaches the client with
  `rex.client.queue`, which the client that pressed the key performs.
- **A key press tells an action where it came from:** `ctx` carries `origin =
  "key"`, `session_id`, `block_id` and `client_id`. Run from `rex do`, `ctx` is
  only `origin = "api"`, so an action meant to be scripted takes the session
  and block as arguments too.
- **Events are the integration seam.** Block events carry a terminal's program
  status, title, foreground process, bell, clipboard writes and notifications;
  session events carry windows opening, closing, being renamed, and any layout
  change. Only a running `rex do` script subscribes (`rex.on`); init.lua
  handlers are reserved for a later Rex. Anything always-on is therefore a
  long-running script, and a detached block (owned by a session, placed in no
  layout, shown nowhere) is the place to host one.
- **Every terminal knows where it is:** `REX_SESSION`, `REX_BLOCK`,
  `REX_SERVER` and `TERM_PROGRAM=rex`, as `$TMUX_PANE` does in tmux.

## Protocols that carry agent work

These are Rex's, not ours, and they are what make Rex better than tmux for
agents; a new integration should reach for them first.

- **Program status, OSC 7501.** A program reports its own state to its
  terminal; Rex keeps one record per `id` on the block, draws a badge on the
  tab ("Show status badges"), answers `program_status`, and emits
  `program_status_changed` with the record and the process that reported it.
  The grammar, worked out by experiment (a malformed report is dropped whole,
  silently):

  ```text
  ESC ] 7501 ; state=S[:kind=K][:id=ID][:app=A][:progress=0-255][:title=BASE64][:msg=BASE64] ESC \
  S: idle working done blocked error clear      K: permission question auth
  ```

  Claude Code's hooks publish through it here, so an agent's state is a typed
  event rather than a pane option polled from a status line.
- **The clipboard, OSC 52.** Written to a terminal, it becomes a
  `clipboard_written` event and the app showing that session copies it: the
  clipboard of the machine you are looking from, with no ssh-aware routing.
- **Notifications, OSC 9 and OSC 777,** become `desktop_notification` events.
- **The foreground process and its cwd** come from the OS through the
  `process` block method, right while nvim or Claude runs: tmux's
  `pane_current_path`.
- **A block's Claude session** needs no plumbing: the status record names the
  Claude process that reported, and Claude writes
  `<config dir>/sessions/<pid>.json` with its session id and directory, which
  `claude-steps` takes.

## Lessons

- **`rex.call` returns `nil, message`; it never raises.** A call that is not
  checked fails later and elsewhere. `rex/.config/rex/lua/rexkit.lua` raises
  on the paths that must not continue.
- **init.lua outlives the connection an action runs on.** A remembered
  "already attached" goes stale after the first run, and the next call is
  refused as not attached. Guard: attach again and retry on that refusal
  (`rexkit`'s `try`).
- **Actions run the code loaded at the last `rex config reload`.** A `rex do`
  test loads everything fresh, so it passes while a key press still runs the
  old code. Reload after editing anything init.lua requires.
- **Actions, and panes the server starts, get the server's bare system
  PATH.** Homebrew and `~/.local/bin` tools are missing unless the action or
  script sets PATH itself.
- **The `rex` CLI probes any terminal its stderr is attached to,** and the
  terminal's reply arrives on stdin as phantom input. A script that reads keys
  and calls `rex` sends rex's stderr elsewhere.
- **Client actions from outside the app need Remote Control** (Rex Settings →
  Rex Server); from a key press they need nothing. A CLI test of an action
  that queues a client step exercises only the server half.
- **The app's `client.tab.goto` counts every session's tabs in the sidebar.**
  Numbering per session, as tmux does, takes an action of one's own that
  focuses the session's Nth window and asks the client to show it.
- **The app owns the colours.** It pushes its theme to every terminal on the
  server, so a server-side `set_theme` is overwritten (it only sets what
  programs see when they query colours). Following our theme means switching
  the app's theme by name, which knows Ghostty themes only once imported.
- **Floating layers are unreliable in this beta.** The app sends them no
  keystrokes, paints their default background see-through, pads their
  terminal by about a row and two columns, and at present lays them out
  without painting them at all. Nothing essential goes in a layer; splits and
  tabs work.
- **Rex's Lua 5.1 crashes the whole script** with a Go nil-pointer error on
  `for … in (s:gsub(…) .. x):gmatch(…)`; the same through a local works.
- **A Rex terminal does not inherit the Claude account choice.** Launch
  Claude with the `x` launchers or an explicit `CLAUDE_CONFIG_DIR`.
- **Claude reports SessionStart before it writes its sessions file,** so a
  lookup made on that first report retries for a moment.

## What the lab builds

The package is `rex/`; `rex-demo` builds an `agents-demo` session that shows
the agent pieces working without spending Claude turns.

- **Agent status:** every Claude in Rex publishes its state over OSC 7501
  (`rex-agent`, from the hooks); the tab badge shows it, a live board lists
  every agent across sessions most-urgent first, and a key jumps to the one
  that has waited longest.
- **claude-steps beside the agent:** a split that runs `claude-steps show` for
  the agent next to it and redraws on each of its status events, instead of a
  popup opened on demand.
- **Navigation and tools:** a `ctrl+a` prefix mode carrying the tmux muscle
  memory, per-session tab numbers kept current by a watcher (`rexd`, in a
  detached block a Rex shell starts), copy-path and gopen keyed to the pane,
  and a worktree picker that can open a worktree with Claude and its steps.
- **Feedback:** toasts in a floating layer, invisible while the app does not
  paint layers.
- **Theme:** `theme-set` switches the app to the Ghostty theme it chose.

It reaches into other packages, which is where a change to them can break it:
the Claude hooks in `claude/.claude/settings.json` (each guarded by
`$REX_BLOCK`, so a no-op outside Rex), step 6 of
`scripts/.local/bin/theme-set`, `zsh/.config/zsh/rex.zsh`, the yank-path block
in `nvim/.config/nvim/lua/config/autocmds.lua`, and `~/.config/rex` as a real
directory (`docs/stow-layout.md`).

## Keys

`rex keymap` is the authority. The shape:

- **`ctrl+a`** enters the `prefix` mode for one key, as tmux's prefix does;
  `escape` leaves it, `ctrl+a` again sends a literal `ctrl+a`, and an unbound
  key does nothing.
- **Panes and tabs after the prefix** follow tmux: `|` `-` split, `hjkl` focus,
  `HJKL` resize, `z` zoom, `c` `n` `p` `x` `m` for tabs, `T` and `(` `)` for
  sessions, `1`–`9` for this session's tab N.
- **Tools after the prefix:** `y`/`Y` copy path, `g` gopen, `W` worktrees, `S`
  `A` `J` steps sidecar, agents board, next agent.
- **Without the prefix:** `ctrl+shift+down`/`up` step through every tab in
  sidebar order, across sessions; ⌘⇧S, ⌘⇧A and ⌘⇧J as above.

## Open questions

- **Floating layers:** the app lays them out (it claims their size) but
  paints nothing, across a full relaunch, both themes and pane headers on;
  they did paint earlier in the day.
- **Statuses in the app** beyond the tab badge: notifications, the sidebar.
- **Persistence past the app:** sessions survive an app quit; a reboot or a
  server restart is untested.
- **Unbuilt next steps:** a notification when an agent blocks while its tab
  is out of view; one board over the laptop's and the mini's servers
  (`rex.server(label)` reaches another host over Tailscale); agents driving
  Rex through `rex run --wait` and `program_status` instead of polling a
  screen.
