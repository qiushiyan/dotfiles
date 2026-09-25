# Office Mac mini (`ssh qiushi-mini`)

My own Mac mini, kept in the office and reached over the company tailnet from
the laptop, in or out of the office. Unlike the shared `macmini`
(`docs/macmini.md`), this box is mine to configure. Facts below were
collected 2026-09-22.

## Connection

| | |
|---|---|
| alias | `ssh qiushi-mini` or `ssh mini` (`sshmini`) — `Host qiushi-mini mini` in `~/.ssh/config` (gitignored; the address lives only there) |
| network | Tailscale, tailnet `planlab-ai.org.github`, node `qiushi-mini` (MagicDNS `qiushi-mini.tailf7adf1.ts.net`) |
| LAN | `qiushi-mini.local` also works on the office Wi-Fi |
| user | `qiushiyan` (uid 502, `admin` group, sudo **with password**) |
| key | default `~/.ssh/id_*` identity (no per-host `IdentityFile`) |
| host key | ED25519 `SHA256:CLzS5O1NtMF/AO6FkM92Ux9n1dNf7iCitDuHDENqvgo` |

Another local account, `maxsnijders`, exists on the machine.

## Tailscale

The open-source `tailscaled` from Homebrew, installed as a system
LaunchDaemon (`sudo tailscaled install-system-daemon`), so it runs at boot
before anyone logs in. There is no Tailscale.app. The CLI is
`/opt/homebrew/bin/tailscale`.

**Node key expiry is on.** I am a member, not an admin, of the company
tailnet, so only an admin can disable expiry in the admin console. The key
expires **2027-03-21**. Once the key expires, the node drops off the tailnet
and can only be re-authorised from the office LAN. Renew it before that date
from the office, over the LAN, because re-authenticating can drop a session
that runs over Tailscale itself:

```bash
ssh -t qiushiyan@qiushi-mini.local 'sudo /opt/homebrew/bin/tailscale up --force-reauth'
```

Check the current expiry on the mini with
`tailscale status --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["KeyExpiry"])'`.

Why the company tailnet rather than my personal one (`qiushiyan.github`): the
laptop stays on the company tailnet, and a member cannot accept a device share
into it, because accepting a share needs the admin console.

## Hardware and OS

| | |
|---|---|
| model | Mac mini `Mac18,5`, Apple M6, 12 cores, arm64 |
| memory | 32 GB |
| disk | 926 GB internal |
| OS | macOS 27.0 (26A425) |
| power | `pmset -a sleep 0 autorestart 1 womp 1`: never sleeps, restarts after power loss, wake-on-LAN |
| FileVault | **on**, and not mine to turn off. After an unplanned restart the mini waits at the FileVault unlock screen, and `tailscaled` is down until someone unlocks it in person. For planned reboots, use `sudo fdesetup authrestart`. |

## Toolchain

A deliberately small subset of the laptop: no `bootstrap.sh`, no Brewfile.
Add a tool when a task on the mini needs it, not to match the laptop.

| tool | version | how | update |
|---|---|---|---|
| CLI tools | — | `brew install gh tmux ripgrep fd fzf jq lazygit zoxide uv stow rsync git-lfs coreutils bat difftastic` (the last three because `aliases.zsh`/`git.zsh` call `gls`, `bat`, `difft`) | `brew upgrade` |
| tmux | 3.7c | `qiushiyan/local/tmux-popupfix`, as on the laptop: a `brew tap-new --no-git` tap holding `docs/tmux-popupfix.rb`; stock `tmux` stays installed, unlinked | `docs/tmux-popup-patch.md` § Upgrading |
| nvm | 0.40.8 | upstream `install.sh` (nvm rejects Homebrew installs) → `~/.nvm` | re-run installer with the new tag |
| node | v24.21.0 LTS (`default` → `lts/*`) | `nvm install --lts` | `nvm install --lts && nvm alias default 'lts/*'` |
| pnpm | 11.27.1 | `get.pnpm.io/install.sh` with `PNPM_VERSION=11.27.1` → `~/Library/pnpm`; pinned to 11 to match the laptop, not the Rust-port 12 | `pnpm self-update` |
| Claude Code | 2.1.280 | native `claude.ai/install.sh` → `~/.local/bin/claude` | auto-updates |
| Codex CLI | 0.155.1 | `chatgpt.com/codex/install.sh` → `~/.local/bin/codex` | `codex update` |
| Python | 3.14.7 | `uv python install 3.14` (versioned `python3.14` only) | `uv python upgrade` |
| AWS CLI | 2.37.3 | `brew install awscli`; `~/.aws/config` copied from the laptop (SSO profiles only; no `credentials`) | `brew upgrade awscli`; re-copy `config` after a profile change |

