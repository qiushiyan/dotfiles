# write-spec — evidence log

The dated entries below are the passes in order: what was mined, what was
found, what changed and how it was checked. This changelog is the short
form, one line per change with the principle behind it, for a reader who
wants the shape of the skill's history before the receipts.

## Changelog

- **2026-08-31 — founded from the snippet family.** The hand-typed
  preamble and the post-spec choreography (commit, validation consult,
  compact) became the skill; the "adapt and simplify" licence stayed in
  the body. Principle: a workflow the user retypes every time is a skill
  waiting to be written.
- **2026-09-18 — the spec as a measured procedure.** Step 1 settles the
  unknowns the design turns on by running them (source read, existing
  test, production read, thin spike, thirty minutes each) instead of
  deferring them to a build phase; the bar took five authorities (Intent,
  Behaviour, Design, Verification, Delivery), a labelled summary block for
  re-grounding after compaction, premises that separate a decision from
  its basis, situations with today/after/mechanism/recurrence, and an
  Opus cold reader that reports what a model with no conversation cannot
  reconstruct. Reports present open decisions as bets with costs.
  Principle: the spec is read by two models that hold none of the
  conversation, so it must carry its evidence and its vocabulary, and the
  journey stays out.
- **2026-09-18, later — the bar owns the shape.** Project convention
  decides placement, front matter and index rows; headings, order and
  prose are the bar's, and sibling specs are not a convention. Both checks
  run at once; a re-read inherits the resolved-term list and the changed
  sections. Principle: a rule loses to an example the model has been
  reading all morning, so the example set must be the bar's own.
- **2026-09-21 — formats that make the gap visible.** From five builds:
  `Today:`/`After:` lines in Wiring, a state table with entry and exit
  rules, a held-by line on every tenet, responsibility-first Structure,
  numbered obligations, requirements rather than verbatim text for
  anything a model or judge reads, revision by replacement; two scripts
  for references and statistics; the pickup gate re-reads `Today:` lines;
  As built assembled from commits. Principle: wrong claims about existing
  code are inevitable, so the format types each sentence as observation,
  design or assumption and the build re-checks the observations cheaply;
  a missing state or an unheld invariant is made visible by an empty cell
  or an empty line rather than forbidden by a rule.

Held constant through every pass: the premises section, the summary
block, the situations and the ordered delivery, which carried every
unattended build; and the evidence standard, that a change ships with the
sessions that motivated it and the measures that would reverse it.

## 2026-08-31 — founding pass (improve-tool over the snippet family)

Corpus: obelisk index through 2026-08-31; signatures = each snippet's
distinctive phrase in user text (`%wherever this project conventionally
keeps specs%` for write-spec). A codex consult
(`~/.local/state/envoy/jobs/dotfiles-4f711dad/20260831-231951-consult`)
independently re-ran the mining; its corrections are folded in below.

Usage shape:

| snippet | msgs / sessions | window |
|---|---|---|
| write-spec (current text) | 33 / 29 | 08-06 → 08-30 |
| compact-for-impl | 46 / 20 | 08-06 → 08-30 |
| update-spec | 33 / 15 | died 07-07 |
| review-spec-again | 20 / 11 | died 07-03 |
| update-spec-again | 12 / 9 | died 07-07 |
| review-spec | 2 / 2 | died 06-25 |
| compact-for-plan | 1 / 1 | 07-03, once |

Frictions and verdicts:

