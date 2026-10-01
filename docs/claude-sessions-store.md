# The shared session store

Where Claude Code transcripts live, which directory a session resumes in, why
every account shares one copy, and who is allowed to delete them. Satellite of `docs/claude-accounts.md` — read that
first for the account model this rests on.

## One store, many accounts

Transcripts are keyed by project cwd and carry no credentials, so they belong to
the **machine**, not the account:

```
~/.claude/projects/                    the canonical store — a real directory
~/.claude-accounts/<email>/projects → ~/.claude/projects
```

Every account's `projects` is a symlink to the primary's, so the resume picker
in any account lists every session and resuming appends to the one canonical
file. Accounts stay auth/quota lanes; they are never history silos.

`headroom launch` re-verifies the link **by inode** on every launch and refuses
to start over a broken topology — a real directory there would fork history
silently, and silently is the whole problem. `headroom check` reports the same
verification per account as its `topology[...]` lines.

**What stays account-local:** per-session extras (`file-history/`, todos,
`session-env/`). Resuming under a different account keeps the conversation but
not its `/rewind` checkpoints.

## Which directory a session resumes in

A transcript lives under one directory's project folder: where the session
started, or where `/cd` last moved it, e.g.
`~/.claude/projects/-Users-qiushi-dotfiles/<id>.jsonl`. headroom's
picker resumes a session in the newest recorded directory that matches that
folder (`~/dev/headroom/DESIGN.md`, "The cd target is verified"). A plain
`claude --resume <id>` ignores it and runs wherever it is launched.

Moving a session therefore persists only if the transcript moves too:

- **`/cd <dir>`** moves the file into `<dir>`'s project folder and records
  the move, so the session resumes in `<dir>`. Claude Code refuses it under
  `claude -p`, and the model cannot type it.
- **`EnterWorktree`** switches directory for the live process only. On exit
  the session moves back to where it was started, and resumes there.

The `enter-worktree` skill uses `/cd` for this reason. Its
`claude/.claude/skills/enter-worktree/scripts/session-cd` types `/cd <dir>`
into the session's own tmux pane, and the TUI runs it when the turn ends. The
script refuses to type when it runs outside Claude Code or tmux, and when the
pane belongs to another process. It also refuses when the prompt box holds a
draft, which would otherwise be sent with the command as one message.
Worktrees of a trusted repo move without a trust prompt; any other directory
asks the user first.

## Retention belongs to ccclean

`cleanupPeriodDays` is pinned to 365 in the shared `settings.json`. Every
account's cleanup sweep prunes the shared store with its own settings, so the
store keeps the shortest period any account names; linking one `settings.json`
into every account makes retention one policy by construction. `headroom
check` guards both halves: its `settings:` line fails unless every account
sharing the store, the primary included, reads one `settings.json`, and its
`retention:` line prints the period and fails when accounts disagree or leave
`cleanupPeriodDays` unset, since Claude Code's 30-day default would then prune
the shared store. That setting is only the floor, and deliberately generous.

The actual policy is **ccclean**'s, a Python CLI in `~/dev/ccclean` (installed
by `uv tool install`). It is not in this repo and nothing here wraps it; its
rules and their evidence live in `~/dev/ccclean/DESIGN.md`. It judges sessions by
human turns rather than age, refuses to prune anything obelisk has not fully
indexed, and its `gc` sweep collects the account-local per-session state that
deleting a shared transcript would otherwise strand in every account that
recorded any.

## obelisk is a search index, never an archive

obelisk (session-history search) indexes `~/.claude/projects` and therefore sees
every account's sessions.

**Index incrementally; never `obelisk --build`.** A force rebuild mirrors only
files still on disk, so for transcripts retention already pruned, the index row
is the last record in existence — and a lossy one: obelisk truncates every
message at 10,000 characters (`TEXT_LIMIT` in its `parsing.js`) and keeps
`toolUseResult` only for its `filePath`. That is why ccclean archives rather
than deletes anything worth keeping, and says so in the prune preview instead of
implying a backup exists.

## Repairing the topology

Seeding creates the link (`headroom accounts add`, which `claude-account-add`
runs), and every launch re-checks it. A launcher that refuses with a topology
error, or a failing `topology[...]` line in `headroom check`, means that
account's `projects` became a real directory again or a wrong link; the error
names the end state required. The repair is manual, with no Claude session
running, and it never discards a transcript:

1. Copy every file under `<dir>/projects/` into the same relative path under
   `~/.claude/projects/` (same-named folders merge), skipping
   `sessions-index.json`, which Claude Code regenerates.
2. A path both trees hold is a collision. Byte-identical files (`cmp`) are
   one file: keep the canonical copy. Different contents are two histories
   of the same session, and neither modification time nor size shows that
   one contains the other. Stop there and reconcile them by hand before
   linking, keeping both originals until that is done.
3. Once every collision is identical, keep the original tree as a backup and
   link: `mv <dir>/projects <dir>/projects.pre-share.$(date +%Y%m%d-%H%M%S)
   && ln -s ~/.claude/projects <dir>/projects`. Delete the backup only after
   `headroom check` passes and the picker shows the folded-in sessions.

headroom's `headroom-setup` skill and the refusal message carry the same
collision rule.

## Where it is tested

headroom owns and tests the topology, retention and launch environment
(`~/dev/headroom`, `internal/accounts` and `internal/check`).
`zsh/.config/zsh/tests/claude-launch.test.zsh` covers what `claude.zsh`'s
launchers add on top (the refusal without headroom, named-launch routing,
workspace effort, x-select's cd), building headroom from `~/dev/headroom` so
routing crosses the real wrapper→engine seam.