Personal CLIs (headroom, envoy, brief, gwt) come from the laptop through
`mini-sync` (§ Sync); Ghostty and its fonts are in § Ghostty on the mini.
Not installed: go, rust, Docker, databases, other GUI apps.

## Shell

The `zsh` package is not stowed. The mini's startup files are hand-written,
and they pull the shared parts from the mirror.

- **`~/.zshenv`** carries everything, because `ssh qiushi-mini '<cmd>'` runs
  a non-login, non-interactive zsh that reads no other file. It sets brew
  shellenv, `~/.local/bin`, `LANG=en_US.UTF-8`, the newest nvm Node `bin`,
  `$PNPM_HOME/bin`, and the SSH-only terminal variables (§ Terminal over
  SSH). It then sources a curated list of modules straight from
  `~/dotfiles/zsh/.config/zsh/`:
  `aliases nav utils git claude claude-sessions codex tmux-utils cwd-guard
  theme`.
  That gives the laptop's muscle memory (`n`, `g`, `lg`, `l`, `t`, `b`,
  `take`, `p`, …) and routes `x`/`cx` through headroom. Laptop-only modules
  stay out: `toolchain` (the PATH lines replace it), `xcode`, `cout`,
  `proxy`. It turns off `EQUALS`, as the laptop does, and exports
  `PROMPT_MACHINE=mini` (below).
- **`aws sso login`:** `.zshenv` wraps `aws` to add `--use-device-code`.
  The default flow redirects the browser to a localhost listener on the
  mini, which a laptop browser can't reach. With the device-code flow the
  printed URL carries the code, so it works in any browser; over SSH,
  `BROWSER` sends it to the laptop clipboard.
- **Locale:** the laptop's ssh sends no `LANG`, so `.zshenv` sets one.
  Without a UTF-8 locale, tmux marks the client non-UTF-8 and draws every
  non-ASCII glyph (status-bar separators, icons) as `_`. tmux fixes that per
  client when it attaches, so a client attached without it must detach and
  attach again.
- **`~/.zprofile`** repeats brew shellenv, because `/etc/zprofile`'s
  `path_helper` reorders PATH for login shells after `.zshenv`.
- **`~/.zshrc`** follows the laptop's order without sourcing it (that file
  names laptop-only paths): vi mode and history settings, oh-my-zsh
  (`history`, `zsh-autosuggestions`; it runs `compinit`),
  zsh-syntax-highlighting, `_git_zsh_register_completions`, the nvm/pnpm
  installer blocks, zoxide, fzf, and oh-my-posh last. oh-my-zsh and the two
  plugins are shallow clones at the laptop's paths; oh-my-posh is from the
  `jandedobbeleer/oh-my-posh` tap.
- **tmux** is the laptop's: the `tmux` package is stowed, so
  `~/.config/tmux` is a folder link into the mirror, and `prefix t` switches
  themes through `~/.local/bin/theme-set`, a link `mini-sync` keeps (§ Sync).
  The plugins are gitignored, so they were cloned on the mini at
  the laptop's commits into the mirror's `tmux/.config/tmux/plugins/`;
  `mini-sync` leaves ignored paths alone. After a plugin update on the laptop,
  run `prefix I`/`prefix U` on the mini too. `~/.tmux.conf.pre-stow` is an
  inert hand-written config tmux never reads. Bindings that call
  laptop-only tools fail on the mini: `prefix T` (sesh) and `prefix b`
  (terminal-browser). `prefix y`/`Y` copy with the mini's `pbcopy`, so over
  SSH the path lands on the mini's clipboard; `frommini -g` fetches it
  (§ Clipboard and attach).

