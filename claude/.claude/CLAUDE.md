# Global context (this machine)

## Claude accounts

Several Claude Code subscriptions coexist on this machine, each with its own
login. When the user asks about usage limits or quota, or wants to switch or
add an account:

- Run `claude-usage` to answer usage questions — it prints every account's
  5-hour/weekly limit bars, each account's launcher command, and which
  account bare `x` currently targets. After a Claude Code update, or when the
  dashboard misbehaves, `claude-usage --check` verifies the machinery.
- Switching accounts means the user runs that account's launcher (`x-<name>`,
  shown in the `claude-usage` output) — it starts an interactive session, so
  suggest the command rather than running it yourself. No `/login` is
  involved; every account keeps its own credentials.
- A new subscription is onboarded with `claude-account-add <email>`, then its
  launcher and a one-time `/login`.

How it works (config-dir isolation, Keychain naming, display order):
`~/dotfiles/docs/claude-accounts.md`.
