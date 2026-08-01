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
  `x-<name>` functions (email local part; collisions fall back to full-email
  names). `claude-usage` globs the same dirs — the two can't drift. Dashboard
  labels come from the email each dir's `.claude.json` *actually* logged in
  as, with a red warning when that mismatches the dir name (i.e. `/login`
  picked the wrong account); the plan tag comes from the Keychain blob's
  `rateLimitTier`.

## Use patterns

- **Daily**: `x`. Nothing else.
- **Out of quota**: `claude-usage`, pick an account with headroom, launch it
  once by name (`x-yan`) — bare `x` follows from then on.
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
a model-scoped one). The endpoint is **undocumented**: parse defensively and
expect its shape to drift, as it already has once (legacy `five_hour` /
`seven_day` fields giving way to `limits`).

**`claude-usage --check`** verifies every reverse-engineered assumption in one
shot — Keychain item naming, credential blob shape, `.claude.json` shape, the
endpoint string in the installed binary, and the live response contract. Run
it after a Claude Code update, or whenever the dashboard misbehaves; a FAIL
line names which assumption broke.

## Invariants

- Account dirs are runtime state — never in this repo. The symlinks inside
  them point *into* the repo.
- The primary stays in `~/.claude`. Relocating it would orphan its history
  and its default-named Keychain item for no benefit.
- `ACCOUNTS_ROOT`, `PRIMARY_NAME`, and the `.current` state file are declared
  in both `claude.zsh` and `claude-usage` — keep them in sync.
- Bypass-everything, if ever wanted, belongs in `settings.json`
  (`"permissions": { "defaultMode": "bypassPermissions" }`), not in wrappers
  around the `claude` command. PreToolUse hooks still fire and block in
  bypass mode.
