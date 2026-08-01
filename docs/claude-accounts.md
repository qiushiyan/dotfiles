# Multiple Claude Code accounts

How several Claude subscriptions live on one laptop with simultaneous logins —
switching by launcher instead of `/login` juggling — and how the cross-account
`/usage` dashboard works.

## TL;DR

- **`x`** — Claude with permissions bypassed, on the *last explicitly chosen*
  account. **`x-<name>`** (`x-qiushi`, `x-yan`, …) chooses an account and
  sticks, so the next bare `x` stays there.
- **`claude-usage`** — every account's 5-hour / weekly limit bars in one view;
  `← x` marks where bare `x` currently points.
- **`claude-account-add <email>`**, then that account's `x-<name>` and
  `/login` — onboard a new subscription.
- Pieces: launchers in `zsh/.config/zsh/claude.zsh`, dashboard in
  `scripts/.local/bin/claude-usage`.

## Model — the filesystem is the registry

There is no account list anywhere. The dirs are the registry:

```
~/.claude                     primary account (Claude Code's default dir)
~/.claude-accounts/
  <email>/                    one dir per extra subscription
    settings.json, skills, …    symlinks → claude/.claude  (config: shared)
    .claude.json, history, …    real files                 (runtime: per-account)
  .current                    which account bare `x` targets
  .order                      dashboard display order (optional, one email
                              per line; unlisted accounts follow A–Z)
```

Everything derives from that tree:

- **Isolation.** Claude Code honors `CLAUDE_CONFIG_DIR`, and — the load-bearing
  fact — keys its macOS Keychain credentials *per config dir*: service
  `Claude Code-credentials` for the default dir, plus `-<sha256(dir)[0:8]>` for
  any other (verified against the binary, v2.1.220). So every dir is an
  independent login; `/login` in one session can never clobber another.
- **Sharing.** Account dirs are seeded with symlinks into the repo's
  `claude/.claude`, so all accounts run identical settings/skills/hooks and a
  config edit lands everywhere. Only runtime state (login, history, sessions)
  is per-account.
- **Discovery.** `claude.zsh` globs the dirs at shell init and generates the
  launchers: `x-<email>` always exists and is the guaranteed identity; a
  short `x-<local-part>` alias (`x-yan`) is added only when the local part is
  unique and isn't the primary's name, so a short name can never hit the
  wrong account. `claude-usage` globs the same dirs — the two can't drift.
  Dashboard labels come from the email each dir's `.claude.json` *actually*
  logged in as, with a red warning when that mismatches the dir name (i.e.
  `/login` picked the wrong account); the plan tag comes from the Keychain
  blob's `rateLimitTier`.

## Use patterns

- **Daily**: `x`. Nothing else.
- **Out of quota**: `claude-usage`, pick an account with headroom, launch it
  once by name (`x-yan`) — bare `x` follows from then on.
- **Reorder the board**: edit `~/.claude-accounts/.order`. The primary is
  always first; a new account needs no entry (it appends alphabetically
  until promoted).
- **Prompted (no bypass) session**: `claude-account <name|email>`; it moves
  the `x` target too.
- **New subscription**: `claude-account-add <email>` seeds the dir and names
  the launcher; `/login` on its first launch binds the account.
- **Stale token** on a rarely-used account: the dashboard says so — run that
  account's `x-<name>` once. The dashboard itself is read-only and never
  writes the Keychain; only Claude Code refreshes tokens.
- **Logged into the wrong account in a dir**: the dashboard's red
  `(dir says …!)` warning catches it. Cleanest fix: `/login` again in that
  dir's session with the right account (the misplaced login can be relocated
  by moving its Keychain item + runtime files, but a re-login is simpler).

## Data source

`claude-usage` calls the endpoint Claude Code's own `/usage` screen uses —
`GET api.anthropic.com/api/oauth/usage` with each account's Bearer token from
the Keychain — and renders whatever the response's `limits` array contains
(accounts genuinely differ: some report an all-models weekly limit, some only
a model-scoped one). Fetches run in parallel and accounts fail independently:
a bad credential or drifted response marks that one account while the rest
still render. The endpoint is **undocumented**: the shape has drifted once
already (legacy `five_hour` / `seven_day` fields giving way to `limits`).

The script parses credentials and responses through exactly two jq programs
(`BLOB_JQ`, `LIMITS_JQ`), tolerant by design — a weird field degrades to
`0` / `resets ?` rather than aborting. **`claude-usage --check`** layers the
strict side on those same parsers: for every logged-in account it asserts the
Keychain item under the predicted name, the blob contract, HTTP 200 with ≥ 1
parseable limit row, and that reset timestamps still parse; it also greps the
installed binary for the endpoint/config-dir/credential seams. Because the
checker asserts through the parsers the dashboard renders with, it cannot
drift from what rendering actually needs. Run it after a Claude Code update,
or whenever the dashboard misbehaves; a FAIL line names which assumption
broke.

## Invariants

- Account dirs are runtime state — never in this repo. The symlinks inside
  them point *into* the repo.
- The primary stays in `~/.claude`. Relocating it would orphan its history
  and its default-named Keychain item for no benefit.
- `ACCOUNTS_ROOT`, `PRIMARY_NAME`, and the `.current` state file are declared
  in both `claude.zsh` and `claude-usage` — keep them in sync.
- The launcher-advertising rule (short alias vs full email) also lives twice:
  `_claude_gen_launchers` in `claude.zsh` and `xcmd_for` in `claude-usage` —
  keep those in sync too.
- Bypass-everything, if ever wanted, belongs in `settings.json`
  (`"permissions": { "defaultMode": "bypassPermissions" }`), not in wrappers
  around the `claude` command. PreToolUse hooks still fire and block in
  bypass mode.
