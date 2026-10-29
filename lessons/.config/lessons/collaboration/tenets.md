# Tenets — the few decisions the rest of a build hangs on

What a reviewer or consult voice hands a build that continues after it: not
rules for the next file, but the handful of decisions everything later rests
on, each with the reason that lets a builder re-derive the local rules when
the plan runs out. The word is Amazon's, and so is the line that closes every
set: *unless you know better ones*.

## The bar

- **A tenet is load-bearing.** Remove it and later phases break, or the
  choice is costly to reverse once they are built. A rule that could change
  without the rest of the build noticing is a tip, and tips are ordinary
  findings.
- **A tenet takes a stand.** It names what is preferred over what, in the
  present tense: *one committer owns the turn boundary over two channels
  each acknowledged on its own*. A line nobody could argue against is a
  platitude; a line the code could not violate is a description.
- **A tenet carries its why.** The builder applies the reason to cases the
  tenet's author never saw; the statement alone invites compliance by the
  letter. State the failure it prevents, in the system's terms.
- **A tenet names no file.** It survives a rewrite of the code beneath it.
  An item that needs a file name to be honest is a rule about that file, and
  belongs with the findings.
- **Seven at most.** Past that, the set is a checklist wearing the word; the
  discipline is choosing which decisions carry the rest. Seven survive a
  compaction summary and a cold read; twenty file-level rules are what a
  summary drops first.
- **A tenet lives where the build rereads**: the spec, beside its phases, or
  the decision record the next session opens first. A tenet stated only in
  conversation is dropped at the next compaction, and the build then breaks
  it with no sign it existed.
- **A tenet the code disproves is struck, with the reason.** Revise the set
  at every milestone. A struck tenet and its reason are worth more than a
  stale one kept for continuity.

## Tenet or tip

The test is what a later change would cost. Two lines from the same review:

<example type="avoid">
Keep the subject descriptor private to `firings.ts`; reuse its cutoff in candidate selection, the under-lock re-read, and the frontier check.
</example>

<example>
The cutoff is spelled once, and every reader of a firing's frontier reads that one spelling — a second spelling of the cutoff is the defect class that produced the under-lock re-read bug, and the panel arm reintroduces it the moment its matcher grows its own.
</example>

The first is a correct rule about one module and belongs in the findings;
it dies with the module's name. The second survives the module being
renamed, split or replaced, and tells the builder of the next arm what not
to grow without being told about that arm.

---

> _Lesson · collaboration. Distilled 2026-09-15 from two consult rounds
> (`run-state-next-milestone/consult-r1`, `pipe-panel-source-and-spawn-sink/consult-r3`)
> whose "guidelines" sections returned file-level rules where the user
> wanted the decisions the rest of the build hangs on, and from the industry
> vocabulary that names the concept: Amazon's tenets, architecturally
> significant decisions ("hard to make and costly to change"), Kaufman's
> "accidentally load bearing", and the governance-decay measurements on
> context compaction._
