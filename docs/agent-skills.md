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
diffs together and run the invocation sync below. Every managed skill must have
a resolving upstream `skillPath`.
A successful update summary is insufficient: renamed or retired paths can be
skipped. Reinstall a confirmed rename under its current name, then reconcile
references. Keep custom forks out of the lockfile, because updates replace them.
An upstream-skill upgrade pass also updates its separately installed engine,
even when the skill hash is unchanged; follow the engine inventory below.

`skills update` chooses detected agents when it reinstalls a skill; its update
command has no agent-selection flag. Use explicit `add` commands above when
installation must be limited to Claude and Codex. `skills remove` deletes skill
files as well as tracking; to stop managing a retained fork, remove only its
entry from the JSON lockfile. The lock contains upstream skills, not an inventory
of every custom or externally linked skill.

### Skills with engines

The Skills CLI replaces skill files; it does not upgrade global packages or
applications. For each engine-backed skill, check the active executable with
`type -a`, resolve the current release from its owner, update through its
existing package manager, and verify both the version and a small functional
probe. Report skill and engine results separately, including any deferred
engine update and why. A matching skill hash says nothing about engine currency.

- **Obelisk:** the customized skill and `@obelisk-apps/cli` have separate
  release streams. Upgrade the CLI with pnpm, then reconcile the skill with
  the installed runtime. Its `.upstream/PINNED.txt` owns the exact procedure;
  `docs/skill-customizations.md` owns what to preserve. A docs-only refresh
  leaves this maintenance incomplete unless the engine is already current
  or its update is explicitly deferred.
- **agent-browser:** keep one global installation, owned by pnpm. The managed
  `SKILL.md` is a discovery stub; the installed CLI serves the working guides
  through `agent-browser skills get core`. Upgrading only the stub cannot
  update those guides or the browser engine. Use the commands below, then
  exercise open → snapshot → click in a fresh named session and close it.
  Inspect duplicate installations with `type -a agent-browser`; remove any
  npm-global copy from its owning Node prefix. Keep this machine policy here,
  outside the upstream-owned stub.

```bash
agent_browser_version="$(npm view agent-browser version)"
pnpm add -g "agent-browser@$agent_browser_version"
agent-browser skills get core
agent-browser install
agent-browser --version
type -a agent-browser
```

Other lifecycle patterns in the collection:

- **terminal-browser:** the skill is linked into the installed app; the
  app's `terminal-browser upgrade` owns both engine and skill. Preserve the
  external link and use that updater when maintaining this skill.
- **find-docs:** its engine is `ctx7`, invoked as `npx ctx7@latest` by the
  skill, so there is no pinned global engine to upgrade in this setup.
- **gh:** the managed skill documents the separately installed GitHub CLI.
  Check `gh --version` and upgrade through its existing installer when the
  skill requires newer commands; the Skills CLI cannot update it.
- **Archify:** `bin/`, renderers, and viewer assets ship inside the managed
  skill directory, so the skill update already updates its engine. Verify
  with `node bin/archify.mjs doctor` from that directory. `skill-creator`
  and `keep-codex-fast` likewise carry their helper scripts with the skill.
- **Local project skills:** `explain-diff`, `greenflag-*`, and
  `read-email`/`write-email` depend on the explain-diff, greenflag, and mailkit
  engines. Their source links follow the owning checkouts; packaged binaries
  can lag those files. Reconcile them through the owning project's release
  or installation procedure when maintaining those skills.

## Shared procedures and composed skills

`find-docs` is the upstream source of truth for documentation lookup. Claude's
`rules/context7.md` and Codex's global `AGENTS.md` contain only pointers to that
shared skill, so CLI instructions and query guidance update with its body.
Keep its default invocation enabled; a manual-only override would prevent
Claude from following the automatic documentation route.

`grilling` owns Matt Pocock's interview workflow. `grill-with-docs` composes it
with `domain-modeling` for glossary and ADR work. The upstream `grill-me` alias
adds no behavior beyond `grilling`, so it is not installed. When updating a
composed skill, check its named skill dependencies as well as its file hashes.

`gh` comes from GitHub's official `cli/cli` repository and is CLI-managed.
Use the shared Skills CLI installation/update workflow above so its source
stays in the same lockfile as the other upstream skills.

## Retained sources outside automatic updates

The [customization guide](skill-customizations.md) owns the purpose and update
judgment for `obelisk` and `tailwind-best-practices`, plus the writing
rulebook's relationship to upstream. Read that entry before upgrading a local
adaptation; its pin owns the commands and its lessons own the evidence.

- **External symlinks** are owned by the referenced projects or applications.
  `terminal-browser` follows the installed app's default skill; local development
  skills follow their `~/dev` projects. Their owners update the target files.

`emil-design-engineering` is CLI-managed from `medoismail/claude-skills`: its
entire directory matched that source byte-for-byte when tracking was recovered.
This establishes the tracked source, not the identity of its original author.

