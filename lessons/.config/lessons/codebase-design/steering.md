# Steering

What a change leaves for the next one to copy. It builds on [deep-modules.md](deep-modules.md) and [composition.md](composition.md).

The **next author** is a session with a one-line request and none of the design. It searches for a name, opens what comes up, copies the code beside its edit, takes the shortest path that compiles, and stops when the checks pass. So ask of any design or diff: *what will the next change of this kind look like if it is written by copying this one?*

## The bar

- **One way to do the job.** Two live shapes means later changes copy either.
- **One declaration per fact.** Lists that name a thing are derived from where it is declared.
- **The wrong version does not compile.** An omitted step is an error where the decision belongs.
- **Decide once, at the top.** The entry point reads as the composition; nothing below decides again.
- **A small door, and nothing else to import.** The shortcut that compiles becomes the interface.
- **One name, one path.** Sessions find code by search.
- **A failure names the fix.** Its reader is a session in the middle of a task.
- **Earned by a next change that is coming**: a kind that keeps growing, a job several authors do, a fault that came back. For a one-off, leave the code direct.

## What it looks like

**One way to do the job.** Finish the conversion in the change and delete the old way. Where it cannot finish, refuse new uses of the old shape first.

```text
avoid   api/projects.ts  getProject()    12 uses
        legacy/fetch.ts  fetchProject()  40 uses     ← the one a search finds first
prefer  api/projects.ts  getProject()    52 uses
```

**One declaration per fact.** Adding an instance is copying a sibling file. The declaration is typed and found by search, never wired by filename magic or an import's side effect.

```ts
// avoid: a new tool means finding every table that spells its name
export const TOOL_NAMES = ['search', 'export'] as const         // tools/names.ts
const HANDLERS = { search: runSearch, export: runExport }       // tools/dispatch.ts
const MUTATING = new Set(['export'])                            // auth/permissions.ts

// prefer: one declaration, and the lists are views of it
export const exportTool = defineTool({                          // tools/on-demand/export.ts
  name: 'export',
  layer: 'on-demand',
  mutates: true,
  run: runExport,
})
export const TOOLS = [searchTool, exportTool] as const          // tools/index.ts
export const MUTATING = TOOLS.filter((t) => t.mutates).map((t) => t.name)
```

This is about facts, not look-alike code. A decision copied into two files drifts when a session edits one; two functions that merely resemble each other are cheaper than one helper bent to fit both.

**The wrong version does not compile.** A required field, a name union or an exhaustive map, over a default that absorbs the new case.

```ts
// avoid: a new kind falls through and ships as a row
function faceOf(kind: string): Face {
  switch (kind) {
    case 'answer': return 'card'
    default: return 'row'
  }
}

// prefer: a new kind is an error here until someone decides
const FACE = { search: 'row', answer: 'card' } satisfies Record<ToolKind, Face>
```

**Decide once, at the top.** Conditions that choose a path live in the entry point; code below receives the decision as data. Input is parsed once at the edge, because a session copies the checks it sees.

```ts
// avoid: a flag travels down, and each layer decides again
async function run(input: Input, opts: { isPool?: boolean }) {
  return stage(input, opts)
}
function stage(input: Input, opts: { isPool?: boolean }) {
  if (opts.isPool) { /* … */ } else { /* … */ }     // and once more two files deeper
}

// prefer: the entry point is the list of stages
export async function run(request: Request) {
  const input = parseRunInput(request)      // untrusted → typed, once
  const plan = resolvePlan(input)           // every "which host, which capability" decision
  const result = await execute(plan)        // reads the plan, never asks which host
  return present(result, plan.surface)
}
```

**A small door, and nothing else to import.** If the unsafe version is one import away, it gets written.

```ts
// avoid: internals are reachable, so the next author uses them
import { encode } from '@/view-state/internal/encode'
history.replaceState(null, '', `?${encode(state)}`)

// prefer: the package exports only the operations that hold its invariant
export { readViewState, writeViewState, shareLink } from './api'   // view-state/index.ts
```

**One name, one path.** A re-export chain, an alias or a generic name hides where a thing lives.

```ts
// avoid
import { TextInput as Field } from '@/components'      // three index.ts files away
function process(data: Data) { /* … */ }

// prefer
import { TextInput } from '@/components/forms/TextInput'
function applyInvoiceLineDiscount(line: InvoiceLine) { /* … */ }
```

**A failure names the fix**: what is wrong, the file to edit, what to do, and who decides when the fix is a product choice.

```text
avoid   expected 41 to equal 42
prefer  risk.ts is in on-demand/ but declares layer: 'loaded'.
        Move the file or change the field (tools/README.md § Layers).
```

## Which mechanism

Take the strongest the fact allows. Each stands behind the ones above it, never in their place, and a fix placed lower says why the level above could not hold it.

1. **The shape**: one way, one declaration, a door that hides the rest.
2. **The type**: the wrong version does not compile.
3. **A check** that fails in a file the author is already editing.
4. **A lint rule**, for a construction no type can see. It refuses a shape and cannot show the one to write, so the right shape must already sit beside the edit.
5. **An instruction file, then a doc.** Docs hold the *why* and the places where the code still misleads. Nothing fails when a session skips them.

## What changes when agents write the code

Clean code still decides how cheaply a change lands. Four things weigh differently.

- **Consistency outranks local elegance.** One odd file is a pattern; one workaround, or the comment excusing it, spreads.
- **Explicit beats implicit.** A session sees the files it opened. Convention by filename, decorators and a check kept in another file are invisible to it.
- **Typing is free.** Long names, required fields and exhaustive maps cost an agent nothing, so brevity is no reason to leave a step to memory.
- **Search is the way in.** Names and paths do what go-to-definition does for a person.

## Checking it

- **Walk the next change.** Name it (the next tool, the next key, the next caller) and follow a session making it: what its search returns, what it copies, what fails when it skips a step. A step nothing forces is the finding.
- **Take the wrong path.** Relabel it, cast it, skip the registration, import the internal. A guard that still passes was checking its own declaration.
- **Count the guards too.** A registry with one member, or three guards for a kind nothing shows growing, is **speculative generality** with a safety label.

---

> _Lesson · codebase-design. New 2026-11, generalized from PlanLab's Loopy changeability initiative (`docs/loopy/changeability/README.md` § Where a change is steered, tenets 8 and 9, lens 9) and from the sessions in which the user typed this question by hand (`~/dotfiles/claude/.claude/skills/strategic-review/EVIDENCE.md`, 2026-11-16). Checked against Lauren Tan's pstack (`cursor/plugins`, `skills/correct`) for the order of mechanisms, matklad's "Push ifs up and fors down", King's "Parse, don't validate", Metz's "The wrong abstraction" and Ronacher's "A language for agents". These are practitioners' observations; no study measures which of two coexisting shapes an agent copies. The split between duplicated facts and duplicated code is this lesson's reconciliation of sources that disagree on DRY. No upstream skill baseline._
