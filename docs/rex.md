# Rex lab

Rex is Superlogical's terminal multiplexer, in private beta: a long-lived
server that owns every session, and clients (the macOS app, the `rex` CLI,
scripts) that connect to it, each rendering terminals with libghostty. Rex
runs beside tmux as a trial, on both machines, while the two are compared;
tmux is not being replaced. The `rex/` package carries the tmux muscle memory
into Rex and tries what Rex makes possible for agent work.

This doc carries what the trial learned, so the next agent builds on it
instead of re-deriving it: how Rex is shaped, where its truth lives, which of
its protocols carry agent work, how the two machines meet in it, and the
traps. Each tool under `rex/` explains itself in its header. Everything here
was established against CLI build `c50b257` and app build 1026, and Rex moves
fast: re-probe what matters after an update.

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
  config check FILE` loads a scratch file and names the field or option a
  call does not take. What the probes found is under § The model and
  § Lessons.
- **The app is unseen, and its log is thin.** No screen capture reaches it
  from here, and what the server holds is not always what the app paints
  (§ What the app does not show). A claim about what the user sees is verified
  by the user. The app logs a refused client step in the unified log
  (`log show --predicate 'subsystem BEGINSWITH "com.superlogical"'`), and the
  lab's actions log their failures, and their results on another host's
  session, to `~/.local/state/rex-lab/actions.log`.

## The model

- **The server owns the state:** sessions, each with windows (the tabs), each
  window with one tiled layer and any number of floating layers, and blocks
  (terminals) placed in layers or detached from all of them. It owns layout,
  focus, processes and every terminal's contents, and it outlives the app:
  quitting the app leaves every session running. Stopping the server ends
  every session on it, agents included; their Claude conversations come back
  with `claude --resume`.
- **The app owns the experience:** what is painted, the colours, key handling
  and modes, the sidebar's order, and its own settings, which `twin` does not
  carry (§ Two machines). The server only checks a key map; the client
  decides which mode is active.
- **A control connection attaches to a session before it may call into it.**
  `rex.session.attach` in a script changes which events it hears, not what it
  may call.
- **Actions come from init.lua, block types and the client, and a key binding
  can name any:** the account's `~/.config/rex/init.lua` (`rex.action`, run
  on the server), a block type's methods (`com.superlogical.terminal.*`), and
  the client's own (`pane.*`, `client.tab.*`, `session.select`). A server
  action reaches the client with `rex.client.queue`, which the client that
  pressed the key performs after the action returns.
- **A key press tells an action where it came from:** `ctx` carries `origin =
  "key"`, `session_id`, `block_id`, `client_id`, and `server` when the session
  is another host's. Run from `rex do`, `ctx` is only `origin = "api"`, so an
  action meant to be scripted takes the session and block as arguments too.
- **The app does not say which session it shows.** It stays attached to every
  session it has opened. The lab keeps its own record of where you are
  (`rexkit`'s `here`): the session of the last key an action took, or of the
  tab rexd saw you switch to.
- **Events are the integration seam.** Block events carry a terminal's program
  status, title, foreground process, bell, clipboard writes and notifications;
  session events carry windows opening, closing, being renamed, and any layout
  change. Only a running `rex do` script subscribes; init.lua handlers are
  reserved for a later Rex. Anything always-on is therefore a long-running
  script, and a detached block (owned by a session, placed in no layout, shown
  nowhere) is the place to host one.
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

  Claude Code's hooks publish through it (`id=claude`), and so does every
  interactive shell for a command that runs ten seconds or more (`id=shell`,
  `zsh/.config/zsh/rex.zsh`), so a finished build is found as an agent is.
- **The clipboard, OSC 52.** Written to a terminal, it becomes a
  `clipboard_written` event and the app showing that session copies it: the
  clipboard of the machine you are looking from, with no ssh-aware routing.
- **The foreground process and its cwd** come from the OS through the
  `process` block method, right while nvim or Claude runs: tmux's
  `pane_current_path`.
- **A terminal's whole scrollback** comes back as text, HTML (palette slots as
  CSS variables) or VT from the `format` block method; `plain` returns
  nothing. The URL picker and the pane export read it.
- **A block's Claude session** needs no plumbing: the status record names the
  Claude process that reported, and Claude writes
  `<config dir>/sessions/<pid>.json` with its session id and directory, which
  `claude-steps` takes.

## Two machines

Each machine runs its own Rex server, and the laptop's app shows the mini's
sessions beside its own in one sidebar, as `mini` attached tmux over ssh.

- **The mini's server serves its API over Tailscale** as
  `qiushi-mini-rex.tailf7adf1.ts.net`, admitting only the account that enrolled
  it. The mini's app starts it that way (Settings → Rex Server); a server
  started from a shell needs the same flags, or it comes back without the
  address:

  ```bash
  rex server start --tailscale --tailscale-hostname qiushi-mini-rex   # on the mini
  ```

  The node's identity lives in `~/Library/Application Support/rex/tsnet`, so a
  restart keeps the address. The first connection after one takes up to 20
  seconds while the certificate is issued.
- **There are two host lists.** The app's, filled by **Add Host…**, is what
  the sidebar shows and what `rex.servers()` returns inside an action a key
  ran. The server's, filled by `rex hosts add`, is what `rex -S <label>` and
  `rex do` scripts see; the laptop's server lists the mini as `mini`, for the
  agents board. Neither fills the other.
- **A key in another host's session runs the config of the app's own
  machine.** The action sees `ctx.server`, and its `rex.call`s travel through
  the app to that host, but its files, processes, `$HOME`, clipboard and `open`
  are the laptop's. `rexkit` carries the guards: `bin` names a tool for a pane
  by the pane host's `$HOME`, `run_there` runs a command on the session's host
  in a hidden block and reads its screen back, `read_state` reads the lab's
  state there, `copy` copies on the app's machine.
- **The app cannot be sent to another host's session.** `session.select`
  queued by an action waits five seconds and gives up ("no host lists it" in
  the app's log). Moving between tabs is therefore the app's own
  `client.tab.next` / `previous`, repeated, which walk the sidebar across
  sessions and hosts; a jump to another host's agent becomes a notice instead.
- **The app's settings are per machine.** The look (theme, vertical tabs, pane
  headers, font) was copied from the mini as `com.superlogical.rex`'s
  `Workspace.*` defaults, which the app reads when it launches. "Prefer
  generated titles" stays off on both, or pane headers show the program's
  name and folder instead of the title it sets.

## Lessons

Each is a trap the Rex environment does not reveal; the guard is named where
one exists.

- **`rex.call` returns `nil, message`; it never raises.** A call that is not
  checked fails later and elsewhere. `rexkit`'s `call` raises on the paths
  that must not continue.
- **init.lua outlives the connection an action runs on.** A remembered
  "already attached" goes stale after the first run, and the next call is
  refused as not attached. Guard: `rexkit`'s `try` attaches again and retries
  on that refusal.
- **Actions run the code loaded at the last `rex config reload`.** A `rex do`
  test loads everything fresh, so it passes while a key press still runs the
  old code. Reload after editing anything init.lua requires, on each machine.
- **Actions, and panes the server starts, get the server's bare system
  PATH.** Homebrew and `~/.local/bin` tools are missing unless the action or
  script sets PATH itself (`rexkit.PATH`).
- **The `rex` CLI probes any terminal its stderr is attached to,** and the
  terminal's reply arrives on stdin as phantom input. A script that reads keys
  and calls `rex` sends rex's stderr elsewhere.
- **Client actions from outside the app need Remote Control** (Rex Settings →
  Rex Server); from a key press they need nothing. A CLI test of an action
  that queues a client step exercises only the server half.
- **A client step runs after the action returns, and the app learns of a new
  window later still.** A tab step queued right after `session.new_window`
  lands one tab too far, in the next session. On this host the action selects
  the new tab instead; on another host's it waits half a second for the app,
  if `rex.sleep` exists in an action, which no probe has confirmed.
- **The app's `client.tab.goto` counts every session's tabs in the sidebar.**
  Per-session numbers, as tmux keeps them, step from the current tab with
  `client.tab.next` / `previous`; `session.focus_next_window` does not wrap.
- **A mode shows a panel of its keys while it is active, and so does a key
  sequence (`ctrl+a>x`).** Both swallow a key nothing binds; `rex.mode` takes
  only `exclusive` and `blocked`. The prefix is a mode, with `escape` to
  leave it.
- **The app evens out a new split when "Balance splits on creation" is on,**
  after the action that made it returns, and no pane is shorter than two rows.
  A pane meant to be small sizes itself once it has started.
- **Events reach a `rex do` script only once its top level has returned.** A
  loop that also polls is `rex.wait(name, seconds)`, which hands over the
  events that arrive meanwhile (the agents board).
- **Rex's Lua 5.1 never closes an `io.popen(…, "w")` pipe,** so a reader such
  as `pbcopy` waits forever; pipe through the shell. It also crashes the whole
  script on `for … in (s:gsub(…) .. x):gmatch(…)`; the same through a local
  works.
- **`rex run --wait` prints no creation result when its output is not a
  terminal.** A caller finds the block by its label (`rex-run`).
- **The app owns the colours.** It pushes its theme to every terminal on the
  server, so a server-side `set_theme` is overwritten (it only sets what
  programs see when they query colours). Following our theme means switching
  the app's theme by name, which knows Ghostty themes only once imported.
- **A Rex terminal does not inherit the Claude account choice.** Launch
  Claude with the `x` launchers or an explicit `CLAUDE_CONFIG_DIR`.
- **Claude reports SessionStart before it writes its sessions file,** so a
  lookup made on that first report retries for a moment.

## What the app does not show

Feedback that tmux draws on its own surfaces has no working home in Rex yet.
Each of these reaches the server and never the screen, so nothing essential
depends on them:

- **Floating layers:** laid out, never painted; the app also sends them no
  keys. Toasts are off (`rexkit`'s `LAYER_TOASTS`), and splits stand in for
  popups.
- **Notifications:** OSC 9 becomes a `desktop_notification` event, and
  neither it nor an `osascript` notification appeared. rexd still sends one
  when an agent or a long command finishes in a tab you are not on.
- **Names set through the API:** a block or window label changed by
  `set_block_label` / `set_window_label` did not reach the pane header or the
  sidebar, though rexd's tab numbers, set the same way when a tab opens, do.
  Untested since generated titles were turned off.
- **The pane header** draws the terminal's title as plain text, with no
  colour, so a styled status such as the tmux context chip belongs in
  Claude's own statusline.
- **Block types of our own** load and work on the server but cannot be drawn
  (§ Block plugins).
- **The web client** (`session.open_on_web`) sits behind Superlogical's own
  sign-in.

## Block plugins

A block type of our own was built and loaded on a scratch server. Findings,
for whoever tries again after a Rex update:

- **Loading:** every executable in `~/Library/Application Support/rex/blocks`
  (or `--block-dir`) starts with the server, which takes it up only at its own
  start. The plugin gets `REX_BLOCKSERVER_INFO_FD=3`, serves HTTP, and writes
  `{"network","addr","base_url","pid"}` to that fd; Rex then dials
  `<base_url>/api/control` as a `rex.control.v1` client and sends
  `block_creator.list`, `block.create`, `block.event`, `block.method` and
  `block.close`. Its methods, actions and events then join the API like the
  terminal's.
- **Drawing:** `data.connect` on its block fails ("block data provider not
  found"), Rex never asks a plugin for data, and the app draws an
  "Unsupported block" card for any creator but the terminal. The probe after
  an update: does `data.connect` on a plugin block succeed?
- **Two hazards on a live server:** a creator name with an underscore loads,
  then makes every `session.create` fail; a plugin may claim
  `com.superlogical.terminal` and silently replace the terminal.

## What the lab builds

The package is `rex/`; `rex-demo` builds an `agents-demo` session that shows
the agent pieces working without spending Claude turns.

- **The tmux keys** (§ Keys), on Rex's own API: pane focus that passes
  `ctrl+h/j/k/l` through to nvim and fzf, per-session tab numbers kept by a
  watcher (`rexd`, in a detached block a Rex shell starts), pane mode with
  push, hold and put across tabs, a scratch split, and a URL picker and pane
  export over the block's scrollback.
- **Agent status:** every Claude in Rex publishes its state over OSC 7501
  (`rex-agent`, from the hooks); the tab badge shows it, `rex-board` lists the
  agents of every server it can reach most-urgent first, and a key jumps to
  the one on this host that has waited longest.
- **claude-steps beside the agent:** a split that runs `claude-steps show` for
  the agent next to it, redraws on each of its status events, and closes with
  it.
- **rex-run:** runs a command in a pane beside the caller and hands back its
  exit status and output, for an agent whose work the human should watch.
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
  `escape` leaves it, and `ctrl+a` again sends a literal `ctrl+a`.
- **Panes after the prefix** follow tmux: `|` `-` split, `hjkl` focus, `HJKL`
  resize, `z` zoom, `X` close, `space` balance, `b` to a new tab, `Z` a
  scratch shell below, `M` rename, `C-k` clear with scrollback, `p` pane mode
  (`hjkl` push, `HJKL` resize, `g` hold, `p` put, `G` release, `Esc` leave).
- **Tabs and sessions after the prefix:** `1`–`9` this session's tab N, `C-h`
  `C-l` (`C-p` `C-n`) previous and next, `Tab` the last tab, `S-Tab` the last
  session on this host, `c` new tab, `N` new tab here, `x` close, `m` rename,
  `T` `(` `)` sessions, `$` rename the session.
- **Tools after the prefix:** `y`/`Y` copy path, `g` gopen, `u` URLs, `e`
  export, `W` worktrees, `S` steps sidecar, `A` agents board, `a` next agent.
- **Without the prefix:** `ctrl+h/j/k/l` pane focus, `ctrl+shift+up/down`
  every tab in sidebar order across sessions and hosts, `shift+up/down` move
  the tab; ⌘⇧S, ⌘⇧A and ⌘⇧J as above.

## Open questions

- **Display:** whether notifications, API-set names and floating layers
  appear after an app update, or with a setting not yet found
  (§ What the app does not show).
- **Persistence past a reboot:** a server restart ends every session; whether
  the app or launchd brings the mini's server back after a reboot is untested.
- **Comparison with tmux:** which workflows feel better in each, as sessions
  move to Rex during the trial.