**Machine badge:** `PROMPT_MACHINE=mini`, set in the mini's `.zshenv`,
marks everything that runs on the mini; the laptop leaves it unset and stays
unmarked. A new machine opts in the same way, with no second config to keep
in step:

- **Prompt:** the `ohmyposh` package is stowed, so the mini renders the
  laptop's `zen.omp.json` in the synced theme's palette. Its first segment is
  a peach ` mini`.
- **tmux status bar:** the shared `tmux.conf` copies the variable into
  `@machine` whenever it is sourced, and draws the same badge at the right
  of the top bar, beside the session badge. It stays visible while an agent holds the pane, which the
  prompt does not.
- **Window title:** tmux titles the Ghostty window `mini · <session>:…`,
  which shows in the Window menu and Mission Control even with the titlebar
  hidden.

The tmux server reads the variable from its own environment, which it takes
from the shell that started it. A server started any other way has no badge
until the variable is set in it.

**Git:** the global identity is the personal Gmail. GitHub auth goes through
`gh auth setup-git` (HTTPS), so no private SSH key lives on the mini.

**Neovim:** the `nvim` package is stowed from the mirror. Plugins install
from `lazy-lock.json`, and Mason installs LSPs on first open.

## Terminal over SSH

The laptop's Ghostty → ssh → mini tmux chain (§ Clipboard and attach says
why the laptop tmux stays out of it) needs these on top of a default mini:

- **terminfo**: `xterm-ghostty` was pushed with
  `infocmp -x xterm-ghostty | ssh qiushi-mini -- tic -x -` (into
  `~/.terminfo`). Without it, tmux and nvim reject the TERM Ghostty sends.
- **Clipboard (OSC 52)**: every tmux between a pane and Ghostty must run
  `set-clipboard on`, because `external` drops OSC 52 sent from panes; the
  shared `tmux.conf` sets it. tmux forwards it only to a client that is
  showing the pane. nvim's yank depends on this: for `SSH_TTY` sessions
  `options.lua` sets `clipboard=unnamedplus` with a provider that copies to
  both OSC 52 and the mini's pbcopy, and pastes from pbpaste. Plain `y`
  reaches the laptop, and `p` reads what mini tools copied, such as
  `brief start`'s pointer, without an OSC 52 read prompt. LazyVim's default,
  an empty `clipboard` over SSH, made `p` paste a stale register from shada.
- **Links**: open them with **Cmd+Shift+click**. Ghostty opens OSC 8 links
  on Cmd-click, and Shift bypasses tmux's mouse capture. sshd doesn't forward
  `TERM_PROGRAM`, so `.zshenv` sets `FORCE_HYPERLINK=1` for SSH sessions;
  without it Claude Code prints plain-text URLs.
- **Ctrl-click in Claude Code** is its own click handler, which runs
  `$BROWSER` (else `open`) on the host, the mini. `.zshenv` sets
  `BROWSER=~/.local/bin/browser-clip` for SSH sessions. That shim hands the
  URL to `toclip`, which sends it to the laptop clipboard instead of opening
  the mini's Safari (§ Clipboard and attach).

## Clipboard and attach

The laptop reaches the mini from its own Ghostty window, never from inside
the laptop tmux: both tmux configs use the same prefixes, so a nested mini
would lose every prefix key to the laptop. In that window, **`mini`** attaches
the most recently active session, including one the Screen Sharing Ghostty
is also showing; `mini <name>` attaches or creates `<name>`. Bare
`tmux attach` is not the same: it prefers an unattached session.

When the mini's tmux server dies, continuum's last snapshot (saved every 15
minutes) brings the sessions back:

1. `tmux new-session -d -s tmp` starts a server; continuum restores the
   snapshot about a second later.
