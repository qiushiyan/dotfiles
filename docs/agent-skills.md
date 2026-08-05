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
- **Forking a CLI-managed skill gets clobbered by `skills update`.** Editing the
  frontmatter of anything in the lockfile is a fork the next update silently
  reverts. Prefer a `skillOverrides` entry (below), which lives outside the file
  and survives; keep a frontmatter fork only for what an override can't express,
  and expect to re-apply it.
- **A renamed upstream skill goes stale in silence.** `writing-great-skills` was
  renamed to `writing-for-agents` upstream on 2026-07-23. Its lockfile
  `skillPath` then 404'd, so `skills update` no-opped on it forever — no error,
  no warning, and the local copy just froze. An update that reports success is
  not evidence the skill still exists upstream; if one looks suspiciously
  unchanged, check the path by hand.

## Controlling invocation

Two mechanisms work, and which one you want depends on **who owns the file**.

**Frontmatter — the default.** Documented, and verified in both directions:

- `disable-model-invocation: true` → user-invoked only, and the description
  leaves the model's context.
- `user-invocable: false` → the inverse (Claude-only).

**`skillOverrides` in `settings.json` — for skills you don't own.** Editing the
frontmatter of a **CLI-managed** skill (anything in
`~/.agents/.skill-lock.json`) is a fork that `skills update` silently reverts.
An override in `settings.json` sits outside the file, so an update can't touch
it:

```jsonc
"skillOverrides": { "writing-for-agents": "user-invocable-only" }
```

Verified working in the restricting direction: `emil-design-engineering` carries
a full model-facing trigger list and no frontmatter flag, and an override alone
keeps it out of the model's skill list. **The re-enabling direction is a
different story** — an `"on"` override failed to bring a disabled skill back on
v2.1.205. So: use it to take a skill away from the model, don't rely on it to
give one back, and remember the field is undocumented with open upstream bugs.
Global overrides go in `claude/.claude/settings.json`; a project-local one in a
repo's own `.claude/settings.local.json` binds only inside that repo.

The one real trap:

- **Never put a skill in `permissions.deny`.** Deny gates _execution_, not
  visibility: the description still costs context, the model still tries and
  gets blocked, and you lose your own `/skill` invocation too. Deny is for tools
  (e.g. `NotebookEdit`), not skills.
