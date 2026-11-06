# emil-design: evidence log

## 2026-11-03: creation pass (improve-tool)

**Corpus.** Obelisk on all three machines (the mini had no hits). The query
matched text containing `aiforui-skills`, `emil-prototype` or
`emil-ui-polish`, excluding this session. Seven UI sessions from 2026-11-01
and 02 were read: mini2 `6283075a` (report dialogs), `fb235a84` (teacher
roster), `da85180f` (Taodesk portal), `f9a31952` (Loopy report follow-up) and
`97036ff7` (staff console); mac `7687b572` (lesson reader) and `5d6bdd27`
(highlights). The setup session `90b2dcb4` and two Codex goal reviews (which
are delegated work) were left out of the counts.

**Findings behind each section.**

- *The skills*: in 7/7 sessions the user wrote by hand where the skills
  live, that they are read by path, and that the project's design doc wins.
  `5d6bdd27` went to a wrong absolute path on the laptop.
- *Loadout*: the picks converged. Every session used `prototype` with its
  three loaded skills. On top of those: `forms-and-inputs` in 5,
  `typography` and `surfaces` in 3, `mobile-native` in 2. The README records
  this.
- *Split the findings*: twice the user asked for direction-independent fixes
  first, then the prototype (`97036ff7`, `f9a31952`).
- *Preview handoff*: in 5/7 the user asked for a URL they could open, a
  tailnet link, or sign-in help (`fb235a84`, `6283075a`, `97036ff7`,
  `f9a31952`, `7687b572`). Agents worked out `tailscale serve` from scratch
  in 4. Planlab needed `PLANLAB_DEV_ALLOWED_ORIGINS` and a preview identity
  (`f9a31952`).
