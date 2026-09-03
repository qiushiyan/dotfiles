# TabType workflow

The snippets in `tabtype/.config/tabtype/config.toml` support a flexible
analysis → design → implementation → review arc. The config owns exact prompt
text and available keys; this page owns sequence. `DESIGN.md` explains why the
families are shaped this way.

The skill-based loop in `docs/doc-loop.md` is the default for projects that
provide those skills. Use these snippets when working manually across agents or
when one focused prompt is lighter than a full skill run.

## 1. Frame and settle the direction

```text
think-holistic → both agents when independent designs are valuable
compare-notes  → implementer synthesizes the second analysis
step-back      → pressure-test an anchored first take
risk-check     → isolate hot-path, user-surface, and core-logic risk
```

Use `elaborate-questions` when a question cannot be decided without hidden
session context.

## 2. Write the design

`write-spec` turns the settled direction into a project-local spec. It owns
product behavior, boundaries, target shape, and test strategy. Review the spec
through `/consult` or the project's review convention.

Before implementation:

```text
compact-for-impl → keep the settled design and why
reread-context   → rebuild file-level understanding from source
```

## 3. Plan when the work needs one

```text
tdd-plan       → vertical red/green/refactor slices
start-plan     → non-TDD sequence with a verification story
review-plan    → reviewer judges tactics against the settled design
update-plan    → implementer integrates the review
*-plan-again   → optional convergence pass
```

Small work may move directly from the spec to implementation.

## 4. Implement

Choose the entry that matches the artifact available:

```text
implement-spec   → build from a settled spec
implement-direct → build a bounded change without a separate spec
```

For a large build, pause at a committed boundary:

```text
midpoint-status → review-midpoint → respond-midpoint → user go-ahead → continue
```

## 5. Review and converge

```text
compact-for-review
  → implementation-handoff
  → review-implementation
  → respond-review
  → user approves changes
  → review-implementation-again
  → respond-review-again
```

`commits-summary` supplies a lighter context block when the full handoff is not
needed. `review-verify` and `consult-verify` spend an agent wait on independent
reproduction rather than idle time.

## 6. Wrap up

```text
compact-for-cleanup → pr-description → optional find-similar-bugs
```

Use `handoff-for-review` instead of merging when the branch needs a fresh
adversarial session.

## Helpers

| Need | Snippet |
|---|---|
| Compact the same in-flight task | `compact-inflight` |
| Generate a session-specific compaction instruction | `generate-compact` |
| Replace a long debugging history with a deliberate handoff | `brief-for-rewind` → `resume-from-brief` |
| Expose guesses | `list-assumptions` |
| Walk one concrete runtime path | `trace-execution` |
| Adapt general guidance to the repository | `smart-adapt-skills` |
| Reframe difficulty around impact and uncertainty | `technical-difficulty` |
| Choose current platform/library primitives deliberately | `use-latest-stack` |
| Triage external review feedback | `handle-review` |

Search `key =` in the config for the full inventory and current prompt text.
