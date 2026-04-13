# Mobile Terminal Access — Design

**Date:** 2026-04-12
**Status:** Approved, in implementation
**Author brainstorming session:** Qiushi + Claude

## Goal

Be able to control and observe long-running terminal-based AI coding agents (Claude Code, Codex CLI, plus a general shell) on the home MacBook from an iPhone 13, with minimal friction, no public network exposure, and no recurring cost beyond what's already paid.

## Non-goals

- Reaching the laptop from a borrowed/random computer's browser. Web-fallback explicitly out of scope.
- Reaching the laptop when it lives outside the home network — the laptop is assumed to stay on home Wi-Fi.
- Using Claude Code's official Remote Control feature. Considered and rejected: it doesn't generalize beyond Claude Code, and the user prefers a single workflow that handles Codex CLI and arbitrary shell work too.
- Using Zellij as the multiplexer. Considered and rejected: deeper Moshi integration and Codex CLI compatibility favor tmux for this stack, and the existing tmux config is already polished.
- Cloudflare Tunnel for SSH. Wrong tool — Tunnel is built for HTTP services. Tailscale is the consensus for laptop-to-phone mesh access.

## Architecture

Two devices joined by a private mesh network. The phone runs a mosh-capable terminal client; the laptop runs `sshd` + `mosh-server` + a long-lived tmux session. All traffic enters the laptop via the Tailscale interface; nothing is exposed to the public internet.

```
iPhone (Moshi) ──[Tailscale / WireGuard]──► MacBook (sshd → mosh-server → tmux "agents" session)
```

## Components

### Laptop side

| Component | Role | Source |
|---|---|---|
| `sshd` (macOS Remote Login) | Inbound SSH on port 22, reachable only via Tailscale interface | Built-in, already enabled |
| Tailscale (mac client) | Joins laptop to private tailnet, gives stable MagicDNS hostname | Already installed |
| `mosh` / `mosh-server` | UDP transport with predictive echo and roaming resilience | `brew install mosh` |
| `tmux` | Session persistence; agents live in a long-lived `agents` session | Already configured |
| `agents` shell function | Helper that creates/attaches to the agents session and embeds a `caffeinate` window | New, in `zsh/.config/zsh/utils.zsh` |
| `agents-status` shell function | Lists windows in the agents session | New, same file |
| `id_ed25519_phone` SSH key | Dedicated key for the phone, separate from existing dev keys, independently revocable | To be generated with user approval |

### iPhone side

| Component | Role | Cost |
|---|---|---|
| Tailscale iOS app | Joins phone to the same tailnet | Free |
| Moshi iOS app | Mosh+SSH terminal client; stores private key in iOS Keychain behind Face ID | Free |

### Network and auth

- Tailscale tailnet with two members: laptop and phone. Default ACL ("everyone in the tailnet can talk to everyone") is fine — there's nothing else in the tailnet.
- Authentication is SSH public key. The phone gets its own Ed25519 key. The public half goes into the laptop's `~/.ssh/authorized_keys` with a clear comment so it can be revoked independently if the phone is lost.
- The macOS firewall stays in default-deny mode for inbound. All access enters via the `utun` (Tailscale) interface.

## Sleep handling

The laptop must stay awake while agents are running but should not be force-awake forever. Solution: the `agents` tmux session contains a dedicated `caffeinate` window running `caffeinate -dimsu sleep infinity`. The Mac stays awake exactly as long as the session exists; killing the session kills the window, which kills caffeinate, which lets the Mac sleep again. No launchd plist, no polling, no extra moving parts.

## Failure modes and fallbacks

| Failure | Fallback |
|---|---|
| Moshi has rough edges in practice | Switch to plain SSH via Termius free tier (loses mosh roaming, keeps everything else) |
| Mosh UDP blocked on some network | Plain SSH over the same Tailscale tunnel still works |
| Tailscale outage | Fall back to local-network SSH while at home; no remote access in this case |
| Phone lost | Remove `phone@moshi` line from `~/.ssh/authorized_keys` on the laptop; revoke device in Tailscale admin |
| `caffeinate` window accidentally closed | Mac will sleep on its idle timer; just re-run `agents` to recreate |

## Setup phases

1. **Network layer** — Tailscale on laptop (already done) and on iPhone.
2. **Mosh + tmux helpers on laptop** — `brew install mosh`, add `agents`/`agents-status` functions to `zsh/.config/zsh/utils.zsh`, restow.
3. **SSH key** — generate `id_ed25519_phone`, append public half to `authorized_keys`. Requires explicit user approval.
4. **Moshi on iPhone** — install, import private key, configure host entry pointing at the Tailscale MagicDNS name, set post-login command to `tmux new-session -A -s agents`.
5. **Smoke test** — start a session on the laptop, connect from the phone, verify roaming and reconnect.

## What we're explicitly not installing

- ❌ Cloudflare Tunnel
- ❌ Termius (Moshi covers our needs; Termius is a fallback if Moshi disappoints)
- ❌ Blink Shell (unavailable in user's region App Store, and now subscription-only anyway)
- ❌ Zellij
- ❌ Any third-party always-awake utility (Amphetamine, Caffeine.app)
- ❌ Any web-based terminal (ttyd, sshwifty, Wetty)
- ❌ Anthropic Claude Code Remote Control (rejected — see Non-goals)
- ❌ launchd plist for caffeinate (replaced by the simpler in-session caffeinate window)

## Open decisions deferred to implementation

- Exact tmux window layout inside the `agents` session (caffeinate window plus a "shell" window plus on-demand windows for specific agents).
- Whether `agents-status` should pretty-print or just `tmux list-windows -t agents`.
