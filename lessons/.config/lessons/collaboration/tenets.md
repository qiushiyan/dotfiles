# Tenets — the few decisions the rest of a build hangs on

What a reviewer or consult voice hands a build that continues after it: not
rules for the next file, but the handful of decisions everything later rests
on, each with the reason that lets a builder re-derive the local rules when
the plan runs out. The word is Amazon's, and so is the convention that closes
every set: *unless you know better ones*.

## The bar

- **A tenet is load-bearing.** Remove it and later phases break, or the
  choice is costly to reverse once the phases after it are built. A rule
  that could change without the rest of the build noticing is a tip, and
  tips are the reviewer's ordinary findings, not tenets.
- **A tenet takes a stand.** It names what is preferred over what, in the
  present tense: *one committer owns the turn boundary over two channels
  each acknowledged on its own*. A line nobody could argue the opposite of
  is a platitude, and a line the code could not violate is a description.
- **A tenet carries its why.** The rationale is what a builder applies to a
  situation the tenet's author never saw; the statement alone invites
  creative compliance. State the failure the tenet prevents, in the
  system's terms.
- **A tenet names no file.** It survives a rewrite of the code beneath it.
  Where the only honest statement needs a file name, the item is a rule
  about that file and belongs with the findings.
- **Seven at most.** A set that grows past that is a checklist wearing the
  word; the discipline is choosing which decisions carry the rest.
- **A tenet lives where the build rereads.** The spec, beside its phases,
  or the decision record the next session opens first. A tenet stated only
  in a conversation is dropped at the next compaction, and the build then
  violates it with no sign it ever existed.
- **A tenet the code disproves is struck, with the reason.** The set is
  revised at every milestone; a struck tenet and its reason are worth more
  than a stale one kept for continuity.

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
renamed, split, or replaced, and tells the builder of the next arm what not
to grow without being told about that arm.

## Why the form matters

Rules cannot cover the situations a build meets after the plan runs out,
which is most of them; a principle with its reason can be applied there,
and a principle without one is obeyed by the letter and defeated by the
next case. The stand-taking form is what keeps a set honest: a tenet that
is always true costs nothing to hold and guides nothing. The cap is what
keeps it read: seven decisions survive a compaction summary and a cold
read; twenty file-level rules become the material the summary drops first.

---

> _Lesson · collaboration. Distilled 2026-09-15 from two consult rounds
> (`run-state-next-milestone/consult-r1`, `pipe-panel-source-and-spawn-sink/consult-r3`)
> whose "guidelines" sections returned file-level rules where the user
> wanted the decisions the rest of the build hangs on, and from the industry
> vocabulary that names the concept: Amazon's tenets, architecturally
> significant decisions ("hard to make and costly to change"), Kaufman's
> "accidentally load bearing", and the governance-decay measurements on
> context compaction._
