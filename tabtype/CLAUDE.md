This folder is a Stow package for **TabType**, a text-expansion tool. `.config/tabtype/config.toml` is the live config — it's symlinked to `~/.config/tabtype/config.toml` by the parent dotfiles Stow setup, so edits here change the running app immediately.

The `snippets` array holds the prompt templates the user pastes into AI coding tools (Claude Code, Codex, etc.) via the `;;` trigger. These snippets — not TabType itself — are the substance of the file, and most work future agents do here will be revising or adding them. They encode a deliberate two-agent, three-stage development workflow.

## The workflow encoded by the snippets

The user runs two coding agents in parallel: one **implementer** (drafts specs, plans, code) and one **reviewer** (critiques each artifact). Snippets get pasted between them across a **spec → plan → implementation** arc, with draft / review / update cycles at each stage and an optional round-2 for follow-on revisions.

Prefix convention: `review-*` is always sent to the reviewer; `update-*` and `respond-*` are sent to the implementer. The `-again` suffix marks a round-2 variant (re-doing the same operation on the updated artifact).

For the full daily flow — every snippet in the typical order it gets used, plus the standalone helpers and when they fit — see [WORKFLOW.md](WORKFLOW.md).

## Design patterns to preserve

When revising or adding snippets, these patterns recur and carry the workflow's intent:

**Stage altitude lens** (in `review-spec`, `review-plan`). Each artifact has a deliberate level of detail, and the reviewer is given a lens so they critique at the right altitude. The two stages shape it differently, because the spec has two tiers and the plan has one:

- **Spec** (`review-spec`) — a **section-scoped** lens. The spec runs top-down, product sections above technical sections, and each tier reviews at its own altitude: a missing behavior is a product-section gap; module boundaries, seams, the target shape, and the test strategy are fair game in the technical sections; code bodies, per-case test enumeration, fixtures, line-level edit plans, and commit order are intentionally deferred. Module design pressed at the product tier is below altitude — judge it in the technical sections instead.
- **Plan** (`review-plan`) — a **flat three-part** lens, since the plan is one altitude throughout:
  1. Vagueness about things the plan _intentionally_ defers (full code bodies) — don't ask for more.
  2. Vagueness about things the plan _should_ answer — flag it.
  3. Technical content the plan _does_ propose — fair game to critique; propose better.

  The plan defers _only_ full code bodies. Test cases, helper internals, fixture shape, and line-level references for existing code _are_ in the plan and are reviewable.

**The spec is half-technical, and the interface is chosen there.** The spec's technical tier owes the module boundaries, the seams, the **target shape** (file structure, public API, integration wiring), and the **test standards** (which behaviors matter, and for each the strategy — through which interface, what gets faked at which boundary). It reads the design lessons closely (`deep-modules`, `design-it-twice`, `deepening`) and skims the testing lessons' `## The bar` as a lens. The plan is then purely tactical: slices, sequencing, specific test cases and fixtures, line-level anchors.

The load-bearing ordering rule: **`design-it-twice` belongs to the spec, not the plan.** The interface gets committed in the spec's target-shape section, and `tdd-plan` tells the implementer to follow the settled spec — so a design-it-twice gate in the plan fires after the decision it exists to inform. The spec sketches three shapes different in kind, commits one, and records the discards in a short "Shapes considered" note (the winner, not the menu) — which `review-spec` then audits: was the shape _chosen_, or merely _first_?

