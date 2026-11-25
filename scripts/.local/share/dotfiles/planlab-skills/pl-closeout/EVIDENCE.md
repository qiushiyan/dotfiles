# pl-closeout — evidence log

The closeout after a Planlab merge: this skill, its check script, the
overlay that installs it, the hook `claude/.claude/hooks/closeout-owed.py`,
and the `merge-when-ready` and `closeout` keys in planlab's `.tabtype.toml`.
Loopy's production half is the team skill `pl-loopy-handoff-distill`, whose
history is planlab's `.agents/skills/pl-loopy-handoff/EVIDENCE.md`; the
entries before 2026-11-24 are there.

## Decisions that stand

- The merging session closes out, without being asked, and the closeout owns merged → serving: it releases what the merge needs, by the release rule `merge-when-ready` used to carry (11-24). 10 of 46 PRs a session merged itself got no closeout: 6 after the user's own merge ask, 4 after a driver's hand-written step, none through `merge-when-ready`, six of them docs PRs; their last messages deferred on "once it's live" (1), cited the user-only rule (2), asked permission (1), or said nothing (6). (Corrected 11-24 by review r1; the first entry read all 10 as freeform asks.)
- Personal by where it lives: the skill sits in dotfiles and the overlay links it into the operator's planlab sessions; the team skill keeps its name and stays manual-only (11-24). A rename would have stopped Steward's in-flight closing reads, which resolve the skill in each task's own worktree, as `skill-unusable`.
- Only what reaches a person waits: a tagged `#loopy` post and a reply to a reporter. Brief verdicts, triage causes, verdict comments, deploys and cleanup are defaults with their undo (11-24). 6 of 6 held brief or worktree verdicts were answered yes in 62 closeout reports, with no later undo; announcements were skipped 5 and changed 5 times of 25; the one reversal was a customer reply.
- The trigger and the typed fallback name the skill's file, so a session the overlay did not launch can still run it (11-24).
- The check holds the one path → domain map; the skill names domains, never paths (11-24). A path it cannot place leans toward serving, since a needless serving read costs one call and a missed release ships nothing (review r1).
- drive needs no skill root: the `closeout` key opens on prose, so no step types `/pl-closeout` (11-24, review r1; `skill_roots`, drive `fa0fb23`, reverted).

## Open comparisons

1. **Missed closeouts.** Merged PRs whose branch ran `pl-loopy-handoff`, with no closeout signature (`brief closeout <head>`, `owed_reads.py … --pr N` without `--ref HEAD`, or a `closeout_check.py N` run) by 7 days after the merge. Baseline 10-20 → 11-24: 12 of 71; 10 of the 46 a session merged. Target: 0 of the next 20 a session merges. Reverse: a closeout the user undoes, or one that released against their wish.
2. **Typed closeouts.** User turns that start a closeout by hand (the `closeout` key or a typed ask). Baseline: 77 in five weeks. Expect only merges made outside any session. Reverse: sessions closing out PRs nobody merged, or the hook's reminder ignored in three sessions.

## 2026-11-24 — the closeout becomes the merging session's own step

**Ask**, the user's: make the post-merge step automatic rather than a skill
they remember to type; then generalise it past Loopy (Taodesk, Bench), keep
it personal, and give the model a trigger and short instructions it
discovers. Session `108a73d0` (mini2); consult `consult-r1` (Fable), whose
answer is in that session's scratchpad.

**Corpus.** Obelisk on mac, mini and mini2, `source='claude'`, self,
sidechains and continuation summaries excluded, 2026-10-20 → 11-24; GitHub
for the user's 268 merged PRs. Predicates, counts and receipts: `ledger.md`
in the session's scratchpad.

**Findings.**
- Every surface handed the step to the user: the team skill was
  `disable-model-invocation`, `pl-loopy-handoff` § Close and `HANDOFF.md`
  step 5 said only the user runs it, `merge-when-ready` ended "then stop …
  its own step".
