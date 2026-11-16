# Steering

What a change leaves for the next one to copy. It builds on [deep-modules.md](deep-modules.md) and [composition.md](composition.md).

The **next author** is a session with a one-line request and none of the design. It searches for a name, opens what comes up, copies the code beside its edit, takes the shortest path that compiles, and stops when the checks pass. So ask of any design or diff: *what will the next change of this kind look like if it is written by copying this one?*

## The bar

These apply where a change sets a pattern, a shape later changes will copy: an entry point, a registry, a kind that keeps growing, a migration, the fix for a fault that came back or sits in several places. Each is earned by a next change the code already shows: members added before, several authors, a recurrence. For a one-off, leave the code direct.

- **One way to do the job.** Two live shapes means later changes copy either (composition's *lava layer*).
- **One declaration per fact.** Lists that name a thing are derived from where it is declared (*information leakage*).
- **The wrong version does not compile.** An omitted step is an error where the decision belongs (*illegal states*, in deep-modules).
- **Decide once, at the top.** Which mode, host or capability applies is settled in the entry point and passed down as data.
- **A small door, and nothing else to import.** The shortcut that compiles becomes the interface.
- **One name, one path.** Each thing has one specific name and one place it is imported from.
- **A failure names the fix.** Its reader is a session in the middle of a task.

## What it looks like

**One way to do the job.** Finish the conversion in the change and delete the old way. Where it cannot finish, refuse new uses of the old shape first.

```text
avoid   api/projects.ts  getProject()    12 uses
        legacy/fetch.ts  fetchProject()  40 uses     ← the one a search finds first
prefer  api/projects.ts  getProject()    52 uses
```

**One declaration per fact.** Adding an instance is copying a sibling file and adding it to one list. The declaration is a typed value a search finds; registration by filename convention or an import's side effect hides it.

```ts
// avoid: a new tool means finding every table that spells its name
export const TOOL_NAMES = ['search', 'export'] as const         // tools/names.ts
const HANDLERS = { search: runSearch, export: runExport }       // tools/dispatch.ts
const MUTATING = new Set(['export'])                            // auth/permissions.ts

// prefer: one declaration, and the other lists are views of it
export const exportTool = defineTool({                          // tools/export.ts
  name: 'export',
  mutates: true,
  run: runExport,
})
export const TOOLS = [searchTool, exportTool] as const          // tools/index.ts
export const MUTATING = new Set(TOOLS.filter((t) => t.mutates).map((t) => t.name))
```

This is about facts, not look-alike code. A decision copied into two files drifts when a session edits one; two functions that merely resemble each other are cheaper than one helper bent to fit both.

**The wrong version does not compile.** A required field, a closed union or an exhaustive map, over a default that absorbs the new case.

```ts
// avoid: a new kind falls through and ships as a row
function faceOf(kind: string): Face {
  switch (kind) {
    case 'export': return 'card'
    default: return 'row'
  }
}

// prefer: a new tool is an error here until someone decides
type ToolKind = (typeof TOOLS)[number]['name']       // defineTool keeps the literal name
const FACE = { search: 'row', export: 'card' } satisfies Record<ToolKind, Face>
```

**Decide once, at the top.** The entry point lists the decisions, each made once; code below receives them as data. Branches about the work itself stay inside the module that owns it. Input is parsed once at the edge (*parse, don't validate*), because a session copies the checks it sees.

```ts
// avoid: a flag travels down, and each layer decides again
async function run(input: Input, opts: { isPool?: boolean }) {
  return stage(input, opts)
}
function stage(input: Input, opts: { isPool?: boolean }) {
  if (opts.isPool) { /* … */ } else { /* … */ }     // and once more two files deeper
}

// prefer: one place answers "which host, which capability"
export async function run(request: Request) {
  const input = parseRunInput(request)      // untrusted → typed, once
  const plan = resolvePlan(input)           // the decisions
  const result = await execute(plan)        // reads the plan, never asks which host
  return present(result, plan.surface)
}
```

**A small door, and nothing else to import.** If the unsafe piece is one import away, it gets used. Leave it unexported; across packages, the package's `exports` map is the door.

```ts
// avoid: the encoder is exported, so the next author writes the URL by hand
import { encode } from '@/view-state/encode'
history.replaceState(null, '', `?${encode(state)}`)

// prefer: view-state/url.ts keeps it private behind the operation that holds the invariant
function encode(state: ViewState): string { /* … */ }
export function writeViewState(state: ViewState) {
  history.replaceState(null, '', `?${encode(state)}`)
}
```

**One name, one path.** One door per package is its interface; past that, a name is imported from where it is declared.

```ts
// avoid
import { TextInput as Field } from '@/components'      // three index.ts files from its home
function process(data: Data) { /* … */ }

// prefer
import { TextInput } from '@acme/forms'
function applyInvoiceLineDiscount(line: InvoiceLine) { /* … */ }
```

**A failure names the fix**: what is wrong, the file to edit and what to do. Where two edits would both turn it green, it says how to tell which is right.

```text
avoid   expected 41 to equal 42
prefer  tools/risk.ts is not in TOOLS (tools/index.ts).
        Add it to the list, or delete the file if the tool was removed.
```

**For a one-off, the direct code.** The same care spent where nothing repeats is *speculative generality* with a safety label.

```ts
// avoid: a registry and a guard for the only exporter there is
export const EXPORTERS = [defineExporter({ name: 'csv', run: exportCsv })] as const

// prefer: one function, called directly, until a second exporter exists
export function exportCsv(rows: Row[]): string { /* … */ }
```

## Which mechanism

Take the strongest the fact allows. Each stands behind the ones above it, never in their place, and a fix placed lower says why the level above could not hold it.

1. **The shape**: one way, one declaration, a door that hides the rest.
2. **The type**: the wrong version does not compile.
3. **A check** whose failure points at a file the author is already editing.
4. **A lint rule**, for a construction no type can see. Its message can name the right shape, which must already exist beside the edit for a session to copy.
5. **An instruction file, then a doc.** Docs hold the *why* and the places where the code still misleads. Nothing fails when a session skips them.

Two things weigh more than they did when people wrote the code. One odd file is a pattern: a workaround, or the comment excusing it, spreads. And typing is free: long names, required fields and exhaustive maps cost an agent nothing, so brevity is no reason to leave a step to memory.

## Checking it

- **Walk the next change** (composition prices it; this follows its author). Name it (the next tool, the next key, the next caller) and follow a session making it through every step it owes: what its search returns, what it copies, what fails when it skips one. A step nothing forces is the finding.
- **Take the wrong path.** Relabel it, cast it, skip the registration, import the internal. A guard that still passes was checking its own declaration.

---

> _Lesson · codebase-design. New 2026-11, generalized from PlanLab's Loopy changeability docs (`docs/loopy/changeability/README.md` § Where a change is steered, tenets 8 and 9; `lenses.md` lens 9) and from sessions in which the user asked this by hand (`~/dotfiles/claude/.claude/skills/strategic-review/EVIDENCE.md`, 2026-11-16). The order of mechanisms follows Lauren Tan's pstack (`cursor/plugins`, `skills/correct`). These are practitioners' observations, with no study of which of two shapes an agent copies; the split between duplicated facts and duplicated code is this lesson's reconciliation of sources that disagree on DRY. No upstream skill baseline._
