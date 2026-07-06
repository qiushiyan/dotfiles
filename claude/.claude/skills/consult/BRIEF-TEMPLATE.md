<!--
Brief template for /consult. Copy the body below into a scratchpad file and fill
every «slot». Keep exactly one of the two MODE blocks and delete the other, along
with these comments — the voice reads a single coherent brief, never a fork.
The fixed lines are distilled from briefs that worked; keep them unless this
run genuinely contradicts them.
-->

# Brief: «one-line problem statement»

«One paragraph anchoring identity for a cold reader: what the project is, in
plain terms, and the one or two facts about its state that the questions below
depend on. The voice has none of your conversation — this paragraph is all the
orientation it gets.»

<!-- MODE: design — the voice designs a solution unanchored.
     Blindness is the point: your and the user's current proposal stays OUT of
     this brief, so the voice designs instead of critiquing what it was handed. -->
## The problem

«The problem, its constraints, and what a good solution must satisfy — stated
without revealing the direction you currently favor.»

<!-- MODE: review — the voice critiques an existing artifact (spec, design doc,
     glossary). It gets the artifact; what it must not do is relitigate settled
     direction. -->
## The foundation — decided, not up for relitigation

Direction is fixed; your job is defects in its *execution* — internal
consistency, gaps, edge cases. If you believe a decided item is fatally flawed,
flag it with concrete evidence (code paths, failure scenarios), clearly marked
"foundational objection" — do not redesign it. The decided items:

1. «settled decision»
2. «settled decision»

## Read these, in this order

«Ordered reading list with absolute paths: the artifact(s) under review or the
relevant code first, then the docs that carry the invariants. The voice reads
them itself — never restate their content here.»

## Concrete questions

«Numbered, specific probes — each answerable from the reading list. Name the
places you already suspect are weakest; a voice pointed at a seam digs deeper
than one asked to "review everything".»

## Output

A prioritized findings list, most severe first. For each: what, where
(file/section/function), why it's a problem (concrete failure or
contradiction), and the smallest fix consistent with the constraints above.
«Review mode: add — "Separate section at the end for foundational objections."»
Be specific and terse; no praise padding.

Design analysis only — do not change any code.
