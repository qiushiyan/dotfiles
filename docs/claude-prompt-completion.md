# Claude Ctrl+G slash completion

Pressing Ctrl+G in Claude Code opens the drafted prompt in Neovim as a temp
markdown file. A small blink.cmp source completes Claude skills there: type
`/` anywhere in the prompt, get `/skill-name` items — global and
project-local skills merged, with the skill's description as documentation.

```
nvim/.config/nvim/lua/
  claude-prompt/source.lua   # the blink.cmp source
  plugins/claude-prompt.lua  # provider registration (merges via opts_extend)
```

## The load-bearing fact: cwd, not buffer path

The prompt file lands in `<base>/claude-<uid>/claude-prompt-<id>.md`, where
the base is `CLAUDE_CODE_TMPDIR` if set, else a hardcoded `/tmp` — Claude Code
ignores the standard `TMPDIR` (verified in the 2.1.215 binary). So the buffer
path says nothing about the project.

But Claude Code spawns `$EDITOR` with the project as its working directory
(verified end-to-end by driving the TUI in tmux with a pwd-capturing fake
editor). The source therefore recovers the project from `getcwd()`, never from
the buffer path.

## Behavior — all deliberate

- Activates only in buffers named `claude-prompt-*`; that prefix is a literal
  in the Claude binary.
- Completes `/partial` at line start or after whitespace, anywhere in the
  line — but not inside paths like `/usr/bin` (the final slash isn't
  whitespace-preceded). Note only a *leading* slash is parsed as a command by
  Claude; a mid-prompt `/name` reaches the model as plain text it treats as a
  skill reference, so mid-line completion is a convenience the normal Claude
  input doesn't offer.
- Skills resolve like Claude Code's own precedence: global `~/.claude/skills`
  is always offered, the nearest project `.claude/skills` (walking up from
  cwd, stopping before `$HOME` so `~/.claude` is never mistaken for a project)
  is merged on top, and a project skill overrides a same-named global one.
  Each item's label detail says `global` or `project`.
- A skill is a `skills/*/` dir containing a `SKILL.md`; the frontmatter
  `description` (single-line or `>-` block scalar) becomes the item docs.
- Item kind is `Keyword`, not `Function` — blink auto-appends `()` to
  `Function`/`Method` kinds.
- Accepting inserts `/skill-name ` with a trailing space, cursor ready for
  arguments.
- Each Ctrl+G spawns a fresh nvim, so source edits apply on the next press —
  no reload dance.

Deliberately not covered (yet): `.claude/commands/`, `@`-file completion.

## Rejected alternative: project-local temp dir

`CLAUDE_CODE_TMPDIR=$PWD/.tmp` also identifies the project (via the buffer
path) and was tried first — but it redirects *all* Claude temp files, child
process `$TMPDIR` and Node/nvim caches included, into the repo, and forfeits
macOS's automatic `/tmp` cleanup. cwd inheritance gives the same information
for free. The override survives as a commented-out line in `x()`
(`zsh/.config/zsh/utils.zsh`), with a matching `.tmp/` entry in the global
gitignore (`git/.config/git/ignore`), should it ever be wanted again.
