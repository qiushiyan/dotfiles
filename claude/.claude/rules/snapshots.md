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
