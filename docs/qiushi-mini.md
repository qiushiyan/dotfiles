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

Installed 2026-09-22. A deliberately small subset of the laptop: no
`bootstrap.sh`, no Brewfile. Two packages are stowed from the mirror: `nvim`
and `claude`. Everything else from this repo arrives through the mirror
(§ Sync).

| tool | version | how | update |
|---|---|---|---|
| CLI tools | — | `brew install gh tmux ripgrep fd fzf jq lazygit zoxide uv stow rsync coreutils bat difftastic` (the last three because `aliases.zsh`/`git.zsh` call `gls`, `bat`, `difft`) | `brew upgrade` |
| nvm | 0.40.8 | upstream `install.sh` (nvm rejects Homebrew installs) → `~/.nvm` | re-run installer with the new tag |
| node | v24.21.0 LTS (`default` → `lts/*`) | `nvm install --lts` | `nvm install --lts && nvm alias default 'lts/*'` |
| pnpm | 11.27.1 | `get.pnpm.io/install.sh` with `PNPM_VERSION=11.27.1` → `~/Library/pnpm`; pinned to 11 to match the laptop, not the Rust-port 12 | `pnpm self-update` |
| Claude Code | 2.1.280 | native `claude.ai/install.sh` → `~/.local/bin/claude` | auto-updates |
| Codex CLI | 0.155.1 | `chatgpt.com/codex/install.sh` → `~/.local/bin/codex` | `codex update` |
| Python | 3.14.7 | `uv python install 3.14` (versioned `python3.14` only) | `uv python upgrade` |

**Shell files, all hand-written (the `zsh` package is not stowed):**

- `~/.zshenv`: brew shellenv, `~/.local/bin`, the newest nvm Node `bin`, and
  `$PNPM_HOME/bin`. This file exists because `ssh qiushi-mini '<cmd>'` runs a
  non-login, non-interactive zsh that reads nothing else. With only
  `.zprofile`, `nvim`, brew `jq` and the rest were missing from PATH.
  It also sets `FORCE_HYPERLINK=1` for SSH sessions. sshd doesn't forward
  `TERM_PROGRAM`, so without it Claude Code prints URLs as plain text. Open
  links with **Cmd+Shift+click**: Ghostty opens OSC 8 links on Cmd-click, and
  Shift bypasses tmux's mouse capture. Plain Ctrl-click is Claude Code's own
  click handler, which runs `$BROWSER` (else `open`) on the host. For SSH
  sessions, `.zshenv` sets `BROWSER=~/.local/bin/browser-clip`, a ten-line
  shim that sends the URL to the laptop clipboard over OSC 52 instead of
  opening the mini's Safari. It writes to the parent's tty when it was
  spawned detached. So on the mini, Ctrl-click copies the link and
  Cmd+Shift+click opens it.
- **OSC 52 requires the laptop tmux at `set-clipboard on`.** The default
  `external` drops OSC 52 from panes, and tmux forwards it only to a client
  that is showing the pane. Both the nvim `"+y` path and `browser-clip`
  depend on this.
- `~/.zprofile`: brew shellenv again, because `/etc/zprofile`'s `path_helper`
  reorders PATH for login shells after `.zshenv`.
- `~/.zshenv` (end): sources a curated list of modules straight from the
  mirrored `~/dotfiles/zsh/.config/zsh/`: `aliases nav utils git claude
  claude-sessions codex tmux-utils cwd-guard`. This gives the same muscle
  memory as the laptop (`n`, `g`, `lg`, `l`, `t`, `b`, `take`, `p`, …), and
  `x`/`cx` route through headroom. Laptop-only modules stay out:
  `toolchain` (the PATH lines above replace it), `xcode`, `theme`, `cout`,
  `proxy`. It also turns off `EQUALS`, as the laptop does.
- `~/.zshrc`: the nvm and pnpm installer blocks, `compinit` plus
  `_git_zsh_register_completions`, zoxide, fzf, `alias v=nvim`, and `EDITOR`.
- `~/.tmux.conf`: eight lines (mouse, history, `tmux-256color`,
  `set-clipboard on`). Plain Homebrew tmux, not `tmux-popupfix`.

**Git:** global identity is the personal Gmail. `~/dotfiles` is cloned over
HTTPS, and GitHub auth goes through `gh auth setup-git`, so no private SSH key
lives on the mini.

