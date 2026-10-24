# The agent guide a Go CLI starts from

A tool's `AGENTS.md` (with `CLAUDE.md` a symlink to it, or the reverse) is read
at the start of every session in the repository, so it carries only what
prevents a wrong edit: what the tool is, the contracts and invariants a change
must keep, and the house conventions every tool shares. Commands live in the
Makefile and `--help`, and architecture in the design doc it names.

Fill the angle-bracket slots from the tool and delete a slot that has nothing
real to say. The plain lines are the house conventions, kept word for word
across tools so one edit here is the whole change; adapt one only where the
tool genuinely differs (a dependency it needs, a machine it does not run on).
A finished guide is usually under 3 KB.

```markdown
# Working on <tool>

<What it does and who calls it: a person, agents, a tmux popup, a skill.>
`<design doc>` owns the design; read it before changing behaviour.

- One maintainer's tool: commit on `main`, push at milestones, and keep
  changes proportional to demonstrated failures or requested features.
  Dependencies: the standard library, clikit and Kong<, plus <module> for <API the standard library lacks>>.
- **Contracts other repositories depend on:** <surface → consumer path>, ...
  pinned by `<Test>`. A change to one updates its consumers in the same pass.
- **<Invariant, as a rule.>** <Why it holds.> Held by `<Test>`.
- Tests never touch live state: <the live state this tool can reach, and the
  stand-in each test uses: a temporary HOME, a private tmux socket, stub
  binaries on PATH>.
- Ship: `make check`, then `make install`. Callers run `~/.local/bin/<tool>`
  and keep the old build until then; the mini keeps its own until
  `twin sync <tool>`.
- The command line runs on clikit: how help renders and how argv errors read
  are clikit's (`~/dev/clikit`). Help, results and errors an agent reads
  follow `~/dotfiles/claude/.claude/skills/prompt-engineering/SKILL.md`;
  library questions go to `~/.agents/skills/find-docs/SKILL.md`.

Docs follow `~/dotfiles/docs/documentation-standards.md`, paths written from
the repository root.
```

Two guides in this shape, written before the template and each with
invariants of its own: `~/dev/claude-steps/CLAUDE.md` and
`~/dev/brief/AGENTS.md`.
