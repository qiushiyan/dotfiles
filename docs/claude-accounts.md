# Multiple Claude Code accounts

How several Claude subscriptions live on one laptop with simultaneous logins —
switching by launcher instead of `/login` juggling — and where each piece
lives.

## TL;DR

```text
x                 → launch on the board's default account
x-<name>          → one launch on a named account; default unchanged
x-accounts / x-acc → choose the default account; no launch
x-select          → resume in the session's project and owning account
x-check           → verify routing after a Claude Code update
```

Every launcher delegates routing and validation to `headroom launch`; wrappers
never set `CLAUDE_CONFIG_DIR` themselves. Accounts are auth/quota lanes.
Sessions are machine-global and remain visible from every lane.

Account lifecycle commands and failure recovery live under **Use patterns**.

## The engine: headroom

This is where the underlying engine lives: **`~/dev/headroom`** — a
standalone Go CLI installed to `~/.local/bin/headroom` via its
`make install`. The account board (`headroom` / `headroom accounts`, with
`--json`), the session picker (`headroom sessions`, with a `--json`
listing; it enters the project dir and execs claude itself), launch routing
(`headroom launch` validates the account, verifies the shared-sessions
topology, and builds the child environment from that decision alone), and
the self-check (`headroom check`) are all engine features; `x`, `x-<name>`,
`x-acc`, `x-select` and `x-check` are thin zsh wrappers over them — flags,
short aliases and the post-session cd, never `CLAUDE_CONFIG_DIR`,
`.current`, or any check a launch depends on: a shell function is frozen at
shell init and lives for weeks, so everything that can misroute lives on
the binary side, re-resolved from PATH at every keystroke. If a
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
  .current                    which account bare `x` targets — headroom's
                              file alone; wrappers never parse it
  state.json                  headroom's own file: request ledger, fetched
                              usage answers, explicit session re-homes
  .order                      board display order (optional, one email
                              per line; unlisted accounts follow A–Z)
