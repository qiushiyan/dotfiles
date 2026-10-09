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