## Controlling invocation

### Claude controls

Which control to use depends on **who owns the file**. In Claude,
frontmatter is the default for skills owned here:

- `disable-model-invocation: true` → user-invoked only, and the description
  leaves Claude's model context.
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

### Synchronizing Codex invocation

Edit personal skill sources through `claude/.claude/skills/` and repo-local
sources through `.claude/skills/`. Their `.agents/skills` aliases expose the
same files to Codex. An external folder symlink points to its owning project's
source; review and commit changes there.

After changing skills, global invocation overrides, or the Codex policy—and
after cloud imports or runtime updates—reconcile the derived files:

```bash
skill-sync
skill-sync --check
```

`scripts/.local/bin/skill-sync` uses `uv` with a pinned YAML dependency. Its
default run scans this repository's personal and repo-local Claude skill trees
and applies the policy and document manifests. For another project's headers,
pass `--skills-dir /path/to/project/.claude/skills`.

`scripts/.local/share/dotfiles/skill-policy.yaml` owns Codex-only policy and
selects the global Claude settings to read. The effective manual-only policy
is the union of `disable-model-invocation: true`, Claude's global
`user-invocable-only` override, and the manifest's `manual` paths. An `on`
override does not bypass a manual-only header. A global `off` override produces
an exact-path Codex exclusion for matching shared skills. Project-local
settings stay local: translating them into shared metadata would change other
projects. `name-only` has no Codex equivalent and leaves the header's policy.

The command derives `policy.allow_implicit_invocation` in each skill's
`agents/openai.yaml`. Skills using the automatic default need no metadata
file. Other fields and comments are preserved. Shared skills return to their
header's default when an override is removed. Runtime skills outside the
shared roots are touched only when explicitly listed; removing one from
`manual` stops managing it, so restore or remove its generated policy field
when retiring that override.

The manifest's `disabled` paths and every `SKILL.md` under `exclude_roots`
become exact-path entries in the marked final block of
`codex/.codex/config.toml`. Each run refreshes the inventory, including new
Claude account caches, and removes stale generated rules. Exact paths preserve
same-named personal and plugin skills. Put hand-edited settings before the
generated block, which must remain last; update policy in the manifest.
Generated paths reflect this machine's cache, so rerun sync after restoring
dotfiles on another machine. Claude settings, skill bodies, the lockfile, and
directory links remain untouched.

[Codex's per-skill policy](https://learn.chatgpt.com/docs/build-skills#optional-metadata)
keeps manual invocation available while excluding manual-only skills from the
default skill declarations. Existing conversation context is not erased; use a
fresh session to verify prompt savings. `docs/bundled-skills.md` owns the
visibility checks and measurement method.

The same command broadcasts shared documents. `scripts/.local/share/dotfiles/documents.yaml`
lists each source (today `docs/documentation-standards.md`) and the checkouts
that carry a verbatim copy. Absent checkouts are skipped with a notice. With
no scope flags, all jobs run. `--skills-dir` alone translates frontmatter only;
`--documents` alone copies documents only; `--policy` applies the named policy
to the default skill roots, or to roots supplied with `--skills-dir`. Scoped
runs never implicitly load the other manifests. Using only `--skills-dir` on
the shared tree can restore an automatic default despite a global manual-only
override; use the default run for personal-skill maintenance.

Repeated runs leave synchronized files untouched; `--check` reports drift
without writing and exits nonzero. All jobs validate before writes, including
YAML/JSON/TOML, boolean policies, links, and conflicting outputs. Tests run a
copied command with temporary manifests and a temporary home.

Commit shared metadata, generated config, and policy changes together.
Upstream skill updates and Codex runtime updates can overwrite metadata; run
`skill-sync` and `skill-sync --check` afterwards to restore the tracked policy.
Runtime metadata is labeled separately and stays outside Git. Other external
destinations are reported for review and commit in their owning repositories.

## Ownership tiers — who may edit a skill, and where a lesson goes

Each directory under `claude/.claude/skills/` has an ownership tier that
decides where an improvement is allowed to land. The lockfile
(`claude/.agents/.skill-lock.json`) identifies managed skills. `.upstream/`
identifies an explicitly pinned customization; history and the retained-source
notes above distinguish other forks from original work.

| tier | tell | edit policy | where our own lessons about it go |
|---|---|---|---|
| **Managed** — installed from upstream and kept current (`writing-for-agents`, `codebase-design`, `research`, …) | in the lockfile, no `.upstream/` | never edit the body; `skills update` reverts it silently (it did: the local `## Tool access` section of `writing-for-agents` was lost on 2026-08-29 and now lives in `lessons/agent-tooling/`). Behaviour changes go through `skillOverrides` (above) | a lesson under `lessons/` that the consuming skill points at (`agent-tooling/usage-lessons.md` is the rulebook's companion) |
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
