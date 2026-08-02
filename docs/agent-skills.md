# Agent skills: Claude Code ⊇ Codex

**The invariant: every skill Codex has, Claude Code has — never the reverse.**
The only permitted exception is a skill _about_ Codex itself
(`keep-codex-fast`), which lives as a real directory in the codex package. A
Claude-only skill is simply one with no Codex symlink.

```
claude/.claude/skills/<name>/          # source of truth — real directories
codex/.codex/skills/<name>             # relative symlink → ../../../claude/.claude/skills/<name>
codex/.codex/skills/keep-codex-fast/   # real dir — the declared Codex-only exception
~/.agents/skills/                      # the `skills` CLI's store — keep it empty
```

**Audit:** every entry under `codex/.codex/skills/` is either a symlink into
`claude/.claude/skills/` or a declared Codex-only skill. Any other real
directory is a bug.

## Why the links must stay inside the repo

`~/.claude/skills` and `~/.codex/skills` are stow symlinks _into this repo_, so
the kernel resolves a skill's relative symlink from its **real** repo location,
not from `$HOME`. A link like `../../.agents/skills/X` therefore resolves to
`dotfiles/claude/.agents/X` and dangles — this silently broke several skills.
Both ends of the Codex links live in the repo, so they resolve correctly and
survive stow, and being git-tracked they make "which skills Codex gets"
versioned.

## Installing

**Always install with `--copy`:**

```bash
npx skills add <owner/repo@skill> -g -a claude-code --copy -y
```

It writes a real directory straight into `claude/.claude/skills/`, leaves the
CLI store empty, and still records a lockfile entry so `skills update` keeps
working. Without `--copy` the CLI creates exactly the `../../.agents/skills/X`
links that can never resolve here. Never pass `-a codex` — that makes a
divergent copy; symlink instead.

Then add the Codex symlink by hand if Codex should get the skill.

- **`skills remove` is all-or-nothing.** It deletes the store directory, the
  lockfile entry, _and_ every agent copy. There is no prune-only command, so
  never reach for it just to "clean the store".
- **`~/.agents/.skill-lock.json` is not in this repo**, so CLI tracking does not
  survive to a new machine — `make install` won't restore it.
- **Forking a CLI-managed skill gets clobbered by `skills update`.**
  `writing-great-skills` has upstream's `disable-model-invocation: true`
  deliberately removed so the model can auto-invoke it. After any update, delete
  the line again or
  `git checkout -- claude/.claude/skills/writing-great-skills/SKILL.md`.

## Controlling invocation

**Invocation control belongs in the skill's frontmatter**, and nowhere else:

- `disable-model-invocation: true` → user-invoked only, and the description
  leaves the model's context.
- `user-invocable: false` → the inverse (Claude-only).

Both are documented and verified working. The two tempting alternatives are
traps:

- **`skillOverrides` in `settings.json` does nothing** — verified on v2.1.205:
  an `"on"` override failed to re-enable a skill, while frontmatter worked. It
  is undocumented with open upstream bugs. Do not use it.
- **Never put a skill in `permissions.deny`.** Deny gates _execution_, not
  visibility: the description still costs context, the model still tries and
  gets blocked, and you lose your own `/skill` invocation too. Deny is for tools
  (e.g. `NotebookEdit`), not skills.
