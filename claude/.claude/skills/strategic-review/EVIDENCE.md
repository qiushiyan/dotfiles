# strategic-review — evidence log

One entry per pass. Counts carry their predicates so the next pass can re-run
them; raw outputs lived in the named session's scratchpad and are not durable.

## 2026-10-07 — the skill's origin, and two rehearsals against the manual prompt

Session `mini:8ae01ce4` (an `/improve-tool` pass, then `/consult`, then a
replay and two rehearsals).

**Request.** The user had begun opening a fresh session for the few PlanLab PRs
big enough to warrant it, with a short prompt: read what the PR is for, then
review it against prompt-engineering, thermo-nuclear and codebase-design. They
asked where that belongs, how to make reviews better on the first attempt, and
what reviews teach upstream. The in-session `/review` stays on every build;
this review stays manual and selective (the user's decision).

**Corpus.**
- Obelisk, both machines, first user turns since 08-01 that ask for a review of
  a PR or branch: two PlanLab PR reviews of this kind, both on 2026-10-06.
  - `d51febff` (PR 8616, zip archives) and `1a990a25` (PR 8620, bounded
    search) both ran after the branch's codex full review and round 2 had
    converged.
  - 8616's manual review found 5 bugs, about 8 model-facing problems and a
    duplicated read queue. The user folded all of it in, and the rebuild
    deleted the codex-round fix `e773533ab4` (`3535c15246`, −700 lines in
    `archive_view.ts`).
  - 8620's manual review was followed by 11 fix commits (`3690cbf8cd..f637d4981d`).
- Envoy job store on the mini, 2026-09-24 → 10-06: 33 PlanLab code-review
  rounds on 30 branches, 354 findings, 329 confirmed.
  - Classified by one subagent into the classes now in
    `~/.config/lessons/collaboration/finding-classes.md`.
  - Tests are 156 of the 329 confirmed findings (unpinned 101, wrong-reason 55).
  - 45 of the 63 criticals are second mechanisms (24), ordering (11) and wrong
    granularity (10). The critical count for second mechanisms is partly the
    brief template's own rule that missed reshapes are critical.
  - Model-facing findings are 10 of 354.

**Consult** (`dotfiles-f38455a2/consult-r1`, Opus, 11 min). It corrected the
host on 8620's follow-up and found a byte-identical Opus+astra pair in the
store. It showed that build sessions ran revert checks only after `/review`
was dispatched, and it located the duplicate queue's origin in the spec.

**Replay** (`replay-0/a/b/c`). PR 8616 frozen at `3386ba65e6`, four arms, scored
blind by a subagent against the manual review's 32 findings:

| arm | hit / partial |
|---|---|
| original codex brief, codex | 3 / 1 |
| same brief, Opus | 4 / 5 |
| lensed brief without the author's hints, codex | 2 / 2 |
| the manual session's four slice prompts, codex | 11 / 6 |

What the replay showed:
- Slicing with specific suspicions dominated, but those prompts came from the
  reference session itself.
- The model mattered for the strategic items: only Opus found the duplicate
  queue, the self-defeating refusal and the `.com` withhold.
- The lenses recovered exactly their targets and nothing more.
- Every arm found real defects outside the key, none wrong.

**Rehearsal v1** (`rehearse-8616`, `-8616-r2`, `rehearse-8620`; Opus; each PR
frozen at the head the manual review saw, with the PR body recovered from
GitHub's edit history).
- **Design of v1.** The review lens (`review-lens.md`) as the stance;
  suspicions written per area before reading it closely; lenses
  paraphrased, thermo-nuclear included.
- **Scoring.** A subagent pooled both reviews' findings, verified each against
  the frozen code, and graded consequence, with the labels hidden.
- **Headless failure.** The first 8616 turn ended while its background
  reviewers ran, which a headless turn cannot survive. It was resumed with
  foreground subagents. This is a rehearsal-harness constraint, not the
  interactive skill's.

| PR | review | real + minor | unique full-real | ships-wrong (full + minor) | maintainability | wrong | time / cost |
|---|---|---|---|---|---|---|---|
| 8620 | manual | 36 (10 + 26) | 6 | 8 | 13 | 0 | ~12 min |
| 8620 | v1 | 14 (6 + 8) | 2 | 1 | 3 | 0 | 40 min, $39.80 |
| 8616 | manual | 33 (9 + 24) | 1 (replace yauzl, built) | 4 + 5 | 2 + 11 | 0 | ~10 min |
| 8616 | v1 | 43 (13 + 30) | 5 (read-email regression, zip memory cap, CI LFS fixtures) | 6 + 7 | 1 + 6 | 0 | 49 min over two turns, $100 |

What v1 showed:
- v1 held up on correctness and on what the model is told.
- It was weaker on design and quality in both PRs.
- It cost two to four times as much.
- The read-email regression and the CI fixture problem stayed open in the
  shipped branch.
- Attributed, without an isolating run, to the stance lesson's "fewer
  findings, each heavier" and to thermo-nuclear reduced to one line.

**Changed for v2.** The standards are read in full, as the manual prompt had
them. `review-lens.md` is gone as the stance. The report covers every problem
the reviewer can point at code for. Splitting is two to four broad areas, with
suspicions handed over after reading. The lenses for outcomes, tests (CI
included), the model's view and claims are kept.

**Rehearsal v2** (`rehearse-v2-8616`, `rehearse-v2-8620`; Opus; same frozen
heads and PR bodies). The rehearsal prompt gained one harness line telling the
session to run subagents in the foreground, because a headless turn cannot wait
for background ones. Each run was added as a third review to the existing pools,
verified to the same standard, with labels hidden. Each pass re-graded one old
item from doubtful to real-minor.

| PR | review | real + minor | full real | ships-wrong | misleads-model | maintainability | wrong | time / cost |
|---|---|---|---|---|---|---|---|---|
| 8616 | manual | 33 | 9 | 4 + 5 | 2 + 5 | 2 + 11 | 0 | ~10 min |
| 8616 | v1 | 44 | 13 | 6 + 7 | 3 + 12 | 1 + 6 | 0 | 49 min, $100 |
| 8616 | v2 | 49 | 11 | 5 + 10 | 2 + 14 | 2 + 8 | 0 | 37 min, $37 |
| 8620 | manual | 37 | 10 | 3 + 5 | 2 + 6 | 4 + 10 | 0 | ~12 min |
| 8620 | v1 | 14 | 6 | 1 + 0 | 2 + 2 | 1 + 2 | 0 | 40 min, $40 |
| 8620 | v2 | 51 | 13 | 3 + 5 | 4 + 7 | 4 + 8 | 0 | 38 min, $41 |

What v2 showed:
- **8616.** v2 proposed both reshapes the author built after the manual
  review: the index's own parser in place of yauzl, and one call-scoped read
  primitive shared with the Files gate.
  - It also found an untested zip-writer CRC path and no cap on total
    decompressed bytes.
  - It missed the eval-fitted CAD sentence, arguing the opposite, and a few
    duplication items.
- **8620.** v2 found two real problems nobody else did: converters abort 5 s
  before the deadline text can fire, and the schedule refill discards
  earlier validated hits on a cut.
  - It missed the palette's missing abort signal and four of the manual
    review's prompt-text items.
- **Overlap.** Each review still holds real items the others miss; one pass
  is a sample.

Limits:
- One run per arm.
- One scoring agent per PR.
- The "addressed by commit" column favours the manual reviews, since the
  author acted on those.
- The manual sessions' cost was not priced.

**Deliberate keeps.**
- No `review-lens.md` stance. Its "fewer findings, each heavier" suits the
  in-session tactical round, and here it halved what 8620's v1 found.
- The three standards read in full rather than paraphrased.
- "Report every problem you can point at code for", because the user sorts
  the list.

**Next comparison.** Real uses after this commit, read through the class
tags:
- Whether the report leads to the user folding in the findings, and which
  classes they act on.
- What later `/review` rounds on the same branch still find, which is the
  miss rate.
- Time per review.

Revise if real uses drop below the manual prompt's yield (about 33–37 real
findings on PRs of this size), if the design reshapes stop appearing, or if
the class tags go unused by a later pass.

**Revision pass** (the prompt-engineering rulebook's revision pass, same
session).

Fixed:
- **Unearned certainty.** Step 3 justified splitting by speed ("goes
  faster"), but v2 took longer than the manual reviews. The split buys a
  complete read of each area, and the text now says so.
- **Duplicated pointer.** The project prompting guide was named in step 1
  and again in step 2. Step 2 now owns it.

Kept:
- The lens bullet's short echo of thermo-nuclear's triggers. It is the
  rehearsed text, and the full standard is still read first.
- No headless-subagent guidance. The skill runs interactively, and that
  constraint belongs to the rehearsal harness.

**At the user's request, after the pass.**
- **PlanLab map.** Intent first now names PlanLab's map: read
  `pl-loopy-onboarding`'s `SKILL.md` and the `routes/` files the PR touches,
  as both manual sessions did, rather than invoking the skill. Onboarding
  ends its turn on a first reply.
- **Prompt-engineering is conditional.** The rulebook, the project
  prompting guide and the model's-view lens are read only when the PR
  description or the touched files show a model-facing change, a changed
  tool behaviour included. Both rehearsed PRs had such a change, so neither
  rehearsal tests the skip.

## 2026-10-09 — first real uses, and a tests lens that weighs both ways

Session `mini:88b18cbd` (an `/improve-tool` pass, dogfooding `~/dev/skill-evals`).

**Corpus.**
- Obelisk, both machines: user messages starting
  `<command-message>strategic-review</command-message>`, this session excluded.
  9 sessions, all on the mini, 2026-10-07 → 10-09; mac 0.
  - 8 PlanLab PRs (8677 8680 8675 8758 8806 8809 8859 8857) and gazette.
  - Report = the longest assistant text between the invocation and the next
    user turn, read in full with `raw()`. For 8809 that is `d517b218`, plus
    the revision `cdb60526`.
- Envoy jobs on the mini for the codex rounds after the fold-ins:
  `automation-files-save` `review-r1+2`/`r2+2`, `sandbox-deadline` `review-r1`.
- Test-quality remarks: typed user text since 08-01 that mentions tests with
  quality words.
- Three read-only graders scored the tests PRs 8809, 8806 and 8680 added,
  build phase against fold-in, by `test-quality.md`, with mutation runs in
  scratch worktrees. Their ledgers lived in this session's scratchpad.

**Findings.**
- **Fold-in is the norm.** All 9 uses folded in every finding. In 5 the user
  typed the same instruction ("structured and holistic, prepare refactoring
  if needed"): 8806 and 8809 verbatim, 8859, 8857, and gazette.
- **The Tests lens only ever added.** The 9 reports carry 16 `unpinned` and 7
  `wrong-reason-test` tags, and no finding to delete, merge or loosen a test.
  The additive-bias counterweight was in `review-lens.md`, dropped in v2.
  The user's own lesson, `testing/test-quality.md`, was never read.
- **The user's complaint recurs:** mac `f79d7036` 08-12 (review-driven tests
  "tailored to the review itself"), `3f7f1fe0` 08-13, `8b472a5b` 08-18,
  `a9194a78` 09-05 ("too literal and not behavior-focused"), and this request.
- **What the graders found.** "Inflated coverage" is weak: 63–91% of tests
  keep, and no fold-in out-paced its code. Two shapes are strong:
  - **Wording pins induced by review.** Low-quality share went from build to
    fold-in as 28% → 37% (8680) and 9% → 20% (8806); 8809 was flat. The
    excess is sentence pins of model-facing text and mocked tests restating
    a minor fix. 8680's report asked for the `REMEDY` lines to be pinned,
    and the fold-in pinned the table verbatim.
  - **Fragile wiring left unguarded**, mutation-confirmed in all three:
    - 8680: deleting `withdrawAttempt` left 23/23 green;
    - 8806: the save-sweep adapter, 69 green;
    - 8809: the S3 ETag check, 424 unit tests green.
- **One retracted verdict.** In 8809 the report was written before area 1's
  fuller report arrived, and its critical hang reversed the verdict (`cdb60526`).
  1 of 9, cause not established: watch it, no change.
- **Later rounds still find criticals.** The codex rounds after fold-in found 2
  criticals on 8806 and 1 on 8758. One pass is a sample, as v2 showed.

**Changed.**
- The skill:
  - `test-quality.md` joins the standards read in full.
  - The Tests lens starts from the risk: break the guarded line in a scratch
    worktree. It weighs the tests the PR added; a sentence pin, a
    restatement, a mock-only or fixture-supplied assertion is a finding,
    fixed by asserting the token or deleting the test.
  - A new "Folding the findings in" section: reshapes first, one commit per
    owner, tests from the lens rather than one per finding, each seen red,
    text pinned by its token, no test for a naming or structure finding.
- `finding-classes.md` gains `low-value-test`.
- `test-audit` became a local adaptation built on the same lesson (734508c).

**Eval** (`~/dev/skill-evals`, case `strategic-review/weighs-added-tests`).
- **Setup.** PR 8680 frozen at `faaceea7d8`, the head the first real review
  saw, offline, on Opus via the subscription. The judge was `gpt-6-sol`.
  The fixture's lessons already held `low-value-test`, so both revisions saw
  that tag.
- **Result.** Red `55a88cb`: 0/3. Candidate: 3/3, at $13.22 against $13.53 a
  rollout. All six still carried a known correctness finding.
  - The candidates named `bridge_facade.test.ts:98`,
    `workspace_files.test.ts:134` and the whole-stdout pin in
    `commit_files_save.test.ts`.
  - All three called `files-save-right.test.ts` "agrees with the Files
    routes" a tautology, overruling the grader. The source confirms it:
    `filesSaveRightOf` calls `canWriteSharepointFiles`.
  - Candidate 2 also found a new critical: a cron Task under approve-all
    saves to SharePoint with no card.
  - Red 3 named two whole-string tests "restate rather than guard" under the
    new tag but asked for stronger tests. It was judged fail.
- **Harness fixes this needed.** The judge first saw only 4k of each 20k
  report and returned fail or unresolved on all six. The final answer now
  reaches it whole, and `judge` re-renders from the raw transcript.
- **Limits.**
  - One case, one PR, n=3.
  - The fold-in section is untested: it needs a second scripted turn.
  - The fixture's lesson copies predate `734508c`'s risk bullet.

**Next comparison.** Real uses after this commit, read through the class tags:
- **Measures:**
  - `low-value-test` findings appear and are folded in;
  - the fold-in's low-quality share is no higher than the build phase's;
  - a mutation of each fragile behaviour the report named goes red after
    fold-in;
  - the user stops typing the holistic fold-in instruction.
- **Revise** if real findings drop below the v2 yield, if deletions remove a
  test that was a contract's only proof, or if the lens crowds out
  correctness findings.

## 2026-10-14 — second opinions from inside the review, replayed on four PRs

Session `mac:9f01709a` (an `/improve-tool` pass). The user asked whether the
skill should send issues worth a second opinion to astra or fable, tested by
replay, without changing the skill until the evidence was in.

**Corpus.**
- Obelisk, both machines, the same predicate as the 10-09 pass: 14 sessions
  since then, all on the mini, 13 PRs (8858 8860 8874 gazette#1 8885 8948 8949
  8955 8959 "2" 8994 9042×2 9069).
- Answer keys for #8858, #8948, #8955 and #8959, each at the head its real
  review read. They were built from the session, the envoy rounds, the bots, CI
  and later fixes, and each was checked at that head. They live in the cases
  under `~/dev/skill-evals/cases/strategic-review/pr-*.md`.

**Findings from the live uses.**
- **No second model.** No review consulted one: all 56 area subagents ran on
  the host model. Wherever another voice later disagreed, it was about a
  prescribed fix, not a finding:
  - 8955: astra r3 overturned F1 and F4, then CodeRabbit overturned F1's
    replacement;
  - 8959: r6's two criticals came from the review's own fixes.
- **The fold-in is unreviewed by default.** All 5 PRs that got a review after
  the fold-in turned up a critical or several moderates, mostly in fold-in
  code: 8948 r3, 8955 r3, 8959 r6, 9042 `08eb4785`, gazette#2. In 3 of the 5
  the fold-in's "each new test seen red" did not hold.
- **Findings lost before the report.** In #8858, 12 of the 21 defects the
  report missed were in its own areas' second passes, which arrived after it.
  In #8948 the lead dropped an area's finding (K10). Reports were written
  before every area returned in 332b9785 and 53805ced, and 8809 in the last
  pass.
- **Stale wakeups.** Four sessions set a wakeup whose prompt was
  `/strategic-review …`: 53805ced, 3836e63b, d174f8f0, a93c3d7e. It fired
  after the work in three:
  - d174f8f0: an unrequested 27-minute round;
  - a93c3d7e: a refused Skill call, and the user confused.
- **The 10-09 measures hold.**
  - `low-value-test` appeared in 11 of 14 reports.
  - Prose pins in the fold-in were no higher than in the build in 11 of 13 PRs.
  - The holistic fold-in instruction was typed in 0 of 14 sessions (5 of 9
    before).

**Replay** (`~/dev/skill-evals`, run `sr-consult-w1` on the mini).
- **Rig.** 60 rollouts on the subscriptions; the judge was gpt-6-sol with 3
  passes.
- **Arms:**
  - `current`;
  - `astra` / `fable`: a step to ask another model wherever being wrong costs
    most and reading has not settled it;
  - `fixes`: astra tries to break each prescribed fix;
  - `builder`: the build session's own "look hardest at" paragraph, forked
    from it at the moment of invocation;
  - `control`: hindsight hints.
- Per run, summed over the four PRs:

| arm | checked defects (39) | of those the real review missed (18) | fix checks (4) | min | $ |
|---|---|---|---|---|---|
| current | 8.3 | 1.9 | 2.7 | 14 | 13 |
| astra | 9.0 | 2.0 | 1.3 | 16 | 13 |
| fable | 9.2 | 1.0 | 1.3 | 24 | 20 |
| fixes | 10.0 | 3.7 | 2.6 | 20 | 14 |
| builder | 10.9 | 3.9 | 2.3 | 16 | 12.5 |
| control | 22.0 | 14.3 | 1.0 | 14 | 11 |

- **Whole-key recall** was flat, 49–56% a run in every arm.
- **Blind rank (pairwise, of 36):**
  - fixes beat current 27, builder 26 and astra 24;
  - builder beat current 23, and astra beat current 22.
  - The ranker and astra are both OpenAI models.
- **What it showed:**
  - A general "ask another model" step does not pay: the consults confirmed
    findings the reviewer already had, and fable cost 50% more.
  - Aiming astra at the fixes, or handing over the builder's doubts, roughly
    doubles the hard misses. Neither made the prescribed fixes safer.
  - The control shows the ceiling is where the reviewer looks, not how well
    it reads.
- **Limits:**
  - 2–3 runs per arm per PR, and the realistic arms differ by 1–2 defects
    over four PRs.
  - In two #8948 rows the report was not the final message, so recall
    excludes them.

**Decisions** (the user's, after the results).
- **Not adopted:** no consult step in the skill.
- **Builder hints** become the TabType snippet `strategic-review-brief`, asked
  of the build session at its end and pasted after `/strategic-review <pr>`.
- **Changed here:**
  - step 3 writes nothing until every area has returned, and waits on
    completion notices rather than a wakeup;
  - step 4 accounts for every area finding, reported or dropped with a reason.

**Next comparison.** Real uses after this commit:
- reviews opened with a pasted brief against bare ones, by finding yield and
  by what later rounds still find;
- no report written before its areas return;
- no wakeup prompted with the skill command;
- whether a post-fold-in review becomes routine, and what it still finds.

Revise if briefed reviews find no more than bare ones over about ten uses,
or if the accounting rule bloats reports without moving what later rounds
find.

## 2026-10-17 — a fields lens, replayed on the same four PRs

Session `mini:e0ebda78`, an `/improve-tool` pass over the agent workflow set
against Felix Rieseberg's "How to be more ambitious" (2026-10-13). Its Range
idea is to bring in other fields and do what each does, not write in its
voice: "don't ask the model to write like a short seller, ask it to do what a
short seller does".

**History** (Obelisk, mini only, 2026-09-24 → 10-16; the laptop was
unreachable).
- **The user rarely brings in a field.** One of 2,706 typed turns does
  (`1a990a25/9aceddfe`, "as an outsider": p50/p90 and real threads, which is
  the field's method). Sessions wrote 898 briefs with no role-play.
- **This skill's Tests lens is the one field method in the reviews.** "Break
  the guarded line" produced mutation findings in at least 6 reviews since
  10-13: #9042, #9069, #9120 twice, and two codex voices.
- **pl-bugbot's charters skip the big PRs.** Its security-access and product
  charters skip PRs over about 5,000 lines (#9081 at 5,103, #8959 at 16,976),
  the PRs this skill exists for.

**Replay** (`~/dev/skill-evals`, run `sr-fields-1017` on the mini).
- **Rig:** 24 rollouts on the subscriptions, 3 per arm per PR, judged by
  gpt-6-sol with 3 passes. The leak check found no reads of today's planlab
  or handoffs.
- **Arms:**
  - `current-1016`: this skill as of 2026-10-16;
  - `fields`: a lens before Tests. An operator replays the deploy, restart and
    rollback order with old and new code on one wire, table or queue. A
    performance engineer bounds each new wait, queue and fan-out on a path
    that runs often at ten times today's load. A security engineer traces
    each moved credential, permission or tenant boundary to all it reaches.
- Per run, summed over the four PRs (90% bootstrap interval on the difference):

| arm | checked defects (36) | of those the real review missed (18) | fix checks (4) | min | $ |
|---|---|---|---|---|---|
| current-1016 | 12.1 | 5.2 | 2.0 | 16 | 13.7 |
| fields | 12.4 [−2.3, +2.7] | 4.6 [−2.2, +0.9] | 1.9 [−1.6, +1.2] | 16 | 14.9 |

- **The defects it was aimed at stayed missed.** The operator-shaped misses
  scored 0 in both arms: #8959 K26 (the committer's replay arm after the
  contract bump), #8959 K28 (the operator script's unchecked `--limit`), and
  #8948 K4 (each poll's publication with no deadline).
- **Whole key:** about the same number of key items per run in both arms.
  Fields raised more new, unverified findings on #8858 (21.7 against 14.3) and
  #8948 (18 against 12), and fewer on #8955 and #8959.
- **Blind rank:** fields beat current 22 of 36, split by PR (9/9 on #8948, 8/9
  on #8959; current 6/9 on #8858, 7/9 on #8955). The one ranker was an OpenAI
  model.
- **Not comparable with the 10-14 table.** Those rows were graded on older
  case text, and step 3 and 4 changed on 10-15.

**The 10-14 limit, explained.** "In two #8948 rows the report was not the
final message": in `astra-1` and `fixes-1` a background task's notification
arrived after the report, and the grader took it for a new prompt and judged
only what followed it. skill-evals `f96f2a7` keeps the report in the answer.
`sr-consult-w1` has not been regraded: OpenRouter was out of credit (HTTP 402)
on 10-17.

**Decision** (the user's): the fields lens is not adopted. The skill is
unchanged.

**Next comparison.** One option stays untested: field charters as subagents
of their own on the PRs pl-bugbot skips. Score it on the three misses above;
adopt it only if it moves them.

## 2026-10-23 — earned handling: what a review asks for, and what a PR already holds

Session `mac:175dfedf` (an `/improve-tool` pass, then `/consult` with fable and
astra, then a replay, all while the user was away under "go with your
recommended default and apply"). The user asked to push against slop and
unearned edge cases, taking inspiration from pstack
(github.com/backnotprop/pstack, clone `e44668c`), especially its review
skills. Their bar: handling is earned by a severe consequence on a real path,
or by production data. Later suspicion: most of it enters through
`pl-handle-code-review` from the Bugbot and codex GitHub integrations, though
many of those fixes are genuine.

**Corpus.**
- Obelisk, both machines, the same invocation predicate as 10-09: 8 PR uses
  10-16 → 10-22, all mini. They are #9240 (`b3094c4e`; `9277a03a` was an
  abandoned start), #9498, #9511, #9531, #9567, #9566, #9539 and #9260
  (`7cd316ae`), plus the new `drive` repo.
- Review-driven code changes, classified as earned / unearned / unclear under
  one written definition, by four subagents and two consult voices:
  - 37 PlanLab PRs merged 09-23 → 10-22;
  - the population was the user's 110 merged PRs of ≥1,000 added lines in that
    month, of the 229 the search API reported (200 fetched).
- Bot denominator: 128 inline bot threads on the user's last 40 merged PRs.
  The user replied fixed 71, dropped 27, product 2.
- User-typed corrections about over-building: at least 8 independent sessions
  since 08-01. All of them are at design time, and none names a review.

**Findings.**
- **Reviews file cases their own text calls unreached, and the fold-in builds
  them.** Seen in 4 of the 7 reports.
  - #9567 finding 4 (moderate): "No body does this today (searched every
    routed body)". It was built as a re-entry guard on every master write.
  - #9567 finding 13: "Production sets no `MemoryMax`". It was built, and broke
    the release bundle.
  - #9511 KIT10 and KB12 have the same shape.
  - Cause: severity follows consequence, and "fold these in" builds every
    finding. The handling counterweight left with `review-lens.md` on 10-07,
    and nothing restored it, unlike the tests counterweight on 10-09.
- **Unearned handling is a minority, in small pieces.**
  - It is about 15% of the classified lines in the first 12 PRs, usually
    5–25 lines per item.
  - Sources: the strategic review's own minors are the largest count in the
    newest PRs. Astra's 12 PRs found 4 unearned of 42.
- **The bot share depends on whether the bots ran (an unresolved fork).**
  - Fable's 13 PRs (09-23 → 10-14, bots mostly running) put the GitHub bots
    first: 55 of 101 unearned items.
  - prs-C's bot-heavy PRs found 4 of 30 fixed bot threads unearned.
  - Astra found codex-GitHub fixes earned 12 of 13.
  - Raters differ at the "severe" boundary.
- **The larger maintenance cost is real cases patched at the symptom.** Seven
  chains in Fable's 13 PRs, and #9531's r2–r4 attribution machinery, deleted
  by the strategic review (9fc132b +112/−210). The strategic review is the
  pipeline's main deletion source: it produced every applied deletion in
  #9498, #9531 and #9539.
- **The 10-14 measures hold.** No report was written before its areas
  returned (0 of 7), and no wakeup carried the skill command (0 of 8). 7 of 7
  fold-ins went unreviewed, and in 3 of them CI or a bot later found faults.
- **Other frictions, owned elsewhere:**
  - a command inside a brief file left the skill unloaded (3 uses);
  - the scratch-worktree mutation instruction collided with the no-install
    rule (3 uses);
  - the driver answered reports "Fold all in" (`drive-session` § Each step).

**Consult** (`consult-r1/codex-gpt-6-astra`, `consult-r1-fable`, 60 minutes,
each on its own half of the 99 PRs not yet classified).
- Adopted:
  - severity stays consequence-based, and the basis line decides build or
    list (both voices);
  - three dispositions: findings, investigate, known limits (astra);
  - a deletion names its cover (astra);
  - the fix names the callers and invariants it changes (astra, from #8955's
    three successive save-recovery fixes);
  - the `reaches:` field (fable);
  - the round history comes from commit bodies and bot threads (fable);
  - the driver line (fable).
- Rebutted:
  - P6's deferral: the class is for counting, and the disposition does the
    preventing;
  - Comment Sicko's deletion under doubt, against astra's #8913 counterexample.
- Escalated: whether `pl-handle-code-review` gets the same rule. It is
  PlanLab's skill, in a repository shared with teammates.

**Changed.**
- **The skill.** A new **Earned handling** lens reads both ways:
  - a finding that asks for handling carries `reaches: traced | evidence |
    none <cover>`;
  - a `none` or minor case goes to known limits, and a serious case that
    stays unsettled goes to investigate;
  - handling the PR already holds without a basis is deleted once its cover is
    named.

  A **Rounds that patched the same place** lens was added. The report gains
  the investigate and known-limits lists, and each fix names the callers and
  invariants it changes. The fold-in builds reshapes and deletions first,
  settles investigate items by their observation, and leaves known limits
  unbuilt. Examples are a deleted clamp and two known limits, invented so
  they leak no case.
- `finding-classes.md` gains `unearned-handling`.
- `drive-session` answers a report with "Fold these in." and lets the known
  limits ride to the report.

**Eval** (`~/dev/skill-evals`, runs `sr-earned-1023a`…`e` on the mini; new case
`pr-9567-earned`; arms `current-1022` (this skill at `1d509a6`), `earned`,
`earned-v2`, `control-1022`).
- **Grading.** OpenRouter refused every judge call with 403 "violation of
  provider Terms Of Service", for every model, including a bare "hi"; key
  usage was $99 of $1,000. So blind subagents graded instead: arm names were
  scrubbed and letters shuffled, against each case's own Checks. This is one
  grader per case, and an Anthropic model judging Anthropic answers.
- **#9567, 2 turns** (the report, then "Fold these in. Before you change any
  code, write out the plan…"; n = 3, control 1):
  - The re-entry guard was left unbuilt in current 1 of 3 runs (built in 2),
    earned 3 of 3, and earned-v2 2 of 2.
  - The cgroup page-cache arithmetic was built in no run. The cgroup leg was
    deleted in current 0 of 3, earned 2 of 3, and control 1 of 1.
  - The earned worker-loss bound was found only by the hinted control (0 of 3
    in each realistic arm). The check measures where a reviewer looks, so the
    case cannot score a loss of earned findings. All 7 case verdicts fail on
    it.
- **Regression on the four older PR replays** (n = 2 per arm):

| | current-1022 | earned |
|---|---|---|
| checked defects named (8 runs) | 24 | 24 |
| fix checks held | 3 / 8 | 8 / 8 |
| case passes | 1 / 8 | 5 / 8 |
| handling asked for cases the report calls unreached (grader count) | 5 | 2 |
| key defects filed as unreached, a known limit or wrong | ≥3 (#8959) | ≥8 (#8948 3, #8858 1, #8959 4–5) |

- **The over-correction.** In `earned`, a reachable key defect sometimes landed
  in the lists: #8948 K5 and K7 as "Nothing known reaches it", #8858 K7. Under
  the first fold-in contract it would not have been built. earned-v2 required
  a `none` to name its cover, sent an uncovered serious case to investigate,
  and had the fold-in settle the investigate list.
  - **Result on #8858 and #8948 (n = 2):** checked defects 5, 2 and 1, 3,
    against earned's 6, 3 and 4, 4 and current's 4, 2 and 2, 2.
  - **Misfiling did not drop.** Reports named a wrong cover ("A reservation
    lives one turn, so this isn't reached", #8948 K7). One filed a reachable
    defect as a known limit because "the base behaved the same" (#8858 K5).
  - **The current skill misfiles too, in the old format.** It lists key
    defects under "checked and found correct": four in one #8858 report,
    three in #8959.
  - **What shipped:** earned's wording plus two lines from v2, the fold-in
    settling each investigate item by its observation, and a pre-existing
    reachable case staying a finding. Those two lines are untested.
- **weighs-added-tests** (n = 2): every run passed in both arms. Named
  correctness findings carried: current 3 and 1, earned 2 and 1. Handling
  asked for an unreached case: current 1, earned 0.
- **Limits.**
  - 2–3 runs per arm.
  - One grader per case.
  - transcript.txt truncates the 9567 reports, so the 9567 grading read the
    plan.
  - The shipped text is earned plus two untested lines.
  - The skill grew from 143 to 218 lines, longer only where the named gap
    was filled: two lenses, two lists and their examples.

**Deliberate keeps.**
- "Report every problem" stays: the known limits are reported, not dropped.
- Severity stays consequence-based.
- No `review-lens.md` stance.

**Next comparison.** Real uses after this commit, read through the class tags
and the fold-ins:
- In a fold-in, `none` items stay unbuilt and investigate items get their
  observation run. Watch whether any item later found reachable had been
  filed as a known limit, which is the over-correction.
- The share of review-driven lines classified unearned, by the same
  definition, on PRs merged after this commit, against the 15% here.
- Whether the user still types holistic fold-in instructions or prunes the
  lists by hand.

Revise if a known limit later proves reachable and costly, if real findings
drop below the v2 yield, or if the lists grow past the findings.

**Pending.**
- `pl-handle-code-review` (PlanLab) has no "real but unreached" disposition.
  Its "pin it red first" accepts a constructed input, and 11 threads merged
  untriaged in #9126 and #9128. This is the user's decision, as above.
- The Grok `drive-session-test` dogfood: this terminal has no Accessibility
  grant (AXIsProcessTrusted false), and the bot has no webhook. The message
  to send it is in this session's closing report.
- OpenRouter's 403 blocks skill-eval judging on the mini.
