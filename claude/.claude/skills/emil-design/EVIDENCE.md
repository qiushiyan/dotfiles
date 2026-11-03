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