- **F1 — hand-typed preamble, 33/33 invocations** ("general mindset below,
  adapt as you see fit"). Verdict: this skill; the adapt/simplify license is
  standing in the body.
- **F2 — post-spec choreography manual.** Riders: commit 5/33, bundled
  validation consult 5/33, validation consult as the next turn 5/33
  (codex counts); immediate `/compact` next in 17/17. Rider sessions
  executed fully without further prompting (6–12 envoy calls, e.g.
  361f63c6, 8c728f33). Verdict (user): **commit + validation consult
  hardcoded as defaults**, free-text arguments override; the consult is
  warm (continuing the session's prior consult, 26/29 sessions had one) or
  fresh (3/29 had none); **no compaction instructions** — stage transitions
  are the user's, never the skill's; the skill never dispatches envoy
  directly — it invokes `/consult`.
- **F3 — dead limbs.** Round-2 snippet chain superseded by `/consult` since
  early July; compact-for-plan dead (the plan stage collapsed into the
  spec). Verdict: deleted review-spec, update-spec, review-spec-again,
  update-spec-again, compact-for-plan from the tabtype config; the
  write-spec snippet **kept** as the paste-in escape hatch; doc-loop.md's
  stale plan-stage language replaced.
- **F4 — per-project riders** (issue-first 5/4, branch handling 4/3,
  cross-repo ordering, standards riders 3/3). Verdict: outside the skill —
  free-text arguments and project workflows own them. Spec-location
  detection already works (20/20 recent specs in the conventional dir); the
  skill spends one line on it plus a read of documentation-standards.md
  when present.
- **PR boundaries** (user vision + codex-refined): pushback toward one PR
  in 8 msgs / 6 sessions (9b313950, 2ef842f1, f10869c8, 024a9e0e,
  42ebd772, fcf7bce5). Doctrine: one PR **and one session** by default;
  phases across ≤2 sessions on one branch as the rare escalation (PlanChat
  exemplar, 2ef842f1 → f4d85b55); multiple PRs only when every intermediate
  PR is independently correct *and* a concrete constraint benefits from the
  seam (cross-repo receipt: 95c0ad90). Landed as
  `lessons/collaboration/pr-boundaries.md`; reach is the skill's Scope
  pointer only, by user decision — see re-measure below.
- **Emphasis heuristics** (user vision, codex-reframed): the axis is where
  the change's load-bearing novelty lives, with refactor → structure/API
  and feature → product as worked examples, explicitly inspirations rather
  than a taxonomy (receipt for the refactor example: PlanChat round-2 rider
  "naming and model structures are very important", 2ef842f1).

Non-frictions (measured): spec quality — corrections after write-spec are
substantive design steering, not process repairs; a spec-shortfall sweep in
implementing sessions came back near-empty. Specs are read by 3–7 later
sessions each (top: durable-steer-inbox 7s/12r).

Consult findings adopted: spike-before-spec ordering (a blocking technical
unknown stops the skill, step 1); "validation consult" naming (round-2
collided with /consult's own resume semantics); spec-only staging, revision
commit only on change, report path/SHAs/out-dir; SPEC-BAR.md split
(261-line body buried the hot path); the two-condition multi-PR rule; the
vocabulary fix (domain/interface naming is the spec's, call-site rename
inventories are not). Rejected: widening the lesson's reach to consult and
exploration surfaces — kept at the Scope pointer per user decision.

Cold readers (two routes: warm consult + rider; fresh + "don't commit"):
both stalled at step 4's warm branch — no route to resume mechanics, and
/consult's round-2 trigger list didn't sanction spec validation. Fixed by a
pointer to /consult step 6 + a fourth-trigger line added there, a decidable
branch condition (out-dir in reach), a fall-through when the set can't
resume, and the override-cascade sentence ("don't commit" carries into
validation reading uncommitted files). SPEC-BAR's reading list now scales
to the novelty; its design-it-twice procedure deduped to the lesson it
already cites. Deliberate keeps, flagged by readers but kept on purpose:
the Emphasis closing note (user-mandated independent-thinking echo of the
opening license); the Scope section's in-line two-condition rule (the spec
author needs it without a file hop; the lesson adds why + exemplar); the
frontmatter defaults line (human-facing gallery text); the vague-verbs
enumeration (trigger vocabulary).

Goal review (codex, cold, out-dir 20260831-235200-review): verdict
"partly" — the phase runs end to end, but SKILL step 2's follow-the-project
convention and SPEC-BAR's own anatomy had no precedence. Fixed: convention
governs names/order/format, SPEC-BAR governs decisions and doneness, its
layout the fallback. Also trimmed on its findings: the interview recipe's
clustering/anatomy scripting (batch discipline kept), the generic
form-submission tree (the prose and the structure/API sketch carry the
pattern). Escalated, recommended keep: rebuilding SPEC-BAR as an outcome
rubric instead of a document anatomy — the anatomy is the user's measured
formula; revisit only if specs come back formally complete but
over-sectioned. The first-party doctrine behind the objection, a sketch of
the rubric variant, and the switch/hold evidence bar are researched in
`RESEARCH-goal-driven-specs.md` (2026-09-01): verdict hold-until-trigger,
then migrate by deletion-with-evals.

## 2026-09-01 — first consumer (itell platform, c6dd7939)

`/write-spec "…lets now write the spec"` ran the whole phase in 17 minutes
with zero corrective user turns: read SPEC-BAR and the project's
documentation-standards.md, settled its one blocking unknown by reading
Payload source (no interview needed — correct skip; no spike needed —
reading sufficed), wrote and committed the spec alone, took the **warm
branch correctly** (resumed the session's codex consult as round 2, label
consult-r2, 10 findings, none foundational), committed the revision
separately, and reported path + SHAs + what settled. The manual
choreography this skill replaced ran 3–4 user turns; here it was one.

Friction, fixed: **none of the six SPEC-BAR lessons were read**, on a
change with real design shape (a read-policy layer, a discriminated result
type). The goal-review reword ("scale the reading to where the novelty
lives") scaled to zero on its first run. User verdict (2026-09-01, stated
as conviction, not measurement): normal runs should read most of the
lessons; trimming is the exception. Reading-list intro reworded to make
reading the default. Next pass still counts lesson read-rate — now to
check the strengthened wording lands, and whether the lessons measurably
earn it.

Re-measure next pass: does the default choreography hold without riders;
warm-vs-fresh consult branch taken correctly; do split proposals persist in
consult rounds (if so, escalate the lesson pointer into /consult's brief
guidance); snippet-vs-skill door counts; sessions-per-PR against the ≤2
default.

## 2026-09-18 — second pass (improve-tool; spec quality and the writing bar)

Corpus: obelisk index through 2026-09-17. Invocation predicate: a user
message carrying `<command-name>/write-spec</command-name>`, or the two
by-path forms, from 2026-08-31; sidechains and the session itself excluded.
Population 44 sessions; 6 steward-eval worktrees set aside; 38 human runs.
Spec sample: 48 unique specs across develop and the worktrees; 36 recoverable
at their first commit before any as-built edit (`git log --all`, first
version without an as-built mark). Query and results: the session
scratchpad (`75e316e5…`), ledger `write-spec-frictions.md`.

What held from the founding pass: commit + validation consult ran unprompted
in 36/38; the warm consult branch was taken whenever a prior consult existed
(34/38); a lesson was read in 35/38 runs, mostly head-of-file or the bar
sections (the 09-01 reword landed); the interview fired once, correctly;
the snippet door had 0 uses. The post-report ritual (`/compact`, then
"reread the settled spec … implement end to end") appeared in ~25/38 and
stays the user's.

Frictions and verdicts:

- **Open decisions not decidable from the report** — 4 sessions
  (81ba94fc 09-02, 4b65a508 09-14, 75b26ed1 09-16, daac7f82 09-17): "can
  you elaborate the trade-off in plain terms? what bet is it relying on?".
  Verdict: SKILL step 5 now carries the decision form (experience per
  option, the bet, the cost if wrong, recommendation, what waits) with a
  worked example lifted from the 09-17 run.
- **Report scheduled the build into another session** — 3 sessions
  (5cd2512a, ff69f762, 37865012). User verdict: not the skill's; those
  sessions began from a spec-focused brief on a `spec/` branch. Dropped.
- **Branch already carrying a spec** — 4 branches, three handlings. User
  verdict: rare; named by hand. Dropped.
- **The specs themselves** (user's priority). First-commit medians: 3,885
  words (p75 4.8k, max 10.4k); summary 418 words; 27 words per sentence,
  18% of sentences over 40 words; journey sections (consult settled, the
  cut, owner decisions, review record) in 31 of 36 at ~5% each. Read
  closely: corpus-reuse (3.6k), authored-artifact-integrity (5.4k), card-ux
  (5.0k), runaway-output (5.5k). Defects verified by reading, not counting:
  a rule stated three ways that drifted (card focus, lines 194/430/556 of
  its first commit); a target shape that could not represent two legal
  states the build had to add; a summary promising a bound the spec's own
  Phase 0 still had to measure; fixtures prescribed from a database the
  build could not reach; an owner assigned a check whose dependency it
  could not import. Build departures (89db4c19, 0b095280, ca31201d,
  952764c4) split into changed realizations and unbuilt commitments listed
  together. No build in the corpus stalled on a spec gap; user turns during
  builds were next-stage commands.
- **Documentation-standards read** — 33/38 runs read the 2,170-word
  project file because step 2 asked. None of its spec-relevant rules were
  in SPEC-BAR. Verdict: six rules absorbed at their homes; step 2 reads the
  specs README and the project bindings only.

Consults (codex, warm chain `dotfiles-4f711dad/consult-r1b` → `consult-r2`
→ `consult-r3`; sketches not blind, the position was in each brief).
Adopted: keep the anatomy; readiness over artifact (design-changing
unknowns settled inside the run, 30 min per question, `/spike` where
reading cannot settle it); decision status split from basis and outstanding
verification, with a local evidence block beside each consequential
premise; one home per rule with derived views allowed; situations including
"if it recurs"; owners must reach their dependencies; behaviours bind,
names are sketches, realizations reported apart from unbuilt commitments;
open questions only for unresolved choices with owner and build dependency;
the cold comprehension check as a resolution task with inspectable output.
Corrected by the voice: the first length baseline was inflated by as-built
edits (5.3k → 3.9k median); shortening demoted from headline to one repair.
Rejected: cutting the Tenets section (`/consult` step 5 writes there).

User decisions: cold read by an Opus subagent (cheaper than the Fable
primary), hard-coded; summary as complete short sentences one per line, not
fragments (the Fable prompting guide's brevity and re-grounding text, over
the "sacrifice grammar" line); Tenets kept for cross-cutting invariants;
full set of forms with positive examples and one avoid case.

Web research (scratchpad `research-notes.md`): first-party guidance on
specs (self-contained, files and interfaces named, out of scope stated,
end-to-end verification) and on brevity by selection not fragments;
spec-kit's clarify (question + why it matters + recommended option) and
analyze (terminology drift and duplication as a severity table) shaped the
open-question, report and cold-read forms; MADR's Confirmation slot became
"outstanding verification"; the ubiquitous-language pattern and a measured
telegraphic-compression result informed the shorthand mechanism and the
summary's sentence form.

Changes: SKILL.md rewritten (procedure settles unknowns; step 2 reads
project bindings; step 4 cold read then validation; step 5 decision form;
Emphasis compressed); SPEC-BAR.md rewritten around the reader contract,
five authorities, the forms with examples, writing rules, readiness;
COLD-READ.md added (the subagent prompt). Example numbers verified against
the source spec's § Evidence; a reproduction path invented in the first
draft was replaced by an honest "not retained" line.

Validation: a warm review (structure, semantics) and a cold codex review
(prompt quality against the rulebook), jobs `dotfiles-4f711dad/spec-skill-review-r1`
and `-r2`. Round 1: both "ship after fixes". Fixed on their findings: the
premise examples taught closure without evidence (date, revision and a
design-preserving fallback added; the "outstanding then settled" line and
the failed-spike duplicate cut); the Design example spliced two domains
and dropped the selection payload (now one domain, payload restored);
the summary collapsed worker death into run death and named a risk without
its guard; step 4's re-entry after validation and the final-revision cold
read were missing; "two cold readers" overstated a resumed consult; Tenets
placement conflicted with `/consult` step 5 (both now say one section where
the spec bar places it, struck-tenet reasons in the synthesis); the report
example never introduced its terms; COLD-READ's example sat outside the
dispatched block; the finding form forced invented alternatives. Round 2:
remaining items were scoped claims in examples (a fallback with no basis,
"nothing can fail a send", "in the kernel", reachability as an import) and
the journey-exclusion sentence the first cut had removed; all applied.
Deliberate keeps: the reproduction line that says the command was not
retained (the form must show how missing provenance is marked); the
Structure writing rule the cold reviewer called doctrine (one of the six
rules the user asked to absorb); SPEC-BAR at ~2.5k words rather than the
reviewer's 20% cut, by the user's choice of the full example set. Not
tested: a live run of the rewritten skill; the cold-read subagent on a real
spec.

Re-measure next pass, over runs after this change ships, against the
baselines above: missing states or behaviours discovered during build or
review; commitments unmet at the first build report; departures split by
kind; unresolved terms returned by the cold read and how many survived to
the build; clarification turns per open decision presented; spec length
and summary length at first commit; whether design-changing checks ran
inside the run (tests, production reads, spikes in the window) instead of
landing as a Phase 0; documentation-standards reads (expect ~0).
Revision or reversal if: runs stall inside the 30-minute boxes without a
decision; the cold read returns mostly false ambiguity; or specs grow past
the current medians with no fall in build-side discoveries.

## 2026-09-18 — first two runs of the rewritten skill

Corpus: the two `/write-spec` runs after commit `8131715` shipped, both on
2026-09-18, both Fable sessions with Opus cold readers: `cc8ba647` (loopy-os
M4 OPC slice, `docs/loopy/specs/loopy-os/23-…`, five commits) and `51310e66`
(coordinator loop gauge, `docs/loopy/infra/specs/2026-09-18-…`, three
commits). Neither has been built yet; this pass measures the spec and the
procedure only. Predicates: the session jsonl (skill text markers, Agent
dispatches with `model`, envoy runs, commits) and the subagent transcripts
under each session's directory (turns, tool calls, usage).

What held: both sessions read SPEC-BAR and COLD-READ at step 2, dispatched
the cold-read block verbatim to Opus, ran the first cold read in parallel
with the warm validation consult, and reported in the step-5 form (the OPC
report carried three decisions with bet, cost and what waits; the gauge
report said nothing was open). The gauge run settled premises in-run with
three scratchpad scripts, a production CloudWatch read, the package test
suite and `tofu validate`, and moved one assumed premise to measured when
the validator asked. The cold reads returned real gaps (two deadline
definitions, a double start at a hand-off, switch-gated hygiene stranding
rows, a ceiling documented as 24 against a release of 64, an existing host
sampler the spec had not mentioned) and listed the coined loopy-os
vocabulary as resolved from the tree docs, so the shorthand check works.
`/spike` was not invoked; the scripts were written directly, same outcome.

What did not hold: prose form. Gauge 5,758 words, mean 33.5 words per
sentence, 26% over 40; OPC 9,621 words, mean 47.1, 40% over 40, longest
paragraph 655 words — the worst profile in the corpus, against a v0 median
of 3,885 words. The OPC spec has no labelled summary block and its status
paragraph names consult rounds and finding counts; the gauge spec ends on a
Consult dispositions section. Cause, from the OPC transcript: SKILL step 2
let project convention govern "format", and the loopy-os siblings (written
under the old bar) supplied a prose summary and a journey paragraph the
model copied. The writing rules lost to the sibling attractor.

Cost: each cold read was 51–79 Opus turns, 30–45 shell calls walking the
docs tree, 26–40k output tokens, 6–9.5 minutes. The first pass overlapped
the consult; the serial re-reads cost 15 min (OPC, two re-reads) and 10 min
(gauge, one). Re-reads re-resolved the same terms from zero. The write-spec
phase was 38 and 28 minutes of sessions lasting 3h17 and 1h45.

Changes: SKILL step 2 — the spec is written to SPEC-BAR; the project
decides placement, front matter or status header, index row, and sections
a written project rule requires; headings, order and prose are the bar's;
existing specs are not a convention (user's call: the loopy-os siblings are
the old skill's output, not a standard). SPEC-BAR's shape says the same. SKILL step 4 — both checks
dispatched at once, one revision; a re-read carries the previous reader's
resolved-term list and the changed sections, reconstruction blind; the
arrow chains and the bold emphasis removed. COLD-READ — two re-read inputs;
resolve from the spec's cited documents first, docs root only for what
they leave open; resolved terms as a bare list; the reconstruction kept to
what the corrections need. SPEC-BAR — the block sits under the project's
summary heading; one topic per paragraph with its reason; "strip the
journey" echoed in Before you finish, naming the opening as its home.
Description names the cold read. doc-loop.md's line updated.

Validation: one Opus cold reader with five route scenarios (both checks
dispatched together; re-read inputs and what stays blind; the sibling-prose
directory; "skip the checks"; an unmeasurable gate premise) resolved each
as intended and flagged four wording defects: Tenets described both inside
Intent and as a sibling section (fixed: a sibling, the project clause
dropped); "the committed spec" against the "don't commit" override (fixed:
"the spec as it stands"); a validation "round" named as a regression's
provenance against the journey rule (fixed); the thirty-minute box not
observable by the agent (kept: the user's chosen bound, a heuristic).

Deliberate keeps: the "adapt and simplify" licence (F1 of the first pass);
the thirty-minute box as a heuristic rather than a measured clock;
the `never`-free boundary at the end of the cold-read block (a reader would
otherwise read code); the five-input block for first reads, where the two
re-read lines carry "none".

Re-measure next pass: sentence and paragraph profile of the next specs in
the loopy-os tree specifically (the sibling attractor is strongest there);
presence of the block under the tree's `## Summary`; journey text in status
paragraphs; re-read duration and shell-call count against 30–45; whether
re-reads still find cross-section contradictions after the delta scope
(reversal condition: a build-side discovery the narrowed re-read would
have caught); build-side departures and missing states on these two
branches once built.

### Third run, same day — the PDF callback spec (`f078881d`)

Loaded the intermediate text (both checks at once, re-read inputs, the
paragraph rule and the journey echo; not yet the "existing specs are not a
convention" line). Tree: `docs/loopy/specs/`, not loopy-os. Spec
`2026-09-18-pdf-callback-uploads-outside-the-proxy.md`, three commits,
3,844 → 5,741 words; the growth is design the validation forced (finite
ceilings, header authentication, the wire change split into a second PR),
not journey: zero mentions of consult, round or cold read in the spec.
Labelled block under `## Summary`, 17 lines; mean 23.9 words per sentence,
10.9% over 40, the best profile in the corpus. Situations, premises with
basis and "does not establish", rejected shapes with their constraint, a
complete failure-class table, obligations with real/substitute/limit, one
open question in the form, three observations parked. Report in the
step-5 form with the one decision carrying bet, cost and what waits.

Timing: spec phase 24 min. First cold read and the fresh consult
dispatched 40 s apart; the consult returned in 3 min. Re-read with the
inherited term list and the changed sections: 16 turns, 8 tool calls,
8.4k output tokens, 3.4 min, against the first read's 65 turns, 37 calls,
29k tokens, 7 min — and it still found a cross-section gap (the text
route's new failure states against § Goals) and a term collision with
`deploy-coupling.md`'s "contract migration". The delta scope did not lose
the whole-spec check on this sample. Supports the hypothesis that the
loopy-os siblings were the prose attractor: this tree's siblings are mixed
and the block appeared without the later step-2 line.

## 2026-09-18 — the three builds (spec → implementation, same sessions)

Three Opus analysts, one per branch, read the build phase of each session
(after the compaction that followed the spec) with the brief in this
session's scratchpad (`build/*.brief.md`; reports `build/*-report.md`).

| | OPC (`cc8ba647`) | gauge (`51310e66`) | PDF (`f078881d`) |
|---|---|---|---|
| build wall time | 1 h 43 | 4 h 34 (incl. 4 review rounds, docs, CI) | 1 h 56 |
| commits | 6 | 18 | 11 |
| user corrections of a spec misreading | 0 | 0 | 0 |
| spec reads during the build | 6, in 3 bursts at phase boundaries, none after the auto-compaction | 1 | 1 |
| measurements re-run | none | none | only the two the spec marked unreachable |
| departures | 8, none in the user report, 4 + 9 in the review brief | 8, all in § As built | 8, all in § As built |
| spec statements wrong against code or itself | 1 (§ Phases vs § Target shape on named sets) | 2 (`close()` on the cleanup list; "registry untouched") | 2 ("unchanged in behaviour" gate; "list is complete") |
| review findings the spec could have prevented | no result landed | ~5 (timer leak, projection, matcher map, partition rule, two closed states) | 3 of 7 (two tenets written after review, pass-through rule) |

What held (all three): unattended builds with zero corrections; premises
and measurements consumed as given, D1/P7/P1 never relitigated; an
assumed premise with a fallback (OPC P9, 64 KiB) implemented and verified
without a detour; § Phases held against a user push to collapse PR 2
(PDF, answered with no tool call); test standards used as a checklist.

What failed, recurrent: (1) facts about existing code stated outside
§ Premises carried no verification and shipped defects — gauge ×2, PDF ×1,
OPC's self-contradiction is the same class; (2) the Structure sketch was
followed literally — PDF's `callback_credentials.ts` produced the review's
only critical finding, gauge's file list omitted the projection; the
"sketches" hedge did not bite; (3) invariants held implicitly and written
only after review — PDF two tenets, gauge "one matcher map per kind";
(4) rules far from the code they bind or restated with drift — gauge's
partition rule in § Delivery, OPC's named-set rule in two sections, the
close-reason precedence never ordered; OPC's 10k words cost a `grep -n
"^#"` index at every phase boundary. Singletons to watch: non-goals that
close a state with one sentence became the gauge's two largest departures;
the org's alarm policy was absent and overturned a specified alarm; the
PDF spec drafted model-facing sentences that failed a prompt pass; the OPC
eval rung vanished with no report, and its departures reached the reviewer
but not the user (the user had deferred docs; the report is the build
skill's).

Proposed bar changes, not yet applied: A. a claim about existing code
outside § Premises carries sha and line or says unverified; B. Structure
names responsibilities and the invariant each protects, file names
optional, rejected shapes rejected by property; C. each phase in
§ Delivery names the sections that bind it, and the verification list is
answered item by item in the build report (the report half belongs to the
build/handoff skill); D. the first cold read also looks for a rule stated
in two sections with different answers. Keep unchanged: § Premises, the
summary block, the situations.

## 2026-09-21 — two more runs on the final text, and five builds in total

Runs `ae6b98fe` (spec/eval-configuration-matrix → built in `d732b40f`, a
separate session, PR #7358) and `81e8cdd7` (feat/eval-trial-record-and-facts,
built in-session). Both loaded the final step-2 text. Both in
`docs/loopy/specs/`. Reports in `build/cfg-report.md`, `build/trial-report.md`.

Spec phase: configuration 29 min (docs tree first), trial 30 min; both
dispatched the cold read beside the warm validation round (Codex and a
Fable voice); re-reads 20 and 22 tool calls, 5 and 7 min, against 30 and
27 on the first read. Labelled block present in both, grouped (15 and 20
lines, 4 gaps); journey words 0. Words: configuration 4,105 → 6,404 at
last spec commit (mean 32.7 w/s, 25% over 40); trial 7,296 → 10,270
(26.9/17% → 32.2/25%); the Design section grew 3,727 → 5,540. The checks
add prose and never remove it, and the sentence profile degrades through
revision. Every spec on the new bar (5.7k–10.3k) is longer than the old
corpus median of 3.9k.

Builds: configuration 9 h 19 wall (4 h 24 of by-hand screen runs), 13
commits, 2 review rounds, zero corrections of a spec misreading; trial 1 h
33, 6 commits one per § Delivery step, zero corrections, no review round,
nine new modules citing the spec's sections in their headers. Premises
reused in both; the configuration's onboarding gate re-verified eight
premises at source and all held.

Recurrent across the five builds (OPC, gauge, PDF, configuration, trial):
- statements about existing code outside § Premises found wrong: 4/5
  (gauge `close()` and registry; PDF "unchanged" gate and "complete" list;
  configuration `step_timeout_ms` "carried by the adapter"; OPC's
  self-contradiction) plus an unbound noun ("the catalog's level map",
  four greps);
- invariants asserted without a mechanism or written only after review:
  3/5 (PDF two tenets; gauge matcher map; configuration r1-critical "so
  the two cannot disagree", and recorded-vs-enforced manifest sources);
- state vocabularies without entry/exit rules or an unordered precedence:
  4/5 (configuration unmeasured/pending, r1 F5; OPC close reasons; gauge
  claimed-not-admitted, partial materialization; PDF over-delivered body);
- Structure sketch followed literally with harm: 2/5 (PDF credentials
  helper, gauge file list);
- verbatim model- or judge-facing text authored by the spec failing in
  reality: 2/5 (PDF failure lines; trial rubric sentence flaky on Bedrock,
  and a determinism escape clause that would have excused it);
- verification obligations dropped without a report: 3/5 (OPC eval rung;
  trial three; configuration said so for two);
- departures reaching the reviewer or a commit but not § As built / the
  user report: OPC, configuration (two), trial (docs deferred).
Singletons: a four-hour wall estimate that ran 1 h 18 (the bar already
excludes estimates); the gauge's org alarm policy; "except where the
judge answered differently" as a tolerance.

Held in all five: unattended builds; premises consumed, no measurement
re-run; ordered § Delivery executed as commits; the summary block and
situations; the phases holding against a user push (PDF).

Proposed bar changes, evidence now at 3–5 of 5: A. a claim about existing
code carries its path, and where a sha matters the sha, or says
unverified; a noun naming a code artefact carries its path; B. an
invariant names its mechanism or becomes a § Verification obligation, and
a recorded fact says whether anything checks it; C. a state list carries
each state's entry and exit rule, and an ordered evaluation is written as
an order; D. Structure names responsibilities and the invariant each
protects, file names optional, rejected shapes by property; E. text the
build will hand to a model or a judge is bound by what it must say, and
if written verbatim it is a premise that ran; F. § Verification
obligations are numbered so the build answers each, and each phase names
the sections that bind it; G. a revision replaces the sentence it corrects
rather than appending a clause, and the final reread cuts what the
revisions duplicated; H. the first cold read hunts a rule stated in two
sections with different answers.

## 2026-09-21 — the layered pass: format, tools, and the build gate

The user reframed the eight proposed rules as patches on one layer and
asked for root causes, formats that make the mistake visible, and
mechanisms over instructions, accepting that wrong claims about existing
code will keep happening and must be cheap to catch. Applied:

- Format (SPEC-BAR): Structure entries carry responsibility, owner, the
  invariant protected, today's file, and a placement sketch last; legal
  states go in a table (entered when, left when, written by); Wiring
  describes today in `Today:` lines read from the file while writing and
  the proposal in `After:` lines; a tenet closes with what holds it, a
  mechanism or a numbered obligation, and one with neither is struck or
  moved to its seam; obligations are numbered and answered by the build;
  text a model or a judge will read is bound by requirements, and written
  verbatim it is a premise that ran; revision by replacement; the Design
  example rewritten to show all of it. Summary sits under `## Summary`.
- Tools (`scripts/`): `check-refs.sh` resolves every cited repository
  path and `§ Heading` (package-relative paths resolve under a directory
  another citation established; other documents' headings are skipped);
  `spec-stats.py` prints words per section, sentence length, the longest
  paragraph and the summary block's shape. Tried on the five specs: the
  post-build trial tree reports only the files the build deleted; the
  configuration spec 2 misses, the PDF spec 3, all references to other
  documents or vendor paths.
- Build gate (handoff/pickup build.md and design.md): a spec's `Today:`
  lines are premises for the source check.
- Handoff (planlab `pl-loopy-handoff`, branch
  `docs/handoff-as-built-from-commits`, commit 0a3037deda, not pushed):
  § As built is assembled from the branch's commits, not from memory.

Validation: an Opus cold reader with seven scenarios resolved the gate
moving case (Today lines, re-read by the build), the state table, the
unheld invariant, the refusal message, the revision procedure and the
Structure order as intended, and flagged nine wording defects; seven
fixed (the disposition of an unheld invariant; the walk linked to the
table; the summary heading named; "the cut" disambiguated; the
reproduction line no longer contradicts "Settled"; the PR boundary
stated always; thresholds for the numbers; the example labels the owner;
the docstring's ordering). Two are pointers to files outside the read
set and stand.

Measure next: `Today:` lines present in Wiring and whether the pickup
gate re-reads them (transcript: reads of the cited paths in the first ten
minutes of a build); state tables present where a spec has states;
held-by lines on tenets and how many are struck at writing time;
obligations answered by number in build reports; spec growth through
checks (target: under a quarter); words per sentence at the last spec
commit against 27.7/19% (trial) and 21.9/7% (PDF). Reverse the Today
convention if the gate's re-reads cost more than the review rounds they
replace, or if writers fill Today lines from memory anyway (wrong Today
lines at the same rate as before).

Cold Codex review (`dotfiles-4f711dad/spec-skill-review-r3`, 2 min,
rulebook first, surfaces second, this log last): verdict ship after
fixes. Applied: the state-table example made coherent (failure and
absence rows, every exit named); the fallback example names the edge
where the premise becomes blocking; the cold reader always returns a
compact reconstruction, then corrections or "none"; the commit boundary
includes the project's index row; corrections replace and missing content
is added at its owning section; Behaviour's mechanism is one line
pointing at Design, the example trimmed to match; proposed placements are
sketches, not citations; thresholds are cues for a reading, not
diagnoses; the checker's header and the bar describe it as heuristic
with its exclusions, a clean run meaning no detected misses; the
statistics docstring says approximate; the headings named in order
instead of "five sections" plus two; the cold-read example tagged; the
report example labelled as the opening and decision portion; the
reader's boundary permits file-reading tools. Cut: the "twice the length"
multiplier and the "writing the line is how the writer finds out"
sentence. Kept against the review: "Writing a spec is a procedure, not
only a document" (it is the anchor for step 1's settle-by-running, the
user's framing); the design-it-twice paragraph (the pointer plus what the
document carries); "Leave out what isn't yours to pin" stays in the
closing rules rather than beside Design, since it covers tests, docs and
estimates too.
