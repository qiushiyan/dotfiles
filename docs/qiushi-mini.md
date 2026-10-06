# Office Mac mini (`ssh qiushi-mini`)

My own Mac mini, kept in the office. At the desk it is the office desktop
(§ At the desk); from the laptop it is reached over the company tailnet, in or
out of the office. It is mine to configure. Facts below were collected
2026-09-22.

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

## At the desk

The mini drives the office monitor (LG 32UN880K-B, 32" 4K over USB-C) at
"looks like 3008 × 1692", the text size of the laptop's 27" at 2560 × 1440.
The NuPhy keyboard and the MX Anywhere 3S are both paired to it over
Bluetooth, the mouse on its own Easy-Switch channel. When the laptop is on the
desk, Universal Control shares them with it.

- **Keyboard and mouse stay on the same Mac.** Universal Control treats the
  Mac whose devices last produced input as the source. With the keyboard on
  one Mac and the mouse on the other, every keystroke and every mouse move
  swaps the source, and keys land on the wrong machine.
- **The keyboard follows a click, never an app coming to the front.** An app
  launched by hotkey on the other Mac gets no keys until it is clicked once.
  Settings: Displays → Advanced → "Link to Mac or iPad", all options on; the
  laptop arranged to the left under Displays → Arrange, or both of the mini's
  side edges lead to it.
- **The link needs both displays on.** A closed lid, a sleeping display or a
  resolution change marks that Mac unavailable, and the Displays pane shows
  no second machine. Wake both, then push the pointer through the edge or pick
  the laptop under Displays → "+" → Link Keyboard and Mouse. The agent
  (`UniversalControl`, launchd label `com.apple.ensemble`) cannot be
  restarted from a shell: SIP refuses `launchctl kickstart`. To diagnose,
  read its log (`/usr/bin/log`, because zsh has a `log` builtin): category
  `EVNT` records `Current Source Device` and key-focus moves, `SYNC` and
  `DISC` record `Device Unavailable`.

  ```bash
  /usr/bin/log show --last 15m --info --debug --style compact \
    --predicate 'subsystem == "com.apple.universalcontrol"'
  ```
- **A link that stays down with both Macs awake on the desk: restart the
  mini's `rapportd` and `sharingd`.** From the laptop:

  ```bash
  ssh mini 'killall rapportd sharingd'
  ```

  launchd starts both again and the link is up within seconds; `Connection
  Ready` in the log above confirms it. The hazard: the mini's `rapportd` can
  lose the laptop as a Bluetooth device without finding it again, and then
  never asks it to come up on AWDL. The mini's own connect times out after
  15 s, and the laptop's incoming connect waits behind it, so both Macs log
  `RPErrorDomain -6722` while the firewall, the LAN and both `awdl0`
  interfaces are fine. The line that tells this case from others is in the
  mini's `rapportd` log:
  `Could not find device to target authTag advertisement to`.

  ```bash
  ssh mini '/usr/bin/log show --last 5m --info --debug --style compact \
    --predicate "process == \"rapportd\" AND category == \"CLinkD\"" \
    | grep -E "authTag|timed out"'
  ```

  `killall UniversalControl` leaves the agent running and changes nothing.
- **The Apple Account on the mini puts iCloud within reach of the
  permission-bypassed agents that run here → iCloud Keychain and iCloud Drive
  stay off.** Universal Control needs only the account and Handoff.
- **Screen Sharing is on**, so `open vnc://qiushi-mini.local` (or the tailnet
  name) from the laptop gives the desktop without the desk.
- **Hyper + letter launches are Raycast hotkeys, held in Raycast's own
  database; Karabiner only turns Caps Lock into the hyper modifier.** On a
  machine where the launches do nothing, import Raycast's settings: Export
  Settings & Data on the laptop, Import Settings & Data here. Over
  Bluetooth the NuPhy is one combined keyboard-and-pointer device, which
  Karabiner modifies only through its device entry in `karabiner.json`
  (vendor 2007, `ignore: false`); over USB it enumerates as separate keyboard
  and pointer devices and needs no entry.
- **Through Universal Control a modifier arrives once per keyboard of the
  source Mac → ctrl+space reaches macOS as F18.** Karabiner's virtual
  keyboard stands beside the NuPhy, Universal Control mirrors both, and the
  other Mac gets every modifier press and release on each mirror. "Select the
  previous input source" commits when the modifier is released, so bound to
  ctrl+space it switches there and back within 20 ms and the input source
  looks stuck. The rule in `karabiner.json` sends F18 for ctrl+space, which
  has no modifier to release; each Mac binds the shortcut to F18 and keeps
  ctrl+space on "select next source" for a keyboard Karabiner does not modify
  (`docs/migration-app-state.md` §5c has the commands). Any other shortcut
  that acts on a modifier's release is exposed the same way. The rule can go
  when one modifier press on the mini's keyboard logs one event on the laptop
  instead of a pair a millisecond apart:

  ```bash
  /usr/bin/log show --last 1m --info --debug --style compact \
    --predicate 'process == "WindowServer" AND eventMessage CONTAINS "kCGSEventFlagsChanged"'
  ```

## Toolchain

A deliberately small subset of the laptop: no `bootstrap.sh`, no Brewfile.
Add a tool when a task on the mini needs it, not to match the laptop.

| tool | version | how | update |
|---|---|---|---|
| Go | 1.27.1 | `brew install go` | `brew upgrade go` |
| 1Password CLI | 2.40.0 | `brew install --cask 1password-cli` (`op`) | `brew upgrade --cask` |
| CLI tools | — | `brew install gh tmux ripgrep fd fzf jq lazygit zoxide uv stow rsync unison git-lfs git-delta coreutils bat difftastic pngpaste` (`unison` is `twin`'s reconciler; `git-delta` is the stowed git config's pager; `coreutils`, `bat` and `difftastic` because `aliases.zsh`/`git.zsh` call `gls`, `bat`, `difft`; `pngpaste` because nvim's image-aware Ctrl+V reads the pasteboard only through it) | `brew upgrade` |
| tmux | 3.7c | `qiushiyan/local/tmux-popupfix`, as on the laptop: a `brew tap-new --no-git` tap holding `docs/tmux-popupfix.rb`; stock `tmux` stays installed, unlinked | `docs/tmux-popup-patch.md` § Upgrading and activating |
| nvm | 0.40.8 | upstream `install.sh` (nvm rejects Homebrew installs) → `~/.nvm` | re-run installer with the new tag |
| node | v24.21.0 LTS (`default` → `lts/*`) | `nvm install --lts` | `nvm install --lts && nvm alias default 'lts/*'`; then move the versioned node path in Portless's service and slack-digest's agent (§ Personal jobs) |
| pnpm | 11.27.1 | `get.pnpm.io/install.sh` with `PNPM_VERSION=11.27.1` → `~/Library/pnpm`; pinned to 11 to match the laptop, not the Rust-port 12 | `pnpm self-update` |
| Claude Code | 2.1.280 | native `claude.ai/install.sh` → `~/.local/bin/claude` | auto-updates |
| Codex CLI | 0.155.1 | `chatgpt.com/codex/install.sh` → `~/.local/bin/codex` | `codex update` |
| Python | 3.14.7 | `uv python install 3.14` (versioned `python3.14` only) | `uv python upgrade` |
| AWS CLI | 2.37.3 | `brew install awscli`; `~/.aws/config` is carried by `twin` (SSO profiles only; no `credentials`) | `brew upgrade awscli` |
| Postgres | 18.6 + pgvector 0.8.6 | `brew install postgresql@18 pgvector`, run by `brew services`; `ALTER SYSTEM` sets `file_copy_method = 'clone'` and `max_connections = 160`, planlab's lane settings | `brew upgrade`; a formula upgrade can drop pgvector (planlab `running-cases.md`) |
| poppler | 26.09.0 | `brew install poppler` (`pdftotext` for planlab `debug:run` document reads) | `brew upgrade` |
| agent-browser | 0.38.1 | pnpm global + `agent-browser install` (Chrome under `~/.agent-browser`), per `docs/agent-skills.md` | same doc |
| obelisk | the manifest's pin | pnpm global `@obelisk-apps/cli`, for the `obelisk` skill; index `~/.obelisk` holds the mini's own sessions, and the skill asks it and the laptop's together (`docs/claude-sessions-store.md`) | change the pin, then `twin tools install obelisk` (`docs/twin.md`) |
| portless | 0.15.6 | `pnpm add -g portless@0.15.6`, the version planlab's `local-dev.md` pins; `sudo portless service install` + `sudo portless trust` from the mini's screen (§ planlab checkout) | follow that pin |

Personal CLIs are built here, from the clones in `~/dev`, by
`twin tools install` (`docs/twin.md`); Ghostty and its fonts are in § Ghostty
on the mini. Karabiner-Elements is installed from its pkg, which needs `sudo`
and so the mini's own screen or a terminal there. The `karabiner` package is
stowed, so `~/.config/karabiner` is a folder link into this repository's
clone, and a change made in Karabiner's UI on the mini is an uncommitted edit
there, to commit and push like any other. Karabiner logs
`Load …/karabiner.json` in `/var/log/karabiner/core_service.log` when it
takes an edit to the file; the laptop's can miss one, and
`launchctl kickstart -k gui/$(id -u)/org.pqrs.service.agent.karabiner_console_user_server`
there makes it reread. TabType is the release
`twin tools install tabtype` installs; its first launch needs the mini's
screen for the Accessibility prompt, which macOS ties to the release's
signature. The other desk apps, such as Raycast, 1Password, Arc, Slack and
OrbStack, are installed by hand, as Homebrew casks or vendor downloads, and
carry no config from this repo.
Not installed: rust.

## Shell

The `zsh`, `tmux` and `ohmyposh` packages are stowed as on the laptop
(`docs/zsh.md` § Machines). What is about being the mini lives in the tracked
`zsh/.config/zsh/hosts/mini.zsh`. The traps particular to the mini:

- **`aws sso login`:** `hosts/mini.zsh` adds `--use-device-code`, because the
  default flow redirects to a localhost listener on the mini that a laptop
  browser can't reach. Over SSH, `BROWSER` sends the URL to the laptop
  clipboard. For a session with the full 8 hours, run `aws-login`
  (`docs/aws-sso.md`).
- **Locale on reattach:** the laptop's ssh sends no `LANG`, and tmux decides
  per client, when it attaches, whether the client is UTF-8. A client attached
  from a shell without a UTF-8 locale draws every non-ASCII glyph
  (status-bar separators, icons) as `_` until it detaches and attaches again.
- **Plugins are clones:** oh-my-zsh, zsh-autosuggestions and
  zsh-syntax-highlighting are shallow clones at the laptop's paths, and the
  tmux plugins are gitignored clones in `tmux/.config/tmux/plugins/`, each
  machine's own. After a plugin update on one machine, run `prefix I`/`prefix U`
  on the other too.
- **tmux bindings:** `prefix T` (sesh) and `prefix b` (terminal-browser) call
  laptop-only tools and fail here. `prefix t` switches this machine's theme
  alone (`docs/theming.md`); `prefix y`/`Y` and `cout` copy through
  `toclip`, so over SSH they reach the laptop clipboard (§ Clipboard and
  attach).

**Machine badge:** `PROMPT_MACHINE=mini`, from `hosts/mini.zsh`, marks the
prompt, the tmux status bar and the Ghostty window title (`mini · <session>:…`);
the laptop leaves it unset and stays unmarked. The tmux server takes the
variable from the shell that started it, so a server started any other way has
no badge until the variable is set in it.

**Git:** the `git` package is stowed, so the identity, the global ignore
file and the per-folder `includeIf` blocks are the laptop's;
`~/.gitconfig.personal`, which they read, is carried by `twin`. GitHub auth
goes through gh's credential helper over HTTPS, so no GitHub SSH key lives on
the mini.

**Neovim:** the `nvim` package is stowed. Plugins install
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
  showing the pane. Over SSH, nvim's `y` copies to both the laptop (OSC 52)
  and the mini's pasteboard, and `p` reads what mini tools copied, such as
  `brief start`'s pointer, without an OSC 52 read prompt (`options.lua`).
- **Links**: open them with **Cmd+Shift+click**. Ghostty opens OSC 8 links
  on Cmd-click, and Shift bypasses tmux's mouse capture. sshd doesn't forward
  `TERM_PROGRAM`, so `hosts/mini.zsh` sets `FORCE_HYPERLINK=1` for SSH sessions;
  without it Claude Code prints plain-text URLs.
- **Ctrl-click in Claude Code** is its own click handler, which runs
  `$BROWSER` (else `open`) on the host, the mini, as `gh --web` and `gopen`
  do. `hosts/mini.zsh` sets `BROWSER=~/.local/bin/browser-clip` in every
  shell, and the shim asks `toclip` per URL: with an ssh client on the pane's
  session the URL goes to the laptop clipboard instead of the mini's Safari,
  otherwise it opens on the mini (§ Clipboard and attach). A check at shell
  start goes stale: a pane keeps the environment it was created with, and
  tmux gives new panes the environment of the shell that started the server,
  so after a server started over ssh every pane would send URLs away even at
  the desk.

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
| `cout`, `prefix o` | either | a command and its output, through `toclip` |
| `prefix y` / `prefix Y` | either | the pane's path, through `toclip` |
| `cpwd` | either | the shell's working directory, through `toclip` |
| `frommini` | laptop | the mini tmux's newest buffer → laptop clipboard |
| `frommini -g` | laptop | the mini's GUI pasteboard, text or image → laptop clipboard |
| `tomini` | laptop | the laptop clipboard, text or image → the mini's pasteboard |

- **OSC 52 is fire-and-forget.** A terminal that ignores it, such as macOS
  Terminal.app, drops the copy without an error. The text still sits in the
  mini tmux's newest buffer, so `frommini` recovers it.
- **`toclip` aims at the ssh client**, not the client tmux picks by activity,
  so a session also shown on the Screen Sharing Ghostty still copies to the
  laptop; an oversize payload stays in the tmux buffer for `frommini`
  (`scripts/.local/bin/toclip`, pinned by `test-toclip.sh`).
- **Images:** a screenshot sent with `tomini` becomes the mini's pasteboard
  image, which Claude Code there pastes with Ctrl+V; `tomini` prints the path
  of its file copy. `scripts/.local/share/dotfiles/pasteboard` owns the
  text-or-image rules for both ends.
- **Screen Sharing shares its own clipboard** with the laptop while its
  window is open (Edit → Use Shared Clipboard). That is separate from all of
  the above.

## Moving a Claude session

Claude Code has no native handoff between local machines (Remote Control
steers a session that stays on its host). `claude-tomini`
(`scripts/.local/bin/`, laptop only) moves one by hand, so work started on the
laptop keeps running on the mini after the laptop leaves:

```bash
claude-tomini -n            # newest session for $PWD; check both ends, change nothing
claude-tomini --start <id>  # move it and resume it in mini tmux session <worktree name>
```

It moves the **code** (the worktree's branch, pushed straight into the mini's
clone and checked out at the same `$HOME`-relative path) and the
**transcript**; the mini resumes with `x --resume <id>`, keeping the session
id and the whole history. The session's **notes** from the `prefix S` board
(`tmux/.config/tmux/scripts/steps.md`) go with it, merged into any notes the
mini already holds for that id, so a repeated move doubles nothing.

- **Preconditions it enforces:** the session is closed on the laptop, the
  worktree is clean, and the session's cwd is under `$HOME`. The home dirs
  differ (`/Users/qiushi` vs `/Users/qiushiyan`), so paths map by that prefix.
- **Never overwrites work on the mini.** An existing worktree or branch there
  only fast-forwards, and the script refuses when the mini already holds this
  transcript, since that may be a previous move's continuation; `--force`
  overrides.
- **What does not come along:** gitignored files (`.env`, `node_modules`;
  the script lists them), background tasks and monitors, and the session's
  `/private/tmp` scratchpad. Earlier turns still name laptop paths; the resume
  adds a system-prompt note about the move.
- **The mini's first turn rewrites the whole prompt cache**, a one-time cost
  per move that no script change avoids: the working directory alone breaks
  the cache match.
- **The laptop copy stays.** Resuming it too forks the conversation. To
  come back, copy the mini's newer `.jsonl` over it by hand; there is no
  reverse script yet.

## Reaching the laptop

From the mini, the laptop is `ssh qiushi-mac` (or `ssh mac`): tailnet node
`qiushis-macbook-pro`, user `qiushi`, with Remote Login on. The alias lives in
the mini's own `~/.ssh/config`, which is untracked. `mac` is the
mirror image of `mini`: it attaches the laptop's most recently active tmux
session. It is the same script, which picks the host by the name it runs as.
Copies go over the same alias: `scp mac:~/path .`, `rsync -a mac:~/dir/ dir/`.

**Git on the laptop, driven from here, needs gh's token in a file.** `twin`
runs the laptop's pulls and fetches over `ssh mac` (`pp`,
`twin repos pull --both`), and that git authenticates
over HTTPS with gh's credential helper, and an ssh session cannot open the
laptop's login Keychain. So the laptop keeps the token in
`~/.config/gh/hosts.yml`, as the mini does (§ Agent config): after a
`gh auth login` there, log in with `--insecure-storage`, or the laptop leg
fails with `could not read Username for 'https://github.com'`.

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

The app is installed by hand. The `ghostty` package is stowed, so
`~/.config/ghostty` is a folder link into this repository's clone, as on the
laptop. `theme-set`, run from `prefix t`, writes the theme include
(`auto/theme.ghostty`) and `~/.config/terminal-theme`. Ghostty reloads config
only with ⌘⇧, or a restart.

**Fonts** are the laptop's casks, `font-jetbrains-mono-nerd-font` and
`font-sarasa-gothic`, installed into `~/Library/Fonts`. A cask's files can
land without being registered: CoreText then lists neither family and Ghostty
falls back to PingFang SC for CJK, until the files are registered once with
`CTFontManagerRegisterFontURLs(…, .user, …)` (what Font Book's Install does).
After a font cask, verify with `ghostty +show-face --cp=0x4E2D`; it must name
`Sarasa Term SC`.

## Agent config

**Auth:** the login Keychain is locked in SSH sessions, so every login lives
in a file:
- Claude Code falls back to `~/.claude/.credentials.json`.
- Codex is pinned to `cli_auth_credentials_store = "file"`.
- gh falls back to plaintext `hosts.yml`.

Each is logged in on the mini itself, never copied from the laptop: OAuth
logins rotate their refresh tokens, so machines sharing one log each other
out.

**Claude Code:** the `claude` package is stowed. `~/.claude` and `~/.agents`
are real dirs, and `settings.json`, `CLAUDE.md`, hooks, mods, rules, commands,
agents and skills link into this repository's clone. Codex reads the same
skills through `~/.agents/skills`. The `lessons` and `tabtype` packages are
stowed for what those sessions read: the reference material skills cite under
`~/.config/lessons`, and the snippet definitions `claude-steps` matches
prompts against for the session board (`prefix S`,
`tmux/.config/tmux/scripts/steps.md`). The `claude-steps` package carries the
board's labels.
- The hooks and the statusline call `~/.config/tmux/scripts/*`, which the
  stowed `tmux` package provides (§ Shell). Those scripts no-op outside tmux.
- A setting changed on the mini (`/config`, the `/model` default) writes
  through the link into the clone, where it is an uncommitted edit to
  `claude/.claude/settings.json`: commit and push it, or discard it.

**Context7:** `find-docs` runs `npx ctx7@latest` (node is in § Toolchain),
and Codex's context7 MCP server reads the same key: `CONTEXT7_API_KEY` in
`~/.secrets.shared`, which `twin` carries and `.zshrc` sources.

**Codex:** `~/.codex/config.toml` is rendered here by `twin dotfiles apply`
from the shared source and `twin/.config/twin/codex/mini.toml`, which pins
the file credential store (`docs/twin.md` § Codex config). `AGENTS.md` and
`themes/` are links into the clone.

**Accounts:**
- Add Claude accounts with `x-account-add <email>` as on the laptop, then
  `/login` on the first `x-<name>`.
- Add Codex accounts with `cx-account-add <email>`, which shares the primary
  home's rendered config, then `cx-<name> login`.

## planlab checkout

`~/dev/planlab/main` is a clone (`gh repo clone planlab-ai/main`), registered
in `twin`'s manifest as `planlab`. `p` jumps to it, and `pp`
(`zsh/.config/zsh/nav.zsh`) fast-forwards it and the handoff briefs clone
(below) here and on the laptop; `pp --cd` then enters the checkout.
Commits use a repo-local identity (`qiushi@planlab.ai` /
`qiushiyan`), as on the laptop. The `planlab` and `bench` launchers come
from each package's own install (`pnpm planlab:install`,
`cd bench && pnpm cli:install`), which bakes this checkout's absolute paths
in. Re-run the installs after moving the checkout.

It is set up for `pl-loopy-verify`: the tools are in § Toolchain, and
`application/setup/bootstrap.sh` built the `planlab` home database. The
ignored env files (`application/.env.development.local`, the loopy-stress
smoke file) and the lane identity (`~/.config/planlab/dev.json`, `lane me`'s
file) are carried by `twin` (`docs/twin.md` § Carried files), all mode 0600,
so a rotation on either machine reaches the other. Bootstrap's own env file
is kept as `.env.development.local.bootstrap`.

`lane up` needs the Portless HTTPS proxy on 443. As on the laptop, it runs as
the boot service `/Library/LaunchDaemons/sh.portless.proxy.plist`, which
`sudo portless service install` writes with the current nvm node's absolute
path. A node upgrade therefore needs the install re-run. The proxy's CA
(`~/.portless/ca.pem`) is trusted in the System keychain, which agent-browser's
Chrome requires (without it: `ERR_CERT_AUTHORITY_INVALID`).
`sudo portless trust` works only from the mini's own screen (Screen Sharing
is fine). macOS asks to confirm a trust-settings change even under sudo, so
over SSH it fails with "Permission denied".

