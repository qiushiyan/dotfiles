# Mobile terminal troubleshooting

Satellite of `docs/mobile-terminal-access.md`. Read this when Moshi cannot reach
the laptop, the `agents` session loses its sleep guard, or the access path is
being changed.

## Connection model

```text
Moshi DNS failure ─┐
raw Tailscale IP hangs ├→ likely iOS VPN data plane, not sshd or Moshi
Tailscale app looks healthy ┘

phone attempt → no new sshd log → packets never reached the laptop
phone attempt → sshd log        → debug authentication or mosh handshake
```

Tailscale's control plane and DISCO ping can remain healthy while iOS has torn
down the VPN data plane and MagicDNS resolver. A successful
`tailscale ping iphone-13` from the laptop does not prove that normal packets
can travel from the phone.

## Recover the iOS tunnel

Use the operating-system VPN control:

```text
iOS Settings → General → VPN & Device Management → VPN → Tailscale
Status off → wait 5 seconds → Status on
```

This rebuilds both the data plane and MagicDNS resolver. Force-quitting Moshi
changes no network state. Toggling inside the Tailscale app sometimes repairs
its control view without rebuilding the iOS VPN profile. Reboot the phone only
if the Settings toggle fails.

To distinguish tunnel failure from SSH failure, stream laptop logs while the
phone connects:

```sh
/usr/bin/log stream --predicate 'process == "sshd"' --style compact
```

The absolute path avoids shells where another tool shadows `log`.

## Failure map

| Symptom | Owner | Check or recovery |
|---|---|---|
| `DNS resolution failed` for `qiushi-mac` | iOS Tailscale VPN | Rebuild the VPN profile above. |
| Raw Tailscale IP hangs while peer status is green | iOS Tailscale VPN | Watch sshd logs; no lines means rebuild the VPN profile. |
| `mosh-server: command not found` or UTF-8 error | non-interactive zsh environment | Verify the brew PATH and `LANG` in `zsh/.zshenv`. |
| `caffeinate` window vanished | `agents()` | Run `agents`; it recreates the missing window. |
| Mac cannot wake with lid closed | macOS power policy | Plug it in or leave the lid open; ordinary caffeinate does not defeat lid sleep. |
| Packets reach sshd but login fails | SSH key/auth | Check the `phone@moshi` entry and Moshi's selected key. |

## Maintenance invariants

```text
agents()             → public API; update agents-status with it
caffeinate -dimsu    → no child command and no `-t`
non-interactive SSH  → PATH + UTF-8 come from .zshenv
phone lost           → remove authorized_keys entry + revoke Tailscale device
```

BSD `sleep` rejects `infinity`; adding `sleep infinity` makes the sleep guard
exit immediately. Verify changes with `agents-status` and
`pmset -g assertions | grep PreventSystemSleep`.

The hardlink at `~/.config/zsh/utils.zsh` is benign for editing but unusual for
Stow. If `agents` changes after a restow, compare inodes with `ls -li` before
repairing anything.
