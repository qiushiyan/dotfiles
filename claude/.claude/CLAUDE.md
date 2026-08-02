# Global context (this machine)

## Claude accounts

Several Claude Code subscriptions coexist on this machine, each with its own
login. When the user asks about usage limits or quota, or wants to switch or
add an account:

- Run `headroom` (alias `x-usage`) to answer usage questions — it prints
  every account's 5-hour/weekly limit bars, each account's launcher command,
  and which account bare `x` currently targets. After a Claude Code update,
  or when the dashboard misbehaves, `headroom check` verifies the machinery.
- Switching accounts means the user runs that account's launcher (`x-<name>`,
  shown in the `headroom` output) or picks one interactively with `x-select`
  — both start an interactive session, so suggest the command rather than
  running it yourself. No `/login` is involved; every account keeps its own
  credentials.
- A new subscription is onboarded with `claude-account-add <email>`, then its
  launcher and a one-time `/login`.

How the account system works (config-dir isolation, launchers, display
order): `~/dotfiles/docs/claude-accounts.md`. The engine behind
`x-usage`/`x-select` is the headroom Go CLI in `~/dev/headroom` — its
DESIGN.md holds the reverse-engineered vendor contracts.
