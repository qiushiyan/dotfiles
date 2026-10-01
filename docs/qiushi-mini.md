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
| tmux | 3.7c | `qiushiyan/local/tmux-popupfix`, as on the laptop: a `brew tap-new --no-git` tap holding `docs/tmux-popupfix.rb`; stock `tmux` stays installed, unlinked | `docs/tmux-popup-patch.md` § Upgrading and activating |
| nvm | 0.40.8 | upstream `install.sh` (nvm rejects Homebrew installs) → `~/.nvm` | re-run installer with the new tag |
| node | v24.21.0 LTS (`default` → `lts/*`) | `nvm install --lts` | `nvm install --lts && nvm alias default 'lts/*'`; then move the versioned node path in Portless's service and slack-digest's agent (§ Personal jobs) |
| pnpm | 11.27.1 | `get.pnpm.io/install.sh` with `PNPM_VERSION=11.27.1` → `~/Library/pnpm`; pinned to 11 to match the laptop, not the Rust-port 12 | `pnpm self-update` |
| Claude Code | 2.1.280 | native `claude.ai/install.sh` → `~/.local/bin/claude` | auto-updates |
| Codex CLI | 0.155.1 | `chatgpt.com/codex/install.sh` → `~/.local/bin/codex` | `codex update` |
| Python | 3.14.7 | `uv python install 3.14` (versioned `python3.14` only) | `uv python upgrade` |
| AWS CLI | 2.37.3 | `brew install awscli`; `~/.aws/config` copied from the laptop (SSO profiles only; no `credentials`) | `brew upgrade awscli`; re-copy `config` after a profile change |
| Postgres | 18.6 + pgvector 0.8.6 | `brew install postgresql@18 pgvector`, run by `brew services`; `ALTER SYSTEM` sets `file_copy_method = 'clone'` and `max_connections = 160`, planlab's lane settings | `brew upgrade`; a formula upgrade can drop pgvector (planlab `running-cases.md`) |
| poppler | 26.09.0 | `brew install poppler` (`pdftotext` for planlab `debug:run` document reads) | `brew upgrade` |
| agent-browser | 0.38.1 | pnpm global + `agent-browser install` (Chrome under `~/.agent-browser`), per `docs/agent-skills.md` | same doc |
| obelisk | the laptop's (0.2.6-rc.0 on 2026-10-01) | pnpm global `@obelisk-apps/cli`, for the `obelisk` skill; index `~/.obelisk` covers the mini's own sessions | `mini-sync` keeps it at the laptop's version (§ Sync) |
| portless | 0.15.6 | `pnpm add -g portless@0.15.6`, the version planlab's `local-dev.md` pins; `sudo portless service install` + `sudo portless trust` from the mini's screen (§ planlab checkout) | follow that pin |

Personal CLIs (headroom, envoy, brief, gwt, gopen, cout) come from the laptop through
`mini-sync` (§ Sync); Ghostty and its fonts are in § Ghostty on the mini.
Not installed: rust, Docker, other GUI apps.

## Shell

The `zsh`, `tmux` and `ohmyposh` packages are stowed as on the laptop
(`docs/zsh.md` § Machines). What is about being the mini lives in the tracked
`zsh/.config/zsh/hosts/mini.zsh`: edit it on the laptop, and `mini-sync`
carries it. The traps particular to the mini:

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
  tmux plugins are gitignored clones in the mirror's
  `tmux/.config/tmux/plugins/`, which `mini-sync` leaves alone. After a plugin
  update on the laptop, run `prefix I`/`prefix U` on the mini too.
- **tmux bindings:** `prefix T` (sesh) and `prefix b` (terminal-browser) call
  laptop-only tools and fail here. `prefix t` switches themes through the
  mini's own `theme-set` (§ Sync); `prefix y`/`Y` and `cout` copy through
  `toclip`, so over SSH they reach the laptop clipboard (§ Clipboard and
  attach).

**Machine badge:** `PROMPT_MACHINE=mini`, from `hosts/mini.zsh`, marks the
prompt, the tmux status bar and the Ghostty window title (`mini · <session>:…`);
the laptop leaves it unset and stays unmarked. The tmux server takes the
variable from the shell that started it, so a server started any other way has
no badge until the variable is set in it.

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
  showing the pane. Over SSH, nvim's `y` copies to both the laptop (OSC 52)
  and the mini's pasteboard, and `p` reads what mini tools copied, such as
  `brief start`'s pointer, without an OSC 52 read prompt (`options.lua`).
- **Links**: open them with **Cmd+Shift+click**. Ghostty opens OSC 8 links
  on Cmd-click, and Shift bypasses tmux's mouse capture. sshd doesn't forward
  `TERM_PROGRAM`, so `hosts/mini.zsh` sets `FORCE_HYPERLINK=1` for SSH sessions;
  without it Claude Code prints plain-text URLs.
- **Ctrl-click in Claude Code** is its own click handler, which runs
  `$BROWSER` (else `open`) on the host, the mini. `hosts/mini.zsh` sets
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
id and the whole history.

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
- Skills linked from other laptop projects dangle on the mini: `explain-diff`
  (absolute `/Users/qiushi` path), `greenflag-*` (resolve once `~/dev/greenflag`
  exists), `read-email`/`write-email` and `terminal-browser` (laptop-only).
- The hooks and the statusline call `~/.config/tmux/scripts/*`, which the
  stowed `tmux` package provides (§ Shell). Those scripts no-op outside tmux.
- A setting changed on the mini (`/config`, the `/model` default) writes
  through the link into the mirror and is lost at the next sync.