- 104 closeouts, 77 typed by the user. Of 71 PRs whose branch ran the
  docs handoff, 12 never closed out; of 59 that did, 15 waited over an hour
  after the merge and 7 over 12 hours. A closeout runs a median 6 minutes.
- What closeouts do, of 103: the brief folder 97%, owed-read listing 92%,
  cleanup 80%, announcement 74%, serving 71%, the changelog 58%, production
  reads 54%, verdict comments up to 39%, triage causes 38%, a Bench card
  37%, a driven thread 30%, a docs PR about 10%.
- Taodesk closeouts carried the user's own "deploy over vercel and migrate
  if needed" three times in two days: the closeout knew Loopy's surfaces
  only.
- Leftovers also came from the cleanup's own rule: 4 of 5 closed-out
  worktrees still on disk held on "the local tip is not the merged PR's
  head", whose `--keep-branch` removal the sweep left for the user, and
  whose digest hid the hold.
- `land-wait.sh --merge` ran in the background 195 of 228 times since
  11-01, so a merge's result arrives as a job's wake, not as output a hook
  can read.

**Changed.** This skill, its notes and `scripts/closeout_check.py`; the
overlay's `personal` skills and its note "After a PR merges"; the hook;
`distill-handoffs` § What waits (one held verdict left) and its step 6 (run
the keep-branch removal, delete a branch whose `git log` is empty; the
digest shows the hold); `skill-sync` reads `planlab-skills/`;
`drive-session/PLANLAB.md` (the merge step closes out under `release`);
`docs/session-pipeline.md`, `docs/doc-loop.md`, `docs/planlab.md`; drive
`fa0fb23` (`skill_roots`). In planlab: the team skill trimmed to Loopy's
production half under its own headings, `pl-loopy-handoff` § Close and
`HANDOFF.md` step 5 point at the closeout after the merge, and the two keys.

**Not taken.** Renaming the team skill (Steward, above). A `--wait serving`
background wait: under a driver's release hold it would block the release
it waits for. `brief start --open` through the overlay: the file path in
the hook and the key covers the closeout without it.

**Fresh reader** (revise-prompt's pass, a subagent with none of this
session's reasoning). Folded in: the done line could never be met (`judge`
lines never clear), now "no line reads `owes`, and the report carries each
`judge` and `waits` line"; `docs/loopy/`, `docs/taodesk/` and `docs/steward/`
had mapped to serving domains, so a docs-only Loopy PR would have released
the app; untagged `#loopy` posts follow the team rule (an internal change's
goes, any other waits) rather than all going; the check names Loopy's
records; Taodesk deploys from a clean `origin/develop` (the deploy uploads a
working tree) and stops on a destructive migration; a false "write the
changelog entry the deploy skill asks for" is gone; a `hold` line sits on the
branch step, after its checkout's `--keep-branch` command, in this skill and
the sweep; the note says the worktree goes last, since `pl-land` removes it
after a merge; the team skill's hint, Steward's mode by its words and its
done line; a stale `§ 2` pointer; the driver's personal-tool hold example.
Not taken: moving the two keys to `.tabtype.local.toml` (planlab keys live in
the committed file by `docs/planlab.md`, and only the user runs TabType).

