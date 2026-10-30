# Office Mac mini 2 (`ssh qiushi-mini-2`)

The second Mac mini in the office, and the office workstation: the monitor,
keyboard and mouse belong to it. The first mini (`docs/qiushi-mini.md`, "the
mini" everywhere in this repository) stays in the office as compute, where
Claude sessions, planlab lanes and personal jobs run without a screen. For dev
tooling the three machines are equals: each one should carry the daily work
on its own. The docs call this machine **mini2**, the name its
`~/.config/machine` holds. Facts below were collected 2026-10-30.

## Connection

| | |
|---|---|
| alias | `ssh qiushi-mini-2` or `ssh mini2`, from the laptop and the mini: `Host qiushi-mini-2 mini2` in each one's untracked `~/.ssh/config` |
| network | Tailscale, tailnet `planlab-ai.org.github`, node `qiushi-mini-2` (`100.95.243.53`, MagicDNS `qiushi-mini-2.tailf7adf1.ts.net`) |
| LAN | `qiushi-mini-2.local`, wired Ethernet at 1 Gb/s |
| user | `qiushiyan` (`admin` group, sudo **with password**) |
| keys | the laptop's `id_ed25519` and the mini's `id_ed25519_mac` are in `~/.ssh/authorized_keys` |
| host key | ED25519 `SHA256:T1zEdhpsP0uVUqhyiF/cUChAH1Y6TprWAYsw7iAgvyA` |
| Screen Sharing | on: `open vnc://100.95.243.53` from the laptop |

The laptop's entry names the tailnet IP rather than the MagicDNS name, as its
`mini` entry does. mini2 reaches the laptop as `ssh qiushi-mac` (or
`ssh mac`) with its own `~/.ssh/id_ed25519_mac`, which the laptop accepts
only `from="100.95.243.53"`, the pattern in `docs/qiushi-mini.md` § Reaching
the laptop. A new Tailscale node gets a new IP, and both the laptop's
`HostName` and that `from=` follow it.

## Tailscale

The standalone Tailscale.app (the `macsys` variant, a system extension), set
to launch at login. It runs inside the login session, so it is up only while
`qiushiyan` is logged in: lock the screen, never log out. Its CLI is
`/Applications/Tailscale.app/Contents/MacOS/Tailscale`; nothing puts it on
`PATH`. The mini runs Homebrew's `tailscaled` as a system daemon instead,
which survives a logout; moving mini2 to it registers a new node.

Node key expiry is on, as on the mini, and only a tailnet admin can turn it
off. The key expires **2027-04-28**; renew it from the office LAN before then
(`docs/qiushi-mini.md` § Tailscale has why and how).

## Hardware and OS

| | |
|---|---|
| model | Mac mini `Mac17,16` (Z1UD001ATB/A) |
| chip | Apple M5 Pro: 15 CPU cores (5 Super, 10 Performance), 16 GPU cores |
| memory | 64 GB |
| disk | 1 TB internal |
| OS | macOS 27.0 (26A425) |
| power | `pmset -a sleep 0 autorestart 1 womp 1`: never sleeps, restarts after power loss, wake-on-LAN |
| FileVault | **on**. After an unplanned restart mini2 waits at the unlock screen and drops off the tailnet until someone unlocks it in person; for a planned reboot, `sudo fdesetup authrestart`. |

Against the mini (M6, 2 Super + 4 Performance + 6 Efficiency cores, 12 GPU
cores, 32 GB), mini2 has 15 fast cores to the mini's 6 and twice the memory:
the machine for parallel sessions, builds and lanes. One core of the newer M6
is likely as fast as one here.

## What is set up

Remote Login, Screen Sharing, Tailscale, Homebrew, the power settings, and
the machine marker. Nothing from this repository runs here yet: there is no
clone, no stowed package, no `hosts/mini2.zsh` and no `.claude/machines`
session text in effect, and `twin`'s manifest knows only `mac` and `mini`, so
`twin` refuses to run here. Until the setup pass, the desk setup in
`docs/qiushi-mini.md` § At the desk and its toolchain are the reference for
what mini2 will need.
