# Lessons

Adapted, owned reference docs that prompt snippets read at design and review time. **These are not Claude Code skills** — they're forked from [mattpocock/skills](https://github.com/mattpocock/skills), consolidated, headless-tuned (no HTML/interactive scaffolding), and tailored to this workflow. The snippets in `~/dotfiles/tabtype`, `~/dev/greenflag`, and the dispatch-skill briefs (`~/dotfiles/claude`) point here.

## Consumption contract

When a snippet hands you these during technical design:

- They are **the bar for a good plan, not optional background.** Read the load-bearing ones; skim the rest as a lens.
- **Adapt, don't recite.** Evaluate each point against the codebase and constraints; discard what doesn't fit.
- If a referenced path is **missing, ask** — don't guess.

## Design-phase reading roadmap

The order a planning model should read these, with gates. The snippet's include list mirrors this table — keep them in sync.

| # | Lesson | Role at design time | Read when |
|---|--------|---------------------|-----------|
| 1 | [`codebase-design/deep-modules.md`](codebase-design/deep-modules.md) | The design lens — calibrates the *shape* before you plan | always |
| 2 | [`testing/tdd-loop.md`](testing/tdd-loop.md) | Slicing + red-green-refactor — how the plan is structured | always |
| 3 | [`testing/mocking-and-fixtures.md`](testing/mocking-and-fixtures.md) | The bridge: how the modules you shaped get tested | always |
| 4 | [`testing/test-quality.md`](testing/test-quality.md) | The bar the planned tests must clear — and the shapes to reject | always |
| 5 | [`testing/vitest.md`](testing/vitest.md) | Vitest API/CLI specifics | **TS-Vitest projects only** |
| 6 | [`codebase-design/composition.md`](codebase-design/composition.md) | The call path between modules — what each hop adds, and whether a change joins the design or accretes beside it | **when the change joins existing code**; always at review time |
| 7 | [`codebase-design/deepening.md`](codebase-design/deepening.md) | Deepen an existing cluster of shallow modules | **only when restructuring** |
| 8 | [`codebase-design/design-it-twice.md`](codebase-design/design-it-twice.md) | Explore alternative interfaces | **only when the interface is uncertain** |

Each doc opens with a **"## The bar"** section (skimmable imperatives), then expands into depth (the planning read).

## Topics

- [`codebase-design/`](codebase-design/README.md) — module design vocabulary and structural patterns.
- [`testing/`](testing/README.md) — test discipline, mocking strategy, Vitest reference.
- [`collaboration/`](collaboration/README.md) — cross-agent working discipline: the review-lens stance for judging another engineer's change.

## Staying in sync with upstream

`.upstream/` holds the pinned pristine Matt Pocock skills these lessons were forked from (see `.upstream/PINNED.txt` for the commit). To pull genuine improvements: download a fresh copy, `diff` it against `.upstream/`, decide what to fold into the lessons, then refresh the pin. Each lesson's provenance line names its source files and baseline so the diff has an anchor.