2. Wait until `tmux ls` lists the restored sessions, then
   `tmux kill-session -t tmp`. Killed sooner, `tmp` is the last session and
   the server exits before the restore runs.
3. Panes return as shells in their folders; agents do not restart. Run
   `claude --continue` (with your usual flags) in each pane to reopen that
   folder's latest conversation, or `--resume` to pick one.

Nothing is forwarded automatically. Copies travel only when you copy on
purpose:

| command | runs on | moves |
|---|---|---|
| terminal copy (Claude's `c`, nvim `y`, tmux copy mode) | mini | to the laptop clipboard over OSC 52, and into the mini tmux's buffers; nvim also writes the mini's pasteboard |
| `<cmd> \| toclip`, `toclip <text>` | either | to the clipboard of the machine you are sitting at |
| `frommini` | laptop | the mini tmux's newest buffer → laptop clipboard |
| `frommini -g` | laptop | the mini's GUI pasteboard, text or image → laptop clipboard |
| `tomini` | laptop | the laptop clipboard, text or image → the mini's pasteboard |

- **OSC 52 is fire-and-forget.** A terminal that ignores it, such as macOS
  Terminal.app, drops the copy without an error. The text still sits in the
  mini tmux's newest buffer, so `frommini` recovers it.
- **`toclip` aims at the ssh client.** With both the laptop's ssh and the
  Screen Sharing Ghostty on one session, an untargeted `load-buffer -w`
  writes to whichever client tmux picks by activity, which can be the mini's
  own screen. `toclip` targets the session's most recent client that has
  `sshd` among its ancestors, and falls back to `pbcopy` when there is none.
  Outside tmux it writes OSC 52 to the session's tty, or its caller's tty when
  it was spawned detached. Payloads over 512 KiB are not sent through the
  terminal; inside tmux they stay in the buffer for `frommini`.
  `scripts/.local/share/dotfiles/tests/test-toclip.sh` pins the routing.
- **Images:** a screenshot sent with `tomini` becomes the mini's pasteboard
  image, which Claude Code there pastes with Ctrl+V. It also stays as a file
  in `~/.cache/clip/` for 7 days, and `tomini` prints its path. When the
  pasteboard holds both text and an image, text wins: a file copied in Finder
  carries its name as text and its icon as an image.
- **One helper for both pasteboards:** `scripts/.local/share/dotfiles/pasteboard`
  (`get`/`put`) is the single place that reads and writes a Mac's pasteboard as
  a typed file. `tomini` and `frommini` run it on both ends, the mini's copy
  from the mirror. Each command lands the whole payload before writing the
  destination, so a failed read never clears a clipboard. It sets `LANG`
  itself, because `pbcopy` garbles non-ASCII text under a caller with no
  locale.
- **Screen Sharing shares its own clipboard** with the laptop while its
  window is open (Edit → Use Shared Clipboard). That is separate from all of
  the above.

## Moving a Claude session

Claude Code has no native handoff between two local machines. Remote Control
steers a session that keeps running on its own host, and `/teleport` pulls a
cloud session down to a terminal but can't push a local one onward.
`claude-tomini` (`scripts/.local/bin/`, laptop only) moves one by hand, so
work started on the laptop keeps running on the mini after the laptop leaves:

```bash
claude-tomini -n            # newest session for $PWD; check both ends, change nothing
claude-tomini --start <id>  # move it and resume it in mini tmux session <worktree name>
```

It moves the **code** and the **transcript**. The code is the worktree's
branch, pushed straight into the mini's clone and checked out at the same
`$HOME`-relative path. The transcript is the `.jsonl` and its sidecar dir,
filed under the mini's project dir. The mini then resumes with
`x --resume <id>`, keeping the same session id and the whole history.

- **Preconditions it enforces:** the session is closed on the laptop (a live
  `sessions/<pid>.json` names it), the worktree is clean, and the session's
  cwd is under `$HOME`. The home dirs differ (`/Users/qiushi` vs
  `/Users/qiushiyan`), so paths map by that prefix.
- **Never overwrites work on the mini.** An existing worktree or branch there
  only fast-forwards. The script refuses when the mini already holds this
  transcript, since that may be a previous move's continuation; `--force`
  overrides.
- **The push skips GitHub and the pre-push hook.** It sends the branch to
  the temporary ref `refs/tomini/<branch>`, which the mini deletes after the
  checkout. Git LFS content does not ride a push, so the script copies the
  LFS objects the mini lacks from the laptop's store before the checkout. A
  file added in an unpushed commit exists nowhere else.
- **What does not come along:** gitignored files (`.env`, `node_modules`;
  the script lists them), background tasks and monitors, and the session's
  `/private/tmp` scratchpad. Earlier turns still name laptop paths. Only
  the `cwd` fields are rewritten, because thinking blocks are signed over
  their exact text. The resume command appends a system-prompt note about
  the move instead.
- **The mini's first turn rebuilds the prompt cache, and that cost is
  accepted.** The cache matches on the exact prompt from its start, and the
  system prompt comes before the history. On the mini it differs in the
  working directory, the environment block and the move note, and the
  account may sit in another organization. So that turn writes the whole
  context to the cache at the cache-write rate. It is a one-time cost per
  move, like resuming after the cache has expired. No script change avoids
  it, because the working directory alone breaks the match. That turn's
  `cache_creation_input_tokens` in the mini's transcript shows the size.
- **The laptop copy stays.** Resuming it too forks the conversation. To
  come back, copy the mini's newer `.jsonl` over it by hand; there is no
  reverse script yet.

## Reaching the laptop

From the mini, the laptop is `ssh qiushi-mac` (or `ssh mac`): tailnet node
`qiushis-macbook-pro`, user `qiushi`, with Remote Login on. The alias lives in
the mini's own `~/.ssh/config`, which is not part of the mirror. `mac` is the
mirror image of `mini`: it attaches the laptop's most recently active tmux
session. It is the same script, which picks the host by the name it runs as.
Copies go over the same alias: `scp mac:~/path .`, `rsync -a mac:~/dir/ dir/`.

**The key is the mini's own, and the laptop fences it.** The key is
`~/.ssh/id_ed25519_mac`. Its line in the laptop's `~/.ssh/authorized_keys`
carries `from="100.68.130.84"`, the mini's tailnet address, so the key is
useless anywhere else.

⚠️ **The key has no passphrase, by choice, for convenience.** The mini is
not a trust boundary (§ Steward host), so every process running as this
user there can log into the laptop unattended. That includes agent sessions
with permissions bypassed and the steward's driven sessions. To close that,
add a passphrase with `ssh-keygen -p -f ~/.ssh/id_ed25519_mac`; the laptop
side is unchanged. To revoke the key, delete its line from the laptop's
`authorized_keys`. Setup, run once by hand:

1. On the mini: `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_mac -C qiushi-mini-to-mac`
2. On the laptop:
   `ssh mini 'cat ~/.ssh/id_ed25519_mac.pub' | sed 's/^/from="100.68.130.84" /' >> ~/.ssh/authorized_keys`

## Ghostty on the mini

The app is installed by hand. The `ghostty` package is stowed from the
mirror, so `~/.config/ghostty` is a folder link into it, as on the laptop.
The mini's `theme-set` writes the theme include (`auto/theme.ghostty`) and
`~/.config/terminal-theme`, run either from `prefix t` or by `mini-sync`
(§ Sync). Ghostty reloads config only with ⌘⇧, or a restart.

**Fonts** are the laptop's casks, `font-jetbrains-mono-nerd-font` and
`font-sarasa-gothic`, installed into `~/Library/Fonts`. The files landed but
were not registered: CoreText listed neither family, and Ghostty fell back to
PingFang SC for CJK, until the files were registered once with
`CTFontManagerRegisterFontURLs(…, .user, …)` (what Font Book's Install does).
After a font cask, verify with `ghostty +show-face --cp=0x4E2D`; it must name
`Sarasa Term SC`.

## Agent config

**Auth:** the login Keychain is locked in SSH sessions, so every login lives
in a file:
- Claude Code falls back to `~/.claude/.credentials.json`.
- Codex is pinned to `cli_auth_credentials_store = "file"`.
- gh falls back to plaintext `hosts.yml`.

Each is logged in on the mini itself, never copied from the laptop (§ Sync,
token files).

**Claude Code:** the `claude` package is stowed from the mirror. `~/.claude`
and `~/.agents` are real dirs, and `settings.json`, `CLAUDE.md`, hooks,
rules, commands, agents and skills link into the mirror. Codex reads the same
skills through `~/.agents/skills`.
- The hooks and the statusline call `~/.config/tmux/scripts/*`, which the
  stowed `tmux` package provides (§ Shell). Those scripts no-op outside tmux.
- A setting changed on the mini (`/config`, the `/model` default) writes
  through the link into the mirror and is lost at the next sync.

**Codex:** `~/.codex/config.toml` is **generated**, not linked, because Codex
writes project and hook trust into it at runtime. `mini-sync` runs the
laptop's file through `scripts/.local/share/dotfiles/mini-codex-config.py`,
which:
- keeps every shared setting: model, reasoning, TUI, features, context7,
  and skill-sync's exclusions;
- drops the ChatGPT desktop integrations (computer-use, node_repl, plugins,
  marketplaces, `desktop`, `notify`);
- keeps the mini's own `projects.*`, `hooks.state*` and
  `tui.model_availability_nux` tables;
- pins the file credential store.

The output is idempotent, and the file is rewritten only when the laptop's
config changed, so a `/model` choice made on the mini lasts until then.
`AGENTS.md` and `themes/` are plain links into the mirror.

**Accounts:**
- Add Claude accounts with `x-account-add <email>` as on the laptop, then
  `/login` on the first `x-<name>`.
- For Codex, don't use `cx-account-add`: it shares the laptop's raw config,
  which lacks the file credential store. Run
  `headroom accounts add --vendor codex --share-config <email>`. A bare
  `--share-config` links the mini primary's generated config.
- headroom 81c3045 reads `.credentials.json` only for non-primary accounts.
  So the Claude primary's board row says "credential unreadable", and
  `headroom check` FAILs `keychain[primary]`/`blob[primary]`. Launch routing
  and the Codex page are unaffected.

## planlab checkout

`~/dev/planlab/main` is a real clone (`gh repo clone planlab-ai/main`), not
part of the mirror. You work in it and pull it like any repo, and `p`/`pp`
reach it. Commits use a repo-local identity (`qiushi@planlab.ai` /
`qiushiyan`), as on the laptop. The `planlab` and `bench` launchers come
from each package's own install (`pnpm planlab:install`,
`cd bench && pnpm cli:install`), which bakes this checkout's absolute paths
in. Re-run the installs after moving the checkout.

Planlab's handoff briefs are their own clone, at the path `brief` derives from
this checkout: `gh repo clone planlab-ai/handoffs ~/dev/.handoffs/planlab-main`.
`brief start` pulls it before a pickup; `git -C ~/dev/.handoffs/planlab-main
pull --ff-only` refreshes it for a session that reads the files directly.
Where a brief lands and what `brief sync` publishes are the binary's rules,
so after a `brief` change on the laptop run `mini-sync` before the mini
writes to the clone rather than waiting for the timer: an older binary files
a brief where the new one reads another slug.

## Sync

`mini-sync` (`scripts/.local/bin/`) runs on the **laptop**. It is one-way,
and the laptop is the source of truth. **Never edit `~/dotfiles` on the
mini.** The next sync overwrites it, so a fix found there is made on the
laptop.

- **dotfiles**: `rsync --delete` of this repo to `~/dotfiles`. It sends
  everything git can see (tracked files plus untracked files that are not
  ignored) and `.git` itself, so the mini's `git status` matches the
  laptop's, uncommitted edits included. Ignored paths never leave the laptop:
  `ssh/`, `vpn-private/`, purchased upstream material, app runtime state,
  `node_modules`.
- **CLIs**: the compiled binaries `headroom envoy brief gwt` are copied from
  `~/.local/bin` (same arch and OS family), so the mini needs no Go and no
  source clones. `planlab` and `bench` are not copied: they are shims into a
  checkout, and the mini generates its own (§ planlab checkout).
- **Codex config**: regenerated as described in § Agent config.
- **Links**: `LINKS` in the script (`theme-set`, `toclip`, `browser-clip`,
  `mac`) are made links in the mini's `~/.local/bin`, pointing into the mirror. The
  `scripts` package is not stowed on the mini because it carries this
  laptop's `mini-sync` LaunchAgent.
- **Theme**: the laptop's theme name is applied by running the mini's own
  `theme-set`, which writes `~/.config/terminal-theme` and the gitignored
  Ghostty include there and reloads the mini's tmux. It runs only when the
  laptop's theme differs from the last one applied (recorded in
  `~/.local/state/mini-sync/theme` on the mini). A theme picked on the mini
  with `prefix t` therefore lasts until the laptop switches, as a `/model`
  choice does for the Codex config.
