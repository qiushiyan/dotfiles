# strategic-review — evidence log

One entry per pass. Counts carry their predicates so the next pass can re-run
them; raw outputs lived in the named session's scratchpad and are not durable.

## Decisions that stand

Each with the entry that holds its evidence. A pass that would undo one
reads that entry first.

- **The standards are read in full and the report carries every problem the
  reviewer can point at code for**, with no "fewer, heavier findings"
  stance (10-07: the paraphrased version found 14 where the manual review
  found 36).
- **The Tests lens weighs both ways**, and a fold builds its tests from the
  lens, not one per finding (10-09: 0 of 3 → 3 of 3).
- **No second model consulted from inside the review, and no lens of
  outside fields** (10-14, 10-17: replays flat on the defects aimed at).
- **The build session writes the review's opening prompt**
  (`strategic-review-brief`; 10-14: its paragraph about doubled the hard
  misses found).
- **No report before every area has returned**, and no wakeup prompted with
  the skill command (10-14).
- **Earned handling reads both ways**: `reaches:`, Investigate, Known
  limits (10-23).
- **The fold is read before it ships.** A wholesale cut of the body to
  1,615 words regressed its cases and was reverted (10-28).
- **A driven review folds on its own recommendations; by hand it stops at
  the report** (11-10).
- **No ownership sentence at the fold** (11-12: no effect), and no closing
  rule for the fold (the user, 11-12).
- **The opening read is one script** (11-16).
- **A lens on what the next change copies**, with the steering lesson
  (11-16). It stays on every kind of PR: 7 of 9 reports after it carry
  next-change findings, UI PRs included (11-19).
