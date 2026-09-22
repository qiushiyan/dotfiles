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
and can only be re-authorised from the office LAN. Renew it over SSH before
that date:

```bash
ssh -t qiushi-mini 'sudo /opt/homebrew/bin/tailscale up --force-reauth'
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

## Toolchain

Homebrew at `/opt/homebrew`, which also installed the Command Line Tools.
Nothing else is set up yet: no dotfiles, no language runtimes.