- **Token files**: `SECRETS` in the script (`~/.planlab/.env`,
  `~/.bench/.env`) are sent 600 inside 700 dirs. Only plain CLI API tokens
  belong on that list. OAuth logins (Claude Code, Codex, gh) rotate their
  refresh tokens, so two machines sharing one log each other out. A file
  deleted on the laptop stays on the mini.
- **Schedule**: `com.qiushi.mini-sync` (a LaunchAgent stowed from
  `scripts/Library/`) runs `mini-sync --quiet` at load and every hour.
  An unreachable mini is a silent no-op, and real failures go to
  `~/Library/Logs/mini-sync.log`. Run `mini-sync` by hand for a change you
  want there now; `-n` previews it.

## Steward host

Since 2026-09-22 this mini runs the steward's production host, moved from the
shared `macmini` (planlab `docs/steward/architecture.md` § Wiring is the
design; `/pl-deploy-steward` redeploys it). It runs in this same account, so
it keeps its own **session home** apart from mine:

| path | whose | what |
|---|---|---|
| `~/.config/steward/` | steward | config, token file (`env`, 600), prelude and wrapper; `paused` is the operator's pause |
| `~/.local/state/steward/` | steward | the store, journal, evidence, launchd logs, deploy records |
| `~/planlab` | steward | its checkout (not `~/dev/planlab/main`, which is mine) |
| `~/steward-worktrees/` | steward | one worktree per task |
| `~/.steward-home/` | steward | the `HOME` every steward process runs under: its own `.claude` (settings, skills link, login), `.codex` (config, login), pinned `dotfiles` clone, `.gitconfig`, `Library/pnpm` (obelisk), `.local/bin/{claude,envoy,steward,planlab}` |
| `/Library/LaunchDaemons/ai.planlab.steward.{tick,digest,sweep}.plist` | root | the three daemons, `UserName` qiushiyan |

- **mini-sync doesn't touch any of it.** Its targets (`~/dotfiles`,
  `~/.codex/config.toml`, the four CLIs in `~/.local/bin`, the token files,
  theme) are mine. The steward's dotfiles are a real clone at the pin in
  `services/steward/host/versions.json`, never this mirror. A skill edit
  reaches the steward only by a pin bump and a deploy.
- **Its logins live in files** in the session home, because the Keychain is
  locked outside the GUI. To log in again:
  `ssh -t qiushi-mini 'HOME=~/.steward-home ~/.steward-home/.local/bin/claude /login'`
  (the same with `codex login`).
- **Not a trust boundary.** Driven sessions run with permissions bypassed as
  my UID; the session home keeps configuration apart, nothing more.
- **Status:** `ssh qiushi-mini '~/.steward-home/.local/bin/steward status'`;
  pause with `steward pause`, resume with `steward unpause`.
- **FileVault:** after an unplanned restart the daemons wait, like
  Tailscale, until someone unlocks the mini.
