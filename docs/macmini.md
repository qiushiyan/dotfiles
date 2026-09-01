# Mac mini (`ssh macmini`)

A colleague's Mac mini on the company tailnet that I have a user account on,
for development over SSH. It is a **shared, production-ish box**: the owner's
account serves `autoandy` from it, so the rule is *don't use up the cores or
the memory*. Facts below were collected 2026-09-01; re-check anything
load-related before relying on it.

## Connection

| | |
|---|---|
| alias | `ssh macmini` — `Host macmini` in `~/.ssh/config` (gitignored; the address lives only there) |
| network | Tailscale, node `macmini2`; direct peer connection, ~7 ms RTT from the laptop |
| user | `qiushiyan` (uid 504, `admin` group, sudo **with password**) |
| key | `~/.ssh/id_ed25519_macmini` (dedicated, no passphrase); installed in the mini's `authorized_keys` |
| host key | ECDSA `SHA256:bRe2KmbVDU5TGBIGu6WI+IimLZp96P2mS1DUVaphU9g` |
| sshd | stock macOS Remote Login (`UsePAM yes`, password auth still on server-side); our `Host *` sends publickey only |
| shell | `/bin/zsh`, fresh home dir — no dotfiles, no `.zshrc` yet |

Other tailnet members seen from the mini: `amac`, `dgx-gx10` (Linux),
`bench` (Linux, tagged), `admins-macbook-air-3`. The prod box
`planlab-prod-loopy-master` is visible from the laptop's tailnet too.

## Hardware and OS

| | |
|---|---|
| model | Mac mini `Mac16,10`, Apple **M4** — 10 cores (4P + 6E), arm64 |
| memory | **32 GB** |
| OS | macOS 26.5.1 (25F80), Rosetta installed, Command Line Tools only (no Xcode.app) |
| power | sleep disabled (`caffeinate`), wake-on-LAN on, auto-restart after power failure |
| uptime at survey | 7 days |

## Disks

| mount | size | free | notes |
|---|---|---|---|
| `/` | 228 GB | ~87 GB | internal, small — keep it clean |
| `/Volumes/T7` | 1.8 TB | ~1.7 TB | Samsung T7 over USB, APFS; ~845 MB/s sequential write |
| `/Volumes/T7/qiushiyan` | | | **mine** — repos, node_modules, datasets, build output go here |

Neighbours on T7: `autoandy/`, `planlab-build/`, `andy/`, `max/` — leave alone.

## What else runs here

- The owner's account (`andy`) runs **autoandy**: the `autoandy slack` daemon,
  `claude -p` worker processes it spawns (one per PR review round), a
  `pl-approver.py` sweeper, and a `next dev` on **port 3100**. Expect 1–5 load
  average and ~20 GB of the 32 GB in use at any time; **memory is the tighter
  resource**, not CPU.
- Docker Desktop is installed but its socket belongs to `andy`
  (`/var/run/docker.sock → /Users/andy/.docker/...`); don't count on Docker
  from this account.
- Two VMs are bridged on `bridge100` (192.168.64.0/24) — Docker's or the
  `container` CLI's.
- Also present: a Homebrew `tailscaled` LaunchDaemon *and* Tailscale.app (two
  `utun`s with two 100.x addresses; `macmini2` / the one in `~/.ssh/config` is
  the app's), Qualys cloud agent, a `pfctl` daemon of the owner's.
- Other human accounts: `andy`, `max`. SMB Public folders are shared with
  guest access — don't put anything private in `~/Public`.

## Toolchain

**Shared (Homebrew 6.0.19 at `/opt/homebrew`, owned by the colleague):** on our
PATH read-only via `brew shellenv` in `~/.zshrc` — `gh`, `git-lfs`, `fzf`,
`btop`, `caddy`, `ffmpeg`, `postgresql@17` clients, `aws`, `cloc`. Never
`brew install` here: it is his install and a version bump would hit his
tooling too. System `git` is Apple's 2.50.1, `python3` the CLT's 3.9.

**Ours (installed 2026-09-01, all under `$HOME`, no sudo):**

| tool | version | how | where | update |
|---|---|---|---|---|
| nvm | 0.40.7 | upstream `install.sh` | `~/.nvm` | re-run installer |
| node | v24.20.0 (LTS, `default` alias) | `nvm install --lts` | `~/.nvm/versions/node/` | `nvm install --lts && nvm alias default lts/*` |
| pnpm | 11.25.0 | standalone `get.pnpm.io/install.sh` | `~/Library/pnpm` (macOS default) | `pnpm self-update` |
| Claude Code | 2.1.252 | native `claude.ai/install.sh` | `~/.local/share/claude`, launcher `~/.local/bin/claude` | auto-updates |
| Codex CLI | 0.152.0 | official `chatgpt.com/codex/install.sh` | `~/.codex/packages`, launcher `~/.local/bin/codex` (PATH line it added to `~/.zprofile` is redundant with `.zshrc` but harmless) | `codex update` or re-run installer |

Why these forms: per-user installs can't collide with his `~/.nvm` /
`~/.cargo`; the native Claude installer is Anthropic's recommended path (npm
still works but isn't the primary tested route); the pnpm standalone script is
the documented default and doesn't depend on node. `~/.zshrc` is the only
config file so far — brew shellenv, `~/.local/bin`, the lines nvm and
pnpm appended, and `alias x="claude --dangerously-skip-permissions"` (a
plain alias; no headroom on the mini, so no account switching). Not stowed from this repo; it's a four-line file.

Not installed: uv, go, rust, tmux, nvim. Add here when they land.

## Etiquette

- Heavy jobs: `nice -n 10`, cap parallelism (`-j4` or less), and watch
  `btop` before launching anything that wants > 8 GB.
- Big files and caches on `/Volumes/T7/qiushiyan`, never on `/`.
- Port 3100 is taken; pick dev-server ports elsewhere.
- Change the initial password the owner handed over (`passwd`) — it travelled
  in chat.

## Next steps

`claude` is installed but not logged in — first `ssh macmini` then `claude`
to authenticate in the browser flow. Repos go in `/Volumes/T7/qiushiyan`.
Consider stowing a zsh/tmux subset of these dotfiles once the minimal
`.zshrc` starts to feel thin.