- *Mix*: 5/7 ended in a hybrid (Roster+, Steps+, Steps plus Editorial, the
  notebook hybrid, and the staff console's "no clear winner"). `MIX.md` was
  read in only 2.
- *Polish and review*: `ui-polish` after the pick was asked for once
  (`da85180f`), and `ui-review` was skipped once (`5d6bdd27`). Running both on
  the promoted code is the user's stated intent and has not yet been
  observed in use.

**Rejected.** Putting the preview fact in `.claude/machines/mini2.md` would
not reach these sessions: that hook runs only in the dotfiles repo, and the
UI sessions run in planlab and itell. A snippet alone was also rejected,
because the later stages need re-reading after `/compact`.

**Validation.** A cold reader ran a scenario on mini2 (a Loopy model-picker
redesign). It confirmed that planlab's prototype bar does not render on a
plain local dev server, that the first reply had no stop, that the mix step
skipped MIX.md's matrix, and three smaller wording gaps. All six were folded
in. The workflow has not been run end to end in a real session yet.

**What the next pass compares.** Over the next five sessions that invoke
this skill:

- Preview asks per session. Success is none past the first handoff.
- Whether a hybrid request goes through MIX.md's matrix.
- Whether `ui-polish` and `ui-review` run on the promoted code.

Revise the handoff step if the user still asks for a reachable link or
sign-in help. Cut the polish and review step if its fixes duplicate what the
prototype already applied.

## 2026-11-06: routes, the closing pass, TabType keys (improve-tool)

**Corpus.** Obelisk on all three machines, user turns since 2026-11-03 naming
`emil-` or `aiforui`, classified by reading. Seven uses: mini2 `1f8bb0da`,
`e950fedf`, `8a703a08`, `faa0a832`, `3dca6c93`; mac `2f01ec71`, `91f6f858`.
`e950fedf`, `8a703a08` and `3dca6c93` share one Loopy surface, so they are
linked work. Left out: `1c432277` (creation), `c7ba697e` and `c5aeacda`
(prompt split, which only cite the course), `9b8924a9` (a review brief),
`9f0b4f57` (no use of the skill), and continuation summaries. Skill reads were
counted from tool input, since agents `cat` through a shell variable.

Course material: the skills manifest re-fetched through `_tools/fetch.py` into
a scratch folder, 63 of 63 files identical to the snapshot. Lessons 6, 7 and 8
unchanged in substance since 11-01. Lessons 3, 5, 9, 10, 11, interaction lab
and tools as means to an end newly read and saved to `_lessons/`. Their
content stays in the private README, because it is paid.

**What the last pass said to compare.**

| Measure | Result | Reading |
|---|---|---|
| Preview asks past the first handoff | 3 of 5 prototype runs: `1f8bb0da` (a sign-in-only URL 404'd), `faa0a832` (three 404s, a planlab host bug the picker exposed), `2f01ec71` (asked for tailnet on the laptop, which the mini-only step skipped) | Not met. Step 4 now runs on any machine and checks from a signed-out session |
| Hybrids through `MIX.md` | 2 of 3 (`1f8bb0da`, `91f6f858`); `2f01ec71` left the parts to the agent | Works, but in both matrix runs the user took the recommendation without ticking, so the matrix now carries it |
| Polish and review on promoted code | `ui-polish` read in 7 of 7 and `ui-review` in 6 (not `8a703a08`). Reads do not show which code each ran on, so this rests on the reports. The user named polish by hand in 5 (`1f8bb0da`, `e950fedf`, `2f01ec71`, `3dca6c93`, `8a703a08`) | Keep: review came back Blocked on promoted code in `1f8bb0da` (5 findings) and `e950fedf` (a focus bug), so its fixes do not duplicate the prototype's. The reversal condition did not fire |

**Findings and changes.**

- *`emil-prep-for-prod` was missing.* Asked for by hand in 4 of 7 (`e950fedf`,
  `8a703a08`, `3dca6c93`, `2f01ec71`) and run in 5, while the skill never named
  it. In `2f01ec71` it found what polish had passed: 1.56:1 link underlines, an
  italic font preloaded on every page, and analytics firing in dev. Scoped to
  one surface in `e950fedf` it found no blockers. Now step 6's third pass.
- *No route without a prototype.* `8a703a08` ("no need to prototype this
  time") and `3dca6c93` (passes on built work) had to say so by hand, and the
  skill's done condition required a pick. Now the Improve and Finish routes.
- *Loadout duplicated `emil-prototype` Phase 3.* The user noticed the overlap.
  The section is gone and step 2 points at Phase 3. Runs loaded four or five
  material skills (`e950fedf`, `2f01ec71`) with no complaint from the user, so
  the one-or-two limit applies only outside that loadout.
- *Cross-variant settings.* Asked for in `faa0a832`, `91f6f858`, `2f01ec71`,
  and `91f6f858`'s reply was a pasted settings block. Now step 3.
- *Repeated words.* The user typed the skill's path in 6 of 7 (TabType's
  skill entry pastes it), then the same asks: prototypes to preview, remove the
  prototype, the closing skills. `emil-prototype`, `emil-improve` and
  `emil-finish` carry those. They read the skill by path because 5 of 7
  invocations came mid-message, where a slash command cannot.

**Keeps.** The first-reply stop: all 4 replies to it steered the work
(`e950fedf`, `faa0a832`, `2f01ec71`, `91f6f858`), which is also what lesson 3
asks for.

**Deletions to watch.**

- *`emil-product-thinking` only when building is open.* Unused in 7 of 7, and
  the README's table carries it. Bring back if a run reaches for it on a
  settled build.
- *The `consult-then-build` line.* That snippet states its own stop, and
  `emil-finish` states it too. Bring back if a PR opens before the report.
- *Naming the stage each skill serves.* Bring back if the first reply stops
  being checkable.
- *Planlab's preview identity and `PLANLAB_DEV_ALLOWED_ORIGINS`.* Moved to the
  README, which has the fuller recipe. Bring back if a planlab run misses them.

**Rejected.** Removing `tailscale serve` on promotion: no safe per-port recipe
was verified, and it would take away the link to the built UI, which
`1f8bb0da` asked for afterwards. A style-lab route from the interaction lab
lesson: no use yet, so it is a README note. Running the official installer: it
writes into `~/.claude/skills`, which links into the public repo.

**Validation.** Two cold readers over the three routes and a parity read
against the previous version, all by reading. They found the build's timing
lost at the first-reply stop, a preview check that an isolated `/proto` route
could not pass, a delegated mix with no base, and a harness teardown that a
project-owned harness forbids; all are fixed. One finding was checked and
dropped: the laptop does have `tailscale` on `PATH`. The findings need a real
app and a browser, so none became a headless eval case. No route has run in a
real session since this change.

**What the next pass compares.** Over the next five uses:

- Whether `emil-prep-for-prod` is still asked for by hand. Success is none.
- Whether the keys replace the hand-typed path. `history.json` counts them.
- Preview asks past the first handoff. Success is none.
- Whether a scoped `prep-for-prod` finds defects after review. Cut it to an
  on-request pass if three runs in a row add nothing.
- Whether Improve runs skip a live look the user then has to ask for.
