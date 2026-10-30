# mini2 migration: what is still open

A working list for moving the desk to mini2 (`docs/qiushi-mini-2.md`) and the
mini to headless compute (`docs/qiushi-mini.md`). Strike an item by deleting
it; delete the file when it is empty.

## At mini2, needing a login or the screen

- **Apple Account**, with iCloud Keychain and iCloud Drive off and Handoff
  on; then link the laptop through Universal Control
  (`docs/qiushi-mini-2.md` § At the desk).
- **Desk apps.** Raycast: Export Settings & Data on the laptop, Import here.
  Karabiner's driver approval and Accessibility and Automation grants
  (`docs/migration-app-state.md` § 5c. App permissions, sign-ins, defaults to undo). Sign in to Slack, Linear, Arc, 1Password.
- **Portless's CA trust, at the screen**: `sudo portless trust` in a
  Ghostty window outside Rex, approving the macOS dialog. From a Rex
  session it times out, as over SSH: the dialog never shows. The service is
  installed (Node 24, `--tld localhost --tld local.itell.ai`), and the CA is
  in the System keychain without trust settings. The rest of planlab's lane
  setup is done.
- **Vercel for itell.** The CLI is signed in as `qiushi-8199` (teams
  `planlab-support` and personal), which cannot see itell's project
  (`team_WN5ARgxWCuO0ZJZMJPj2wKeX`), so itell's staging checks fail at
  `vercel env pull --environment=staging`. Sign in with the account in
  itell's team, or `vercel switch` to it.
- **drive's page** on the tailnet:
  `/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https=8444 http://127.0.0.1:8792`.
- **Time Machine to the T7, Monday 2026-11-02**, and the mini's old
  destination removed: `docs/recovery.md` § Time Machine on mini2.

## Rex

- TabType's `rex_hosts` (`tabtype/.config/tabtype/config.toml`) names the mini
  and the laptop only; add mini2's server once its label is settled.
- The laptop's server lists the mini for the agents board (`rex hosts add`);
  add mini2 there too (`docs/rex.md` § Several machines).
- Confirm mini2's Rex app restarts its server with Tailscale on (the two
  `defaults` keys were written by hand).

## The mini

- `sudo rm -rf "/Library/Application Support/org.pqrs"`; Karabiner's driver
  extension clears at the next restart.
- Decide which of Arc, Chrome, Slack, Raycast and Ghostty to keep once the
  desk has settled on mini2.

## Unresolved

- Screen Sharing to mini2 refuses the right password
  (`screensharingd`: `client evidence does not match`).
- `claude-tomini`, `tomini`, `frommini` and the `mini`/`mac` attach script
  still target the mini only; left as they are for now.
