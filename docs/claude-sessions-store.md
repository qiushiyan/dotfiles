# The shared session store

Where Claude Code transcripts live, why every account shares one copy, and who
is allowed to delete them. Satellite of `docs/claude-accounts.md` — read that
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
silently, and silently is the whole problem.

**What stays account-local:** per-session extras (`file-history/`, todos,
`session-env/`). Resuming under a different account keeps the conversation but
not its `/rewind` checkpoints.

## Retention belongs to ccclean

`cleanupPeriodDays` is pinned in the shared `settings.json` — never `0`, which
disables persistence rather than cleanup — and every account's cleanup pass
applies it to the shared store, so retention is one policy by construction. That
setting is only the floor, and deliberately generous.

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

A launcher that refuses with a topology error means that account's `projects`
became a real directory again, or a wrong link. Quit every Claude session and
run `claude-sessions-migrate`. It is all-or-nothing: it refuses while any
session runs, verifies a hash manifest of every source file before swapping, and
keeps each merged tree as a `projects.pre-share.<timestamp>` backup.

Seeding creates the link in the first place (`_claude_link_projects` in
`zsh/.config/zsh/claude.zsh`), and every launch re-checks it.

## The code and its tests

The session toolkit is `zsh/.config/zsh/claude-sessions.zsh`; its sandbox
harness is in `zsh/.config/zsh/tests/`. The harness also covers `claude.zsh`'s
launchers, building headroom from `~/dev/headroom` so it exercises the real
wrapper→engine seam — run it after touching any of the three.
`claude-sessions-check` verifies the sharing machinery on the live system, and
its `--canary` proves cross-account resume end to end at the cost of one request
on two accounts.
