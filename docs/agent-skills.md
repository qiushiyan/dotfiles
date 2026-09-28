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

`~/.claude`, `~/.codex`, and `~/.agents` remain real directories. The personal
skill tree and lockfile are linked into the repo. Claude cloud downloads land
under the linked tree's ignored `synced/` directory; other runtime state stays
outside it. Codex exclusions leave those downloads on disk.
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

Global scope matters: a bare noninteractive update inside a repo can select
project scope. `update` reinstalls for every detected agent and has no
agent-selection flag, so an installation limited to Claude and Codex uses the
explicit `add`. `update` checks upstream hashes and does not repair local
drift: to restore a missing managed skill, repeat its `add` with the source in
the global lockfile; `make install` restores the tracked bodies and lockfile
without a network install.

**The CLI must see one directory.** Claude's skill path and the canonical
store resolve to the same place, so the CLI keeps a real skill directory
instead of replacing it with an agent link. Keep that equality when changing
the Stow layout.

Before an update, check `git status`; afterward, review the skill and lockfile
diffs together and run the invocation sync below. A successful update summary
is insufficient: every managed skill needs a resolving upstream `skillPath`,
and a renamed or retired path is skipped. Reinstall a confirmed rename under
its current name, then reconcile references. Keep custom forks out of the
lockfile, because updates replace them; `skills remove` deletes skill files as
well as tracking, so stop managing a retained fork by removing only its
lockfile entry.

### Skills with engines

The Skills CLI replaces skill files; it does not upgrade global packages or
applications, and a matching skill hash says nothing about engine currency.
An upgrade pass therefore updates each engine too: check the active executable
with `type -a`, resolve the current release from its owner, update through its
existing package manager, and verify both the version and a small functional
probe. Report skill and engine results separately, including any deferred
engine update and why.

- **Obelisk:** a customized skill whose pnpm-owned `@obelisk-apps/cli` has
  its own release stream. Its `.upstream/PINNED.txt` owns the upgrade
  procedure; `docs/skill-customizations.md` owns what to preserve.
- **Externally linked skills** (a symlinked folder in `ls -l
  claude/.claude/skills`): the link's owner updates skill and engine together
  — `terminal-browser upgrade` for the app's skill, the owning `~/dev`
  project's release or install for the rest. Preserve the link.
- **Engines inside the skill:** Archify (probe: `node bin/archify.mjs doctor`
  from its directory), `skill-creator` and `keep-codex-fast` ship their
  helpers in the skill directory, and `find-docs` runs `npx ctx7@latest`, so
  the skill update is the whole upgrade.
- **agent-browser:** one global installation, owned by pnpm. The managed
  `SKILL.md` is a discovery stub; the installed CLI serves the working guides
  (`agent-browser skills get core`), so upgrading the stub alone updates
  neither the guides nor the browser engine. Run the commands below, exercise
  open → snapshot → click in a fresh named session and close it, and remove
  any npm-global duplicate `type -a` shows from its Node prefix.

```bash
agent_browser_version="$(npm view agent-browser version)"
pnpm add -g "agent-browser@$agent_browser_version"
agent-browser skills get core
agent-browser install
agent-browser --version
type -a agent-browser
```

## Shared procedures and composed skills

`find-docs` is the upstream source of truth for documentation lookup. Claude's
`rules/context7.md` and Codex's global `AGENTS.md` contain only pointers to that
shared skill, so CLI instructions and query guidance update with its body.
Keep its default invocation enabled; a manual-only override would prevent
Claude from following the automatic documentation route.

`rules/scoping.md` and `rules/snapshots.md` are inline rather than pointers,
because each has to act from the first turn: scoping on every proposal, the
snapshot rule before the first destructive command. Codex's global `AGENTS.md`
(`codex/.codex/AGENTS.md`) carries the same text after the find-docs pointer,
in that order; edit each pair together.

`grill-with-docs` composes `grilling` with `domain-modeling`; the upstream
`grill-me` alias adds nothing beyond `grilling`, so it is not installed. When
updating a composed skill, check its named skill dependencies as well as its
file hashes.

## Controlling invocation

### Claude controls

Which control to use depends on **who owns the file**:

- **Skills owned here:** frontmatter. `disable-model-invocation: true` makes a
  skill user-invoked only and removes its description from Claude's model
  context; `user-invocable: false` is the inverse (Claude-only).
- **Skills you don't own:** `skillOverrides` in `settings.json`. Editing the
  frontmatter of a **CLI-managed** skill (anything in the lockfile) is a fork
  that `skills update` silently reverts; an override sits outside the file.

```jsonc
// this repo's own .claude/settings.local.json — the live example
"skillOverrides": { "emil-design-engineering": "user-invocable-only" }
```