**Neovim:** only `nvim` is stowed from `~/dotfiles`. Plugins were restored
from `lazy-lock.json`, and Mason installs LSPs on first open. Over SSH,
LazyVim leaves `clipboard` empty and `options.lua` sets
`vim.g.clipboard = "osc52"`, so `"+y` lands in the laptop's clipboard
(Ghostty allows OSC 52 writes by default). Without that, Neovim prefers the
mini's own pbcopy.

**Ghostty terminfo:** `xterm-ghostty` was pushed with
`infocmp -x xterm-ghostty | ssh qiushi-mini -- tic -x -` (into `~/.terminfo`).
Without it, tmux and nvim reject the TERM that Ghostty sends.

**Auth over SSH:** the login Keychain is locked in SSH sessions. Claude Code
falls back to `~/.claude/.credentials.json`. Codex is told to use a file
(`cli_auth_credentials_store = "file"` in `~/.codex/config.toml`, which is not
stowed). gh falls back to plaintext storage.

**Claude Code config:** the `claude` package is stowed. `~/.claude` and
`~/.agents` are real dirs, and `settings.json`, `CLAUDE.md`, hooks, rules,
commands, agents and skills link into the mirror. Codex reads the same
skills through `~/.agents/skills`. The hooks and the statusline call
`~/.config/tmux/scripts/*`, so that one dir is linked to the mirror's
`tmux/.config/tmux/scripts`. The laptop's `tmux.conf` is not linked, and
`~/.tmux.conf` stays the mini's own. Those scripts no-op outside tmux.
`settings.json` is a link into the mirror, so a setting changed on the mini
(`/config`, `/model` default) is lost at the next sync. Change it on the
laptop.

**Codex config:** `~/.codex/config.toml` is **generated**, not linked,
because Codex writes its project and hook trust into it at runtime.
`mini-sync` passes the laptop's file through
`scripts/.local/share/dotfiles/mini-codex-config.py`, which:
- keeps every shared setting: model, reasoning, TUI, features, context7,
  and skill-sync's exclusions;
- drops the ChatGPT desktop integrations (computer-use, node_repl, plugins,
  marketplaces, `desktop`, `notify`);
- keeps the mini's own `projects.*`, `hooks.state*` and
  `tui.model_availability_nux` tables;
- pins `cli_auth_credentials_store = "file"`.

The output is idempotent, and the file is rewritten only when the laptop's
config changed. `AGENTS.md` and `themes/` are plain links into the mirror.
A `/model` choice made on the mini is replaced by the laptop's at the next
sync.

**Extra Codex accounts:** don't use `cx-account-add` here. It shares the
laptop's raw `codex/.codex/config.toml`, which has no file credential store.
Run `headroom accounts add --vendor codex --share-config <email>` instead:
bare `--share-config` links the mini primary's generated config.

Not installed: go, rust, Docker, databases, fonts, GUI apps, oh-my-zsh.

## Sync

`mini-sync` (`scripts/.local/bin/`) runs on the **laptop**. It is one-way
and the laptop is the source of truth.

- **dotfiles**: `rsync --delete` of this repo to `~/dotfiles` on the mini.
  It sends everything git can see (tracked files plus untracked files that
  are not ignored) and `.git` itself, so the mini's `git status` matches the
  laptop's, uncommitted edits included. Ignored paths never leave the laptop:
  `ssh/`, `vpn-private/`, purchased upstream material, app runtime state,
  `node_modules`.
- **CLIs**: the compiled binaries `headroom envoy brief gwt` are copied from
  `~/.local/bin` (same arch and OS family). There is no Go and there are no
  source clones on the mini. `planlab` and `bench` are deliberately absent:
  they are two-line shims that `exec` tsx inside the laptop's
  `~/dev/planlab/main` checkout.
- **Schedule**: `com.qiushi.mini-sync` (LaunchAgent, stowed from
  `scripts/Library/`) runs `mini-sync --quiet` at load and every 15 minutes.
  An unreachable mini is a silent no-op. Real failures go to
  `~/Library/Logs/mini-sync.log`. Run `mini-sync` by hand after a change you
  want there now; `-n` previews it.

**Never edit `~/dotfiles` on the mini.** The next sync overwrites it. A fix
found there gets made on the laptop.

**headroom on the mini:** Claude Code credentials live in
`.credentials.json`, not the Keychain, because the Keychain is locked over
SSH. headroom 81c3045 reads that file only for non-primary accounts, so the
primary's board row says "credential unreadable" and `headroom check` FAILs
`keychain[primary]`/`blob[primary]`. Routing (`x`, `x-<name>`) and the Codex
page are unaffected.