Planlab's handoff briefs are their own clone, at the path `brief` derives from
this checkout: `gh repo clone planlab-ai/handoffs ~/dev/.handoffs/planlab-main`.
`brief start` pulls it before a pickup; `git -C ~/dev/.handoffs/planlab-main
pull --ff-only` refreshes it for a session that reads the files directly.
`pp` fast-forwards both machines' clones along with the checkout, from either
machine; the manifest allows the briefs clone only `main`, so one on another
branch is refused. Where a brief lands and what `brief sync` publishes are
the binary's rules, so after a `brief` change, install it on both machines
(`twin tools install brief` on each) before the other writes to the clone:
an older binary files a brief where the new one reads another slug.

## Personal jobs

- **slack-digest** — the daily Slack briefing (`cmd/slack-digest` in
  `~/dev/slackkit`, built from the clone here by
  `twin tools install slackkit`). `twin` carries `~/.config/slack-digest`
  (config and workspace notes) and slackkit's token store `~/.config/slack`
  (read by `slack-digest` and the `slack` CLI) between the machines. The
  LaunchAgent `com.qiushi.slack-digest` runs it at 08:30, and
  `com.qiushi.slack-digest-listen` makes a pass every minute over what he
  did in the digest DMs (an emoji on an item, a command, a reply the
  briefing's judge answers). Both are installed and reloaded here with
  `make -C ~/dev/slackkit agents`, which is also how a newly installed
  binary is picked up. Its ledger and digests live only here, in
  `~/.local/share/slack-digest/`; logs `~/Library/Logs/slack-digest.log` and
  `slack-digest-listen.log`. Both agents' PATH names nvm's node by version,
  for planlab's CLI; after a node upgrade, edit both plists in
  `cmd/slack-digest/launchd/` and re-run `make agents`, or planlab's
  briefing loses its deploy state. From the laptop, every `slack-digest`
  subcommand (items, replies, replay, tracing) reaches the ledger and the
  run records over ssh.
  `~/dev/slackkit/docs/digest/operations.md` § Where it runs has the rest.
- **The hourly `twin tick` and the daily snapshot** — this repository's
  `launchd-mini/` package (`docs/twin.md` § The hourly tick;
  `docs/recovery.md` § Local snapshots).

## Steward host

This mini runs the steward's production host (planlab
`docs/steward/architecture.md` § Wiring is the design; `/pl-deploy-steward`
redeploys it). It runs in this same account, so it keeps its own **session
home** apart from mine:

| path | whose | what |
|---|---|---|
| `~/.config/steward/` | steward | config, token file (`env`, 600), prelude and wrapper; `paused` is the operator's pause |
| `~/.local/state/steward/` | steward | the store, journal, evidence, launchd logs, deploy records |
| `~/planlab` | steward | its checkout (not `~/dev/planlab/main`, which is mine) |
| `~/steward-worktrees/` | steward | one worktree per task |
| `~/.steward-home/` | steward | the `HOME` every steward process runs under: its own `.claude` (settings, skills link, login), `.codex` (config, login), pinned `dotfiles` clone, `.gitconfig`, `Library/pnpm` (obelisk), `.local/bin/{claude,envoy,steward,planlab}` |
| `/Library/LaunchDaemons/ai.planlab.steward.{tick,digest,sweep}.plist` | root | the three daemons, `UserName` qiushiyan |

- **`twin` doesn't touch any of it.** What `twin` manages is mine: the
  clones under `~/dev` and `~/dotfiles`, `~/.codex/config.toml`, the CLIs in
  `~/.local/bin`, the carried files. The steward's dotfiles are a separate
  clone at the pin in `services/steward/host/versions.json`. A skill edit
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
