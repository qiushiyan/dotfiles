# Two harnesses, one canon

Findings from the 2026-07-26 side-by-side reading of the two agent-workflow
product lines — **greenflag** (`~/dev/greenflag`: the statechart-enforced,
semi-AFK orchestrator) and the **dispatch skills** (`~/dotfiles/claude`:
`review` / `consult` / `delegate` over `envoy`, the attended lightweight flow).
This doc is the maintainer's memory: what the two share, what must stay
different, and the queue of consolidation work with each item's fate. Read it
before editing either side's review/consult/delegate-shaped prompts; it is not
loaded into any agent context and never ships.

## The thesis

The skills trio is greenflag's protocol with the orchestrator promoted to the
host and the statechart replaced by the conversation. The prompt DNA is
demonstrably shared — several frames are near-verbatim twins (the step-back
sentence in `review/BRIEF-TEMPLATE.md` and greenflag's `review-implementation`;
delegate's "your judgment at the ends … labor in the middle" and relay's
economics line). The divergence concentrates in three places: who holds
judgment, which verification instruments each side developed, and prose drift
in the shared frames. So the synthesis is not an architecture merge — it is
reconciling a small set of named **moves** into one canonical home each, while
the products stay independent.

**The one hard constraint:** no shared runtime dependency, no merged snippet
library, no common config. The sync mechanism is the lessons corpus itself —
the skills read `~/.config/lessons/…` live; greenflag vendors a frozen snapshot
(`pnpm vendor-lessons`) it ships and re-syncs deliberately. Divergence between
the runtimes is always visible as a pending re-vendor, never an accident.

## The escalation ladder

Both product lines answer "how much harness does this work need", keyed on
presence and stakes:

1. **Bare Fable** — plan and implement in one attended session. The default.
2. **+ `/review`** — an independent cold reviewer on the committed work, when
   whoever wrote the code shouldn't be its only reviewer.
3. **+ `/consult`** — independent design takes before committing a direction,
   when the plan deserves adversarial pressure.
4. **+ `/delegate`** — a background session does the labor from a written spec;
   host judgment at the ends.
5. **greenflag** — the full statechart: walk-away/overnight runs, multi-phase
   ceremony, gate auditability, un-forgeable human authority.

Rungs 1–4 assume the human is present (the conversation is the gate); rung 5
exists for when they are not.

## Deliberate asymmetries — never "fix" one toward the other

Each of these is an opposite bet made for a reason, not incoherence:

| greenflag | skills | why they differ |
|---|---|---|
| Orchestrator does triage, **never substance** | The host **is the lead** — judges, fixes, synthesizes | Human absent → judgment must not hide in the router. Human present → the host's judgment is reviewed live in chat |
| Structural gates (statechart; no tool emits `human.*`) | The conversation is the gate | Authority must be un-forgeable only when nobody is watching |
| Consultant audits the bet (cross-family, low-context) | No bet-audit voice | A present human owns the bet themselves |
| Snippets adapted per-turn by the orchestrator | Briefs authored per-dispatch by the host from templates | Same discipline/generality split; different author |
| Lessons **vendored frozen** (`{{lessons_dir}}`) | Lessons read **live** (`~/.config/lessons/…`) | A mid-flight AFK run must be immune to dotfile edits; an attended dispatch wants the latest text |

## The shared moves — inventory and fates

The duplicated blocks found in the 2026-07-26 audit, each with its decided
fate. "Extract" = one lesson in `collaboration/`, both runtimes cite it.

