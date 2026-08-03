# Multiple Claude Code accounts

How several Claude subscriptions live on one laptop with simultaneous logins —
switching by launcher instead of `/login` juggling — and where each piece
lives.

## TL;DR

- **`x`** — Claude with permissions bypassed, on the *last explicitly chosen*
  account. **`x-<name>`** (`x-qiushi`, `x-yan`, …) chooses an account and
  sticks, so the next bare `x` stays there.
- **`x-usage`** — every account's 5-hour / weekly limit bars in one view;
  `← x` marks where bare `x` currently points. `x-usage check` verifies the
  machinery after a Claude Code update.
- **`x-select`** — interactive picker: choose an account off the live usage
  board, stick like `x-<name>` does, then launch on it.
- **Sessions are machine-global** — `x --resume` from any account lists every
  session on the machine (`Ctrl+W` all worktrees, `Ctrl+A` all projects);
  which account recorded a conversation never matters.
  `claude-sessions-check` verifies the sharing machinery.
- **`claude-account-add <email>`** (alias **`x-account-add`**), then that
  account's `x-<name>` and `/login` — onboard a new subscription.
- Pieces: launchers in `zsh/.config/zsh/claude.zsh` (this repo); the
  dashboard/picker engine is **headroom**, a separate Go project (see below).

## The engine: headroom

This is where the underlying engine lives: **`~/dev/headroom`** — a
standalone Go CLI installed to `~/.local/bin/headroom` via its
`make install`. The dashboard (`headroom`, with `--json` and `watch` forms),
the interactive picker (`headroom select`), and the self-check
(`headroom check`) are all engine features; `x-usage` and `x-select` are
one-line zsh wrappers over them. If a
wrapper misbehaves, the fix is almost certainly in the engine — its mental
model, the reverse-engineered vendor contracts (Keychain service naming, the
OAuth usage endpoint, response-drift handling), and its verification story
live in `~/dev/headroom/DESIGN.md`, not here.

## Model — the filesystem is the registry

There is no account list anywhere. The dirs are the registry:

```
~/.claude                     primary account (Claude Code's default dir)
  projects/                   the canonical session store — all accounts share it
~/.claude-accounts/
  <email>/                    one dir per extra subscription
    settings.json, skills, …    symlinks → claude/.claude   (config: shared)
    projects                    symlink → ~/.claude/projects (sessions: shared)
    .claude.json, history, …    real files                  (login: per-account)
  .current                    which account bare `x` targets
  .order                      dashboard display order (optional, one email
                              per line; unlisted accounts follow A–Z)
```

Everything derives from that tree:

