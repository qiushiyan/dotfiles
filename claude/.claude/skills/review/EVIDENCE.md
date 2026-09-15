# review + consult — evidence log

One entry per mining pass over the sessions that ran these skills; counts are
written so the next pass can re-run them. The two skills share a log because
their briefs, dispatch, and reports are one workflow.

## 2026-09-14 — the modes, the briefs, and the report

Session `cecd2be9`; ledger `review-consult-frictions.md` in its scratchpad
(predicates, receipts, saved query results `r1.json` … `r9.json`). The
2026-09-12 pass (session `4c5605d8`) covered dispatch mechanics and shipped
envoy 0.6.0; this pass covered what the briefs carry and what comes back.

**Corpus.** Invocation = user row, not meta, not sidechain, not a continuation
summary, carrying `<command-name>/review</command-name>` (or `/consult`) or
the SKILL.md path. Claude-hosted: review 335 invocations / 255 sessions
(2026-07-08 → 09-14), consult 250 / 214 (07-04 → 09-14). Codex-hosted since
08-18 (`source='codex'`, `$review`/`$consult` or the path, brief titles
excluded): review 4 rows / 3 sessions, consult 5 / 4 — the first query
excluded these and the consult voice caught it. Mode word = regex over the
args (quick `\bquick\b|快速|小改`, goal `\bgoal\b|\bgold\b`, full
`\bfull\b|\bful\b`). Steward-driven invocations excluded (4). Briefs read: 5
review and 11 consult briefs surviving in scratchpads (09-11 → 09-14) and
every `prompt.md`/`result.md` under `~/.local/state/envoy/jobs` (11 projects).

| finding | evidence and limits | verdict / layer |
|---|---|---|
| `quick` unused after its launch week | 7 human-typed asks, 6 in 08-18 → 08-22; one assistant-selected use since (`codex:01a09f78…`, job `itell-b8fe3e69/pr313-review-r1`, 09-14). The user's 08-18 ask (`8b472a5b`) that even quick check whether green means anything is the lens it uniquely carried. | retired; the revert-test lens moved into full's Evaluate and, scoped, into goal's. Instructions. |
| `goal` used as the default cold read, not the closing read it was designed as | 51 goal rounds / 46 sessions since 08-18; 31 with no prior review dispatch. Hosts filled the mandatory covered-ground section with consults, bots and suites (`d091b53c`, `89db4c19` briefs). Six host reports read: every one a "partly landed" verdict with 1–3 verified, fixed findings; no user pushback in the next turn. Quality claim rests on those six; no paired comparison with full. | goal is the cheap independent read before or after rounds; "already judged" replaces covered ground, may say "nothing", records what was examined and confers no immunity. Instructions. |
| full and goal feel the same to the user | the host's verify → fix → report loop is identical; the briefs differ in what they hand over (report and fence vs the goal alone) and in cost (full: warm + cold, 60 min, round 2 in 3 of 5 jobs since 09-12; goal: one cold voice, 45 min). The "compaction ate the mode" case (`4b65a508`) was a user re-ask (`32be242d`), withdrawn. | two modes named by what the reviewer is handed; fresh-eyes' structural lens folded into goal as a switch (`main-ca6ae1ca/review-r1` found a structural critical over 410 green tests); full always hands over the report, fence deleted when nothing outside the session settled the design. |
| consult approach briefs proposal- and probe-heavy; the "real problem" opener is ceremony | 11 briefs: 1,769–3,263 words, proposals 200–1,019 words, 6–12 numbered probes in 9 of 9 approach briefs; voices answered in order (`0b095280` r1: 8 findings ↔ 8 probes); 7 of 7 stored results open "matches your framing", 2 with a "but" the host adopted. Counter-evidence for deleting probes: `d3ce3d35` 09-10, probe 1's three-point trace overturned the host's split and the user authorized implementation two minutes after the synthesis (`8417c2ec…`, `5ad50738…`). The user asked for goal-led briefs in 5 sessions (`2db6f3a9`, `e949674d`, `abd24d95`, `4c5605d8`, `d091b53c`). | approach brief reordered: goal → constraints → reading → the voice's sketch → our position as one paragraph → areas of doubt with the few probes that can falsify; sketch-first labeled a sequencing experiment, withholding for round 2 where independence matters. Instructions. |
| syntheses and reports hand the user technical dispositions, not the decision | three expanded cases where the next user turn was the re-present snippet (`89db4c19` `deeddeef…` "Your two earlier questions stand as before"; `427df3ec` `b0f8ea75…`; `f2010548` `cf7dc567…`). 27 snippet fires in 24 of 158 sessions overall; the right denominator is reports that asked for a decision. Ranked first by the consult voice; adopted. | consult step 7 and review step 8 lead with each decision standalone in product terms, then the dispositions. Instructions. |
| the ask is stock | "codex full review" ×36, "codex goal review" ×25 in September; 150 of 250 consult asks are "agree with the direction, settle the final approach". No correction names the ask shape. | one sentence in review step 2 on what a good ask carries; the host says the pick back before writing. Instructions. |