| Move | Copies today | Fate |
|---|---|---|
| **Review lens** (step-back, additive-bias bar, right-sizing, Chesterton's fence, evidence-backed findings, artifact-not-account) | ~~5 copies~~ | **Done 2026-07-26** → [`collaboration/review-lens.md`](collaboration/review-lens.md). Consumers: greenflag `review-implementation`/`review-direct`/`review-and-fix`; both `review/` brief templates' posture; `delegate` step 5. Extended 2026-07-31 (artifact-vs-account, withheld-design) — **greenflag's vendored copy is stale until `pnpm vendor-lessons`** |
| **Settled-foundation fence** — direction decided, hunt execution defects; fatal flaws in decided items become marked foundational objections, never smuggled fixes | consult review mode, review brief, greenflag `review-spec`/`review-plan` | **Extract next** — but only after review-lens has live evidence (a few `/review` dispatches + one greenflag run) that the cite-a-stance pattern holds in dispatched behavior |
| **Handoff report** — the implementer's map: what/why, change map, key decisions, candid deviations, where-to-look-hardest; point, don't self-grade | delegate final-message contract, review step 2, greenflag `implementation-handoff`/`handoff-direct` | **Extract bundled** with the test-accounting port (below) — same lines, one pass |
| **Disposition ledger** — every finding ends adopted/fixed, rebutted-with-reason, or escalated; done when nothing lacks a verdict | consult step 4, review steps 5–6, greenflag `respond-review`/`apply-review`/`review-and-fix` | **Extract bundled** with the red-test-pinning port (below) |
| **Blind first round** — independent takes before anyone sees a proposal; synthesis that neither averages nor capitulates | consult design mode, review fresh-eyes mode (2026-07-31), greenflag `think-holistic`→`compare-notes` | **Probably no lesson** — greenflag enforces blindness structurally (parallel sends), so only the *why* is shared; at most a paragraph in the topic README. Note the dispatch side now blinds at two phases (design, then review), which greenflag has no equivalent of post-build |
| **First-principles grounding** — "an analysis that doesn't cite the files it stands on is guessing" | consult posture, `think-holistic` | **No lesson** — two sentences; a two-sentence lesson is a pass-through. Reconcile wording in place |

Consult is the biggest beneficiary of the queue: it holds an inlined copy of
four of the five remaining moves (review-lens touched none of it — code review
is the one move consult doesn't speak).

## The extraction recipe (proven on review-lens)

1. **Gather the twins**; per fragment, pick the sharper articulation (either
   side can win — additive bias came from the skills, the fixer's
   Chesterton clause from greenflag).
2. **Rulebook defect pass** (`/prompt-engineering`) before canonizing. The
   review-lens pass caught four: negation-as-lever → positive trigger with a
   skip condition; a missing skip condition on the headline rule;
   harness-specific vocabulary ("beyond the spec" → authority-neutral); an
   editor-facing note → model-facing orientation.
3. **Author the lesson** in house format: thesis → skimmable `## The bar` →
   short why-sections → `> _Lesson · …_` provenance. It carries the *stance*;
   severity ladders, output contracts, fences, and report routing stay in each
   harness's prompt (say so in the lesson's opening).
4. **Wire the consumers.** Skills: templates cite the live path. greenflag:
   add the topic to `scripts/vendor-lessons.mjs` `TOPICS`, `pnpm
   vendor-lessons`, snippets cite `{{lessons_dir}}/…` and keep only run
   wiring; `tests/snippets.test.ts` proves the citation resolves; parity pins
   move as a deliberate feature commit.
5. **Full suite green** before calling it done; update the indexes (topic
   README, greenflag `lessons/README.md`, `docs/snippets.md`).

## Instrument ports still queued (independent of lesson extraction)

Cross-product upgrades where one side built the better instrument:

- **Skills → greenflag: red-test pinning** (review skill step 5). A
  critical/moderate behavioral finding gets pinned with a test *before* any
  fix — red confirms, green over a genuinely-reaching test rebuts. Port into
  `respond-review` and especially relay's `review-and-fix`, where prose
  self-assessment is weakest.
- **Skills → greenflag: test accounting** (delegate report §6). Every test
  file touched → the command that ran it, or an explicit not-run-with-reason.
  Port into `implementation-handoff`/`handoff-direct`; worth more under AFK
  than it is in the attended flow that invented it.
- **greenflag → skills: pre-registered acceptance assertions.** The skills
  flow has no artifact linking design-time intent to review-time verification.
  When consult settles a design, author 3–5 falsifiable assertions then
  (elicitation triad from `consultant-contract`: pre-mortem,
  definition-of-wrong, red-team-the-tests); the review/delegate collection
  verifies them by *running the system*, not reading the diff.
- **Trivial: severity-wording drift** — "blocks merge" vs "blocks ship" per
  copy; unify opportunistically.

## Direction note

Both products move the same way the Claude 5-era guidance points: fewer rules,
more judgment, progressive disclosure, high-signal positive steering. The
keep-list is the named elicitation frameworks (pre-mortem, design-it-twice,
step-back, Delphi) — those are the tokens that earn their place. greenflag's
pre-Fable prose-heavy snippets are the diet candidates, but any diet runs
through its own eval loop (run notes, parity pins, corpus replay), never a
blind slash.

---

> _Findings doc · 2026-07-26 session (greenflag repo, Fable 5). Evidence:
> obelisk scan of live consult/delegate usage across itell, loopy,
> duet/greenflag, envoy (2026-07); the twin-prose citations above are readable
> side-by-side in the two repos' git history at this date._
