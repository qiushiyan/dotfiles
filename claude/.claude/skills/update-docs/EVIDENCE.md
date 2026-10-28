# documentation standards — evidence log

Usage evidence for `docs/documentation-standards.md`, the shared standard
this skill and `distill-docs` apply. The standard is broadcast verbatim and
kept under ~14 KB, so its receipts live here.

## 2026-09-28 — first mining pass (improve-tool)

**Corpus.** Obelisk index, Claude sessions 2026-06-26 → 2026-09-28. Readers of
any copy (non-edit tool calls naming `documentation-standards`): 683 sessions,
194 since the shared copy began on 2026-09-11. `/update-docs` + `/distill-docs`
invocations: 106, 23 since 2026-09-05, each read to its next two user turns.
Check-block runs since 09-11 (`git diff --cached` plus the grep's pattern):
changelog 82 sessions, cardinal 79, PR/date 75, table 69, status-page loop 41,
post-merge 36. User-voice sweep: user text in doc-touching sessions since
08-20 on history/philosophy/depth terms, 24 hits read in context.

**Findings and dispositions.**

- **The status-page rule contradicted its only user.** planlab #7973
  (`origin/develop` 6894503677b) retired its status pages after session
  4fc50d59 (09-27) measured 14 sessions / 30 conflict hunks, 17 in per-PR
  owed items; that session's standards proposal was never integrated.
  dotfiles, itell and tabtype each bound the rule only to skip it.
  → Replaced with owed-read markers in the change's record, the
  "no region that every change writes" rule, per-milestone delivery state,
  and a marker grep. Verdict semantics follow the as-merged planlab rule
  (only a confirming comment closes), not the earlier proposal.
- **Docs accrete history and incident notes; the user asks for present
  design and its reasons** (024a9e0e 08-26, abd24d95 09-04, 4ce07439 09-19,
  a0710781 09-24, 4fc50d59 09-27). The Present-state rule already existed.
  → The user's purpose paragraph folded into the opening; lessons entries
  whose hazard is gone are deleted; a predecessor a reader might propose
  again is kept as the alternative the design beats.
- **Docs deeper than the reader acts on** (024a9e0e 08-26, 2eeff918 09-25,
  16b71a86 09-25). → "Mechanism below the reader's action" under what does
  not earn documentation.
- **PR-number rule conflict** (read, no stall observed): § What this change
  can know said docs cite the PR; the check block flags PR numbers in design
  docs. → The change's record cites it.
- **No change:** the other check-block greps (no false-positive complaint
  found in the sample).

**Verification.** The marker grep passes all 55 planlab marker lines on
`origin/develop` except legacy unnumbered ones, and flags a synthetic
unnumbered marker. Two cold readers (a production-read `/update-docs` in a
bindings-light repo; distilling history, incident and mechanism excerpts):
both took the purpose from the opening; their shared-cause findings (where
doubt lives after merge, what closes a read, decision vs history, lessons
retention, bindings location) were repaired. Not repaired: update-docs'
"after a change lands" wording and the `docs/*.md` pathspec default.

**Next pass compares.** Owed-read wording in sessions after the broadcast:
markers in records vs dated items on shared pages; user corrections about
history or mechanism depth after `/update-docs` and `/distill-docs`, against
the five sessions above. Revise if agents drop owed reads entirely (no
marker where production had to answer) or keep narrating predecessors under
the "might propose again" clause. External bindings still name the removed
status-page loop: planlab `pl-loopy-handoff` ("`<status pages>` is empty"),
itell `update-docs`, tabtype `CLAUDE.md`/`AGENTS.md`.

## 2026-10-28 — a brief instead of a gated procedure; doc-check

**Mined** (obelisk, both machines, 2026-08-29 → 10-28, 226 runs in 194
sessions; scripts were scratch): median 2.0 minutes and 11 tool calls per
run; 109 of 128 doc commits grew the docs (median +14.5 lines); 25 of 174
requests front-loaded "concise / high level / lean"; five sessions asked
for trims afterwards (2eeff918, 13bbb6dc, 2a777f87, bda3d27a, 4af0682b).
The gate held an item in about 31 runs: about 18 approved in a word, none
rejected, about 11 dropped when the user moved on, one annoyed
(1c9c81f0: "if something you can verify yourself, just do it"). The plan
template appeared in 25 of 215 runs. The check block ran in 49% of editing
runs; its real catches were broken `§` references and changelog phrasing;
in at least 3 sessions zsh left the live-doc list unsplit and the greps
passed against a path that did not exist. 20 runs were reshape requests the
diff-first steps did not fit.

**Changed:** the body is a brief (goal and done, scope including reshape
requests, writing against growth with the user's own words, authority in
place of the gate, report), 898 → 456 words. `scripts/doc-check` runs the
standard's check block on the staged docs, resolves each `§` reference
against the cited doc's headings, and prints each doc's growth in words;
live-doc pathspecs are separate arguments. `tests/test-doc-check.sh` pins
it (10 checks). The shared standard was rewritten in the same pass
(2,451 → 1,948 words, its section headings unchanged because other repos
cite them).

**Eval** (`~/dev/skill-evals/cases/update-docs/sync-a-feature`, fixture
`docs-jobq`, hand-built: jobq's retries/idempotency/cancel branch with its
docs left stale; red 93be78c; n=5; graded first by `codex:gpt-6.1-terra`,
then, after the covers check stopped failing runs that documented the
fixture's real resend defect, by the default Claude Sonnet 5.5):
docs words 438 → median 862 at red (+424) and 649 with the rewrite (+211);
covers 5/5 and 4/5 (the miss: the three-attempt limit), stale, present
tense and committed 5/5 both; report 5/5 both under Sonnet (2/5 and 5/5
under Terra). The two judges disagree on details; the growth figure is
measured from the kept repositories.

**Next pass compares** live runs after this commit: doc growth per pass
against the 109-of-128 baseline, user trims after a pass, reshapes made
without asking that the user then reverts, and whether `doc-check` runs.
