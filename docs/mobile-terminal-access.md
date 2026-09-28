# Mobile Terminal Access

A persistent setup for running terminal-based AI coding agents (Claude Code,
Codex CLI, plain shell) on the home MacBook and reaching them from an iPhone
without exposing the laptop to the public internet. This is the architecture and
normal-operation spine; connection recovery lives in
`docs/mobile-terminal-troubleshooting.md`.

## The pieces

```text
iPhone: Moshi (mosh) ──[Tailscale]──► laptop sshd ──► tmux session "agents"
                                                        ├─ caffeinate -dimsu
                                                        └─ shell: claude, codex, …
```

Each piece solves one problem:

- **Tailscale — the network.** The laptop sits behind home NAT with no public
  IP. Tailscale joins phone and laptop in a private WireGuard mesh with a
  stable hostname (`qiushi-mac`), so nothing is exposed and the laptop's
  firewall stays default-deny.
- **mosh — the transport.** Plain SSH is TCP and dies whenever the phone
  changes network or sleeps. mosh authenticates over SSH, then keeps its own
  UDP session that survives roaming and sleep, with local echo. **mosh has no
  scrollback:** it syncs the visible screen, so scrollback comes from tmux's
  `mouse on`, which Moshi turns into swipe-to-scroll.
- **tmux — persistence.** The session keeps `claude` and friends running with
  no client attached; after an OS reboot, resurrect restores the layout, not
  the processes. Mobile use needs no tmux changes.
- **Moshi — the iOS client.** It speaks SSH and mosh, keeps the key behind
  Face ID, and works with tmux mouse mode (the alternatives are in § Things we
  explicitly chose not to do).
- **caffeinate — sleep.** `caffeinate -dimsu` runs as a window inside the
  `agents` session, so its lifetime is the session's: kill the session and the
  Mac may sleep again. It has no child command and no `-t`, and that shape is
  load-bearing (`docs/mobile-terminal-troubleshooting.md`).

## What's installed where

### Laptop

| Path | Purpose |
|---|---|
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

`agents` (`zsh/.config/zsh/utils.zsh`) creates or attaches the `agents`
session, a `caffeinate` window plus a `shell` window, and recreates the
caffeinate window if it was closed; it is idempotent, so run it before leaving
or from the phone. `agents-status` checks the caffeinate window inside that
session rather than `pgrep -x caffeinate`, because macOS daemons spawn their
own caffeinate processes and a system-wide check would lie.

## Daily workflow

1. Leave the laptop open and plugged in, energy settings as above; tmux needs
   no preparation.
2. In Moshi, tap `mac`. From a plain shell, `agents` creates the session,
   attaches, and starts caffeinate.
3. Run `claude`, `codex`, etc. `prefix c` opens a window and `prefix C-h`/`C-l`
   move between them (`tmux/.config/tmux/workflow.md`).
4. Close Moshi; mosh holds the connection, and reopening resumes it.

To warm the session before leaving, run `agents` on the laptop and detach
(`prefix d`). Back home, `tmux kill-session -t agents` releases caffeinate, or
leave it running: plugged in, the energy setting keeps the Mac awake anyway.

### If the phone is lost

1. On the laptop, remove the line ending in `phone@moshi` from `~/.ssh/authorized_keys`. SSH access via that key is revoked immediately.
2. In the Tailscale admin console (login.tailscale.com), remove the phone device.
3. The key in iOS Keychain becomes orphaned and harmless.

## Accessing dev servers from the phone

`localhost` on the phone is always the phone. To reach a dev server running on the laptop you bind it to all interfaces, or front it with Tailscale Serve for real HTTPS, and browse to the laptop's Tailscale hostname. Your phone's *browser* talks to the laptop directly — this path does not involve Moshi at all → `docs/mobile-dev-servers.md`.

## Why the Mac stays awake (defense in depth)

Independent layers, strongest first:

1. **Energy → "Prevent automatic sleeping on power adapter when display is
   off" (ON).** Plugged in, the Mac never idle-sleeps, caffeinate or not.
2. **The `caffeinate -dimsu` window in the `agents` session.** Blocks idle
   sleep on any power source and dies with the session.
3. **Energy → "Wake for network access: Only on Power Adapter".** If the Mac
   does sleep, an incoming Tailscale connection wakes it.

**Lid-closed sleep is not defended.** Closing the lid without an external
display, keyboard and power sleeps the Mac; layer 3 usually brings it back,
but the safe default is to leave the lid open.

## Things we explicitly chose not to do

| Rejected | Reason |
|---|---|
| **Cloudflare Tunnel** for SSH | Built for HTTP services; Tailscale is the laptop-to-phone mesh. |
| **Claude Code Remote Control** | Claude Code only; one workflow has to cover Codex CLI and plain shell work too. |
| **Zellij instead of tmux** | Scroll bug with Codex CLI's alt-screen TUI ([openai/codex#2836](https://github.com/openai/codex/issues/2836)), shallower Moshi integration, and the tmux config already exists. |
| **launchd plist for caffeinate** | The in-session window has the same lifetime with fewer moving parts. |
| **Blink Shell** | Subscription-only, unavailable in some regions. |
| **Termius (free tier)** | No mosh. |
| **Auto-starting agents at login** | Runs tmux and caffeinate when not needed; the laptop stays empty until the session is wanted. |

## Recovery and maintenance

Connection diagnosis, iOS VPN recovery, the failure map, and implementation
invariants live in `docs/mobile-terminal-troubleshooting.md`.
