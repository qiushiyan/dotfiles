# handoff — evidence log

Earlier passes (the gate, the pickup gates, the At-pickup claim format) are
recorded in `~/dev/brief/EVIDENCE.md`, beside the engine this skill drives.

## 2026-10-29 — plain sentences, and what the CLI already holds

**Ask.** The user approved rewriting the over-budget skills after the tstack
refactor (prompt-engineering, 2026-10-28).

**Usage since 09-01** (obelisk, both machines; typed `/handoff` and
`/distill-handoffs`, self excluded): 8 typed forward handoffs (mini 2, mac 6)
and 9 continuation-mode runs, all from the steward (mac, 09-06 → 09-07). No
next user turn corrected a brief. Most sessions end at the report. `brief
check` ran 1–6 times per handoff, so writers fix flagged heads in a loop
rather than writing them right first. Nothing measured shows which body
rules a writer skips.

**Changed.** Body 3,209 → 2,329 words; average sentence 32.6 → 20.6 words;
em-dashes 78 → 2. Same sections, numbers and anchors: `brief new --help`
cites "§4", distill-handoffs cites § 4, the steward's `compact` invokes
continuation mode and relies on "the invocation's arguments".
- The At-pickup shape block is gone. `brief new` scaffolds those slots.
  The parity read (10-29) found `brief check` passes a scaffold whose claim
  and approach still read TODO, and that the scaffold pre-fills `none` for
  forks and gates. So the body now says each slot needs an answer and each
  `none` is a claim that you looked; the cheaper home is `brief check`
  refusing TODO in `## At pickup`, not yet built.
- The `blocked-by`/`collides-with` "always answered" lines are gone. `brief
  check` errors on a missing `collides-with` when siblings exist and on a
  missing required field.
- `pickup/build.md`, `pickup/design.md` and `SLUG-NAMING.md` are unchanged.
  They are the pickup contract the 09-04 pass measured.

**Deletions to watch** (author's own parity read; no independent reader was
available to this pass):
- "Neither gate skips the consult; a brief whose question the checks already
  answered closes instead; `build` only narrows what it asks." It returns if a
  writer picks `build` to avoid a consult, or the next pickup asks whether a
  build brief needs one.
- The description of what `/distill-handoffs` deletes (`<branch>` or
  `review-<branch>`, within the branch's domain). It returns if a user asks
  what the printed command will touch.
- "the sweep may flip `pickup:`", and "a project skill wrapping this one may
  bind the slug to its vocabulary". Both are facts about other skills. Either
  returns if a writer contradicts the wrapper.

**Untested.** No eval case. No failure was found to replay, and writing a
brief needs the brief CLI and a handoff folder, which the rig does not
isolate. **Next pass compares** `brief check` rounds per handoff (1–6 now)
and any correction after a handoff report.
