# Multiple Claude Code accounts

How several Claude subscriptions live on one laptop with simultaneous logins —
switching by launcher instead of `/login` juggling — and where each piece
lives.

## TL;DR

```text
x                 → launch on the board's default account
x-<name>          → one launch on a named account; default unchanged
x-accounts / x-acc → choose the default account (compact board); no launch
x-select          → resume in the session's project and owning account
x-check           → verify routing after a Claude Code update
headroom login    → renew the logins that end within a week, one click each
```

Every launcher delegates routing and validation to `headroom launch`; wrappers
never set `CLAUDE_CONFIG_DIR` themselves. Accounts are auth/quota lanes.
Sessions are machine-global and remain visible from every lane.

Account lifecycle commands and failure recovery live under **Use patterns**.

## The engine: headroom

**`~/dev/headroom`**, a Go CLI installed to `~/.local/bin/headroom` by its
`make install`, owns the account board, the session picker, launch routing and
`headroom check`; the `x*` launchers in `zsh/.config/zsh/claude.zsh` are thin
wrappers, and that file's header says why nothing that can misroute lives in
them. A misbehaving wrapper is almost always an engine fix: its mental model,
vendor contracts and verification live in `~/dev/headroom/DESIGN.md`.

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
  The service-name derivation: `~/dev/headroom/DESIGN.md` § The system
  observed: the filesystem is the registry.
- **Sharing.** Account dirs are seeded with symlinks into the repo's
  `claude/.claude`, so all accounts run identical settings/skills/hooks and a
  config edit lands everywhere. Mods ride the same link: the shared
  `settings.json` names their folders (`docs/claude-mods.md`). Only login state (`.claude.json`, the Keychain
  item) and prompt history are per-account.
- **Sessions** belong to the machine, not the account:
  `docs/claude-sessions-store.md` § One store, many accounts.
- **Launchers** are generated from the dirs at shell init: `x-<email>` always,
  and a short `x-<local-part>` only when it is unambiguous. The naming rules
  are `claude.zsh`'s header; headroom revalidates every name, so a stale or
  ambiguous one fails by name instead of routing anywhere.

## Use patterns

- **Daily**: `x`. Nothing else.
- **Effort per workspace**: list the dir in `CLAUDE_X_EFFORT` in `claude.zsh`;
  a launch inside it adds `--effort <level>` for that session only, over
  `settings.json`'s default. Precedence and the `x-select` gap are in the
  comment above the table.
- **Which lane is a running session on, and how much is left in it?** Its
  tmux context chip leads with the account, then the model and the lane's
  5-hour and 7-day usage (`yan opus-5[1m]:high 5h:23 7d:41 ✳ 37%`); `x-acc`
  is the complete board. The
  chip's rendering and quota sources: `tmux/.config/tmux/scripts/context-chip.md`.
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
  regeneration; the engine seeds and verifies the dir, and `/login` on its
  first launch binds the account.
- **Retired subscription**: `claude-account-remove <email>` (alias
  `x-account-remove`) ≡ `headroom accounts remove <email>` plus dropping the
  generated launchers. The engine refuses while the account has a live (or
  unverifiable) session, asks for confirmation (`--yes` off a terminal), then
  deletes the account's Keychain item, its dir and its `.order` line
  (`~/dev/headroom/DESIGN.md` § The account lifecycle). Transcripts survive —
  they are machine-global — and the picker shows the dead owner as degraded
  until `x` re-homes each session. If bare `x` pointed at the removed account,
  launches refuse until `x-acc` repicks.
- **A `<name>.lock` "account" appears**: vendor lock debris a crashed Claude
  Code strands in the accounts root, not an account. Discovery skips it,
  `headroom check` names it, and `claude-account-remove <name>.lock` (or a
  plain `rm -rf` with no claude running) deletes it.
- **Stale token** on a rarely-used account: the board says so — run that
  account's `x-<name>` once. Claude Code alone refreshes tokens.