- **The build session's brief guides; it does not classify.** No kind or
  surface label in the brief, the digest or the report; the skill reads the
  brief as leads that can add a check and never narrow the lenses (11-19,
  the user's call: PRs are hybrid).
- **A check that meets the change as its user does** runs by `USE-CHECK.md`
  beside the area reads, and a non-trivial UI or UX change gets the emil
  design skills, asked for by the brief (11-19).
- **An unrun check is not a known limit.** It stays under investigate; one
  the verdict rests on leads the report and holds the merge (11-19).

## Open comparisons

Each is a measurement a pass can run. The first is this log's newest.

1. **Use checks, after 11-19.** Briefs that ask for a check meeting the
   change as its user does, reviews that run it, and what only it found
   (first live use, #11858: the preview master's missing S3 grants, a
   driven focus bug). Baselines: the user's hand asks for a UI, Emil or
   dogfood pass after a report, about 7 of 106 review sessions; typed
   additions to a hand-sent brief, 4 of 31; Emil asked for mid-review, once
   on 11-19. Reverse the step-3 check if ten that ran find nothing the area
   reads did not.
2. **Brief length and pointing.** New-snippet briefs ran 289–360 words
   against a 300 cap, and one of two judges saw them point at one fewer of
   five real-review findings (11-19). Watch what later rounds find on
   briefed reviews; tighten the snippet if misses rise.
3. **Unrun checks that lead a report:** how many, whether the driver relayed
   them (`PLANLAB.md`) or merged past them.
4. **Steering, after 11-16:** registries, guards or lint rules the lens asks
   for that a later review deletes as unearned would reverse it. (Reports
   carrying next-change findings, answered 11-19: 7 of 9.)
5. **Live folds since 10-28:** faults CI or the bots find after the fold's
   own round, and known limits that later turned into incidents.
6. **Driven reviews since 11-10:** how many stopped before the fold (target:
   only on a finding with no recommendation), and what the read of the fold
   found, against the unread folds of 10-28.
7. **Fable at `xhigh` against `high`** on `pr-8858` and `pr-8959`: what the
   extra third of cost finds (11-10).
8. **Review-driven lines classified unearned** on PRs merged after 10-23,
   by that entry's definition, against 15%.

Retired: 10-07's yield against the manual prompt and 10-09's measures
(answered on 10-09 and 10-14); 10-14's briefed-against-bare comparison on
live uses (the replay's builder arm answered it, and the brief is now sent
by default, so live bare reviews are no longer a fair control); 10-17's
field charters as subagents (not adopted, untested); whether the 11-16
script changes what reviews find (it changed the opening read only).

## 2026-10-07 — the skill's origin, and two rehearsals against the manual prompt

Session `mini:8ae01ce4` (an `/improve-tool` pass, then `/consult`, then a
replay and two rehearsals).

**Request.** The user had begun opening a fresh session for the few Planlab PRs
big enough to warrant it, with a short prompt: read what the PR is for, then
review it against prompt-engineering, thermo-nuclear and codebase-design. They
asked where that belongs, how to make reviews better on the first attempt, and
what reviews teach upstream. The in-session `/review` stays on every build;
this review stays manual and selective (the user's decision).

**Corpus.**
- Obelisk, both machines, first user turns since 08-01 that ask for a review of
  a PR or branch: two Planlab PR reviews of this kind, both on 2026-10-06.
  - `d51febff` (PR 8616, zip archives) and `1a990a25` (PR 8620, bounded
    search) both ran after the branch's codex full review and round 2 had
    converged.
  - 8616's manual review found 5 bugs, about 8 model-facing problems and a
    duplicated read queue. The user folded all of it in, and the rebuild
    deleted the codex-round fix `e773533ab4` (`3535c15246`, −700 lines in
    `archive_view.ts`).
  - 8620's manual review was followed by 11 fix commits (`3690cbf8cd..f637d4981d`).
- Envoy job store on the mini, 2026-09-24 → 10-06: 33 Planlab code-review
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
- **Planlab map.** Intent first now names Planlab's map: read
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
  - 8 Planlab PRs (8677 8680 8675 8758 8806 8809 8859 8857) and gazette.
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
  - 37 Planlab PRs merged 09-23 → 10-22;
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
  Planlab's skill, in a repository shared with teammates.

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
- `pl-handle-code-review` (Planlab) has no "real but unreached" disposition.
  Its "pin it red first" accepts a constructed input, and 11 threads merged
  untriaged in #9126 and #9128. This is the user's decision, as above.
- The Grok `drive-session-test` dogfood: this terminal has no Accessibility
  grant (AXIsProcessTrusted false), and the bot has no webhook. The message
  to send it is in this session's closing report.
- OpenRouter's 403 blocks skill-eval judging on the mini.

## 2026-10-28 — the fold-in gets read; a wholesale cut that did not hold

**Mined** (obelisk, both machines, every use since the 10-23 change: 16
completed, 12 Planlab and 4 itell, 8 driver-sent; scratch scripts): reports
followed the skill closely (`reaches:` and known limits 15/15, investigate
14/15, no report before its areas returned 0/15, known limits never built
0/16). Median 39 minutes, about 360 subagent tool calls, 4,088-word reports.
What hurt was after the report:
- Fold-ins went unread: CI, Codex, or CodeRabbit found faults in the fold's
  own code in at least 5 of 11 pushed folds (`1716fb2f`, `75b67e11`,
  `3dd27fb7`, `ab92c50e`, `8357d67c`), and every fold added more lines than
  it removed (+23.3k/−14.0k over 11). On #9989 the fold built guards for the
  bypasses its reviewers had planted; the second review filed that rule
  (87 → 333 lines, 0 real occurrences) as unearned handling.
- Only 6 of 15 reports stated CI; `936e3ba8` missed a red CI of 53 tests.
- A known limit ("no per-story deadline") turned critical within hours
  (`8ac288e1` → `3034da84`, 11 of 33 dogfood runs).
- All 3 typed replies to held decisions deferred to the recommendation.

**A wholesale cut did not hold.** A rewrite to 1,615 words (all four
additions, the other lenses compressed; a parity read restored 8 losses
first) was replayed against `2d96259` on two cases, n=3, judge Claude
Sonnet 5.5 (`sr-1028-*`): pr-9567-earned cgroup left unbuilt 3/3 → 1/3 (the
fold built page-cache accounting as a critical), limit recorded 2/3 → 3/3,
settle bound 0/3 → 1/3; pr-8955 defects found 13 → 11 of 24 checks and
prescribed fixes right 6/9 → 3/9. A case that passed started failing, so it
was dropped; it is kept as scratch, not shipped. This skill was tuned
against these cases, and its long lenses carry behavior a cut loses.

**Changed instead, a focused repair:** step 1 reads CI status (a red check
is a finding or a flake shown by evidence); the fold-in holds its own fixes
to the earned-handling bar and, with push rights, gets one CI-and-bot round
before reporting, or says it is unread. Replayed on pr-9567-earned (n=3,
`sr-1028-pr-9567-earned-focused`): every check identical to `2d96259`
(3/3, 3/3, 0/3, 2/3); all three runs asked for CI. The body grew 2,039 →
2,161 words; its record was raised by hand with this reason.

**Not added:** a bound on work that can stall is never a known limit (one
incident; a reader predicted findings asking to bound every await), and
making engineering calls instead of holding them (deferral was 3 of 3, but
the cut version that carried it built more). **Next pass compares** live
folds after this commit: faults CI or bots find after the fold's round,
reports stating CI, and known limits that turn into incidents.

## 2026-11-10 — a driven review folds on its own; the fold is read before the merge

From an improve-tool pass over the session pipeline (mini2 `427f5995`; its
scratchpad holds `ledger-A.md`, `ledger-C1.md`, `ledger-C2.md`).

**Corpus.** Seven strategic reviews among 8 sampled PRs merged from drive
batches 11-02, 11-06 and 11-09, read from the review sessions' reports and
the PRs' commits; the bot's `sends/` in those batches; 13 hand-run reviews
in planlab sessions 10-25 → 11-10.

**Observed.**
- **Yield.** A behaviour defect found in 5 of 7 runs and a reshape in 7 of
  7; the fold is 13 to 41% of a PR's line changes, median 23%, and near
  net-zero in lines (+1,363/−1,126, +942/−969). Median 40 minutes to the
  report, 92 for the fold. Four reports say earlier rounds patched one
  premise (#10555, #10468, #10800, #10453).
- **Where the review round was skipped** (#10804, #10800, #11027) the
  strategic review found the behaviour defects by probe: the bug the PR
  exists to fix still occurring in a variant; a held draft disappearing
  after an `ask`; a dead worker's text read as a reply.
- **The stop before the fold.** Driven, it is always answered "Fold these
  in": 15 sends across 12 sessions, each extended by hand with the same
  riders (an independent review of substantive fixes, the applicable prompt
  check, a docs pass, do not merge). By hand, 11 of 13 answered "fold … in",
  7 bare and 4 with an amendment, and 2 did not fold; three declined the
  published page.
- **The fold's own check had gone stale.** The skill told the fold to wait
  on `gh pr checks --watch` and judge each bot finding; since 11-05
  Planlab's CI and reviewers run only on a label, which the team's
  `pl-land` adds.

**Changed.**
- A review whose first message says someone else sends its steps while the
  user is away writes its report, then folds on its own recommendations. A
  finding it can recommend nothing on stays unfolded and leads the report.
  By hand the stop stays: the user steered or declined 6 of 13 times.
- § Folding: the fold is read before it ships, by a `/review` round over
  its substantive fixes, the prompt check where it changed text a model
  reads, and the project's docs pass; then pushed and settled as the
  project settles a PR, with the merge left as its own step.

**A fresh reader's pass** (revise-prompt's, with none of this pass's
reasoning) found three faults in the new text, all fixed: "write the report,
then fold" would leave the fold's note as the newest reply, which is all a
driver reads, so the turn now ends on the report as it stands after the
fold; "in one round" contradicted `pl-land`'s loop; "the prompt check" was
undefined here and is now revise-prompt's pass.

**Cuts, with what each guarded.**
- "The user opens it only for PRs big or consequential enough…": false
  since strategic review became planlab's default.
- "since past reports lost more findings this way than any other": a
  receipt, kept in the 10-09 entry.
- The Report section's restated `reaches:` line and its definitions of the
  two lists: both are stated in the earned-handling lens. Bring back if
  reports drop the `reaches:` line or the lists.

**Not built: the ownership sentence.** Anthropic's Fable 5.2 guide measures
"This codebase is yours: what it's for and how it's built are your call,
and you'll keep building on it" at about half of tries merging repeated
code against under a tenth, for 1.5 times the output, unrequested
additions, and a changed existing behaviour in one try in six to ten. This
skill opens on the opposite frame ("a pull request that someone else
built"), which suits the report. The fold is where the sentence could help
or hurt, just before a merge. Tested there on 11-12: no effect (that entry).

**Effort on Fable 5.2: no difference once the replay runs as live reviews
do.** The user runs strategic reviews on Fable. Replayed `pr-8948`
(`~/dev/skill-evals`, the skill at the mini's HEAD, report only, Sonnet 5.5
judge with three passes; the runner gained `--effort` and
`--context-window` for this). Answer-key checks passed, of 10, per review:

| the lead's context | `high` | `xhigh` |
|---|---|---|
| 200k, the runner's default: every lead compacted two or three times near 167k | 5, 6, 4 | 2, 2, 3 |
| 1M (`claude-fable-5-2[1m]`, `--context-window 833000`): no lead compacted, peaks 360k to 475k | 4, 5, 2 | 5, 5, 3 |

Live reviews run as the second row: of the 12 on planlab from 11-01 to
11-10, six never compacted (peaks 479k to 748k) and the rest once, at 460k
or more. So the first row's gap belongs to the replay. There every `xhigh`
lead compacted once before it dispatched its areas and again before it
wrote, and the reports were written from summaries: the area reviewers had
found the ten defects 15 times against 13, and the reports carried 13
against 8 (trace of all six in that session's scratchpad, `sr/funnel.md`).
At the live window three runs a level cannot tell the levels apart (3.67
against 4.33 a run); `xhigh` took 35 to 48 minutes against 37 to 38 and
cost about a third more ($20.42 against $15.55 a review). Both rows found
K2 and K3 every time and K19 never.

On the first row alone the user set `claude-fable-5-2` to `high`, with
`drive open --effort xhigh` for a review they want at `xhigh`. The second
row neither supports that nor overturns it. Runs `sr-fable-high-1110`,
`sr-fable-xhigh-1110`, `sr-smoke-window` (200k, `high`, one compaction: 5),
`sr-smoke-window-1m` (the first `high` at 1M), `sr-fable-high-1m-1110`,
`sr-fable-xhigh-1m-1110`.

**Next pass compares** driven reviews that stopped before the fold (target:
only on a finding with no recommendation); bot steps that still carry the
fold riders (target none); and what the read of the fold found, against the
unread folds of 10-28. And Fable's effort at the live window on a second
and third replay (`pr-8858`, `pr-8959`): what `xhigh` finds beyond `high`,
against a third more cost.

## 2026-11-12 — the ownership sentence at the fold: no effect; every fold under-reports and repeats one fault

**Ask.** The user: run the fold test the 11-10 entry deferred, shaped by
our own view of the problem.

**Design.** `~/dev/skill-evals` tool `strategic-review-fold`, run
`srf-ownership-1112` on the mini. Each rollout forks one of the two Fable
reviews of `pr-8948` from run `sr-fable-high-1m-1110` (`claude-fable-5-2[1m]`,
`high`, 833k window) right after its report, and answers "Go ahead and fold
all in." with the day's setup; the review, prompt and docs passes are cut,
the same in every arm. Holding the report fixed measures the fold, not the
review: rerunning the review per rollout, as the 11-10 plan had it, puts the
spread between reviews into the arms. Case a's report asks no design
question; case b's F1 asks to delete the pull reservation and its migration.
Arms, words before the request: `base` none; `owner` the guide's sentence;
`owner-change` "The code this pull request touches is yours: how it's built
is your call, and you'll keep building on it." n=2 per arm per case. The
runner gained `export` (commit `ea3672d`): each rollout's diff against the
review's head is kept and read by the judge, `codex:gpt-6.1-terra` with three
passes (the mini's Claude judge login had lapsed).

**Result: the sentence moved nothing.** Per arm, mean over four rollouts:

| | base | owner | owner-change |
|---|---|---|---|
| files touched (a / b) | 36 / 48 | 38 / 51 | 35 / 46 |
| lines + / − (a) | 1188 / 861 | 1184 / 927 | 1215 / 896 |
| lines + / − (b) | 1626 / 1696 | 1605 / 1736 | 1496 / 1634 |
| output tokens | 344k | 364k | 372k |
| agent $ (API estimate) | 41.71 | 47.07 | 41.48 |

Checks, share of judge passes, cases a and b pooled: `beyond` (a change no
finding asked for) 1.00 in every arm; `merged-unasked` 0.75, 0.92, 0.67;
`unasked-behaviour` (no behaviour changed outside the findings) 0 in every
arm; `told` (the closing message names every change) 0 in every arm;
`fold-faults` 0 in every arm. Every 90% interval of a group against `base`
spans or touches 0. Every b rollout took F1 (about 1,700 lines deleted) and
said why. The guide's effect, merging repeated code in half of tries against
under a tenth, does not appear because the baseline already merges: this
skill's § Folding (reshapes and deletions first, every finding folded, one
commit per owner) already does what the sentence does, so the sentence goes
nowhere, here or in `drive-session/NOTICE.md`.

**What every arm got wrong**, from the judge's evidence, checked against the
diffs:
- **The closing message leaves out changes, 12 of 12.** A new test file, an
  extracted helper, a changed folder name in a result, a new queued note:
  the guide's warning ("its closing summary named the larger changes but
  often left out small ones"), with no ownership sentence needed.
- **Behaviour changes outside the findings go unnamed, 12 of 12**: pull
  consumption no longer stamping its turn index, `isDeliveryReceived`
  accepting every `assigned` row, recollection limited to conversation runs.
- **Every fold repeats r3 F2.** None of the 12 diffs passes a publication
  budget into the lookup (the `settleWithinMs` fix that held); 11 add a grace
  timer around a loop whose lookups each await `publishChildTerminal` with no
  deadline. The `/review` round after the fold is what caught it in the real
  PR, so that round is load-bearing.

Not tested: a build from a spec, where the sentence might act where no
fold instruction stands in for it; a second PR. Leaks: three rows each
matched a pattern on a syntax check, a `git status` and a look for
TypeScript in the real checkout's `node_modules`, none of later history;
kept.

**Not pursued (the user, 11-12):** a closing rule for the fold, built from
the diff rather than from memory. If picked up, test it on the same forks:
`told` and `unasked-behaviour` against these `base` rows.


## 2026-11-16 — the opening read becomes one script

Session `mini2:443dcb52` (an informal pass at the user's ask, not an
`/improve-tool` loop).

**Request.** The first call of a review is usually a wide `gh pr view`
dumped through `head -c 20000`; the user asked for a tailored snippet that is
easier to read and cheaper, and for any other friction in the review.

**Corpus.** Obelisk, Claude sessions since 10-25 whose user turns hold
`<command-name>/strategic-review`: 34 on mini2, 19 on mini (mac not reached).
Main thread only (`is_sidechain` 0); stored results cap at 10k characters,
so character counts are floors.
- The opening, gh and git calls before the first read of a standard or the
  onboarding map: median 5 calls (2 to 11), median 28.9k characters (12.8k
  to 71.2k), over the 52 sessions with more than 10 calls.
- In their first six calls, 20 of 53 ran `gh pr view … commits … | head -c`.
  gh prints JSON keys in alphabetical order, and each commit carries about
  350 characters of author metadata, so on PRs of 20 to 100 commits (commit
  JSON 22k to 107k characters) the cut lands inside `commits` and drops
  `files`, `headRefName`, `title` and `url`; the next calls refetch them.
- In their first six calls, 24 of 53 read the file list through
  `gh pr view --json files`, which stops at 100 without saying so (PR 11443:
  100 of 145).
- Over whole sessions, `gwt --help` ran 29 times and `git worktree list` 148.
- Area subagents (mini2, since 11-01) ran 116 `gh pr view`/`gh pr diff`/
  merge-base calls in 63 subagents; a sample of 30 was mostly the
  description again.

**Change.** `scripts/pr-context.sh` prints one digest and writes the
context file `pr-<N>.md` (description, every commit message, every file);
step 1 runs it, step 3 hands area subagents the file's path, and the rounds
lens reads commit messages there. Measured: PR 11512 9.8k characters in one
call against about 35k over the three calls its session made; 11447 (97
commits, 82 files) 23.8k; 11443 (145 files, by directory) 16.3k. Not tested:
whether reviews find more or less with it.

**Seen, not changed.** Pre-report tool errors are incidental (grep exit 1,
zsh no-match globs, two reads of a whole diff over the 25k-token limit).
Planlab's `pnpm -s review-engine check <pr>` gives CI and open bot findings
in about 900 characters, but only the outstanding ones, so the rounds lens
still reads the threads.

## 2026-11-16 — a lens on what the next change copies, and the steering lesson

Session `mini2:a00a379e` (an `/improve-tool` pass over this skill and the
`strategic-review-brief` snippet: findings, a design the user approved, then
the build and a replay).

**Request.** The user keeps asking sessions, by hand, what code a refactor,
a fix or a redesigned entry point should leave so that later coding
sessions follow it without reading the design: illegal states made
unrepresentable, logic in one home, a layout that shows the layering, entry
points where the composition is evident, lint where it helps. Where should
that live, in this review and beyond it? Verification harnesses were out of
scope.

**Corpus.** Obelisk, all three machines, Claude sessions, main thread, user
turns by MINE.md's predicate. Lexical predicates; each hit read before it
was counted.
- **The ask, typed by hand:** 10 turns in 9 sessions, 10-01 → 11-16, read
  from hits on `future session|future agent|future coding|naturally
  follow|pattern … follow|oxlint|unrepresentable` (mini and mini2 by `LIKE`;
  mac by FTS only, after the `LIKE` sweep timed out there, so mac is a
  floor). Where it was typed:
  - at design, on or beside a consult snippet: `ea20fe91`, `e9437249`,
    `56790c82`, `507b5185`, `mac:a255066d`;
  - framing an initiative or a brief for another session: `d4f11c70`,
    `f15adeac`, `4f5dddcd`;
  - on the strategic-review brief: `e9437249` (appended to the snippet),
    which produced the opening prompt of `091dc313`;
  - inside a strategic review, while it ran: `c49b138a` (#10244).
- **Design-snippet sends** (`Agreeing with the general direction`, since
  10-01, continuations excluded): 113 (mini2 49, mac 27, mini 37); 5 match
  the steering words, 4 confirmed by reading. The user adds it to about one
  design round in thirty, the ones that set a pattern.
- **Reviews:** 103 invocations in 98 sessions since 10-07 (mini 56, mini2
  37, mac 10); 82 sessions hold a report (assistant text over 3,000
  characters with "erdict"). Reports that read the change as a later
  session would meet it (`future session|future agent|next agent|cold
  agent|would copy|will copy|next tool|next author|teaches the|session
  adding`): 2 of 82, `091dc313` and `c49b138a`, both asked for by the user.
  Unasked: 0 of 80. The predicate is lexical: reports do file
  `second-mechanism` and `structure` findings, which look back at the join;
  none walks the next change.
- **Brief snippet:** 20 sends in 19 sessions; 1 carried a typed addition
  about patterns. Of the 103 review openings, 2 hold the word "pattern".

**Findings.**
- **Asked, the answer is specific and gets built.** `091dc313` read each of
  five named patterns "as a future session would meet it", defeated one
  compile guard by relabelling a kind (the guard and its type assertion
  still passed), and its reshape of the one family with a second shape went
  into the fix-before-merge list; the user folded all. `ea20fe91`'s consult
  came back with done-checks grouped "so future code can't reintroduce it"
  (a key without a declared home fails type-check; no exported function
  builds the unsafe value; lint refuses the direct write). `e9437249`
  declined a lint rule because a type and a render test fail in the files
  an author already edits.
- **The standards the review reads hold the pieces, not the reader.**
  `composition.md` prices the next change and names the lava layer;
  `deep-modules.md` has illegal states; thermo-nuclear has the canonical
  layer. None takes the view of a session that searches a name, copies the
  code beside its edit and stops at green, so none is applied that way.
- **The view exists, in one project's docs.** Planlab's
  `docs/loopy/changeability/README.md` § Where a change is steered orders
  eight moments from the landing site to the docs, with tenets 8 and 9 and
  lens 9 (forced and discretionary steps, the cold probe). It reaches
  sessions on Loopy's routes only.
- **Outside practice agrees on the order and adds removal.** pstack's
  `/correct` (read at `cursor/plugins`; `backnotprop/pstack`, which the
  10-23 pass cloned, is its port): architecture, then types, then a lint
  whose error names the fix, then tests, docs last, "prove each check fails
  on a real past mistake", and delete the old way an agent would copy.
  OpenAI's harness-engineering post and five other first-hand accounts were
  read by a subagent, not by this session. No source offers controlled
  evidence on which of two coexisting shapes an agent copies.

**Built** (the user: a lesson, shorter than the first draft, each principle
with an avoid/prefer pair; then "go ahead").
- `~/.config/lessons/codebase-design/steering.md`: seven principles with a
  pair each, a pair for the one-off left direct, the order of mechanisms,
  and how to check a claim. A second research pass (a subagent's read of
  matklad, King, Metz, Ronacher and agent-era posts) gave the facts-against-
  look-alike-code split and what weighs differently when agents write.
- Here: step 2 reads the lesson when the PR sets a shape later changes
  repeat, step 3 keeps that read for the lead, and the lens "What the next
  change copies" asks for the walk, the wrong-path probe, a `reaches:` line
  citing what shows the kind growing, and one example finding tagged
  `other (unforced step)`. No class was added.
- Elsewhere: `consult-design`, `consult-then-build` (with planlab's local
  draft and itell's file), `strategic-review-brief`, `consult/VOICE.md` and
  the spec bar's Design views (`tabtype/EVIDENCE.md`, same date).

**Replay** (`~/dev/skill-evals`, case `pr-11512-steering`, run
`sr-steering-1116` on the mini; Fable 5.2 at the 1M window; judge
`codex:gpt-6.1-sol`, 3 passes, at the user's word, after the Claude judge's
login had expired and a first grading by `codex:gpt-6.1-terra`).
PR #11512 at the head its review read, opened from the builder's brief with
the user's paragraph about patterns removed; dependencies absent, so nothing
could be probed. Per check, share of judge passes over the runs:

| check | control (hinted, n=1) | before (n=3) | lens (n=3) |
|---|---|---|---|
| second-shape (subagent placed apart from the promotion table) | 1.00 | 0.67 | 1.00 |
| guard-weak (the compile guard passes under a relabel) | 1.00 | 0.00 | 0.00 |
| restated-rule (readers restate the promotion rule) | 1.00 | 1.00 | 1.00 |
| next-change-walk (judges a pattern as a later author meets it) | 1.00 | 0.00 | 1.00 |
| kept: failed-push, refused-row, file-size (summed) | 2.00 | 2.00 | 2.00 |
| verdict | 1 of 1 | 2 of 3 | 3 of 3 |
| agent cost a run | $12.10 | $11.98 | $18.20 |

- **The count above undersold the skill.** Unasked, it already finds the
  second shape in 2 of 3 runs and a restated rule in all three, under the
  design lens. The lexical 0 of 80 measured the walk, not those findings.
- **What the lens adds here:** the walk in 3 of 3 runs against 0 of 3, and
  the second shape in 3 of 3. The steering checks rose 1.33 a run (90%
  interval +1.00 to +1.67); the kept checks did not move. Terra had read the
  walk in 2 of 3 lens runs and the restated rule in 0.89 of the runs before;
  the two judges agree on every other check.
- **What it did not add:** the weak guard, which the real review showed by a
  probe this rig cannot run.
- **Cost:** half as much again a run, on three runs each; rollouts have
  ranged $7 to $25, so this may be noise.
- **Limits:** one PR, two judges of one other family, checks written by this
  pass, and the first lens run read the lesson before its first reader's
  fixes (it passed the same checks as the third).

**After a pass by revise-prompt and writing-for-agents** (the user's prompt
check, same day). The gate says "pattern", the user's word, where it said
"shape"; the lens drops a reason the lesson gives and splits a two-part
sentence. Two rollouts of the skill at `3988acd5` (arm `head`, same run and
judge): the walk and the second shape in 2 of 2, the kept checks 3.0 a run,
$19.76 a run. A cold read then added "or a second way beside an old one" to
the gate's kinds (`3203ab3a`), which no rollout has read.

**Read by a fresh reader** (a subagent given revise-prompt and the touched
surfaces, none of this reasoning). It ran the lesson's pairs through a type
checker and found the small-door and registry pairs failing the lesson's own
wrong-path probes, a gate worded six ways, and this lens sending every fix
it asks for to the known limits under Earned handling's `reaches:` rule.
All fixed before the replay's lens runs, except as noted above.

**Not cut.** The body grew 2,165 → 2,395 words and nothing paid for it: the
10-28 wholesale cut regressed this skill's cases. The example finding is the
first candidate if the body must shrink; it guards the class tag and the
`reaches:` form, and reports scattering such findings across classes would
bring it back.

**Open comparisons** are the first item in the list that opens this log. The
comparisons promised on 10-28 and 11-10 were not reached by this corpus.

## 2026-11-19 — the builder's brief as guidance, a check that meets the change as its user does

Session `mini2:9635e033` (an `/improve-tool` pass, a consult round with
Fable, Carbon and Astra, then the build on the user's go). Its scratchpad
held the ledger, the consult data (`consult/`) and the fork test
(`forks/`); not durable.

**Request.** Make the brief and the review fit the change: different
implementations need different focus, and the steering lens seemed suited to
fixes and refactors more than UI. After a first proposal (a kind / surfaces /
repeats line), the user set the frame: PRs are hybrid, the build session has
the best context on what the review needs, and the snippet inspires rather
than classifies. Later, live: a non-trivial UI or UX change gets the emil
design skills, and a brief that does not ask for them is the snippet's
problem.

**Corpus.** Obelisk, mac, mini and mini2 (all reached), Claude, main thread,
2026-10-07 → 11-19. Reviews: user turns starting
`<command-message>strategic-review</command-message>` or holding
`<command-name>/strategic-review</command-name>`: 114 rows, 109 sessions
(mac 11, mini 53, mini2 45). Report: the longest main-thread assistant text
with "erdict" over 2,500 characters before the next user turn; 77 recovered
(driven folds and interrupted runs under-represented). Brief sends: user
turns holding "going to run /strategic-review on this PR in a fresh
session": 31, 28 texts; hand-sent only, since driven sends live in drive's
files (at least 25 on mini2). 89 Planlab PRs labelled by one rater by the
part most at risk.

**Findings.**
- **What reviews find already shifts with the change.** Model-facing is 22%
  of findings on agent-behaviour PRs, 1–2% on UI and runtime ones; ordering
  is 13% on runtime PRs. One rater, a tag parser that drops grouped
  findings, and a disabled dedup: a direction, not a measure.
- **Steering pays where it fires**, UI PRs included: 7 of 9 finished reports
  after `fa27b414` carry next-change findings, most probe-confirmed (#11512,
  #469, #11602, #11785, #11706, #11583, #11863). The user's example of a
  lens unsuited to UI did not hold.
- **The brief was filled as a form.** A patterns paragraph in 9 of 12
  hand-sent briefs once its bullet landed; #469's filed an undriven checkout
  under it; #10969's put every paragraph outside the fence.
- **The skill never said what the brief is** ("a question this PR raises").
- **Reviewers parked what needed running.** About 15–17 of 77 reports list
  under Investigate a check needing a lane, browser, phone, screen reader or
  staging (#10670's iOS Safari at 375px, #11244, #469's checkout), and the
  fold moved what nothing showed reached to the known limits. 0 of 7 UI
  reviews drove the app before the report (#10136's 5 browser calls drove a
  capture controller, not the app).
- **The user supplied use by hand:** Emil at #10670's fold (one fix, a
  phone tap flash), UI/UX typed into #11858's brief, the visual pass on
  #11244; dogfood asks after #11376, #8994 and iTELL #411. #11376's pass
  found two defects present at the reviewed head (`20ff0831421`: the page
  reader printed only a page's entry; meeting "Decided:" lines unrelated to
  the query) and one the fold introduced (`1d7f4a2e74e`: a card-key search
  past `--limit`).
- **Fix PRs are already re-checked by probe** (11-10 entry); nothing added.

**Consult** (`consult-r1`, `consult-r2`; members `codex-gpt-6.2-astra`,
`claude-claude-fable-5-2`, `agy-gemini-4-carbon`; round 1 the data alone,
round 2 our design). All three converged on: no router; the brief as a
form; the skill silent on the brief; use checks not a first-class move.
Round 2 changed the design: an unrun check stays unverified rather than
waiting on the user; the app's bring-up rule contradicted itself;
emil-ui-review is read whole with the README's project exceptions; no
`experience` class (all three; the `other` labels cluster on access more
than UI); the brief names the one check worth most; the test gained a
negative control, #11376 and #10969.

**Changed** (`c5cd0162`, `10a4eeb2`, `993b52fe`; committed locally first and
used live on mini2 while the replays ran).
- `strategic-review-brief`: same opening; everything inside the fence,
  commands in inline backticks; what the reviewer reads anyway; what costs
  most and is least sure; who meets the change and the one check worth
  most, how to exercise it and what stopped the builder; for a non-trivial
  UI or UX change, the emil design skills.
- Step 1: who meets the change; what the brief is. Step 2: emil-ui-review
  on a non-trivial UI or UX change, handed to the UI code's reviewer and any
  walk. Step 3: a check meeting the change as its user does, by the new
  `USE-CHECK.md`; the wait covers every reviewer assigned. Report: an unrun
  check the verdict rests on leads it. Fold: an unrun check stays under
  investigate; UI findings build by `emil-design`'s Finish route.
- `drive-session/PLANLAB.md`: the driver relays such a check.
- Cuts: the test-quality lesson's one-line summary in step 2 (the lesson is
  read whole); the second Known-limits example (the first carries the
  shape); a shorter Planlab onboarding sentence. Bring the summary back if
  the Tests lens stops weighing the PR's own tests. Budget raised by hand,
  2,403 → 2,562 body, 2,752 total.
- A first fresh reader (revise-prompt's pass) found twelve faults, a second
  one walking #11858's phone check found nine; all fixed but two left to
  the project's rules (CI reruns, the Loopy engine on a lane).

**Verified.**
- **Briefs, by fork** (`forks/`): five build sessions cut at the snippet's
  send (#11858 before the user's typed UI line, #11376, #469, #10969,
  #11785), resumed with `--fork-session` in a throwaway config, tools off,
  Opus 5.5 at 1M; old and new snippet, plus four historical briefs; 20
  briefs judged blind by Astra and Fable against each real review's
  fix-before-merge list. A use check asked for: new 10 of 10, old 0 of 10,
  both judges. Padding 0.2–0.3 against 1.0–1.6; mean rank 1.8–2.0 against
  3.0–3.2 of 4. Real-review findings pointed at: Fable 4.7 against 5.7, Astra
  4.0 against 3.9. Every fork kept its focus inside the fence; the
  historical #10969 brief was the one loss. New briefs ran 289–360 words.
- **Parity replays** (`~/dev/skill-evals`, `sr-tailored-1119-*` with the
  first candidate, `sr-shipped-1119-*` at `10a4eeb2`, `sr-red-1119-pr-8948`;
  Fable 5.2 at 1M, high; judge Claude Sonnet 5.5, three passes).
  #9567-earned: 2 of 2 against 1 of 2, checks level or up, a third cheaper.
  #11512-steering: 2 of 2 both; walk, second shape and restated rule held;
  refused-row 0 → 1.00, guard-weak 0.67 → 0 (0 in both 11-16 arms).
  weighs-added-tests: 2 of 2 both. #8948: red 1 of 2 at 2.2 checks a run,
  candidate 2 of 3 at 3.0 and 5 (one `head` rollout retried after the local
  commit moved HEAD and was excluded). Every weighs-added-tests rollout in
  both arms read the real checkout's git objects through alternates: a
  harness leak shared by the arms. At `10a4eeb2`, one rollout each: every
  case passed (#11512's steering checks 3 of 4 and kept 2 of 3; #9567 3 of 4;
  weighs-added-tests; #8948 5 checks). Parity held; n of one or two per arm
  sees a large regression, not a small one.
- **Live, #11858** (`mini2:d42df2ac`): the brief asked for two use checks;
  the review ran both beside five area reads. Its report led with the check
  the verdict rests on: the preview master's role lacks
  `s3:ListBucketVersions` and `s3:DeleteObjectVersion`, so no conversation's
  files publish on any preview (84 overdue publications in 14 days). A
  driven walk found the sheet's close sending focus to `<body>` in four of
  five ways it opens. The first walk met a lane the cleanup had stopped
  when its starting session ended, and the lead's brief forbade `lane up`;
  the lead brought it up and reran. Emil ran only after the user asked
  mid-review, because the standard then rode with the walk alone: fixed in
  `10a4eeb2` and `993b52fe`.
- **Not run:** a re-review of #11376 at its reviewed head. The dogfood's data
  copy was deleted; it needs a local Bench on a fresh production copy at a
  six-day-old head, unsandboxed where the merged PR is one command away,
  and both new briefs named production as the realistic route, which now
  serves the merged code. The next agent-facing tool PR measures it live.

**Not built:** the classification line, path hints and the report's
classification line (the user); an `experience` class (the consult);
splitting reviewers by question (Astra), kept as the lead's choice of who
runs the use check.

## 2026-11-22 — the reviewer reads the build session for its decisions

**Asked** by the user: the brief carries the build session's id, and the
review reads that session with obelisk to judge the decisions in context.

**Changed.**
- `strategic-review-brief`: the fence's second line is `Build session:
  <id>`, read from the environment. Claude Code sets
  `CLAUDE_CODE_SESSION_ID`; Codex sets `CODEX_THREAD_ID` in its shell
  (checked with `codex exec`, 0.171.0), indexed by obelisk as
  `codex:<thread-id>`.
- Step 1: once the intent is written, the build session is read with
  obelisk for which decisions the user made, the alternatives rejected,
  what was measured and what review rounds argued. It is leads, like the
  brief; a finding against such a decision names the session's reason and
  why it fails. Read after the intent statement so the build's framing is
  not the reviewer's starting point.

**Not run:** a replay or live review with the session read. The next driven
strategic review is the first measure: whether its findings against
deliberate decisions cite the session's reason, and whether it drops real
findings because the session argued them away.