**Verified.** Tests: `test_closeout_check.py` (28), the overlay's suite with
its personal-skill case (52), `closeout-owed.test.zsh` (25, Python 3.15 and
3.9), `pr-stage-check.test.zsh` (174, the shared lexer), drive's `make
check`; `skill-sync --check`; planlab's `check-agent-layout.py` and
Steward's `obligations.test.ts` and `skills.test.ts` (28). By running: the
check on #12139; the hook against real `gh` on #12139 with a throwaway state
directory (recorded, reminded once, then silent); a headless `claude -p` with
the overlay's arguments listed `pl-closeout` with its description.

**Eval** (`skill-evals` `cases/pl-closeout`, written before the edits, red =
planlab `662102595d8`, dotfiles `946e985d`; runs `pl-closeout-1124` and
`pl-closeout-1124-rewrite` on mini2, 3 runs an arm, 3 judge passes). The
control passed every check after the requests said nothing is reachable
from the rollout (the first control explored an empty home and ran out of
turns). Passes of 3, red → candidate: merge-and-close-out 0 → 3 (the hook
arm 2, its miss asking about a lockfile change not the session's); Taodesk
0 → 3; rewrite applied as a default 0 → 3. The first rewrite run gave each
arm only the sweep, and the candidate chose a Note (0 of 3); with each arm's
Loopy brief rule beside it, as a real closeout reads it, red held the rewrite
3 of 3 and the candidate applied it 3 of 3. `keeps-foreign` passed in every
arm, so it separates nothing. Untested: a live merge through the hook in a
real session, and the driver's merge step closing out under `release`.

## 2026-11-24 — revise-prompt's pass over every surface the build touched

**Ask**, the user's: review and revise the model-facing surfaces with
`revise-prompt` and `writing-for-agents`, new text included, proving fixes by
reading or a behaviour case. Same session.

**Findings and fixes.**
- The check's output was the weakest surface: a PR with no owed-read marker
  read as "owed reads unread" (`owed_reads.py` says so on stderr and exits 1,
  as it does on a crash, so the check now reads stderr for its own words);
  the candidate-briefs line printed `owes` after the sweep had judged them,
  so the done line could never be met (now `judge`); `packages/dev-host`,
  `packages/lane*`, `packages/planlab` and `infra/devpool` fell under the app
  and would have released it (now tooling); nothing pointed at
  `domains/tooling.md` (now a line); the title ran into "merged"; an unnamed
  read printed its whole id. A legend of the four states ends the output, so
  the skill defines none.
- The skill stated the migration gate twice, the worktree's last place
  twice, and restated what the check prints for a docs-only merge; the done
  line now allows an `owes` line left with its reason. `app.md` lost a
  driver-hold sentence that changed nothing and a confirm step the check's
  rerun covers; `loopy.md` lost "the check reads both"; `taodesk.md` now
  reads deploy, then order, then the stop; `handoffs.md` stopped restating
  the sweep's step 7. Body 585 → 479 words, total 852 → 719.
- The overlay note narrated a mechanism ("pl-land's removal … waits"); it
  now says to leave the worktree to the closeout. The hook's last sentence
  restated the skill's description; cut. The overlay printed "1 personal
  skills".
- The sweep's "Empty, delete the branch" dropped grammar to save words.
- The team skill's opening tangled who runs which part; `merge-when-ready`
  said "ship it" and asked for what each surface serves, both the closeout's.
- `docs/planlab.md` claimed the closeout holds only posts and replies.

**Verified.** By reading, each surface whole. By running: the check on
#12460, #9081 and #12139 after the fixes; its tests (31, a crash and a
no-marker case among them), the hook's (25), the overlay's (52). The three
behaviour cases on the revised text, run `pl-closeout-1124-pass`: candidate 3
of 3 on each, the hook arm 3 of 3 (2 of 3 before).

## 2026-11-24 — review r1 (Neon, full, cold), all four repositories

**Ask**, the user's: have Neon review the whole implementation. Job
`review-r1` (`agy-gemini-4-neon`); its brief and result in the session's
scratchpad, `review/`.

**Method findings, checked.** Of the 10 missed merges, 4 were a driver's
hand-written step and 6 docs PRs (confirmed from `r14.json` and the PR
titles; the decision line above is corrected). The 104 closeouts are the
ledger's predicate; earlier rounds counted 111 (mini 37) by one the rounds
do not keep. The three Taodesk examples are mini's, 10-14 and 10-15, before
the window, since the query failed on mini2. The eval cases test a session
holding the text, not one discovering it.

**Findings fixed**, each pinned red first where it was behaviour:
- F1, the hook missed `gh pr merge` with a flag's value before the number,
  a `land-wait.sh` run through a shell, and a worktree removed before the
  turn ended (H10–H12).
- F2, the check called a merge surface-free when its paths were unread,
  unmapped or infrastructure (C10); `AGENTS.md`, `CLAUDE.md` and `README.md`
  are not runtime wherever they sit, and `services/wiki-relay/` ships with
  the app (C11). Rebutted in part: `packages/loopy-eval` and
  `loopy-research-campaign` are in the app's runtime dependency closure, and
  the other packages named are left on the app, where a wrong guess costs a
  serving read.
- F3, `pl-deploy-steward` is manual-only and the overlay hides
  `pl-taodesk-tickets`; the skill says to read a team skill that will not
  load from `.agents/skills/<name>/SKILL.md`. The Bench point stands too:
  `ACK_INTERRUPTION` is that migration gate's override, which
  `pl-deploy-bench-prod` both allows for a false positive and keeps for a
  person; § What waits makes the closeout ask (round 2 corrected the
  rebuttal round 1 gave).
- F4, a fetch that failed read as no marker (C12); an error answered as JSON
  crashed the check or read as no brief (C13); a retired brief owed forever,
  and a cleanup step's note was dropped (C14).
- F5, simultaneous launches in one checkout raced on the link and dropped a
  session to the team setup; a repository skill sharing a personal skill's
  name would be hidden (O13).
- F6, a check run before the merge marked its closeout begun (H13); the
  record's writes are locked and their temporary file is the process's own.
- F7, `skill_roots` reverted (above). F8, the sweep's deferral named any
  repository skill that mentions it, which after this change is only
  `pl-loopy-handoff`: it now names the project closeout that runs it, and
  says the sweep runs alone from inside it; `doc-loop.md` says which defers
  to which; `domains/taodesk.md` no longer credits `pl-deploy-taodesk` with
  its `origin/develop` rule. F9 left: Rex shows a continued turn as done
  until its first tool call, and drive reads turns from the transcript, not
  from Rex. F10, Stop writes only
  what changed. F11, § What waits names a gate a domain note or deploy skill
  keeps for a person, so the migration detail lives in the notes.
- F12–F16, tests: the Stop envelope parsed, the wiring and two PRs (H14,
  H15); the check's command line, its checkout, and each state's line (C15,
  C16); every command it runs is one of its reads (C6, an allowlist).

**Ideas.** Built: the undo names the commit `brief sync` printed. Not
built: each open read's predicate on its check line, since the Loopy note
sends the session to the team procedure that prints it.

**Cut beside the fixes**, each restating text the reader meets where it
acts: `cleanup.md`'s hold paragraph (the sweep's step 6), the domain notes'
list of the Taodesk deploy's checks, the Loopy note's reply rule (§ What
waits). Total 719 → 688 words.

**Round 2** (`review-r2`, the same session): every round 1 fix integrated.
New: the cut hold paragraph left `cleanup.md` pointing at the manual-only
sweep by name, which a merge with no brief reaches without having read
`handoffs.md`; it now names the file. Rebutted: "the undo idea was not
built", which is `0b545be8`, outside the round's brief. Beside it, the
merge case's `holds-only-outward` had slipped to 0.78 across this day's
edits, one rollout in three offering the user a force-removal of a worktree
holding someone else's change; `cleanup.md` now leaves that worktree "to
them", and the rerun (`pl-closeout-1125-owner`) passed 3 of 3 at 0.89, the
one failing judge pass calling the extra ask minor.

## 2026-11-25 — the migration gate's override is the user's standing word

Both team deploy skills said an override of a clearable false positive "is
fine" beside the bold rule that only a person's explicit instruction sets
`ACK_INTERRUPTION`; planlab #12497 keeps the bold rule and has the session
recommend. `domains/app.md` overrode on its own authority, so it now names
the user's standing instruction (`docs/session-pipeline.md` § Who decides)
as that word and has the reason quote it; `domains/bench.md` takes the same
rule.
