# AWS SSO sessions and `aws-login`

The AWS CLI signs in to planlab's IAM Identity Center through the
`[sso-session planlab]` block in `~/.aws/config` (the same file on the laptop
and the mini; `docs/qiushi-mini.md` § Toolchain). The organisation's session
limit is 8 hours and not mine to change, so an agent that needs CloudWatch or
S3 for longer than that depends on someone signing in again.
`scripts/.local/bin/aws-login` is that sign-in, for a human at the terminal
and for the Codex automation alike.

## Three clocks, and which one `aws sso login` resets

- **Access token** (`~/.aws/sso/cache/<hash>.json`, `expiresAt`): one hour.
  The CLI refreshes it on its own with the cached `refreshToken`, which is why
  the file's `expiresAt` is always about an hour ahead of its mtime and says
  nothing about when the sign-in ends.
- **Identity Center session** (AWS calls it the user interactive session):
  8 hours by default, 15 minutes to 90 days at the admin's choice. Refresh
  works only while it lives; when it ends, the next refresh fails and every
  profile on the `sso-session` needs a new sign-in. This is the clock that
  forces the daily logins.
- **Role credentials** (`~/.aws/cli/cache/`, from the permission set): issued
  per profile, up to 12 hours, and they keep working after the session ends.

`aws sso login` alone does **not** restart the second clock while the browser
is still signed in to the access portal: "If you already have an active
session, the existing session is reused and expires when the existing session
expires." So a login that only shows "Allow access" hands the CLI a new token
on the old session, and the 8 hours still run from the first sign-in.
`aws sso logout` ends the server-side Identity Center session, so the sign-in
after it is a real one, with the full duration. Sources, read 2026-09-28: the
AWS CLI user guide `cli-configure-sso-concepts` (the reuse rule) and the SSO
Portal API `Logout` reference (the server-side end).

## What `aws-login` does

```bash
aws-login                     # planlab-prod
aws-login planlab-dev         # any profile in ~/.aws/config
aws-login --status            # what the CLI has now; exit 1 when nothing works
```

It signs out (ending the session on AWS's side and clearing every profile's
cached credentials), signs in with the device-code flow on the mini, verifies
with `aws sts get-caller-identity`, and only then stamps the sign-in time,
which `--status` reads back; the script's header has the details.

- **Expect the passkey prompt.** After the sign-out the portal is signed out
  too. A run that only asks "Allow access" is the reuse case above: the logout
  did not reach the server, so check the network before trusting the new
  token's clock.
- **A failed login leaves the CLI with nothing**, since the old session is
  already gone; exit 1 tells an agent to escalate rather than retry blindly.
  Exit 2 is a bad argument or a profile not in `~/.aws/config`, checked before
  anything is signed out.

## Machines

- **Laptop:** the default PKCE flow opens Arc, which redirects to a listener on
  localhost. The Codex Desktop automation "Refresh planlab-prod AWS SSO"
  (`~/.codex/automations/`, runtime state, not tracked) runs every 8 hours
  and drives 1Password and the "Allow access" button by computer use. Its
  prompt must call `aws-login` rather than `aws sso login`, or the run
  refreshes the token on the old session whenever it fires while the portal
  is still signed in.
- **Mini:** the `scripts` package is stowed there, so the script is on PATH
  as on the laptop. Over SSH the device-code URL goes to
  the laptop clipboard through `BROWSER=browser-clip`; paste it in any
  browser and approve. The mini keeps its own token cache and stamp, since
  refresh tokens rotate and two machines cannot share one.

## Checking that a run started a new session

The access portal lists the user's own active sessions with their start
times (IAM Identity Center user guide, "Viewing and ending your active
session"). After `aws-login`, the list should show one session started at
the time the script printed; a login that reused the session leaves the old
start time in place. `aws-login --status` then keeps the answer local.

Pinned by `scripts/.local/share/dotfiles/tests/test-aws-login.sh`
(`docs/testing.md`).
