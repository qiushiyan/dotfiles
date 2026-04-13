# Mobile Terminal Access

A persistent setup for running terminal-based AI coding agents (Claude Code, Codex CLI, plain shell) on the home MacBook and reaching them from an iPhone over the public internet — without exposing the laptop to the public internet.

> **Detailed rationale:** see `docs/superpowers/specs/2026-04-12-mobile-terminal-access-design.md`. This document is the operational quick-reference: what's installed, where it lives, how to use it, and how to fix it.

## The four pieces

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

Mosh keeps the *connection* alive. tmux keeps the *session* alive across full disconnects, machine sleep, and laptop reboots-of-the-tmux-server. A `claude` process started in a tmux window keeps running with no client attached; you reattach later and pick up exactly where you left off.

The existing tmux config (`tmux/.config/tmux/tmux.conf`) already has `mouse on`, vi mode, and the catppuccin theme. We didn't change it.

### Moshi — the iOS client

iOS doesn't ship a terminal. We need a third-party app that speaks both SSH and mosh, handles a hardware keyboard, supports biometric-protected SSH key storage, and works with tmux's mouse mode for swipe scrolling.

[Moshi](https://getmoshi.app/) (free) covers all of that and is purpose-built for "AI agent from your phone" workflows. The two main alternatives are Blink Shell (subscription, unavailable in some regions) and Termius (free tier doesn't support mosh).

### caffeinate — the sleep problem

If the Mac sleeps while you're away, the agents pause. macOS's built-in `caffeinate -dimsu` (no child command, no `-t`) prevents idle and system sleep until SIGTERM. We bundle it as a window inside the `agents` tmux session so its lifetime is automatically tied to the session: kill the session, the window dies, caffeinate exits, the Mac is free to sleep again. No launchd, no PID tracking, no polling.

> **Critical detail:** the early version of this used `caffeinate -dimsu sleep infinity`, which silently fails on macOS because BSD `sleep` doesn't accept "infinity" — it requires an integer. caffeinate then exited because its child died. The fix is to give caffeinate no command at all; with neither a child command nor `-t`, it blocks indefinitely. If you ever debug this and see a `caffeinate` window that closed itself, this is probably why.

## What's installed where

### Laptop (`/Users/qiushi/dotfiles/`)

| Path | Purpose |
|---|---|
| `zsh/.zshenv` | Adds `/opt/homebrew/bin` to PATH and sets `LANG=en_US.UTF-8` for **non-interactive** SSH shells. Without this, mosh-server fails because Apple Silicon's brew shellenv loads from `/etc/zprofile` (login shells only) and macOS doesn't set a UTF-8 locale for non-login non-interactive shells. mosh-server hard-refuses to start without UTF-8. |
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

## Common failure modes and fixes

| Symptom | Cause | Fix |
|---|---|---|
| `mosh-server: command not found` over SSH | `/opt/homebrew/bin` not in PATH for non-interactive ssh | Already fixed in `zsh/.zshenv`. If broken, verify the brew shellenv guard there. |
| `mosh-server needs a UTF-8 native locale` | LANG/LC_ALL not set in non-interactive shell | Already fixed in `zsh/.zshenv`. |
| `caffeinate` window dies immediately on session create | Old buggy `caffeinate -dimsu sleep infinity` (BSD sleep doesn't accept "infinity") | Fixed in `agents()` — no child argument. |
| `agents-status` reports caffeinate active when it isn't | Old `pgrep -qx caffeinate` matched unrelated macOS daemons | Fixed — now scoped to the agents session via `pane_current_command`. |
| caffeinate window vanished from a running session | Manually killed, or the underlying process crashed | Re-run `agents` — the function self-heals the missing window. |
| Mac asleep with lid closed, can't wake from phone | Wake-on-Network on battery is disabled (current setting is "Only on Power Adapter") | Plug in the laptop before leaving, or keep the lid open. |
| Connection hangs at "Connecting..." in Moshi | Tailscale not connected on phone, or the Mac is fully powered off | Check Tailscale iOS toggle. If the Mac is off, no remedy short of physical access. |

## File map

```
docs/
  mobile-terminal-access.md                              ← this document
  superpowers/specs/
    2026-04-12-mobile-terminal-access-design.md          ← design rationale
zsh/
  .zshenv                                                ← PATH + locale fixes
  .config/zsh/utils.zsh                                  ← agents, agents-status
tmux/
  .config/tmux/tmux.conf                                 ← pre-existing, unchanged
```

## Maintenance hooks for future-you

If a senior engineer is reading this with intent to improve:

- **The single point of failure for "Mac stays awake" is the caffeinate window.** Layers 1 and 3 from the energy-settings section above provide partial coverage, but the only thing that defends `agents` against unplugged-on-battery + idle is the caffeinate window. Test changes to `agents()` with `pmset -g assertions | grep PreventSystemSleep`.
- **The PATH and locale fixes in `.zshenv` benefit any tool that ssh-launches commands**, not just mosh. If you remove them, audit other tools first (rsync, scp targets, anything using `ssh host cmd`).
- **`caffeinate -dimsu` with no child argument is a non-obvious idiom.** Resist the urge to "improve" it by adding `sleep infinity` or similar — it will silently break on macOS BSD coreutils.
- **The hardlink situation on `~/.config/zsh/utils.zsh`** (same inode as the dotfile rather than a Stow symlink) is benign for editing but means `make restow` could reconcile it unexpectedly. If you see `agents` mysteriously stop working after a restow, check `ls -li`.
- **The `agents` shell function is the only public API**; everything else is implementation detail. If you change tmux session naming, key generation, or the caffeinate strategy, update `agents` and `agents-status` together.
