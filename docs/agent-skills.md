# Agent skills: Claude Code ⊇ Codex

**The invariant: every skill Codex has, Claude Code has — never the reverse.**
The only permitted exception is a skill _about_ Codex itself
(`keep-codex-fast`), which lives as a real directory in the codex package. A
Claude-only skill is simply one with no Codex symlink.

```
claude/.claude/skills/<name>/          # source of truth — real directories
codex/.codex/skills/<name>             # relative symlink → ../../../claude/.claude/skills/<name>
codex/.codex/skills/keep-codex-fast/   # real dir — the declared Codex-only exception
codex/.codex/skills/.system/           # Codex's bundled skills — gitignored, not ours
~/.agents/skills/                      # the `skills` CLI's store — should be empty; a dir here is a
                                       # leftover copy, removed only after the repo has the real dir
```

**Audit:** every entry under `codex/.codex/skills/` is either a symlink into
`claude/.claude/skills/` or a declared Codex-only skill. Any other real
directory is a bug — except `.system/`, Codex's own bundled skills, which it
reinstalls and `.gitignore` excludes.

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

**`skills update` has no `--copy` and re-creates the bad link.** Verified
2026-08-29 updating `writing-for-agents`: the CLI replaced the real directory
with `../../.agents/skills/<name>` (dangling from the repo) and put the files
in `~/.agents/skills/<name>/`. Recovery, every time:

```bash
S=claude/.claude/skills/<name>
rm $S && cp -R ~/.agents/skills/<name> $S && rm -rf ~/.agents/skills/<name>
git diff --stat $S     # read the upstream change before committing
```

Scope updates to one skill (`npx skills update <name> -g -y`) — a bare
`skills update` also touches every customized skill still in the lockfile
(see Ownership tiers).

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
- **A renamed upstream skill goes stale in silence.** When a skill is renamed
  upstream, its lockfile `skillPath` starts 404ing and `skills update` no-ops on
  it forever — no error, no warning, the local copy just frozen. (This is not
  hypothetical: it happened to `writing-great-skills` → `writing-for-agents`.)
  An update that reports success is not evidence the skill still exists
  upstream; if one looks suspiciously unchanged, check the path by hand.

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

Verified working in the restricting direction: that skill carries a full
model-facing trigger list and no frontmatter flag, and the override alone keeps
it out of the model's skill list. **The re-enabling direction is unreliable** —
an `"on"` override failed to bring a disabled skill back when last tested
(v2.1.205), and the field is undocumented with open upstream bugs. So: use it to
take a skill away from the model, and don't depend on it to give one back
without re-testing. Global
overrides go in `claude/.claude/settings.json`; a project-local one in a repo's
own `.claude/settings.local.json` binds only inside that repo.

The one real trap:

- **Never put a skill in `permissions.deny`.** Deny gates _execution_, not
  visibility: the description still costs context, the model still tries and
  gets blocked, and you lose your own `/skill` invocation too. Deny is for tools
  (e.g. `NotebookEdit`), not skills.

## Ownership tiers — who may edit a skill, and where a lesson goes

Every directory under `claude/.claude/skills/` is one of four things, and the
tier decides where an improvement is allowed to land. The tell is the lockfile
(`~/.agents/.skill-lock.json`) plus the presence of `.upstream/`.

| tier | tell | edit policy | where our own lessons about it go |
|---|---|---|---|
| **Managed** — installed from upstream and kept current (`writing-for-agents`, `codebase-design`, `research`, …) | in the lockfile, no `.upstream/` | never edit the body; `skills update` reverts it silently (it did: the local `## Tool access` section of `writing-for-agents` was lost on 2026-08-29 and now lives in `lessons/agent-tooling/`). Behaviour changes go through `skillOverrides` (above) | a lesson under `lessons/` that the consuming skill points at (`agent-tooling/usage-lessons.md` is the writing-for-agents companion) |
| **Customized** — upstream pinned beside a rewritten body (`obelisk`) | `.upstream/PINNED.txt` + `LESSONS.md` in the skill dir | edit the body freely; upgrade by hand per `PINNED.txt`, re-checking every `LESSONS.md` item against the new upstream | in the skill's own `LESSONS.md` (receipts) and body (rules) |
| **Original** — ours (`review`, `consult`, `improve-tool`, `handoff`, …) | in neither | edit freely | in the body, or in a lesson when several skills share the rule |
| **Vendored bundled** — a copy of a Claude Code built-in (`artifact-design`) | listed in the section below | treat as managed by hand: refresh from the CLI, don't customize | — |

