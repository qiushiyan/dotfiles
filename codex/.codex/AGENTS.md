For documentation questions about a library, framework, SDK, API, CLI tool,
or cloud service, read and follow `~/.agents/skills/find-docs/SKILL.md`.
That upstream skill owns when to look up docs, query formulation, the CLI
procedure, and error handling.

Scope and judge work by what the problem needs.

A holistic feature or refactor ships as one PR, however many layers it spans:
it is built, tested and reviewed against the whole design once, and no merge in
between leaves the product half-rewired. Work too large for one session runs as
phases on the same branch, usually two sessions at most — still one PR, with a
handoff between them. Propose several PRs only when each intermediate PR is
correct as a merge state and a concrete constraint needs the seam — a
repository or ownership boundary, an infra apply or migration that must land
first, release or rollback mechanics, or evidence only a merged PR can produce
— and name that constraint. Diff size and review load are not reasons to split.
The reasoning is in `~/.config/lessons/collaboration/pr-boundaries.md`.

Recommend the design that is right for the problem, and compare options on how
fully and safely each solves it and what it leaves to run and maintain, rather
than on how long each takes to build. A ticket's priority or due date, or
someone's ask for an ETA, is for the people tracking the work and does not
change which design is right; give a delivery estimate only when the user asks
for one. Urgency comes from the user: when they call something a hotfix, scope
to the smallest safe fix.

Before an operation that could destroy work git cannot bring back —
uncommitted edits, gitignored files, anything outside a repository — run
`snapshot` first. It takes an APFS snapshot of the whole Data volume in a few
seconds, needs no sudo, and replaces the previous one it took, so taking
another before each such step costs nothing. The operations that call for it:
a recursive or wildcard delete, `git clean`, `git reset --hard`, `git checkout`
or `git restore` over uncommitted changes, `git stash drop`, `rsync --delete`,
a move or copy that overwrites, a bulk rewrite across a tree, and a test suite
or script that deletes paths it computes at runtime — the one no command line
reveals, since the path exists only once it runs. Skip it when every path
involved is inside a scratchpad or temp directory, or was created by this
session. If `snapshot` fails or is missing, tell the user before going ahead.
Restoring needs sudo; `snapshot --help` has the mount command to hand the user.
