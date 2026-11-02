# mini2 migration: what is still open

A working list for moving the desk to mini2 (`docs/qiushi-mini-2.md`) and the
mini to headless compute (`docs/qiushi-mini.md`). Strike an item by deleting
it; delete the file when it is empty.

## At mini2, needing a login or the screen

- **Desk apps.** Sign in to Linear, Arc, 1Password.
- **Reinstall Karabiner.** `/Library/Application Support/org.pqrs` was removed
  here on 2026-11-02, and the services that lived in it stopped at the restart:
  `brew reinstall --cask karabiner-elements`, then approve what it asks. Done
  when `pgrep -f Karabiner-Core-Service` finds it.

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
