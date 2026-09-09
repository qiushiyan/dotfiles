# Agent skills: shared by Claude Code and Codex

**Claude Code and Codex use the same personal skill directory.** Real skill
files live in `claude/.claude/skills/`; both agents and the Skills CLI resolve
to that directory. A Claude-only installation is therefore visible to Codex
without a second installation or a per-skill link.

```text
claude/.claude/skills/          # shared source of truth, stowed to ~/.claude/skills
claude/.agents/skills           # symlink → ../.claude/skills; stowed to ~/.agents/skills
claude/.agents/.skill-lock.json # CLI's global lock, stowed to ~/.agents/.skill-lock.json
~/.codex/skills/.system/        # Codex-owned bundled skills; runtime-owned and separate
.claude/skills/                 # repo-local skills, shared via .agents/skills → ../.claude/skills
```

`~/.claude`, `~/.codex`, and `~/.agents` remain real directories. Only the
skills and lockfile are linked into the repo; runtime files stay outside it.
`make install` / `make restow` enforce that boundary; see [Stow layout](stow-layout.md).

[Codex discovers `~/.agents/skills` and follows symlinked skill folders](https://learn.chatgpt.com/docs/build-skills#where-codex-loads-local-skills).
[Claude discovers `~/.claude/skills`](https://code.claude.com/docs/en/skills).
Keep Codex's `.system` separate: it has its own lifecycle and can contain
same-named bundled skills, such as `skill-creator`. Personal availability is
shared; invocation controls and compatibility with agent-specific tools remain
agent-specific. Plugin skills belong to their plugin managers, outside this tree.

## Installing and updating

Use the [Skills CLI](https://github.com/vercel-labs/skills) with the two intended
agents explicitly selected:

```bash
npx skills@latest add <owner/repo> --skill <name> -g -a claude-code codex -y
npx skills@latest update -g -y
```

`upgrade` aliases `update`. Global scope matters: a bare noninteractive update
inside a repo can select project scope. To restore a missing managed skill,
repeat its `add` command using the source in the global lockfile; `update`
checks upstream hashes and does not repair arbitrary local drift. `make install`
restores the tracked bodies and lockfile without a network install.

The shared directory makes both copy and symlink installation modes work.
Skills CLI 1.5.25 compares resolved paths before creating an agent link, so it
keeps a real skill directory when Claude and the canonical store resolve to the
same place. This was verified with an isolated installation and a global update.
Keep that equality when changing the Stow layout: the CLI avoids replacing
the skill with an agent link because both paths resolve to the same directory.

Before an update, check `git status`; afterward, review the skill and lockfile
diffs together. Every managed skill must have a resolving upstream `skillPath`.
A successful update summary is insufficient: renamed or retired paths can be
skipped. Reinstall a confirmed rename under its current name, then reconcile
references. Keep custom forks out of the lockfile, because updates replace them.

`skills update` chooses detected agents when it reinstalls a skill; its update
command has no agent-selection flag. Use explicit `add` commands above when
installation must be limited to Claude and Codex. `skills remove` deletes skill
files as well as tracking; to stop managing a retained fork, remove only its
entry from the JSON lockfile. The lock contains upstream skills, not an inventory
of every custom or externally linked skill.

## Retained sources outside automatic updates

- **`obelisk`** is customized; `.upstream/PINNED.txt` owns its manual upgrade
  procedure. It is absent from the CLI lockfile.
- **`gh-cli`** is a customized fork of `github/awesome-copilot`, with local pager
  and practical-usage additions. Upstream [retired the skill](https://github.com/github/awesome-copilot/commit/352def3ca2a5)
  rather than providing an update target. Preserve the local fork.
- **`tailwind-best-practices`** is a customized adaptation of the purchased
  `tailwindcss/insiders` rules. `.upstream/PINNED.txt` owns its manual update
  procedure; `LESSONS.md` records the preservation constraints. The upstream
  contents are gitignored, with only the pin tracked. Keep it outside the CLI
  lockfile and restore its private baseline using authenticated GitHub access.
- **External symlinks** are owned by the referenced projects or applications.
  `terminal-browser` follows the installed app's default skill; local development
  skills follow their `~/dev` projects. Their owners update the target files.

`emil-design-engineering` is CLI-managed from `medoismail/claude-skills`: its
entire directory matched that source byte-for-byte when tracking was recovered.
This establishes the tracked source, not the identity of its original author.

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
// this repo's own .claude/settings.local.json — the live example
"skillOverrides": { "emil-design-engineering": "user-invocable-only" }
```

The [documented override states](https://code.claude.com/docs/en/skills#override-skill-visibility-from-settings)
are `on`, `name-only`, `user-invocable-only`, and `off`. A missing entry
means `on`. `user-invocable-only` removes the skill's listing from model
context while preserving explicit invocation; `off` also hides it from the
slash menu and blocks invocation. Plugin skills use plugin controls instead.
An `on` override does not bypass frontmatter, feature gates, or the bundled
kill switch. Global overrides go in `claude/.claude/settings.json`; a
project-local entry in `.claude/settings.local.json` binds only inside that
repo. Bundled-skill policy and upgrade checks: `docs/bundled-skills.md`.

The one real trap:

- **Never put a skill in `permissions.deny`.** Deny gates _execution_, not
  visibility: the description still costs context, the model still tries and
  gets blocked, and you lose your own `/skill` invocation too. Deny is for tools
  (e.g. `NotebookEdit`), not skills.

## Ownership tiers — who may edit a skill, and where a lesson goes

Each directory under `claude/.claude/skills/` has an ownership tier that
decides where an improvement is allowed to land. The lockfile
(`claude/.agents/.skill-lock.json`) identifies managed skills. `.upstream/`
identifies an explicitly pinned customization; history and the retained-source
notes above distinguish other forks from original work.

| tier | tell | edit policy | where our own lessons about it go |
|---|---|---|---|
| **Managed** — installed from upstream and kept current (`writing-for-agents`, `codebase-design`, `research`, …) | in the lockfile, no `.upstream/` | never edit the body; `skills update` reverts it silently (it did: the local `## Tool access` section of `writing-for-agents` was lost on 2026-08-29 and now lives in `lessons/agent-tooling/`). Behaviour changes go through `skillOverrides` (above) | a lesson under `lessons/` that the consuming skill points at (`agent-tooling/usage-lessons.md` is the rulebook's companion) |
| **Customized** — upstream-derived with local changes (`obelisk`, `gh-cli`) | a pin or documented provenance and local changes; absent from the lock | edit freely; upgrade by hand, using `PINNED.txt` and `LESSONS.md` where present | in the skill's own lessons and body |
| **Original** — ours (`review`, `consult`, `improve-tool`, `handoff`, …) | authored here, no managed upstream | edit freely | in the body, or in a lesson when several skills share the rule |

### Where a writing guideline lives

Guidance for writing agent-facing text is layered, and the layer decides the
file:

```
claude/.claude/skills/prompt-engineering/   original — the one rulebook: model-facing text,
                                            structure, pointers, the revision pass
claude/.claude/skills/writing-for-agents/   managed — reached only for SKILL-MECHANICS.md
                                            (frontmatter, invocation, routers); its
                                            general rules are folded into the rulebook
lessons/.config/lessons/agent-tooling/      ours — what measured sessions added on top:
                                            examples over prose, answer in the engine,
                                            cold readers, the doctrine gap
claude/.claude/skills/<skill>/SKILL.md      the skill-specific gist + pointers up the stack
```

A general rule about *how to write any agent-facing document* goes in the
rulebook (original, editable); one that only measured sessions could supply
goes in the lesson; never into `writing-for-agents` (managed). A rule about
*one skill's* domain goes in that skill.

### The rulebook and its upstream sibling — how they stay in sync

Two files, one direction of flow. `prompt-engineering/SKILL.md` is ours and
is the **one home** for general writing rules; `writing-for-agents/` is
installed from `mattpocock/skills` (lockfile `skillPath`
`skills/productivity/writing-for-agents/SKILL.md`) and is reached only for
`SKILL-MECHANICS.md` — frontmatter, model- versus user-invocation, router
skills. On 2026-09-04 (dotfiles `bfb4b83`) the rulebook absorbed the
sibling's transferable rules — context pointers, the two loads, the
steps/reference ladder, leading words, completion criteria, no-ops, the
environment as a source of truth — as they stood at upstream folder hash
`ad2925850efb8973a72d2e666f7a975f9a2d4a9b` (lockfile `updatedAt`
2026-08-29). That hash is the **fold baseline**: everything upstream adds
after it is unreviewed until the sync below runs.

Rules never flow the other way. A general rule discovered here goes into
the rulebook, not into the sibling (managed: `skills update` reverts it);
a project's house guide graduates its general lessons up into the rulebook
and keeps the instance. The sibling's own body is never edited, so a
`skills update` can never conflict with our work — the only thing it can do
is carry new rules the rulebook has not judged yet.

**The sync, monthly or when a pass on the rulebook runs:**

```bash
S=claude/.claude/skills/writing-for-agents
BEFORE=$(git log -1 --format=%h -- $S)              # last synced state
npx skills@latest update writing-for-agents -g -y
git diff $BEFORE -- $S                               # the upstream delta, read whole
```

Triage every hunk of that delta into one of three bins, and write the
verdict into `prompt-engineering/EVIDENCE.md` with the new folder hash from
`~/.agents/.skill-lock.json`:

1. **Graduate** — a general writing rule that is new or sharper than the
   rulebook's version. It enters the rulebook rewritten in the rulebook's
   register and under the section it belongs to (the bar, a surface, the
   revision pass), never pasted. Then run the rulebook's own revision pass
   on the rulebook: an upstream addition is a reason to be better, not
   longer.
2. **Mechanics** — anything about frontmatter, invocation, or routers.
   Nothing to do; `SKILL-MECHANICS.md` is read directly.
3. **Covered or rejected** — the rulebook already carries it, or it
   contradicts a measured lesson or an owner decision. One line in the
   evidence log saying which, so the next sync does not re-judge it.

Commit the sibling's update and the rulebook's change separately, so the
upstream delta stays readable in history. Close with the pointer check:

```bash
grep -rn "writing-for-agents" --exclude-dir=.git . | grep -v "skills/writing-for-agents/"
```

Every hit should name `SKILL-MECHANICS.md` or the ownership rules above;
a hit that sends a reader to the sibling's body for a general rule is a
pointer the fold missed. The previous sync's baseline and verdicts are the
newest entry in `prompt-engineering/EVIDENCE.md`; a sync that finds an
empty delta is recorded there too, as a measured empty. Lessons are not skills — no frontmatter, not invokable,
reached only by a pointer from a skill or snippet — and `lessons/.config/lessons/CLAUDE.md`
carries the conversion rules between the two forms.

## Bundled skills

Claude owns bundled skill bodies and supporting files. Keep them upstream;
a personal copy with the same name shadows the bundled version and prevents
updates from taking effect. Selective enablement, manual invocation, and
upgrade checks: `docs/bundled-skills.md`.