**"What not to include" guardrails** (in `write-spec`, `tdd-plan`). Each draft snippet explicitly names what gets designed at a _later_ stage, to stop the agent from prematurely committing to details (e.g., the spec doesn't include doc-update plans because those happen post-implementation).

**Round-2 review** (`review-implementation-again`, `review-plan-again`). Re-check after the drafter applies feedback — focus is "was the concern actually addressed, or hand-waved?" Apply the same altitude lens; don't relitigate settled points.

**Reflect-before-change for code feedback** (`respond-review`). The drafter analyzes critique _before_ touching code. Spec/plan use direct `update-*` snippets since text is cheap to revise; code uses the reflect pattern because code changes are more expensive. Round-2 (`respond-review-again`) drops the analysis gate and applies inline, since the work is narrower and the goal is converging.

**Mid-point checkpoint** (`midpoint-status`, `review-midpoint`, `respond-midpoint`). For large implementations (10+ slices), the implementer is paused partway to report status, the reviewer critiques the work-so-far _and_ guides the rest, then the implementer triages the feedback before resuming. Two ideas specialize the altitude lens here:

- **Time axis** — slices not yet reached are _intentionally undone_, not defects; the reviewer must not flag them as missing (the temporal analogue of "don't ask for more on deferred things").
- **Early-correction leverage** — foundational/structural problems are weighted _highest_ because they compound across every remaining slice, while local nits defer to the final `review-implementation`.

The response reuses the reflect-before-change gate from `respond-review`, but its triage is forward-looking: each point sorts into fix-now / fold-into-remaining-slices / disagree. No `-again` round-2 variants — a checkpoint is one-shot; you fix and continue.

**Review-aligned handoff** (`implementation-handoff`). When the implementer reports finished work to orient the reviewer, the report's sections mirror `review-implementation`'s evaluation axes — what/why, change map, key decisions, deviations, tests, where-to-look-hardest — so each thing the reviewer is about to assess is pre-loaded. It's a guided map, _not a self-review_: the implementer marks the riskiest/most-complex changes (shifting the framing burden to whoever knows the code best) but does **not** grade quality — that's the reviewer's job. It supersedes the thin `commits-summary` as the final review's context block, feeding `review-implementation`'s `$0` directly. The general principle: a report snippet should be shaped by the review snippet it feeds.

**Step back, then right-size** (`review-implementation`). The code-review lens guards two opposite failures. Tactical narrowing: accepting the implementation's framing and optimizing inside it — a local optimum — so the lens opens by demanding a step-back (would a new module or helper, a shared extraction, a redesigned contract, or different wiring dissolve the problem?) before any local fix is endorsed. Additive bias: improving by adding — defensive branches for impossible states, speculative abstraction, reflexively requested tests — so right-sizing flags over-building and a deletable test counts as a finding. The two aren't in tension; both push toward the design where complexity disappears. The settled-spec fence bounds the step-back: shape of the code, never approved decisions.

**Tests as a cross-cutting concern.** Test thinking isn't confined to the plan/TDD stage — it threads through the whole arc, each phase at its own altitude. Match the prompt to the phase: don't ask for test cases where they're intentionally deferred, and don't let them silently drop where they're due.

- **Spec** (`write-spec`, `review-spec`) — the **test standards**: name the behaviors that matter, and for each the strategy — through which interface, what gets faked at which boundary. Mocking is a *design* decision (a mock of your own module is a signal to fix the interface), so the boundary is settled here; the specific cases and fixtures are deferred. The spec skims the testing lessons' `## The bar` as a lens; it never writes an assertion, so `vitest.md` stays out of it.
- **Plan** (`tdd-plan`, `review-plan`) — test cases and fixtures are first-class and reviewable, against the standards the spec already set. This is where the testing lessons are read in full. Non-TDD plans (`start-plan`) still owe a verification story per phase.
- **Implementation review** (`review-implementation`, `implementation-handoff`) — test quality is an explicit evaluation axis and a reported section.
- **Responding to review** (`respond-review`) — a finding is a signal about test quality: diagnose coverage-gap vs. weak-test, then plan add / strengthen / delete. `review-implementation-again` then verifies those test changes actually held up.
- **Mid-point checkpoint** (`midpoint-status`, `review-midpoint`, `respond-midpoint`) — test state is surfaced for the completed slices, reviewed, and any fallout triaged into fix-now / fold-into-a-slice.

When adding or revising a snippet, ask whether its phase has a test angle and pitch it at that phase's altitude.

**Compaction is shaped by the next phase** (`compact-for-plan`, `compact-for-review`, `compact-for-cleanup`). Compaction snippets reset context at a stage boundary — they preserve the settled artifact and drop the journey that produced it. Each is tuned to what the _next_ phase consumes, so each keeps a different slice:

- `compact-for-plan` keeps the spec, architectural direction, and _why_ — planning builds on them — and drops brainstorming, cross-agent synthesis, and round-1 critiques.
- `compact-for-review` keeps the implementation status, the load-bearing mental model and critical files, and the decisions + _why_ — the reviewer will probe them — and drops the step-by-step build process.
- `compact-for-cleanup` keeps the finished code's state and the leftover task list — finishing builds on them — and drops the whole spec → plan → review journey.

The pair around the review boundary shows the principle sharply: `compact-for-review` _retains_ the decision rationale (you must defend it under review) that `compact-for-cleanup` _discards_ (finishing doesn't relitigate it). The load-bearing rule when adding another: preserve only what the work _after_ the compaction consumes; everything else is noise.

`compact-inflight` (standalone helper) is the cousin for a pause that _isn't_ a stage boundary — the same task continues immediately after, so there's no "next phase" to tune for. It keeps the work's live state (what's in progress, decisions made and why, live repo facts) instead of a settled artifact, but drops the journey the same way the boundary compacts do. Choosing rule: `compact-for-*` at a stage boundary, `compact-inflight` when the pause is mid-work.

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