- **Isolation.** Claude Code honors `CLAUDE_CONFIG_DIR`, and — the load-bearing
  fact — keys its macOS Keychain credentials *per config dir*, so every dir is
  an independent login and `/login` in one session can never clobber another.
  (Details of the service-name derivation: headroom's DESIGN.md.)
- **Sharing.** Account dirs are seeded with symlinks into the repo's
  `claude/.claude`, so all accounts run identical settings/skills/hooks and a
  config edit lands everywhere. Only login state (`.claude.json`, the
  Keychain item) and prompt history are per-account.
- **Sessions.** Transcripts are keyed by project cwd and carry no
  credentials, so they belong to the machine, not the account: every
  account's `projects/` symlinks to the primary's store, the resume picker
  in any account lists every session, and resuming appends to the one
  canonical file — accounts are auth/quota lanes, never history silos. The
  launcher re-verifies the link (by inode) on every launch and refuses to
  start over a broken topology, because a real directory there would fork
  history silently. Per-session extras (`file-history/`, todos,
  `session-env/`) stay account-local: resuming under a different account
  keeps the conversation, not `/rewind` checkpoints. Retention is one
  policy by construction — `cleanupPeriodDays` is pinned in the shared
  `settings.json` (never `0`, which disables persistence, not cleanup),
  and every account's cleanup pass applies it to the shared store.
- **Discovery.** `claude.zsh` globs the dirs at shell init and generates the
  launchers: `x-<email>` always exists and is the guaranteed identity; a
  short `x-<local-part>` alias (`x-yan`) is added only when the local part is
  unique and isn't the primary's name, so a short name can never hit the
  wrong account. headroom discovers the same dirs — the two can't drift.
  Dashboard labels come from the email each dir's `.claude.json` *actually*
  logged in as, with a red warning when that mismatches the dir name (i.e.
  `/login` picked the wrong account).

## Use patterns

- **Daily**: `x`. Nothing else.
- **Out of quota**: `x-select` — pick an account with headroom off the live
  board; bare `x` follows from then on. (Or `x-usage` to look, then an
  `x-<name>` by hand.)
- **Resume an old conversation**: `x --resume` on whatever account has
  quota — the picker sees every session on the machine.
- **Reorder the board**: edit `~/.claude-accounts/.order`. The primary is
  always first; a new account needs no entry (it appends alphabetically
  until promoted).
- **Prompted (no bypass) session**: `claude-account <name|email>` (alias
  `x-account`); it moves the `x` target too.
- **New subscription**: `claude-account-add <email>` seeds the dir and names
  the launcher; `/login` on its first launch binds the account.
- **Stale token** on a rarely-used account: the dashboard says so — run that
  account's `x-<name>` once. Only Claude Code refreshes tokens; the engine is
  read-only (its single write is `.current`).
- **After a Claude Code update**, or when the dashboard misbehaves:
  `x-usage check` — a FAIL line names which reverse-engineered assumption
  broke. Run `claude-sessions-check` alongside it for the session-sharing
  machinery; its `--canary` proves cross-account resume end to end but
  spends one request on two accounts.
- **Launcher refuses with a topology error**: that account's `projects`
  became a real directory again (or a wrong link) — quit every Claude
  session and run `claude-sessions-migrate`. It is all-or-nothing: refuses
  while any session runs, verifies a hash manifest of every source file
  before swapping, and keeps each merged tree as a
  `projects.pre-share.<timestamp>` backup.
- **Logged into the wrong account in a dir**: the dashboard's red
  `(dir says …!)` warning catches it. Cleanest fix: `/login` again in that
  dir's session with the right account.

## Invariants

- Account dirs are runtime state — never in this repo. The symlinks inside
  them point *into* the repo.
- The primary stays in `~/.claude`. Relocating it would orphan its history
  and its default-named Keychain item for no benefit.
- `~/.claude/projects` is a real directory — never itself a link — and every
  account dir's `projects` is a symlink to it. Seeding creates the link
  (`_claude_link_projects` in `zsh/.config/zsh/claude.zsh`), every launch
  re-checks it, and `claude-sessions-migrate` converts a tree that predates
  the convention. The session toolkit and its sandbox harness live in
  `zsh/.config/zsh/claude-sessions.zsh` and `zsh/.config/zsh/tests/` — run
  the harness after touching either file.
- obelisk (session-history search) indexes `~/.claude/projects` and so sees
  every account's sessions. Index it incrementally, never `obelisk --build`:
  a force rebuild mirrors only files still on disk, and for transcripts
  retention already pruned, the index row is the last record in existence.
- The launcher-advertising rule lives twice: `_claude_gen_launchers` in
  `claude.zsh` and `accounts.Launcher` in headroom — keep them in sync,
  including the reserved local parts (`usage`, `account`, `account-add`,
  `select`) that x-* utilities claim ahead of any account.
- `ACCOUNTS_ROOT`, `PRIMARY_NAME`, and the `.current` state file are declared
  in `claude.zsh` and in headroom's config defaults — keep those in sync too
  (headroom side is overridable via `HEADROOM_*` env vars).
- Bypass-everything, if ever wanted, belongs in `settings.json`
  (`"permissions": { "defaultMode": "bypassPermissions" }`), not in wrappers
  around the `claude` command. PreToolUse hooks still fire and block in
  bypass mode.
