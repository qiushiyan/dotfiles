# AWS SSO sessions and `aws-login`

The AWS CLI signs in to planlab's IAM Identity Center through the
`[sso-session planlab]` block in `~/.aws/config` (the same file on the laptop
and the mini; `docs/qiushi-mini.md` § Toolchain). The organisation's session
limit is 8 hours and not mine to change, so an agent that needs CloudWatch or
S3 for longer than that depends on someone signing in again.
`aws-login`, the Go CLI in `~/dev/aws-login` that twin builds on every
machine, is that sign-in, for a human at the terminal and for the Codex
automation alike. Its `--help` owns what it does and its exit codes;
`~/dev/aws-login/docs/design.md` owns its design and the behaviour this
repository relies on.

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

## Using `aws-login`

```bash
aws-login                     # planlab-prod, signed in only if it has no credentials
aws-login planlab-personal    # any profile in ~/.aws/config
aws-login --renew             # a new session with the full 8 hours
aws-login --status            # what the CLI has now; exit 1 when nothing works
```

- **A profile that already works is never signed out.** The planlab SSO
  profiles all use the one `[sso-session planlab]`, so while that session lives
  each of them gets credentials, and signing in to a second account must not
  cost the first one its session. `aws-login` signs out and in only when the
  named profile has no credentials, or with `--renew`; the sign-out is there
  only to restart the second clock, and it ends the session for every
  profile until the sign-in succeeds.
- **Expect the passkey prompt.** After the sign-out the portal is signed out
  too. A run that only asks "Allow access" is the reuse case above: the logout
  did not reach the server, so check the network before trusting the new
  token's clock.
- **A failed login leaves the CLI with nothing**, since the old session is
  already gone; exit 1 tells an agent to escalate rather than retry blindly.

## Machines

- **Laptop:** the default PKCE flow opens Arc, which redirects to a listener on
  localhost. The Codex Desktop automation "Refresh planlab-prod AWS SSO"
  (`~/.codex/automations/`, runtime state, not tracked) runs every 8 hours
  and drives 1Password and the "Allow access" button by computer use. Its
  prompt must call `aws-login --renew`: plain `aws-login` does nothing while
  the session lives, and `aws sso login` refreshes the token on the old
  session, so either leaves the 8 hours running from the last real sign-in.
- **Minis:** twin builds the tool on each, as on the laptop. Over SSH the device-code URL goes to
  the laptop clipboard through `BROWSER=browser-clip`; paste it in any
  browser and approve. Each machine keeps its own token cache and stamp,
  since refresh tokens rotate and two machines cannot share one.

## Console links

`sso_start_url` in `~/.aws/config` is the Identity Center issuer URL
(`https://identitycenter.amazonaws.com/ssoins-7223ebd098f80c49`). The CLI
accepts it, but a browser gets 404 there. The access portal is
`https://ssoins-7223ebd098f80c49.portal.us-east-1.app.aws/`, and a link that
signs in to an account and role and then opens a console page is

```
<portal>/#/console?account_id=<id>&role_name=<role>&destination=<url-encoded console URL>
```

Account ids and role names are the profiles' `sso_account_id` and
`sso_role_name`. The Health API (`aws health describe-events`) answers
`SubscriptionRequiredException` on these accounts, which have no Business or
Enterprise support, so open issues are read in the console.

## Checking that a run started a new session

The access portal lists the user's own active sessions with their start
times (IAM Identity Center user guide, "Viewing and ending your active
session"). After a run that signed in, the list should show one session
started at the time `aws-login` printed; a login that reused the session leaves the old
start time in place. `aws-login --status` then keeps the answer local.
