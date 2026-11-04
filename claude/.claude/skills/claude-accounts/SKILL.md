---
name: claude-accounts
description: "This machine's multi-account Claude Code setup: quota, launching, onboarding."
disable-model-invocation: true
---

Several Claude Code logins coexist here, one per config dir; the `headroom`
CLI reads them all. Answer from its output, and hand interactive steps to
the user as commands to run — launchers start live sessions.

- **Usage / quota**: run `headroom` — every account's 5-hour/weekly limit
  bars, each account's launcher command, and `← next` on the account bare
  `x` would take. `headroom --json` for scripting.
- **Choosing an account**: bare `x` takes the least-loaded account;
  `x-<name>` (shown on the board) is one session on that account. The board
  (`x-acc`) records nothing. Give the user the command. Launchers route
  through `headroom launch`, which validates the account and owns
  `CLAUDE_CONFIG_DIR`. Credentials are per-account — `/login` plays no part.
- **Resuming / session history**: sessions are machine-global — every
  account's `projects/` symlinks to `~/.claude/projects`. `x-select` lists
  every session and resumes each on the account that last drove it (`x` on
  a row moves it elsewhere); native `x --resume` also sees everything
  (`Ctrl+A` = all projects) and is placed like bare `x`.
- **New subscription**: `claude-account-add <email>`, then that account's
  launcher and a one-time `/login`.
- **Dashboard misbehaving, or after a Claude Code update**: `headroom check`
  — a FAIL line names which reverse-engineered assumption broke. It covers
  session sharing too: `topology[...]` per account; `settings:`, which
  fails unless every account reads one `settings.json`; and `retention:`,
  which fails when accounts disagree on `cleanupPeriodDays` or leave it
  unset.
- **A launcher refuses with a topology error**: that account's `projects`
  is a real directory or wrong link, and the error names the required end
  state. The repair is manual, with no Claude session running: hand the
  user the steps in `~/dotfiles/docs/claude-sessions-store.md` § Repairing
  the topology.

Mechanism (config-dir isolation, the shared session store, launcher
generation, display order): `~/dotfiles/docs/claude-accounts.md`. Engine
internals and vendor contracts: `~/dev/headroom/DESIGN.md`.
