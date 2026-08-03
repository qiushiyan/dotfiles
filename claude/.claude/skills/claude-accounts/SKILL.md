---
name: claude-accounts
description: This machine's multi-account Claude Code setup — usage/quota via headroom, switching via launchers, machine-global sessions, onboarding a subscription.
disable-model-invocation: true
---

Several Claude Code logins coexist here, one per config dir; the `headroom`
CLI reads them all. Answer from its output, and hand interactive steps to
the user as commands to run — launchers start live sessions.

- **Usage / quota**: run `headroom` (alias `x-usage`) — every account's
  5-hour/weekly limit bars, each account's launcher command, and which
  account bare `x` currently targets. `headroom --json` for scripting.
- **Switching**: the user runs that account's launcher (`x-<name>`, shown in
  the dashboard) or picks interactively with `x-select`; give them the
  command. Credentials are per-account — `/login` plays no part in
  switching.
- **Resuming / session history**: sessions are machine-global — every
  account's `projects/` symlinks to `~/.claude/projects`, so `x --resume`
  on any account lists every session (`Ctrl+A` = all projects). Which
  account recorded a conversation never matters; pick the account by quota.
- **New subscription**: `claude-account-add <email>`, then that account's
  launcher and a one-time `/login`.
- **Dashboard misbehaving, or after a Claude Code update**: `headroom check`
  — a FAIL line names which reverse-engineered assumption broke. For the
  session-sharing machinery: `claude-sessions-check` (same
  PASS/FAIL/INCONCLUSIVE contract); offer `--canary` rather than running
  it — it spends a request on two accounts.
- **A launcher refuses with a topology error**: that account's `projects`
  is a real directory or wrong link. Have the user quit every Claude
  session, then run `claude-sessions-migrate` (all-or-nothing; keeps
  `projects.pre-share.<ts>` backups).

Mechanism (config-dir isolation, the shared session store, launcher
generation, display order): `~/dotfiles/docs/claude-accounts.md`. Engine
internals and vendor contracts: `~/dev/headroom/DESIGN.md`.