**Consult round.** `consult-r1/codex` (job `dotfiles-4f711dad/consult-r1`,
6 min, `--allow-write` so it could query the index); brief written in the
reordered shape. Its own read was frozen before it opened the ledger. It
corrected three receipts (above), reframed the priority (report first,
probes kept where they falsify, sketch-first as an experiment), and raised
one foundational objection accepted as a reframing: nothing in the corpus
predicts a smooth implementation; authorization measures readiness to
proceed (`steward-context-usage/review-r2` said "achieved" and the user later
could not find the figure, `9544e522…`; the one-activation rollout hit a
cross-PR collision no suite ran, `e3f0fca8…`).

**Changed.** `review/SKILL.md` (two modes, ask sentence, unpinned-behaviour
verification, report contract), `review/GOAL-BRIEF.md` (already judged,
scoped revert test, structural switch, output), `review/BRIEF-TEMPLATE.md`
(fence deletable, blast radius and revert test absorbed), `QUICK-BRIEF.md` and
`FRESH-EYES-BRIEF.md` deleted, `consult/APPROACH-BRIEF.md` (reordered),
`consult/SKILL.md` (steps 2, 6, 7). Steward: planlab branch
`chore/steward-review-mode-string`, dispatch string `full, one round`, tests
green (21/21). Deferred: `docs/steward/skills.md`, `envoy/DESIGN.md`, the
provenance notes in `lessons/collaboration/review-lens.md` and `SYNTHESIS.md`.

**Next comparison.** Windows after this change. Review: mode distribution;
goal briefs whose "already judged" says "nothing" when nothing ran; the user's
next turn after a goal report (authorization vs re-present). Consult: rounds
where the voice's sketch differs from the host's position (today the opener
differs in 2 of 7); probe count per brief (today 6–12); brief words (today
1,769–3,263); deltas the host adopts per round. Follow the chain rather than
the brief: the user's stated outcome survives into the brief; a finding
changes a decision or catches a verified defect; the host explains the
remaining choices without a re-present request; later implementation or use,
in any session, reveals nothing the round should have caught. Classify extra
rounds by cause — a returned falsifier or a planned spec round is not failed
convergence. Revise if goal rounds start returning line-level defect lists,
if consult sketches never differ from the position, or if reports grow a
decision preamble the user skips.

**Validation.** Two cold readers on the revised files, one per route, before
commit. Goal route (`/review codex goal review` after a consult, no review
round): stalled on the consult line under "already judged" handing over the
design a consult settled; found the drift bullet assuming rounds ran and step
6 applying fixes before the report that authorizes them. All three fixed.
Left as is: the full-only fan-out prose that a goal round reads past, and no
`argument-hint`. Consult route (`/consult agreeing with the general
direction, settle the final approach with codex`): found the withhold trigger
stated three ways, no precedence for user-endorsed session analysis under the
fence rule, the design-twice bar colliding with the sketch block, the planned
test case with no spec to live in, a stale trigger count, and probe guidance
duplicated between step 2 and the template. All six fixed; step 6 is the one
home of the withhold trigger. Both readers verified the envoy commands against
the CLI source. This is a read-only scenario check; no round has yet run on
the revised briefs, and the outcome measures above remain pending.

