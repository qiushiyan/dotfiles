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
| outbound | its own `~/.ssh/id_ed25519_mac` reaches the laptop (`ssh mac`) and the mini (`ssh mini`); each accepts it only `from="100.95.243.53"` |
| host key | ED25519 `SHA256:T1zEdhpsP0uVUqhyiF/cUChAH1Y6TprWAYsw7iAgvyA` |
| Screen Sharing | on, but a sign-in from the laptop fails with the right password (`screensharingd`: `client evidence does not match`), unresolved; Rex reaches its sessions instead |

The laptop's entry names the tailnet IP rather than the MagicDNS name, as its
`mini` entry does. The outbound key follows
`docs/qiushi-mini.md` § Reaching the laptop, and `twin` needs every machine to reach every other by these
aliases. A new Tailscale node gets a new IP, and the laptop's `HostName` and
both `from=` follow it.

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

## At the desk

mini2 drives the office monitor (LG 32UN880K-B, 32" 4K over USB-C) at
"looks like 3008 × 1692", the text size of the laptop's 27" at 2560 × 1440.
The NuPhy keyboard and the MX Anywhere 3S pair to it over Bluetooth, the
mouse on its own Easy-Switch channel. When the laptop is on the desk,
Universal Control shares them with it. The setup below was worked out while
the mini held the desk, and moved here with it.

- **Keyboard and mouse stay on the same Mac.** Universal Control treats the
  Mac whose devices last produced input as the source. With the keyboard on
  one Mac and the mouse on the other, every keystroke and every mouse move
  swaps the source, and keys land on the wrong machine.
- **The keyboard follows a click, never an app coming to the front.** An app
  launched by hotkey on the other Mac gets no keys until it is clicked once.
  Settings: Displays → Advanced → "Link to Mac or iPad", all options on; the
  laptop arranged to the left under Displays → Arrange, or both of mini2's
  side edges lead to it.
- **The link needs both displays on.** A closed lid, a sleeping display or a
  resolution change marks that Mac unavailable, and the Displays pane shows
  no second machine. Wake both, then push the pointer through the edge or pick
  the laptop under Displays → "+" → Link Keyboard and Mouse. The agent
  (`UniversalControl`, launchd label `com.apple.ensemble`) cannot be
  restarted from a shell: SIP refuses `launchctl kickstart`. To diagnose,
  read its log (`/usr/bin/log`, because zsh has a `log` builtin): category
  `EVNT` records `Current Source Device` and key-focus moves, `SYNC` and
  `DISC` record `Device Unavailable`.

  ```bash
  /usr/bin/log show --last 15m --info --debug --style compact \
    --predicate 'subsystem == "com.apple.universalcontrol"'
  ```
- **A link that stays down with both Macs awake on the desk: restart the
  desk Mac's `rapportd` and `sharingd`.** From the laptop:

  ```bash
  ssh mini2 'killall rapportd sharingd'
  ```

  launchd starts both again and the link is up within seconds; `Connection
  Ready` in the log above confirms it. The hazard: the desk Mac's `rapportd`
  can lose the laptop as a Bluetooth device without finding it again, and then
  never asks it to come up on AWDL. Its own connect times out after
  15 s, and the laptop's incoming connect waits behind it, so both Macs log
  `RPErrorDomain -6722` while the firewall, the LAN and both `awdl0`
  interfaces are fine. The line that tells this case from others is in the
  desk Mac's `rapportd` log:
  `Could not find device to target authTag advertisement to`.

  ```bash
  ssh mini2 '/usr/bin/log show --last 5m --info --debug --style compact \
    --predicate "process == \"rapportd\" AND category == \"CLinkD\"" \
    | grep -E "authTag|timed out"'
  ```

  `killall UniversalControl` leaves the agent running and changes nothing.
- **An Apple Account here puts iCloud within reach of the
  permission-bypassed agents that run here → iCloud Keychain and iCloud Drive
  stay off.** Universal Control needs only the account and Handoff.
- **Hyper + letter launches are Raycast hotkeys, held in Raycast's own
  database; Karabiner only turns Caps Lock into the hyper modifier.** On a
  machine where the launches do nothing, import Raycast's settings: Export
  Settings & Data on the laptop, Import Settings & Data here. Over
  Bluetooth the NuPhy is one combined keyboard-and-pointer device, which
  Karabiner modifies only through its device entry in `karabiner.json`
  (vendor 2007, `ignore: false`); over USB it enumerates as separate keyboard
  and pointer devices and needs no entry.
- **Through Universal Control a modifier arrives once per keyboard of the
  source Mac → ctrl+space reaches macOS as F18.** Karabiner's virtual
  keyboard stands beside the NuPhy, Universal Control mirrors both, and the
  other Mac gets every modifier press and release on each mirror. "Select the
  previous input source" commits when the modifier is released, so bound to
  ctrl+space it switches there and back within 20 ms and the input source
  looks stuck. The rule in `karabiner.json` sends F18 for ctrl+space, which
  has no modifier to release; each Mac binds the shortcut to F18 and keeps
  ctrl+space on "select next source" for a keyboard Karabiner does not modify
  (`docs/migration-app-state.md` §5c has the commands). Any other shortcut
  that acts on a modifier's release is exposed the same way. The rule can go
  when one modifier press on mini2's keyboard logs one event on the laptop
  instead of a pair a millisecond apart:

  ```bash
  /usr/bin/log show --last 1m --info --debug --style compact \
    --predicate 'process == "WindowServer" AND eventMessage CONTAINS "kCGSEventFlagsChanged"'
  ```

## What is set up

`BOOTSTRAP_MACHINE=mini2 ./scripts/bootstrap.sh` built it, then `twin` cloned
every repository in its manifest, installed the tools and copied the carried
files (`docs/twin.md` § A new machine joins). It stows the Makefile's default
set and the Brewfile's every-machine and desk sections, as the laptop does,
and runs `launchd-mini2/`'s agents. What is its own:

- **Logins live in files**, so a session reached over ssh, `twin`'s git
  included, can use them: gh in `~/.config/gh/hosts.yml`
  (`gh auth login --insecure-storage`), Codex by `codex/mini2.toml`'s file
  credential store.
- **The primary Claude account** in `~/.claude` is `qiushi@planlab.ai`, as on
  the laptop (`hosts/mini2.zsh`); the other accounts are the laptop's set.
- **Postgres** carries planlab's lane settings, as the mini's (§ Toolchain
  there).
- **Rex** serves over Tailscale as `qiushi-mini-2-rex`
  (`docs/rex.md` § Several machines).

Not done yet, each needing a login or the screen: the Claude accounts, Codex
and AWS; an Apple Account for Universal Control (above); Raycast's import and
Karabiner's driver and Accessibility grants; Portless (`sudo portless service
install`, then `sudo portless trust` at the screen) and planlab's home
database (`docs/qiushi-mini.md` § planlab checkout); agent-browser; and
`tailscale serve` for drive's page, through the app's CLI above.