```

Everything derives from that tree:

- **Isolation.** Claude Code honors `CLAUDE_CONFIG_DIR`, and — the load-bearing
  fact — keys its macOS Keychain credentials *per config dir*, so every dir is
  an independent login and `/login` in one session can never clobber another.
  (Details of the service-name derivation: headroom's DESIGN.md.)
- **Sharing.** Account dirs are seeded (`headroom accounts add
  --share-config=<dir>`, which `claude-account-add` points at the repo's
  `claude/.claude`) with symlinks into that package, so all accounts run
  identical settings/skills/hooks and a config edit lands everywhere. Only login state (`.claude.json`, the
  Keychain item) and prompt history are per-account.
- **Sessions.** Transcripts carry no credentials and are keyed by project cwd,
  so they belong to the machine, not the account: every account's `projects/`
  symlinks to the primary's store, and any account's picker lists every
  session. Accounts are auth/quota lanes, never history silos. The store, its
  retention policy and its repair runbook: `docs/claude-sessions-store.md`.
- **Discovery.** `claude.zsh` globs the dirs at shell init and generates the
  launchers: `x-<email>` always exists and is the guaranteed identity; a
  short `x-<local-part>` alias (`x-yan`) is added only when the local part is
  unique and isn't the primary's name, so a short name can never hit the
  wrong account. Short aliases are this repo's convenience alone — headroom
  advertises only the full identity, and every launcher body just delegates
  to `headroom launch --account <email>`, which discovers the same dirs and
  revalidates, so a stale or ambiguous name fails by name instead of routing
  anywhere. Board labels come from the email each dir's `.claude.json`
  *actually* logged in as, with a red warning when that mismatches the dir
  name (i.e. `/login` picked the wrong account).

## Use patterns

- **Daily**: `x`. Nothing else.
- **Which lane is a running session on, and how much is left in it?** Its
  tmux pane border says so — the context chip
  (`yan 5h:23 Fable:15 opus-5[1m] ✳ 37%`) leads with the account's email local
  part, or the full email when two lanes share one, and follows it with that
  lane's 5-hour and model-scoped weekly limits. `x-acc` remains the complete
  board; the chip answers only for the pane in front of you. Rendering, quota
  sources, identity fallbacks, freshness, and shedding live in
  `tmux/.config/tmux/scripts/context-chip.md`.
- **Out of quota**: `x-accounts` (or `x-acc`) — pick an account with
  headroom off the live board, then type `x`; bare `x` targets it from then
  on. For a one-off session on another account without moving `x`, that
  account's `x-<name>`.
- **Resume an old conversation**: `x-select` — every session on the
  machine, this repo's (all worktrees) on top. Enter continues it in its
  own project dir on the account that last drove it, so a session keeps its
  account (and its `/rewind` checkpoints) no matter what `x-accounts` did
  since; the cd sticks after the session ends. `x` on a row resumes it on
  the current account instead *and re-homes it* — from then on it lives
  there (recorded in headroom's `state.json`; also the escape hatch when a
  session's account was deleted). Rows whose project dir no longer exists
  say so and refuse — `dd` is the cleanup. Native `x --resume` still works
  and always uses the current account.
- **Reorder the board**: edit `~/.claude-accounts/.order`. The primary is
  always first; a new account needs no entry (it appends alphabetically
  until promoted).
- **Prompted (no bypass) session**: `claude-account <name|email>` (alias
  `x-account`); like `x-<name>`, bare `x`'s target is untouched.
- **New subscription**: `claude-account-add <email>` ≡ `headroom accounts
  add --share-config=~/dotfiles/claude/.claude <email>` plus launcher
  regeneration — the engine makes the dir, links `projects/`, symlinks every
  entry of the config package, and verifies the topology it just built;
  `/login` on its first launch binds the account.
- **Retired subscription**: `claude-account-remove <email>` (alias
  `x-account-remove`) ≡ `headroom accounts remove <email>` plus dropping the
  generated launchers — the engine refuses while the account has a live (or
  unverifiable) session, asks for the dir name back (`--yes` off a
  terminal), then deletes its Keychain item (service
  `Claude Code-credentials-` + `sha256(dir)[:8]`, the same derivation Claude
  Code uses — headroom's one Keychain write, DESIGN.md's third documented
  exception) and the dir, and scrubs the `.order` line. Transcripts
  survive — they are machine-global —
  and the picker shows the dead owner as degraded until `x` re-homes each
  session. `.current` is never rewritten behind headroom's back: if bare `x`
  pointed at the removed account, launches refuse until `x-acc` repicks.
- **A `<name>.lock` "account" appears**: vendor lock debris, not an account —
  Claude Code's config locking creates `<dir>.lock` directories and a crash
  strands them in the accounts root (observed 2026-08-10). headroom's
  discovery and the launcher glob both skip them, and `headroom check` names
  stranded ones; `claude-account-remove <name>.lock` (or a plain `rm -rf`
  with no claude running) deletes the debris.
- **Stale token** on a rarely-used account: the board says so — run that
  account's `x-<name>` once. Claude Code alone refreshes tokens. Headroom's
  routine paths write only `.current`, `state.json`, and explicit session
  rename/delete operations; account removal is the one path that deletes a
  vendor credential from Keychain.
- **After a Claude Code update**, or when the board misbehaves:
  `x-check` — a FAIL line names which reverse-engineered assumption
  broke. Run `claude-sessions-check` alongside it for the session-sharing
  machinery; its `--canary` proves cross-account resume end to end but
  spends one request on two accounts.
- **Launcher refuses with a topology error**: that account's `projects`
  became a real directory again, or a wrong link — quit every Claude session
  and run `claude-sessions-migrate` → `docs/claude-sessions-store.md`.
- **Logged into the wrong account in a dir**: the dashboard's red
  `(dir says …!)` warning catches it. Cleanest fix: `/login` again in that
  dir's session with the right account.

## Invariants

- Account dirs are runtime state — never in this repo. The symlinks inside
  them point *into* the repo.
- The primary stays in `~/.claude`. Relocating it would orphan its history
  and its default-named Keychain item for no benefit.
- `~/.claude/projects` is a real directory — never itself a link — and every
  account dir's `projects` is a symlink to it. Everything that rests on that
  (retention, obelisk's index, the migrate runbook, the test harness):
  `docs/claude-sessions-store.md`.
- Launch routing belongs to headroom, verification included: wrappers
  delegate to `headroom launch` / `headroom sessions`, which validate the
  account and the shared-sessions topology themselves — wrappers never set
  `CLAUDE_CONFIG_DIR`, never launch bare `claude`, never parse `.current`,
  and never parse anything headroom prints. When headroom is missing or
  refuses, they stop loudly rather than falling back; the unmanaged escape
  hatch is `env -u CLAUDE_CONFIG_DIR claude` (or the variable set by hand). Short
  `x-<local-part>` aliases and the reserved utility names are `claude.zsh`'s
  own concern — headroom advertises only full identities, so there is no
  naming policy to keep in sync.
- `CLAUDE_ACCOUNTS_ROOT` matches headroom's default accounts root; the
  primary's name is *not* a headroom default anymore — headroom derives it
  from the primary's logged-in email unless `HEADROOM_PRIMARY_NAME` pins it,
  and `claude.zsh` exports that variable from `CLAUDE_PRIMARY_NAME` so both
  sides answer to `qiushi` by one declaration. The other `HEADROOM_*` env
  overrides re-point headroom only (they exist for
  its test harnesses); under one, wrapper degradations are loud or absent —
  a launcher that doesn't exist, a preflight that refuses — never a silent
  misroute, because the preflight follows headroom's classification.
- tmux strips `CLAUDE_CONFIG_DIR` from the server's global environment at
  start (`tmux.conf`): a server started from inside a Claude Code session
  would otherwise hand every pane that session's account. Managed launches
  neutralize the variable regardless — this line protects everything
  *outside* them that still reads it.
- Bypass-everything, if ever wanted, belongs in `settings.json`
  (`"permissions": { "defaultMode": "bypassPermissions" }`), not in wrappers
  around the `claude` command. PreToolUse hooks still fire and block in
  bypass mode — and `permissions.deny` rules survive it too, which is why
  `docs/bypass-cd-read-guard.md` exists (a temporary hook for a 2.1.259
  prompt that bypass mode does not skip).
