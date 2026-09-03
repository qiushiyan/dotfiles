# Mobile Terminal Access

A persistent setup for running terminal-based AI coding agents (Claude Code,
Codex CLI, plain shell) on the home MacBook and reaching them from an iPhone
without exposing the laptop to the public internet. This is the architecture and
normal-operation spine; connection recovery lives in
`docs/mobile-terminal-troubleshooting.md`.

## The pieces

```
┌─────────────────┐    ┌──────────────────────────────────────────┐
│ iPhone (Moshi)  │    │ MacBook (laptop)                         │
│                 │    │                                          │
│ ┌─────────────┐ │    │ ┌────────┐  ┌───────────────────────┐  │
│ │  Moshi.app  │─┼─[Tailscale]──►│ sshd   │─►│ tmux session "agents" │  │
│ │  + mosh     │ │    │ └────────┘  │  ┌─────────────────┐  │  │
│ └─────────────┘ │    │             │  │ caffeinate -dim │  │  │
└─────────────────┘    │             │  ├─────────────────┤  │  │
                       │             │  │ shell (claude,  │  │  │
                       │             │  │ codex, etc.)    │  │  │
                       │             │  └─────────────────┘  │  │
                       │             └───────────────────────┘  │
                       └──────────────────────────────────────────┘
```

Each piece solves exactly one problem.

### Tailscale — the network problem

The laptop is at home behind NAT with no public IP and no port forwarding. The phone needs to reach it from anywhere. Tailscale solves this by joining both devices to a private WireGuard mesh and giving each a stable hostname (`qiushi-mac` for the laptop). Once both devices are signed in, they can talk to each other over an encrypted tunnel as if they were on the same LAN — regardless of what physical network either one is on. Nothing is exposed to the public internet; the laptop's firewall stays in default-deny mode and all traffic enters via the `utun` interface.

Free for personal use up to 100 devices.

### Mosh — the transport problem

Plain SSH is TCP, so it dies whenever the phone's network changes (Wi-Fi → cellular, walking between rooms, screen-lock for too long). Each reconnect means re-authenticating and losing your scrollback.

Mosh is UDP-based. It runs over SSH for the initial auth handshake, then drops the SSH connection and uses its own UDP protocol. Benefits for mobile use:

- Survives network changes — phone hops Wi-Fi/cellular without dropping the session
- Reconnects automatically when the phone wakes from sleep
- Predictive local echo, so typing on cellular doesn't feel laggy
- The mosh-server process keeps running on the laptop even if the phone is offline for hours

**Important caveat:** mosh syncs the visible screen, not the output stream. It has no scrollback of its own. Scrollback comes from tmux below it, which is why mouse mode in `tmux.conf` matters (Moshi reads it as swipe-to-scroll on iOS).

### tmux — the persistence problem

Mosh keeps the *connection* alive. tmux keeps processes alive across client
disconnects and machine sleep; a `claude` process keeps running with no client
attached. After an OS reboot, resurrect restores tmux's saved structure, not the
processes that occupied it.

The existing tmux config (`tmux/.config/tmux/tmux.conf`) already provides what this needs — `mouse on` and vi mode — so mobile access required no tmux changes. Its theme follows `$TERMINAL_THEME` (`docs/theming.md`).

### Moshi — the iOS client

iOS doesn't ship a terminal. We need a third-party app that speaks both SSH and mosh, handles a hardware keyboard, supports biometric-protected SSH key storage, and works with tmux's mouse mode for swipe scrolling.

