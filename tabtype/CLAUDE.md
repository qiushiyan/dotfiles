This folder is a Stow package for **TabType**, a text-expansion tool. `.config/tabtype/config.toml` is the live config — it's symlinked to `~/.config/tabtype/config.toml` by the parent dotfiles Stow setup, so edits here change the running app immediately.

The `snippets` array holds the prompt templates the user pastes into AI coding tools (Claude Code, Codex, etc.) via the `;;` trigger. These snippets — not TabType itself — are the substance of the file, and most work future agents do here will be revising or adding them. They encode a deliberate two-agent, three-stage development workflow.

## The workflow encoded by the snippets

The user runs two coding agents in parallel: one **implementer** (drafts specs, plans, code) and one **reviewer** (critiques each artifact). Snippets get pasted between them across a **spec → plan → implementation** arc, with draft / review / update cycles at each stage and an optional round-2 for follow-on revisions.

Prefix convention: `review-*` is always sent to the reviewer; `update-*` and `respond-*` are sent to the implementer. The `-again` suffix marks a round-2 variant (re-doing the same operation on the updated artifact).

For the full daily flow — every snippet in the typical order it gets used, plus the standalone helpers and when they fit — see [WORKFLOW.md](WORKFLOW.md).

## Design patterns to preserve

When revising or adding snippets, these patterns recur and carry the workflow's intent:

**Stage altitude lens** (in `review-spec`, `review-plan`). Each artifact has a deliberate level of detail. The reviewer is given a three-part lens so they critique at the right altitude:

1. Vagueness about things the artifact _intentionally_ defers — don't ask for more.
2. Vagueness about things the artifact _should_ answer — flag it.
3. Technical content the artifact _does_ propose — fair game to critique; propose better.

What counts as "intentional" differs by stage:

- **Spec** defers line-level edits, specific test cases, doc plans, and commit order.
- **Plan** defers _only_ full code bodies. Test cases, helper internals, fixture shape, and line-level references for existing code _are_ in the plan and are reviewable.

**"What not to include" guardrails** (in `write-spec`, `tdd-plan`). Each draft snippet explicitly names what gets designed at a _later_ stage, to stop the agent from prematurely committing to details (e.g., the spec doesn't include doc-update plans because those happen post-implementation).

**Round-2 review** (`review-implementation-again`, `review-plan-again`). Re-check after the drafter applies feedback — focus is "was the concern actually addressed, or hand-waved?" Apply the same altitude lens; don't relitigate settled points.

**Reflect-before-change for code feedback** (`respond-review`). The drafter analyzes critique _before_ touching code. Spec/plan use direct `update-*` snippets since text is cheap to revise; code uses the reflect pattern because code changes are more expensive. Round-2 (`respond-review-again`) drops the analysis gate and applies inline, since the work is narrower and the goal is converging.

**Mid-point checkpoint** (`midpoint-status`, `review-midpoint`, `respond-midpoint`). For large implementations (10+ slices), the implementer is paused partway to report status, the reviewer critiques the work-so-far _and_ guides the rest, then the implementer triages the feedback before resuming. Two ideas specialize the altitude lens here:

- **Time axis** — slices not yet reached are _intentionally undone_, not defects; the reviewer must not flag them as missing (the temporal analogue of "don't ask for more on deferred things").
- **Early-correction leverage** — foundational/structural problems are weighted _highest_ because they compound across every remaining slice, while local nits defer to the final `review-implementation`.

The response reuses the reflect-before-change gate from `respond-review`, but its triage is forward-looking: each point sorts into fix-now / fold-into-remaining-slices / disagree. No `-again` round-2 variants — a checkpoint is one-shot; you fix and continue.

**Review-aligned handoff** (`implementation-handoff`). When the implementer reports finished work to orient the reviewer, the report's sections mirror `review-implementation`'s evaluation axes — what/why, change map, key decisions, deviations, tests, where-to-look-hardest — so each thing the reviewer is about to assess is pre-loaded. It's a guided map, _not a self-review_: the implementer marks the riskiest/most-complex changes (shifting the framing burden to whoever knows the code best) but does **not** grade quality — that's the reviewer's job. It supersedes the thin `commits-summary` as the final review's context block, feeding `review-implementation`'s `$0` directly. The general principle: a report snippet should be shaped by the review snippet it feeds.

**Tests as a cross-cutting concern.** Test thinking isn't confined to the plan/TDD stage — it threads through the whole arc, each phase at its own altitude. Match the prompt to the phase: don't ask for test cases where they're intentionally deferred, and don't let them silently drop where they're due.

- **Spec** (`write-spec`, `review-spec`) — name the behaviors that matter; specific cases, fixtures, and mocking boundaries are deferred (the altitude lens enforces this).
- **Plan** (`tdd-plan`, `review-plan`) — test cases, fixtures, and mocking boundaries are first-class and reviewable. Non-TDD plans (`start-plan`) still owe a verification story per phase.
- **Implementation review** (`review-implementation`, `implementation-handoff`) — test quality is an explicit evaluation axis and a reported section.
- **Responding to review** (`respond-review`) — a finding is a signal about test quality: diagnose coverage-gap vs. weak-test, then plan add / strengthen / delete. `review-implementation-again` then verifies those test changes actually held up.
- **Mid-point checkpoint** (`midpoint-status`, `review-midpoint`, `respond-midpoint`) — test state is surfaced for the completed slices, reviewed, and any fallout triaged into fix-now / fold-into-a-slice.

When adding or revising a snippet, ask whether its phase has a test angle and pitch it at that phase's altitude.

## Snippet schema

```toml
[[snippets]]
key = "snippet-name"
expand = '''
text with literal newlines
and $0 cursor'''
```

- `key` triggers via `;;key`; the `;;` trigger is set at the top of the file.
- `expand` uses TOML literal multi-line strings (`'''…'''`) — content is verbatim, no escape processing. Place the closing `'''` on the last content line to avoid an extra trailing newline. For short single-line snippets, a basic string (`expand = "…"`) is fine.
- `$0` marks where the cursor lands after expansion (used wherever the user is about to paste reviewer feedback: `update-*`, `respond-*`, `review-*-again`).
- A `---` separator with a blank line before `$0` is the convention for snippets that need a visual separator before the pasted content.

Naming convention: stage artifacts follow `write-X` (implementer creates), `review-X` (reviewer critiques), `update-X` / `respond-X` (implementer revises based on critique), and `review-X-again` / `update-X-again` / `respond-X-again` for the round-2 variant. Implementer-produced status reports take a descriptive `-status` / `-handoff` name (`midpoint-status`, `implementation-handoff`). Standalone snippets use descriptive names (`think-holistic`, `find-similar-bugs`).

## Editing

Edits to `.config/tabtype/config.toml` are live in TabType immediately via the Stow symlink — no reload needed. After editing, validate TOML:

```bash
python3 -c "import tomllib; tomllib.load(open('.config/tabtype/config.toml', 'rb'))"
```
