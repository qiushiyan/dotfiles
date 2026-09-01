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

## Toolchain (as of survey)

Homebrew 6.0.19 at `/opt/homebrew` — **not on PATH for a fresh account**;
add `eval "$(/opt/homebrew/bin/brew shellenv)"` to `~/.zshrc` first. Already
installed via brew: `gh`, `git-lfs`, `fzf`, `btop`, `caddy`, `ffmpeg`,
`postgresql@17` client tools, `aws`, `cloc`, `container`, numpy/numba.

Not installed system-wide: **node/pnpm/bun, uv, go, rust, tmux, nvim, claude,
codex**. The owner has per-user `nvm`, `cargo` and `~/.local/bin`; install my
own copies under my home (or on T7) rather than borrowing. System `git` is
Apple's 2.50.1; `python3` is the CLT's 3.9.

## Etiquette

- Heavy jobs: `nice -n 10`, cap parallelism (`-j4` or less), and watch
  `btop` before launching anything that wants > 8 GB.
- Big files and caches on `/Volumes/T7/qiushiyan`, never on `/`.
- Port 3100 is taken; pick dev-server ports elsewhere.
- Change the initial password the owner handed over (`passwd`) — it travelled
  in chat.

## Setting it up for development (todo)

Nothing beyond the SSH key exists on the mini yet. When the time comes:
brew shellenv → stow a minimal subset of these dotfiles (zsh, tmux, nvim) →
node via a version manager into `$HOME` → clone repos into
`/Volumes/T7/qiushiyan`. Record the choices here as they land.