[Moshi](https://getmoshi.app/) (free) covers all of that and is purpose-built for "AI agent from your phone" workflows. The two main alternatives are Blink Shell (subscription, unavailable in some regions) and Termius (free tier doesn't support mosh).

### caffeinate — the sleep problem

If the Mac sleeps while you're away, the agents pause. macOS's built-in `caffeinate -dimsu` (no child command, no `-t`) prevents idle and system sleep until SIGTERM. We bundle it as a window inside the `agents` tmux session so its lifetime is automatically tied to the session: kill the session, the window dies, caffeinate exits, the Mac is free to sleep again. No launchd, no PID tracking, no polling.

The command has no child and no timeout. That shape is load-bearing; recovery
and the BSD `sleep` trap live in `docs/mobile-terminal-troubleshooting.md`.

## What's installed where

### Laptop (paths relative to this repo)

| Path | Purpose |
|---|---|
| `zsh/.zshenv` | PATH and `LANG=en_US.UTF-8` for **non-interactive** SSH shells — mosh-server hard-refuses to start without UTF-8, and `/etc/zprofile` fires only for login shells. Why `.zshenv` is the right file: `docs/zsh.md`. |
| `zsh/.config/zsh/utils.zsh` | Defines the `agents` and `agents-status` shell functions (search for `agents() {` near the bottom). |
| `mosh` | Installed via Homebrew (`brew install mosh`), version 1.4.0+. |
| `~/.ssh/id_ed25519_phone` | Dedicated SSH key for the phone, **NOT** in the dotfiles repo. Generated with `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_phone -C "phone@moshi" -N ""`. |
| `~/.ssh/authorized_keys` | Contains the phone's public key with the comment `phone@moshi`. |
| Tailscale (Mac client) | Signed in via GitHub. Adds the laptop to the tailnet as `qiushi-mac`. |
| macOS Remote Login | Enabled in System Settings → General → Sharing. |
| macOS Energy settings | "Prevent automatic sleeping on power adapter when display is off" → ON. "Wake for network access" → Only on Power Adapter. |

### iPhone

| | Purpose |
|---|---|
| Tailscale iOS app | Always-on VPN enabled, signed into the same GitHub account. |
| Moshi iOS app | SSH/mosh client. Private key imported into iOS Keychain, Face ID gate enabled. |
| Moshi host config | Name=`mac`, Host=`qiushi-mac` (Tailscale MagicDNS), Port=22, User=`qiushi`, Auth=Key File (`id_ed25519_phone`), Connection Type=Mosh, Mosh Path=`/opt/homebrew/bin/mosh-server`. |

## Helper functions

Defined in `zsh/.config/zsh/utils.zsh`. Both are loaded automatically by `zsh/.zshenv`'s `source ~/.config/zsh/*.zsh` glob.

### `agents`

Creates or attaches to the long-lived `agents` tmux session. Specifically:

1. If no `agents` session exists: creates it with two windows — a `caffeinate` window running `exec caffeinate -dimsu`, and a `shell` window for actual work.
2. If the session exists but the `caffeinate` window has been killed (a documented failure mode): self-heals by recreating it. Without this self-heal, the Mac would silently sleep on its idle timer.
3. Attaches (or `switch-client`s if already inside tmux).

Use this both **before leaving the laptop** and **from the phone** to bootstrap the session on demand. It's idempotent.

### `agents-status`

Reports whether the session is running, lists its windows, and verifies the caffeinate window is actually running caffeinate (not a shell that the caffeinate process exited from). Does **not** use `pgrep -qx caffeinate` because macOS daemons (Bluetoothd, Sharingd, Powerd) frequently spawn their own caffeinate processes — that check would lie. The check is scoped to the agents session via tmux's `pane_current_command`.

## Daily workflow

### The 95% case: bootstrap on demand from the phone

1. Walk out of the house. Don't touch tmux. Lid open, plugged in, energy settings as above.
2. Open Moshi → tap `mac` → connect.
3. If Moshi drops you into a regular shell (no existing session), type `agents`. Session is created on the spot, you're attached, caffeinate starts.
4. Run `claude`, `codex`, etc. Use `Ctrl+b c` for new windows, `Ctrl+b N` to switch.
5. Close Moshi. Mosh holds the connection in the background; reopen later to resume.

### Optional: warm the session up before leaving

From a laptop terminal:

```sh
agents          # creates session, attaches you
# Ctrl+b d      # detach immediately if you don't want a window in your face
```

### When you get home

Either kill the session to release caffeinate:

```sh
tmux kill-session -t agents
```

…or just leave it running. Caffeinate is essentially free, and the energy-settings layer (see below) means the Mac wouldn't sleep anyway while plugged in.

### If the phone is lost

1. On the laptop, remove the line ending in `phone@moshi` from `~/.ssh/authorized_keys`. SSH access via that key is revoked immediately.
2. In the Tailscale admin console (login.tailscale.com), remove the phone device.
3. The key in iOS Keychain becomes orphaned and harmless.

## Accessing dev servers from the phone

`localhost` on the phone is always the phone. To reach a dev server running on the laptop you bind it to all interfaces, or front it with Tailscale Serve for real HTTPS, and browse to the laptop's Tailscale hostname. Your phone's *browser* talks to the laptop directly — this path does not involve Moshi at all → `docs/mobile-dev-servers.md`.

## Why the Mac stays awake (defense in depth)

There are **three independent layers** preventing sleep, in order of strength:

1. **macOS Energy → "Prevent automatic sleeping on power adapter when display is off" (ON).** While plugged in, the Mac never idle-sleeps regardless of caffeinate. This is the strongest layer for the at-home case.
2. **The `caffeinate -dimsu` window inside the agents session.** Defends against idle sleep regardless of power source, dies cleanly with the session.
3. **macOS Energy → "Wake for network access: Only on Power Adapter".** If the Mac ever does sleep (e.g., lid closed and you forgot to set up clamshell), an incoming Tailscale connection wakes it.

**What's NOT defended:** lid-closed sleep is not prevented by any of these. If you close the lid without an external display + keyboard + power (true "clamshell mode"), the Mac sleeps. Layer 3 usually brings it back when you connect from the phone, but the safest default is "leave the lid open."

## Things we explicitly chose not to do

| Rejected | Reason |
|---|---|
| **Cloudflare Tunnel** for SSH | Built for HTTP services. Wrong tool. Tailscale is the consensus for laptop-to-phone mesh. |
| **Anthropic Claude Code Remote Control** | Only works with Claude Code, not Codex CLI or arbitrary shell work. The user wanted one workflow that handles all three. |
| **Zellij instead of tmux** | Known scroll bug with Codex CLI's alt-screen TUI ([openai/codex#2836](https://github.com/openai/codex/issues/2836)), shallower Moshi integration, and the existing tmux config is already polished. |
| **launchd plist for caffeinate** | The in-session caffeinate window is simpler and equivalent — same lifetime, fewer moving parts. |
| **Blink Shell** | Subscription-only since 2023, unavailable in some regions. |
| **Termius (free tier)** | Doesn't support mosh, which is the whole point of using mosh. |
| **Auto-starting agents at login** | Would always run tmux + caffeinate even when not needed. The user prefers an empty laptop unless they explicitly want the session. |

## Recovery and maintenance

Connection diagnosis, iOS VPN recovery, the failure map, and implementation
invariants live in `docs/mobile-terminal-troubleshooting.md`.
