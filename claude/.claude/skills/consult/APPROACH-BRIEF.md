<!--
Brief template for /consult in approach mode: a design choice is on trial —
how to build something, which shape to commit to, where a seam goes. Copy the
body below into a scratchpad file, fill every «slot», delete these comments.
A section with nothing real to say gets deleted, not filled: an empty heading
invites invented content. The fixed lines are distilled from briefs that
worked; keep them unless this run genuinely contradicts them.

Where a causal claim sits under the question — a bug, a regression, a "why is
it doing this" that a hypothesis already answers — DIAGNOSIS-BRIEF.md is the
instrument: it puts the cause on trial before the fix, which this one does not.

The degenerate case is a session with no position yet. Then "What we propose"
is deleted rather than filled, and the voice designs from the choice and the
constraints alone. That is rare — a consult usually has something to attack —
but the brief works unchanged.
-->

# Consult: «the choice being made, one line»

«One paragraph anchoring identity for a cold reader: what the project is, in
plain terms, and the one or two facts about its state that the questions below
depend on. The voice has none of your conversation — this paragraph is all the
orientation it gets.»

## Posture — first principles, grounded

Reason from first principles, grounded in the code you read — an analysis that
doesn't cite the files it stands on is guessing. Name the real problem in your
own words before answering the stated one; the question as asked is sometimes
a symptom. Then judge any direction by how fully it solves that root problem
on a clean structural footing, not by how little it disturbs: prefer the shape
that makes the problem disappear over the patch that quiets it. A structural
claim needs the code that proves it and the cost it carries.

## The choice

«What is being decided, and what has to be true once it is: the outcome in the
user's terms rather than a mechanism, and the constraints any answer has to
satisfy — compatibility, operational limits, work already committed elsewhere.»

## What we propose

«The position this session arrived at, stated as a design it would defend
rather than a menu: the shape it would build, the vocabulary it introduces, and
what already stands in the working tree versus what remains. The voice's job is
to find where it breaks. Delete this section when the artifact under review is
a file the reading list already points at — the artifact is the proposal then.»

## What is actually settled

«The fence rule decides what may go here. This session's own analysis is not
it — that goes under "What we propose", where the voice is meant to attack it.
Nothing left to list? Delete the section: an empty fence is better than a false
one.»

Those items are fixed; on them your job is defects in the *execution* —
internal consistency, gaps, edge cases. If you believe a settled item is
fatally flawed, flag it with concrete evidence (code paths, failure scenarios),
clearly marked "foundational objection" — do not redesign it. Everything not
listed above is open, the proposal included.

## The design bar

Read `~/.config/lessons/codebase-design/deep-modules.md` closely — the shape
under discussion is judged in its vocabulary: depth, seams, the deletion test,
illegal states. Where an interface is being committed, design it twice
(`design-it-twice.md`, same directory): sketch two or three shapes different in
kind — write each one's constraint down first and hold the others out of view —
compare on depth, locality, and seam placement, and land on the winner plus a
line per discard, never a menu. When the change restructures an existing
cluster, `deepening.md` decides whether a seam earns a port. Where the proposal
joins an existing call path, `composition.md` decides whether it was absorbed
or bolted on.

## Read these, in this order

«Ordered reading list with absolute paths: the artifact(s) under review or the
relevant code first, then the docs that carry the invariants, then any rulebook
this session is working under — a house guide, a project doc the user handed
over — so the voice works to that bar rather than its own defaults. The voice
reads them itself — never restate their content here.»

## Concrete questions

«Numbered, specific probes — each answerable from the reading list. Name the
places you already suspect are weakest; a voice pointed at a seam digs deeper
than one asked to "review everything". Ask what should happen rather than
offering a menu: a question shaped "A or B?" has already made the decision and
leaves the voice only the picking.

The same trap wears a second costume — an example inside an open question. "Is
this the right framing, or is the real problem something else (e.g. …)" reads
as open and hands over the answer, and when the voice returns that answer
neither of you can tell whether it was found or fed. Name the **area** you
doubt; let the voice name what is wrong in it.»

## Output

1. **The real problem, in your own words** — before you engage the proposal,
   two or three sentences naming what you think is actually wrong. Where that
   matches the framing above, say so plainly; where it differs, this is the
   most valuable line in your reply. Write it from the code you read, not from
   the questions you were asked.
2. **Findings**, most severe first. For each: what, where
   (file/section/function), why it's a problem (concrete failure or
   contradiction), and the smallest fix consistent with the constraints above.
   Where you would have built it differently, say so and what keeping ours
   costs.
3. **Foundational objections** — a separate section, "none" said explicitly
   when it is empty.

Be specific and terse; no praise padding.

Design analysis only — do not change any code.