**First round on the revised briefs** (`dotfiles-4f711dad/review-r1`, goal
mode, one cold Codex voice, 2 min, range `251730b..d3feee3`). Verdict
"partly": short asks route and both report contracts hand over decisions;
independence broke on one route. Confirmed and fixed: the approach brief
listed the artifact under review in the reading list, so "consult this spec"
exposed the proposal before the sketch (the artifact now lives under "What
we propose", opened after the sketch); the goal brief's empty-history example
asserted a green suite nothing had run (a check joins the section only from
a run on record); the design doc repeated measurements the evidence log
owns. Unpinned, and the next pass's first measures: unattended completion
from a Codex host, a generated brief in which the user's goal survives and
the sketch precedes the proposal, a synthesis whose claims were verified and
whose decisions read standalone, and the consult-to-review handoff. This
round exercised the goal brief itself: the reviewer wrote its expectation
first, judged at altitude, and returned no line-level ladder.

## 2026-09-15 — tenets for the rest of a build

**Request.** The user asks a voice for "high level design and guidelines",
"tenets, principles, or guidelines for implementing the rest", and gets
implementation tips back. Asked what the industry calls the thing wanted,
and at which layer the fix belongs.

**Corpus and predicates.** Obelisk, user turns (`role='user'`,
`source='claude'`, non-meta), 2026-07-15..09-15; codex|consult|second
opinion AND advice|guidance|guideline|principle|suggestion|high-level →
220 turns / 171 sessions, nearly all briefs, cold-reader prompts, and the
`implement-spec` boilerplate. Hand-classified two independent verbatim asks,
both 2026-09-15: `b0b522b9/c3daa065` ("settle down the high level approaches
and important guidelines … phase 2 and 3") and `8e4901ad/bf5282ee` ("high
level design and guidelines for implement this"). Snippet uses:
`review-midpoint` 13 (12 Codex pastes, 2026-06-06..07-07, none since),
`respond-midpoint` 5 (..07-07), `midpoint-status` 1 (07-31).

**Observed.** The M3 brief (`consult-r3-brief.md`) asked for "the short list
a build session should hold to … each one line with the file or seam it
protects"; its own list was "real Postgres for anything that takes a lock;
harness fixtures always carry `authority` and `origin`". Codex returned ten
lines, about seven file-level. The run-state brief (`consult-r1-brief.md`)
asked for "seams touched, the invariants that must survive, the order of
slices, the tests"; Codex returned mechanics, Opus returned a seven-item
"Invariants that must survive" section, the only output matching the ask,
and only because the item happened to name the word. Neither round drew a
correction; the friction is the user's report plus the brief wording. The
retired `review-midpoint` snippet asked for "Tips" by name.

**Cause.** Instruction layer. No brief defined what a guideline is, so host
and voice wrote at the altitude the rest of the brief works at. The
milestone review had no home in the review skill after the snippet family
went dormant. Guidance returned into the conversation had no pinned home;
`compact-for-impl` preserves "the invariants the build must hold" but
nothing upstream produced them.

**Vocabulary (web, 2026-09-15).** Amazon *tenets* (take a stand, present
tense, seven at most, "unless you know better ones"); architecturally
significant decisions ("hard to make and costly to change"); Kaufman's
"accidentally load bearing" as the selection test; "guardrails" means
enforced policy in platform engineering, which is why asking for them buys
rules; arXiv 2606.22528 "Governance Decay": constraints in context obeyed at
0% violation, 30% after compaction (59% on some models), 0% when the
constraint survives the summary. Rejected "invariant" as the headline word
at the user's request; kept it inside the lesson where it is the CS term.

**Changed.** `lessons/collaboration/tenets.md` (new: the bar, tenet-or-tip
pair, provenance) and its README row. `review/BRIEF-TEMPLATE.md`: the
rest-of-the-build bullet under Evaluate and its output item, both a switch.
`review/SKILL.md`: the switch in step 3's scoping list; step 6 writes
surviving tenets into the spec beside its phases. `tabtype`: `review-midpoint`
and `respond-midpoint` deleted; `DESIGN.md` and `WORKFLOW.md` route the
milestone round to `/review`. Not changed: `consult/APPROACH-BRIEF.md`, the
user's open decision; `midpoint-status`, left with no skill consumer.

**Next comparison.** The first full round on a milestone with the switch
kept, starting with `feat/pipe-panel-source-and-spawn-sink` milestone 1.
Measures: the tenets section's count (seven or fewer), file names in it
(zero), whether each item names a reason, and whether the host wrote them
into the spec in the fix commit. Success is a later phase in that session,
or the next session after a compaction, citing a tenet at a decision the
spec did not cover. Revise if the section returns file-level rules again
(then the lesson's test is not doing the work and the brief needs the
tenet-or-tip pair inline), or if the host skips the spec write.

**Validation.** One cold reader on the revised template and skill, milestone
scenario on the pipe-panel worktree, read-only, before commit. It picked
full mode, kept the switch, and confirmed nothing would lead a reviewer to
file-level rules under the tenets heading. Four defects, all fixed: the
judge pass had no verdict class for tenets (step 5 now judges them by the
lesson's bar and demotes failures to findings); the first milestone had no
route because the template assumed a tenet set already existed (the set
written is the first, and step 6 names the `## Tenets` heading and the
no-fix commit case); the step-8 report contract omitted the tenets; the
switch was stated in three places (the template comment cut). Also
generalised the lesson's avoid example away from the module under review.
No round has run on the revised brief; the outcome measures above are
pending.
