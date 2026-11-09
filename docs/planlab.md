# PlanLab: my setup around the team's repository

PlanLab's monorepo (`~/dev/planlab/main`, worktrees under
`~/dev/.worktrees/main/<branch>`) ships configuration that every engineer's
agents load: a root `AGENTS.md`, about 90 skills, and hooks. This repository
adds a layer that changes what my own sessions get and leaves my colleagues'
untouched. Three rules shape it:

- **Cut the team's text, never rewrite it.** The team edits `AGENTS.md` every
  few days, and a rewritten copy would quietly fall behind. My layer removes
  named parts and adds a note, so every other edit still arrives; a cut that
  stops matching leaves its text in and says so at launch.
- **A team hook goes quiet through the team's own code.** Nothing outside a
  hook can silence it short of disabling every hook, so the team's reminder
  hooks read an opt-out variable (planlab-ai/main#10902 and #10982), and I set
  it.
- **Rules about production and workspaces stay out of the repository,** in
  untracked files that twin carries to every machine.

## What is customised, and where

| What | What it does | Where it lives |
|---|---|---|
| Instructions and skills (Claude) | A launch through `x` or `x-<name>` gives the session and its subagents the team's `AGENTS.md` with my cuts and a note on how I use Bench, and hides every repository skill outside a keep list | `scripts/.local/bin/claude-planlab-overlay`; my choices, each with its reason, in `scripts/.local/share/dotfiles/planlab-overlay.toml`; run from `_claude_overlay` in `zsh/.config/zsh/claude.zsh` |
| Team reminders | The Bench tracking and transcript reminders, and the schedule-sample reminder, stay silent | `PLANLAB_BENCH_REMINDERS=off` and `PLANLAB_CORPUS_REMINDERS=off`: the `env` of `claude/.claude/settings.json` for Claude, `zsh/.config/zsh/codex.zsh` for Codex |
| My rules | Read production AWS without asking, never change it unasked; write on deployed workspaces only in my sandbox, `planlab-dev-qiushi` | Claude: `~/dev/planlab/CLAUDE.local.md` and `~/dev/.worktrees/main/CLAUDE.local.md`, identical, carried by twin. Codex: `codex/.codex/AGENTS.md`. Three copies, kept in step by hand |
| Worktrees | gwt puts each branch at `~/dev/.worktrees/main/<branch>`; the main checkout refuses to create a branch; a session that creates a worktree moves into it | `tmux/.config/tmux/scripts/worktree.md` maps it; the guard reaches planlab through `.githooks/reference-transaction`, a wrapper twin carries |
| Git | Pushes skip the LFS-only pre-push hook; settings and a warm cache keep status fast in many worktrees | `git/.config/git/planlab.gitconfig`; `docs/git-performance.md` |
| Ignored local files | The app's and the stress tests' env files, `.tabtype.local.toml`, `~/.config/planlab/dev.json`, `~/.bench/.env` | Carried by twin: `twin/.config/twin/twin.toml`, `[repos.planlab]` and `[home]` |
| Credentials | AWS SSO sign-in; each machine's Backstage login, renewed together; a reminder before a token expires | `aws-login` (`docs/aws-sso.md`); `planlab-login-all` logs in on every machine at once (a login's token works only on the machine that asked for it, so `~/.planlab/.env` stays on each); `planlab-tokens`, run by a LaunchAgent on the mini |

## Where it does not reach

- **A launch not through the `x` launchers** gets the team's setup whole:
  `x-select` (headroom's session picker), Rex, the dev pool, and `claude -p`
  helpers. `x -c` and `x --resume <id>` from a checkout keep it.
- **Codex** gets the reminder switches and its own copy of my rules, not the
  cuts or the hidden skills.
- **A checkout behind the two team PRs** still speaks those reminders; `--show`
  names which hook.

## Changing it

- **See what a session reads:** `claude-planlab-overlay --show` in a checkout
  prints the cuts as a diff of the team's file, my note, each hook's switch,
  and the visible skills. Every launch also prints one line,
  `planlab overlay: …`, or why the overlay did not apply.
- **Cut more or less, or keep a skill visible:** edit the TOML, then run
  `--show`. A launch line saying `no match, left in` means the team renamed
  what a cut names; update the cut. The overlay's tests are listed in
  `docs/testing.md`.
- **Change a rule about production or workspaces:** edit both
  `CLAUDE.local.md` copies and `codex/.codex/AGENTS.md`, then
  `twin files sync`.
- **Quiet a new team reminder:** its hook needs an opt-out first, in a team PR
  like #10982; then set the variable in both places above.
- **Why each piece is built as it is:** the overlay script's header, and the
  worktree map.
