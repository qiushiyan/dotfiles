# Office Mac mini (`ssh qiushi-mini`)

My own Mac mini, kept in the office and reached over the company tailnet from
the laptop, in or out of the office. Unlike the shared `macmini`
(`docs/macmini.md`), this box is mine to configure. Facts below were
collected 2026-09-22.

## Connection

| | |
|---|---|
| alias | `ssh qiushi-mini` — `Host qiushi-mini` in `~/.ssh/config` (gitignored; the address lives only there) |
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
| nvm | 0.40.8 | upstream `install.sh` (nvm rejects Homebrew installs) → `~/.nvm` | re-run installer with the new tag |
| node | v24.21.0 LTS (`default` → `lts/*`) | `nvm install --lts` | `nvm install --lts && nvm alias default 'lts/*'` |
| pnpm | 11.27.1 | `get.pnpm.io/install.sh` with `PNPM_VERSION=11.27.1` → `~/Library/pnpm`; pinned to 11 to match the laptop, not the Rust-port 12 | `pnpm self-update` |
| Claude Code | 2.1.280 | native `claude.ai/install.sh` → `~/.local/bin/claude` | auto-updates |
| Codex CLI | 0.155.1 | `chatgpt.com/codex/install.sh` → `~/.local/bin/codex` | `codex update` |
| Python | 3.14.7 | `uv python install 3.14` (versioned `python3.14` only) | `uv python upgrade` |

Personal CLIs (headroom, envoy, brief, gwt) come from the laptop through
`mini-sync` (§ Sync). Not installed: go, rust, Docker, databases, fonts, GUI
apps, oh-my-zsh.

## Shell

The `zsh` package is not stowed. The mini's startup files are hand-written,
and they pull the shared parts from the mirror.

- **`~/.zshenv`** carries everything, because `ssh qiushi-mini '<cmd>'` runs
  a non-login, non-interactive zsh that reads no other file. It sets brew
  shellenv, `~/.local/bin`, the newest nvm Node `bin`, `$PNPM_HOME/bin`, and
  the SSH-only terminal variables (§ Terminal over SSH). It then sources a
  curated list of modules straight from `~/dotfiles/zsh/.config/zsh/`:
  `aliases nav utils git claude claude-sessions codex tmux-utils cwd-guard`.
  That gives the laptop's muscle memory (`n`, `g`, `lg`, `l`, `t`, `b`,
  `take`, `p`, …) and routes `x`/`cx` through headroom. Laptop-only modules
  stay out: `toolchain` (the PATH lines replace it), `xcode`, `theme`,
  `cout`, `proxy`. It turns off `EQUALS`, as the laptop does.
- **`~/.zprofile`** repeats brew shellenv, because `/etc/zprofile`'s
  `path_helper` reorders PATH for login shells after `.zshenv`.
- **`~/.zshrc`** holds the nvm and pnpm installer blocks, `compinit` plus
  `_git_zsh_register_completions`, zoxide, fzf, `alias v=nvim`, and `EDITOR`.
- **`~/.tmux.conf`** is eight lines (mouse, history, `tmux-256color`,
  `set-clipboard on`), on plain Homebrew tmux rather than `tmux-popupfix`.

**Git:** the global identity is the personal Gmail. GitHub auth goes through
`gh auth setup-git` (HTTPS), so no private SSH key lives on the mini.

**Neovim:** the `nvim` package is stowed from the mirror. Plugins install
from `lazy-lock.json`, and Mason installs LSPs on first open.

## Terminal over SSH

The laptop's Ghostty → laptop tmux → ssh chain needs these on top of a
default mini:

- **terminfo**: `xterm-ghostty` was pushed with
  `infocmp -x xterm-ghostty | ssh qiushi-mini -- tic -x -` (into
  `~/.terminfo`). Without it, tmux and nvim reject the TERM Ghostty sends.
- **Clipboard (OSC 52)**: the laptop tmux must run `set-clipboard on`,
  because `external` drops OSC 52 sent from panes. tmux forwards it only to a
  client that is showing the pane. nvim's `"+y` depends on this:
  `options.lua` sets `vim.g.clipboard = "osc52"` for `SSH_TTY` sessions,
  because Neovim otherwise prefers the mini's own pbcopy. LazyVim leaves
  `clipboard` empty over SSH, so plain `y` stays in Vim registers.
- **Links**: open them with **Cmd+Shift+click**. Ghostty opens OSC 8 links
  on Cmd-click, and Shift bypasses tmux's mouse capture. sshd doesn't forward
  `TERM_PROGRAM`, so `.zshenv` sets `FORCE_HYPERLINK=1` for SSH sessions;
  without it Claude Code prints plain-text URLs.
- **Ctrl-click in Claude Code** is its own click handler, which runs
  `$BROWSER` (else `open`) on the host, the mini. `.zshenv` sets
  `BROWSER=~/.local/bin/browser-clip` for SSH sessions. That shim sends the
  URL to the laptop clipboard over OSC 52 instead of opening the mini's
  Safari, and writes to the parent's tty when it was spawned detached.

## Ghostty on the mini

The app is installed by hand. The `ghostty` package is stowed from the
mirror, so `~/.config/ghostty` is a folder link into it, as on the laptop.
The theme include (`auto/theme.ghostty`) and `~/.config/terminal-theme`
arrive through `mini-sync` (§ Sync). Ghostty reloads config only with
⌘⇧, or a restart.

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
- The hooks and the statusline call `~/.config/tmux/scripts/*`, so that one
  dir links to the mirror's `tmux/.config/tmux/scripts`. The laptop's
  `tmux.conf` is not linked. Those scripts no-op outside tmux.
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
- **Theme**: `THEME` in the script sends theme-set's two outputs
  (`~/.config/terminal-theme`, the gitignored Ghostty include), so the mini's
  Ghostty, nvim, statusline and prompt follow the laptop's theme.
- **Token files**: `SECRETS` in the script (`~/.planlab/.env`,
  `~/.bench/.env`) are sent 600 inside 700 dirs. Only plain CLI API tokens
  belong on that list. OAuth logins (Claude Code, Codex, gh) rotate their
  refresh tokens, so two machines sharing one log each other out. A file
  deleted on the laptop stays on the mini.
- **Schedule**: `com.qiushi.mini-sync` (a LaunchAgent stowed from
  `scripts/Library/`) runs `mini-sync --quiet` at load and every 15 minutes.
  An unreachable mini is a silent no-op, and real failures go to
  `~/Library/Logs/mini-sync.log`. Run `mini-sync` by hand for a change you
  want there now; `-n` previews it.