**Context7:** `find-docs` runs `npx ctx7@latest` (node is in § Toolchain),
and Codex's context7 MCP server reads the same key. The mini's `~/.secrets`
(600, sourced by `.zshrc` as on the laptop) holds only the laptop's
`CONTEXT7_API_KEY` line, copied by hand on 2026-09-27. mini-sync doesn't
carry it, so after rotating the key, copy the line again.

**Codex:** `~/.codex/config.toml` is **generated** from the laptop's by
`mini-sync` (what travels: `scripts/.local/share/dotfiles/mini-codex-config.py`),
not linked, because Codex writes project and hook trust into it at runtime.
Each sync rewrites it whenever it differs from what the laptop's config
derives, so a setting changed on the mini outside the runtime-owned tables, a
`/model` choice included, is reverted within the hour. `AGENTS.md` and `themes/` are plain links
into the mirror.

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
part of the mirror. You work in it and pull it like any repo; `p` jumps to it,
and `pp` (`zsh/.config/zsh/nav.zsh`) pulls it and the handoff briefs clone
(below) here and on the laptop, all four in parallel; `pp --cd` then enters
the checkout.
Commits use a repo-local identity (`qiushi@planlab.ai` /
`qiushiyan`), as on the laptop. The `planlab` and `bench` launchers come
from each package's own install (`pnpm planlab:install`,
`cd bench && pnpm cli:install`), which bakes this checkout's absolute paths
in. Re-run the installs after moving the checkout.

It is set up for `pl-loopy-verify`: the tools are in § Toolchain, and
`application/setup/bootstrap.sh` built the `planlab` home database. The
ignored env files (`application/.env.development.local`,
`loopy-stress/.env.smoke.local`) and the lane identity
(`~/.config/planlab/dev.json`, `lane me`'s file) are copies of the laptop's,
all mode 0600. Re-copy them after a credential rotation. Bootstrap's own env
file is kept as `.env.development.local.bootstrap`.

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
`pp` pulls main into both machines' clones along with the checkout, from
either machine; a briefs clone on another branch fails its pull. No pull may
prompt, so one that needs a password fails. Where a brief lands and what `brief sync`
publishes are the binary's rules, so after a `brief` change on the laptop run
`mini-sync` before the mini writes to the clone rather than waiting for the
timer: an older binary files a brief where the new one reads another slug.

## Sync

`mini-sync` (`scripts/.local/bin/`) runs on the **laptop**. It is one-way,
and the laptop is the source of truth. **Never edit `~/dotfiles` on the
mini.** The next sync overwrites it, so a fix found there is made on the
laptop. The script's header and its `BINS`, `SECRETS`, `ENGINES` and `LINKS`
lists say what it carries: the working tree as git sees it (uncommitted edits
included, ignored paths never), the Codex config (§ Agent config), engine
versions, links into the mirror for the scripts the mini runs by name, and
the laptop's theme, applied only when the laptop switches, so a `prefix t`
pick on the mini lasts until then.

- **Compiled CLIs are copied**, the binaries named in `BINS`, so the mini
  needs no Go and no source clones. `planlab` and `bench` are not: they are
  shims into a checkout, and the mini generates its own (§ planlab checkout).
- **Engines are version-matched**, the pnpm globals named in `ENGINES`
  (`@obelisk-apps/cli`): a skill in the mirror is written against the
  laptop's engine, so when the mini's version differs, the mini runs
  `pnpm add -g` for the laptop's exact version. They are node packages, so
  they are installed, not copied like `BINS`. A new entry installs on the
  next sync; an engine absent on the laptop is skipped.
- **Token files**: only plain CLI API tokens belong on `SECRETS`, as a file
  or a directory with the private config that travels beside them. OAuth
  logins (Claude Code, Codex, gh) rotate their refresh tokens, so two
  machines sharing one log each other out. A file deleted on the laptop stays
  on the mini. Parents are created 700 when missing and otherwise left alone,
  so `~/.config` keeps its mode.
- **Schedule**: `com.qiushi.mini-sync` (a LaunchAgent stowed from
  `scripts/Library/`) runs `mini-sync --quiet` at load and every hour.
  An unreachable mini is a silent no-op, and real failures go to
  `~/Library/Logs/mini-sync.log`. Run `mini-sync` by hand for a change you
  want there now; `-n` previews it.

## Personal jobs

- **slack-digest** — the daily Slack briefing (`~/dev/slack-digest` on the
  laptop, not cloned here). `mini-sync` carries the binary and
  `~/.config/slack-digest` (config and workspace notes) and slackkit's
  token store `~/.config/slack` (read by `slack-digest` and the `slack`
  CLI, also carried); the LaunchAgent
  `com.qiushi.slack-digest` runs it at 08:30 and is installed from the
  laptop with `make -C ~/dev/slack-digest install-mini`. Its ledger and
  digests live only here, in `~/.local/share/slack-digest/`; log
  `~/Library/Logs/slack-digest.log`. The agent's PATH names nvm's node by
  version, for planlab's CLI; after a node upgrade, edit
  `launchd/com.qiushi.slack-digest.plist` and re-run `install-mini`, or
  planlab's briefing loses its deploy state. The ledger and the run records
  stay here too; from the laptop, every `slack-digest` subcommand (items,
  replies, replay, tracing) reaches them over ssh. The repo's `DESIGN.md`
  § Where it runs has the rest.

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

- **mini-sync doesn't touch any of it.** Its targets (`~/dotfiles`,
  `~/.codex/config.toml`, the `BINS` and `LINKS` in `~/.local/bin`, the token
  files, theme) are mine. The steward's dotfiles are a real clone at the pin in
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
