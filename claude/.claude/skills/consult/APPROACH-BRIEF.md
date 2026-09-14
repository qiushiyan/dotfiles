<!--
Brief template for /consult in approach mode: a design choice is on trial —
how to build something, which shape to commit to, where a seam goes. Copy the
body below into a scratchpad file, fill every «slot», delete these comments.
A section with nothing real to say gets deleted, not filled: an empty heading
invites invented content. The fixed lines are distilled from briefs that
worked; keep them unless this run genuinely contradicts them.

The order is the instrument. The voice reads the goal, the constraints and
the code, and sketches what it would build before it sees our position; the
delta between its sketch and ours is the round's product, where a voice that
starts from our design critiques inside its frame. Same-file ordering is a
sequencing nudge, not blinding — the position is on the next page. SKILL.md
step 6 says when "What we propose" is withheld from this brief and sent as
round 2 into the same session instead.

Where a causal claim sits under the question — a bug, a regression, a "why is
it doing this" that a hypothesis already answers — DIAGNOSIS-BRIEF.md is the
instrument: it puts the cause on trial before the fix, which this one does not.
-->

# Consult: «the choice being made, one line»

«One paragraph anchoring identity for a cold reader: what the project is, in
plain terms, and the one or two facts about its state that the choice below
depends on. The voice has none of your conversation — this paragraph is all the
orientation it gets.»

## The goal, and what must be true

«The outcome in the user's own terms — who it is for and what they can do once
this is decided — rather than a mechanism. Then what any answer has to satisfy:
the constraints from outside this session — compatibility, operational limits,
a decision the user made, work already committed elsewhere. This session's own
analysis is not a constraint; it goes under "What we propose", where the voice
is meant to attack it.»

Those constraints are fixed; on them your job is defects in the *execution* —
internal consistency, gaps, edge cases. If you believe one is fatally flawed,
flag it with concrete evidence (code paths, failure scenarios), clearly marked
"foundational objection" — do not redesign it. Everything else is open.

## Posture — first principles, grounded

Reason from first principles, grounded in the code you read — an analysis that
doesn't cite the files it stands on is guessing. Judge any direction by how
fully it solves the real problem on a clean structural footing, not by how
little it disturbs: prefer the shape that makes the problem disappear over the
patch that quiets it. A structural claim needs the code that proves it and the
cost it carries.

## The design bar

Read `~/.config/lessons/codebase-design/deep-modules.md` closely — the shape
under discussion is judged in its vocabulary: depth, seams, the deletion test,
illegal states. Where an interface is being committed, design it twice
(`~/.config/lessons/codebase-design/design-it-twice.md`): sketch two or three shapes different in
kind — write each one's constraint down first and hold the others out of view —
compare on depth, locality, and seam placement, and land on the winner plus a
line per discard, never a menu. When the change restructures an existing
cluster, `~/.config/lessons/codebase-design/deepening.md` decides whether a
seam earns a port. Where the proposal joins an existing call path,
`~/.config/lessons/codebase-design/composition.md` decides whether it was
absorbed or bolted on.

## Read these, in this order

«Ordered reading list with absolute paths: the relevant code or the artifact
under review first, then the docs that carry the invariants, then any rulebook
this session is working under — a house guide, a project doc the user handed
over — so the voice works to that bar rather than its own defaults. The voice
reads them itself — never restate their content here.»

## Your sketch, before reading on

Write this down now, before reading past this heading: from the goal, the
constraints and the code, what you would build — two or three sentences on the
shape, the one alternative you would discard and why, and the place you are
least sure of. This is a quick commitment, not the design-twice comparison;
that comparison belongs in your output, after you have read our position.
Report the sketch verbatim in your output. Where it differs from what
follows is the most valuable thing this round produces, and it is unrecoverable
once you have read on.

## What we propose

«The position this session arrived at, as one paragraph it would defend rather
than a design document: the shape it would build and the vocabulary it
introduces, then the alternative it discarded and why. Delete this section
when the artifact under review is a file the reading list already points at —
the artifact is the proposal then — or when SKILL.md step 6 withholds it for
round 2.»

## Where we doubt it

«Prose, not a questionnaire. Name the areas of the proposal you already
suspect are weakest, and the few observations or counterexamples that could
change the decision — a path traced at three points in time, a caller that
would pay, a state the shape cannot represent. A probe earns its place by
being able to defeat a load-bearing claim; a question that enumerates the
proposal or carries its own answer ("is the real problem X, e.g. …") hands the
voice the conclusion and leaves only the picking. Name the area you doubt; let
the voice name what is wrong in it.»

## Output

1. **Your sketch** — verbatim, as written before you read our position.
2. **Where you differ from us, and why** — from the goal restated in your own
   words if it differs, through the shape. Where the sketches agree, one line;
   where they don't, this is the finding — write it from the code you read,
   not from the doubts we named.
3. **Where ours breaks** — most severe first. For each: what, where
   (file/section/function), why it's a problem (concrete failure or
   contradiction), and the smallest fix consistent with the constraints above.
   "None" is a real answer.
4. **Foundational objections** — a separate section, "none" said explicitly
   when it is empty.

Be specific and terse; no praise padding.

Design analysis only — do not change any code.