**Trap: a customized skill that is still in the lockfile.** `obelisk` is
both — installed by the CLI on 2026-07-20 and rewritten since, and its lock
entry's `skillPath` resolves on the current upstream repo, so `skills update`
would overwrite the customized body with upstream's. `skills remove` cannot fix
it (all-or-nothing — it deletes the directory). The safe move is to delete the
`obelisk` entry from `~/.agents/.skill-lock.json` by hand, so the CLI forgets
it and the `PINNED.txt` procedure is the only upgrade path. Until that is done,
run `skills update` only after `git status` shows the skill tree clean, and
diff before committing.

### Where a writing guideline lives

Guidance for writing agent-facing text is layered, and the layer decides the
file:

```
claude/.claude/skills/writing-for-agents/   managed — structure, pointers, leading words   (upstream's)
claude/.claude/skills/prompt-engineering/   original — model-facing text, the defect lens
lessons/.config/lessons/agent-tooling/      ours — what measured sessions added on top:
                                            examples over prose, answer in the engine,
                                            cold readers, the doctrine gap
claude/.claude/skills/<skill>/SKILL.md      the skill-specific gist + pointers up the stack
```

A rule about *how to write any agent-facing document* goes in the lesson,
never into `writing-for-agents` (managed). A rule about *one skill's* domain
goes in that skill. Lessons are not skills — no frontmatter, not invokable,
reached only by a pointer from a skill or snippet — and `lessons/.config/lessons/CLAUDE.md`
carries the conversion rules between the two forms.

## Vendored bundled skills

`"disableBundledSkills": true` in `claude/.claude/settings.json` is what we
want for ~30 bundled skills and wrong for a handful. **There is no way to
exempt one.** The kill switch is all-or-nothing with a single hardcoded
escape hatch — a `survivesBundledKillSwitch` property set in the CLI's own
source, and as of v2.1.233 exactly one skill sets it (`/doctor`). No
`enabledSkills` / `disabledSkills` / per-skill settings key exists, in the
binary or the docs. `skillOverrides` doesn't reach these either: it's the
re-enabling direction, which is the direction that doesn't work (above).

So the way back in is to **vendor the skill** — a real directory under
`claude/.claude/skills/`. Skills there are explicitly unaffected by the kill
switch, and a user skill shadows a bundled one of the same name, so a vendored
copy stays correct whether or not the switch later flips.

Currently vendored:

```
claude/.claude/skills/artifact-design/   # ← bundled, CLI v2.1.233 (2026-08-17)
```

The Artifact tool description says you *must* load `artifact-design` before
writing any artifact, and `"disableArtifact": false` is set — so without this
the tool was live and its mandatory skill was missing. Two sibling skills,
`artifact-diagramming` and `artifact-capabilities`, are in the same state and
deliberately not vendored yet; `artifact-capabilities` is the one the tool
calls mandatory before declaring `capabilities` or writing `window.claude.*`
runtime code.

**This is a copy, and copies rot.** Re-extract after a CLI upgrade that touches
artifacts. The body lives in the binary as a template literal:

```bash
node -e '
  const fs=require("fs"), B=process.env.HOME+"/.local/share/claude/versions/<VER>";
  const s=fs.readFileSync(B).toString("latin1"), k="var otg=`";
  const a=s.indexOf(k+"---")+k.length, b=s.indexOf("`;var ntg=",a);
  const body=Buffer.from(s.slice(a,b),"latin1").toString("utf8");
  process.stdout.write(eval("`"+body.replace(/\$\{/g,"\\${")+"`"));
'
```

Two extraction traps:

- **Don't go through `strings`.** `strings -n 6` drops every line shorter than
  six bytes — which silently eats the blank lines and the `---` frontmatter
  fence, collapsing the whole document into one paragraph. Read the raw binary.
- **`<!-- dataviz-callout -->` is a placeholder, not content.** The runtime
  substitutes it only behind the `tengu_cobalt_plinth_dataviz` flag (default
  off). Delete the line — left in, it points at `dataviz`, which the kill
  switch still disables.

The `var otg=` symbol is minifier output and will not be stable across
versions. Locate the skill by its frontmatter (`name: artifact-design`) and
re-derive the surrounding variable name.