- **Logins ending**: a login lasts about a month from the day it was made,
  however much the account is used, and each machine holds its own login
  per account. `headroom login` renews every one that ends within a week,
  `headroom login --all` every account so they end together, and
  `headroom login <name>` one the vendor refused early (`Login expired ·
  Please run /login` while the board still showed it healthy). Each
  approval page opens in the Chrome profile named after the account's local
  part, so the click is Authorize and nothing else; a `✗ … logged in as`
  line means the wrong profile approved. Over ssh from the other machine,
  run `security unlock-keychain` in that session first, or the accounts
  whose login lives in the Keychain are left alone; each URL then opens on
  the machine you are at, and you paste back the code it shows. The
  mechanism: `~/dev/headroom/DESIGN.md` § Renewing logins.
- **After a Claude Code update**, or when the board misbehaves:
  `x-check` (`headroom check`) — a FAIL line names which reverse-engineered
  assumption broke. It also covers the session-sharing machinery: a
  `topology[...]` line per account, and one `settings:` and one
  `retention:` line (`docs/claude-sessions-store.md` § Retention belongs to
  ccclean).
- **Launcher refuses with a topology error**: that account's `projects`
  became a real directory again, or a wrong link. The error names the end
  state; the manual repair is in `docs/claude-sessions-store.md` § Repairing
  the topology.
- **An MCP server asks for its login again on each account**: Claude Code
  stores an MCP server's OAuth login in the account's Keychain item, beside
  the Claude login, so it is per-account like the login itself. A server
  every account should reach authenticates with a static key instead: the
  project's `.mcp.json` declares it with `"Authorization": "Bearer ${NAME}"`,
  and `~/.secrets` exports `NAME`. When a plugin ships a server at the same
  URL, the declared one replaces it and the plugin's skills and hooks keep
  working. Two traps: a set `Authorization` header disables OAuth for that
  server, so an unset variable is a failed connection; and a `headersHelper`
  cannot read the key from the environment, because Claude Code strips
  credential-named variables from the helper's process. iTELL's PostHog
  server (`POSTHOG_MCP_API_KEY`) is the instance.
- **Logged into the wrong account in a dir**: the dashboard's red
  `(dir says …!)` warning catches it. Cleanest fix: `headroom login <name>`,
  or `/login` again in that
  dir's session with the right account.

## Invariants

- Account dirs are runtime state — never in this repo. The symlinks inside
  them point *into* the repo.
- The primary stays in `~/.claude`. Relocating it would orphan its history
  and its default-named Keychain item for no benefit.
- `~/.claude/projects` is a real directory — never itself a link — and every
  account dir's `projects` is a symlink to it. Everything that rests on that
  (retention, obelisk's index, the repair runbook, where it is tested):
  `docs/claude-sessions-store.md`.
- Launch routing belongs to headroom, verification included: wrappers
  delegate to `headroom launch` / `headroom sessions`, which validate the
  account and the shared-sessions topology themselves — wrappers never set
  `CLAUDE_CONFIG_DIR`, never launch bare `claude`, never parse `.current`,
  and never parse anything headroom prints. When headroom is missing or
  refuses, they stop loudly rather than falling back; the unmanaged escape
  hatch is `env -u CLAUDE_CONFIG_DIR claude` (or the variable set by hand).
- `CLAUDE_ACCOUNTS_ROOT` matches headroom's default accounts root, and
  `claude.zsh` pins headroom's primary name to `CLAUDE_PRIMARY_NAME` through
  `HEADROOM_PRIMARY_NAME`, so both sides answer to `qiushi` by one
  declaration. The other `HEADROOM_*` overrides exist for headroom's test
  harnesses and re-point headroom only; under one, wrapper degradations are
  loud or absent, never a silent misroute, because headroom revalidates every
  name a wrapper passes.
- tmux strips `CLAUDE_CONFIG_DIR` from the server's global environment at
  start (`tmux.conf`): a server started from inside a Claude Code session
  would otherwise hand every pane that session's account. Managed launches
  neutralize the variable regardless — this line protects everything
  *outside* them that still reads it.
- Bypass-everything, if ever wanted, belongs in `settings.json`
  (`"permissions": { "defaultMode": "bypassPermissions" }`), not in wrappers
  around `claude`. Hooks and `permissions.deny` rules still apply in bypass
  mode.
