# mini2 migration: what is still open

A working list for moving the desk to mini2 (`docs/qiushi-mini-2.md`) and the
mini to headless compute (`docs/qiushi-mini.md`). Strike an item by deleting
it; delete the file when it is empty.

## At mini2, needing a login or the screen

- **Desk apps.** Sign in to Linear, Arc, 1Password.
- **macOS loads no font from `~/Library/Fonts`.** The Brewfile's fonts are
  there, but the folder is missing from fontd's registry, and neither
  restarting fontd nor rebuilding the registry adds it. The folder was created
  after this login, so try a restart first (`sudo fdesetup authrestart`), which
  also tests Rex below. Done when `/Applications/Ghostty.app/Contents/MacOS/ghostty
  +list-fonts --family="JetBrainsMono Nerd Font"` lists the family.

## Rex

- Confirm mini2's Rex app restarts its server with Tailscale on (the two
  `defaults` keys were written by hand). The running server predates them: its
  command line has no `--tailscale`, where the mini's has, so the first
  restart is the test, and it ends every session on the server.

## The mini

- Karabiner's driver extension is still active, and clears at the next
  restart; `/Library/Application Support/org.pqrs` holds only the `tmp` it
  recreated. Remove the folder if it survives that restart.
- Decide which of Arc, Chrome, Slack, Raycast and Ghostty to keep once the
  desk has settled on mini2.

## Unresolved

- Screen Sharing from the laptop to mini2 refuses the right password
  (`screensharingd`: `Authentication: FAILED … Type: RSA-SRP`). Not the
  password: changing it with `passwd` changed nothing, and `qiushiyan` is in
  `com.apple.access_screensharing`. mini2 (27.0) signs in to the mini
  (27.0); the laptop runs 26.5. Next: Screen Share from the laptop to the
  mini. If that fails too, it is the laptop's version, not mini2.
- `claude-tomini`, `tomini`, `frommini` and the `mini`/`mac` attach script
  still target the mini only; left as they are for now.
