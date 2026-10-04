For documentation questions about a library, framework, SDK, API, CLI tool,
or cloud service, read and follow `~/.agents/skills/find-docs/SKILL.md`.
That upstream skill owns when to look up docs, query formulation, the CLI
procedure, and error handling.

Scope work by what the problem needs. A feature or refactor ships as one PR,
however much code it touches and including the follow-up fixes found along the
way, because one PR is easier to dogfood and test as a whole and no merge in
between leaves the product half-done. Propose a split only for a genuine
operational reason, such as a repository boundary, a migration that must land
first, or a merged first PR that unblocks other work, and name that reason.

Judge designs by what is right for the problem, not by effort or time to build,
and leave out timelines and ETAs unless asked. Propose the proper fix first;
scope to the smallest safe fix only when the user calls it a hotfix.

Update documentation when the user asks for it. After implementing a change,
leave the docs that describe it as they are: the user starts a separate pass
that reconciles them against the project's documentation standards, once the
implementation has settled. Once that pass has run in the session, the docs
are yours to keep current: when a later change, such as a review fix, makes
them wrong, correct them by the same standards.

Specs and other working documents the implementation is built from are part
of the work; keep them current.

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
