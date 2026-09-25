<!--
The brief a /consult voice reads. Copy the body below into a scratchpad file,
fill every «slot», delete these comments. A section with nothing real to say
is deleted, not filled: an empty heading invites invented content. The fixed
lines are distilled from briefs that worked; keep them unless this run
genuinely contradicts them.

The order is the instrument. The voice reads the goal and what was observed,
commits its own reading of the problem and the shape before it reads the code
or our position, then judges ours. Where the two readings differ is the
round's product; a voice that starts from our position critiques inside its
frame. Same-file order is a nudge, not blinding — SKILL.md step 6 says when
our position is withheld for a second turn instead.
-->

# Consult: «the question in one line — the outcome to reach or the symptom as seen, never the answer»

«One paragraph anchoring identity for a cold reader: what the project is, in
plain terms, and the one or two facts about its state the question depends on.
The voice has none of your conversation — this paragraph is all the
orientation it gets. Describe the system, not the bug.»

## The goal, and what must be true

«The outcome in the user's own terms — who it is for and what they can do once
this is settled — and, where something is going wrong, the symptom as a user
or a log sees it. No cause, no fix. Then what any answer has to satisfy: the
constraints from outside this session — compatibility, operational limits, a
decision the user made, work already committed elsewhere. This session's own
analysis is not a constraint; it goes under "What we believe", where the voice
is meant to attack it.»

Those constraints are fixed; on them your job is defects in the *execution* —
internal consistency, gaps, edge cases. If you believe one is fatally flawed,
flag it with concrete evidence (code paths, failure scenarios), clearly marked
"foundational objection" — do not redesign it. Everything else is open.

## What we observe

«Only what someone saw, and how. For something going wrong: the
reproduction and how reliable it is, the timeline and what changed around it,
log lines, stack traces, query results and metrics quoted rather than
summarised, and the numbers where they are known. For something to build:
what users reported, and to whom, and the current behaviour as read in the
code. One inference here spends what the round was bought for; causes and
suspicions go under "What we believe". Where a count, a rate or a timing is
this session's own measurement, add DATA-BLOCK.md's bullets here: the queries
and raw outputs by absolute path, and what the voice can run. Delete the
section only when the position rests on reasoning alone (SKILL.md step 2).»

## Your read, before reading on

Write this down now, before you open any file or read past this heading:

1. **The problem**, in two or three sentences — what is actually wrong or
   needed. Where something is going wrong, the two or three causes you would
   rank most likely, and for each the cheapest observation that would
   separate it from the others.
2. **The shape** you would build, in two or three sentences, the one
   alternative you would discard and why, and the place you are least sure of.

This is a quick commitment, not the analysis — the code-grounded comparison
comes in your output. Report it verbatim. Where it differs from what follows
is the most valuable thing this round produces, and it is unrecoverable once
you have read on.

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
(`~/.config/lessons/codebase-design/design-it-twice.md`): sketch two or three
shapes different in kind — write each one's constraint down first and hold the
others out of view — compare on depth, locality, and seam placement, and land
on the winner plus a line per discard, never a menu. When the change
restructures an existing cluster, `~/.config/lessons/codebase-design/deepening.md`
decides whether a seam earns a port. Where the proposal joins an existing call
path, `~/.config/lessons/codebase-design/composition.md` decides whether it was
absorbed or bolted on.

## Read these, in this order

«Ordered reading list with absolute paths: the code the observations and the
goal touch, in the order a reader would trace it — not the order of our causal
chain — then the docs that carry the invariants, then any rulebook this session
is working under, so the voice works to that bar rather than its own defaults.
The voice reads them itself — never restate their content here. An artifact
that *is* our proposal — a spec, a design doc — is named under "What we
believe", after the voice's read.»

## What we believe

«The position this session would defend, in two parts — a statement to
attack, not a design document.

**The problem.** What we think is wrong or needed and why, as a chain —
X, which causes Y, which is why we see Z — with every link marked observed
(and where) or inferred, then what we never checked: the links believed rather
than seen, the alternatives dropped early, the tools we lacked. A belief with
its grounds, not a finding.

**What we propose.** The shape we would build and the vocabulary it
introduces, the alternative we discarded and why, and where it aims — at the
cause, at a link in the chain, or at the symptom. When the proposal is a file,
its absolute path and one line on what it decides; the voice opens it only
now.

Delete this section and "Where we doubt it" when SKILL.md step 6 withholds
our position for round 2.»

## Where we doubt it

«Prose, not a questionnaire. Name the areas of our position you already
suspect are weakest, and the few observations or counterexamples that could
change the decision — a path traced at three points in time, a caller that
would pay, a state the shape cannot represent. A probe earns its place by
being able to defeat a load-bearing claim; a question that enumerates the
proposal or carries its own answer ("is the real problem X, e.g. …") hands the
voice the conclusion and leaves only the picking. Name the area you doubt; let
the voice name what is wrong in it.»

## Output

0. **The method** «only when the observations carry the data bullets» —
   before any conclusion: is the right data pulled for the question, is data
   missing that would change the answer, is the approach sound, and which
   counts or claims it cannot support as stated. Doubt a count: re-run or vary
   it if the brief says you can, else say what you would run and what a
   different result would change. "Sound, with these limits" is a real answer.
1. **Your read** — verbatim, as written before you read on.
2. **The problem** — ours confirmed, sharpened, replaced by a different one
   you back, or not carried by the evidence, with the evidence for your
   verdict. Confirmed takes one line. Where a cause is claimed, take its chain
   link by link: which links are observed, which inferred, and which
   alternatives the evidence does not exclude, each with what would separate
   it. Whatever you conclude here is the problem the rest of your answer
   solves.
3. **The falsifying observation** — for the cause you back, the cheapest
   thing we could run that would show it wrong: the query, the log to grep,
   the test to write. Where nothing available could separate it from its
   alternatives, say so; that is a finding. "No causal claim" is a real
   answer.
4. **The approach** — where your shape differs from ours and why, written
   from the code you read rather than from the doubts we named; where they
   agree, one line. Where the evidence cannot yet support a build, the
   approach is the observation that would settle it.
5. **Where ours breaks** — most severe first. For each: what, where
   (file/section/function), why it's a problem (a concrete failure or
   contradiction), and the smallest fix consistent with the constraints
   above. "None" is a real answer.
6. **Tenets for the build** «keep only when the round decides how a build
   proceeds — a milestone, a phase plan, an ask for guidelines; otherwise
   delete this item» — read `~/.config/lessons/collaboration/tenets.md`
   first. The few load-bearing decisions the build holds to, from your read
   and ours: each a stand with its reason, no file names, seven at most and
   fewer the norm — a decision the later phases could survive without is left
   out.
7. **Foundational objections** — a separate section, "none" said explicitly
   when it is empty.

Be specific and terse; no praise padding.

Design analysis only — do not change any code.