The override states and what each hides are in
[Claude's docs](https://code.claude.com/docs/en/skills#override-skill-visibility-from-settings).
Global overrides go in `claude/.claude/settings.json`; a project-local entry
in `.claude/settings.local.json` binds only inside that repo. Plugin skills use
plugin controls. Bundled-skill policy and upgrade checks: `docs/bundled-skills.md`.

**Never put a skill in `permissions.deny`.** Deny gates _execution_, not
visibility: the description still costs context, the model still tries and
gets blocked, and you lose your own `/skill` invocation too. Deny is for tools
(e.g. `NotebookEdit`), not skills.

### Synchronizing Codex invocation

Edit personal skill sources through `claude/.claude/skills/` and repo-local
sources through `.claude/skills/`. Their `.agents/skills` aliases expose the
same files to Codex. An external folder symlink points to its owning project's
source; review and commit changes there.

After changing skills, global invocation overrides, or the Codex policy—and
after cloud imports, skill or Codex runtime updates (either can overwrite
metadata), or restoring dotfiles on another machine (generated paths reflect
the local cache)—reconcile the derived files and commit them with the policy:

```bash
skill-sync
skill-sync --check
```

`scripts/.local/share/dotfiles/skill-policy.yaml` owns Codex-only policy and
names the Claude settings to read. The Codex controls derive from it:

- **Manual-only** is the union of `disable-model-invocation: true`, Claude's
  global `user-invocable-only` override, and the manifest's `manual` paths; an
  `on` override does not bypass a manual-only header. It becomes
  `policy.allow_implicit_invocation: false` in the skill's `agents/openai.yaml`,
  which [Codex](https://learn.chatgpt.com/docs/build-skills#optional-metadata)
  keeps invocable but out of the default catalog. The manifest lists
  runtime-owned or imported skills because their owners refresh that metadata;
  removing one from `manual` stops managing it, so restore or remove its
  generated field when retiring that override.
- **Disabled** comes from a global `off` override, the manifest's `disabled`
  paths, and every `SKILL.md` under `exclude_roots` (the Claude cloud cache).
  Each becomes an exact-path entry in the marked final block of
  `codex/.codex/config.toml`, which preserves same-named personal and plugin
  skills. Put hand-edited settings before the generated block, which must
  remain last.
- **Project-local settings stay local:** translating them into shared metadata
  would change other projects. `name-only` has no Codex equivalent and leaves
  the header's policy.

The same command broadcasts shared documents:
`scripts/.local/share/dotfiles/documents.yaml` lists each source and the
checkouts that carry a verbatim copy. A scope flag runs only the job it names
(`skill-sync --help`). The trap: `--skills-dir` alone on the shared tree
translates frontmatter without the policy manifest, so it can restore an
automatic default despite a global manual-only override; use the default run
for personal-skill maintenance. Runtime metadata stays outside Git; external
destinations are reported for review and commit in their owning repositories.
`docs/bundled-skills.md` owns the visibility checks and measurement method.

## Ownership tiers — who may edit a skill, and where a lesson goes

Each directory under `claude/.claude/skills/` has an ownership tier that
decides where an improvement is allowed to land. The lockfile
(`claude/.agents/.skill-lock.json`) identifies managed skills; `.upstream/`
or an entry in `docs/skill-customizations.md` identifies a customization.

| tier | tell | edit policy | where our own lessons about it go |
|---|---|---|---|
| **Managed** — installed from upstream and kept current (`writing-for-agents`, `codebase-design`, `research`, …) | in the lockfile, no `.upstream/` | never edit the body; `skills update` reverts it silently. Behaviour changes go through `skillOverrides` (above) | a lesson under `lessons/` that the consuming skill points at (`agent-tooling/usage-lessons.md` is the rulebook's companion) |
| **Customized** — upstream-derived with local changes (`obelisk`, `tailwind-best-practices`) | a pin or documented provenance and local changes; absent from the lock | edit freely; upgrade by hand, using `PINNED.txt` and `LESSONS.md` where present | in the skill's own lessons and body |
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
rulebook (original, editable) — including one a project's house guide
discovers, which keeps only the instance; one that only measured sessions
could supply goes in the lesson; never into `writing-for-agents` (managed). A
rule about *one skill's* domain goes in that skill. Lessons are not skills — no
frontmatter, not invokable, reached only by a pointer — and
`lessons/.config/lessons/CLAUDE.md` carries the conversion rules between the
two forms.

### The rulebook and its upstream sibling — how they stay in sync

`prompt-engineering/SKILL.md` is ours and the **one home** for general writing
rules; `writing-for-agents/` (from `mattpocock/skills`) is reached only for
`SKILL-MECHANICS.md`. Rules flow one way: the sibling's body is never edited,
so an update can only carry rules the rulebook has not judged yet. The first
**fold baseline** is upstream folder hash
`ad2925850efb8973a72d2e666f7a975f9a2d4a9b`; each sync records its new hash and
verdicts as the newest entry in `prompt-engineering/EVIDENCE.md`, and whatever
upstream adds after that entry is unreviewed.

**The sync, monthly or when a pass on the rulebook runs:**

```bash
S=claude/.claude/skills/writing-for-agents
BEFORE=$(git log -1 --format=%h -- $S)              # last synced state
npx skills@latest update writing-for-agents -g -y
git diff $BEFORE -- $S                               # the upstream delta, read whole
```

Triage every hunk into one bin and write the verdicts into
`prompt-engineering/EVIDENCE.md` with the new folder hash from
`~/.agents/.skill-lock.json` (an empty delta is recorded too):

1. **Graduate** — a general writing rule new or sharper than the rulebook's.
   Rewrite it into the rulebook section it belongs to (a layer, every
   sentence, a surface, the revision pass), never pasted, then run the
   rulebook's revision pass on the rulebook: an upstream addition is a reason
   to be better, not longer.
2. **Mechanics** — frontmatter, invocation, or routers. Nothing to do;
   `SKILL-MECHANICS.md` is read directly.
3. **Covered or rejected** — already carried, or contradicting a measured
   lesson or an owner decision. One line saying which, so the next sync does
   not re-judge it.

Commit the sibling's update and the rulebook's change separately, so the
upstream delta stays readable in history. Close with the pointer check: every
hit should name `SKILL-MECHANICS.md` or the ownership rules above, and one that
sends a reader to the sibling's body for a general rule is a pointer the fold
missed.

```bash
grep -rn "writing-for-agents" --exclude-dir=.git . | grep -v "skills/writing-for-agents/"
```

## Bundled skills

Claude owns bundled skill bodies and supporting files. Keep them upstream;
a personal copy with the same name shadows the bundled version and prevents
updates from taking effect. Selective enablement, manual invocation, and
upgrade checks: `docs/bundled-skills.md`.
