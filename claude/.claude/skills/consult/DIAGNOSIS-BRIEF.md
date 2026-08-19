<!--
Brief template for /consult in diagnosis mode: a causal claim is on trial.
Copy the body below into a scratchpad file, fill every «slot», delete these
comments. The fixed lines are distilled from briefs that worked; keep them
unless this run genuinely contradicts them.

**The order of the sections is the instrument.** The voice reads what was
observed, writes its **blind read** of it, and only then sees what this session
concluded. Independent convergence on the same cause is evidence; agreement
after being handed the answer is not — which is the whole reason a consult is
worth its cost after a long debugging session. A conclusion that lands above
the blind read, or an observation section padded with inferences, spends that
evidence and leaves the round buying a critique of a hypothesis instead of a
check on it.

Nothing here is fenced: by the fence rule this session's own analysis is the
artifact on trial, not settled direction. Where a design choice with no causal
claim behind it is the question, APPROACH-BRIEF.md is the instrument instead.
-->

# Diagnosis: «the symptom, one line, as observed rather than explained»

«One paragraph anchoring identity for a cold reader: what the project is, in
plain terms, and the one or two facts about its state the questions below
depend on. The voice has none of your conversation — this paragraph is all the
orientation it gets. Describe the system, not the bug.»

## Posture — first principles, grounded

Reason from first principles, grounded in the code you read — an analysis that
doesn't cite the files it stands on is guessing. Judge any direction by how
fully it solves the real problem on a clean structural footing, not by how
little it disturbs: prefer the shape that makes the problem disappear over the
patch that quiets it. A structural claim needs the code that proves it and the
cost it carries.

## What we observe

«Only what was observed, and how. The symptom as a user or a log sees it; the
reproduction and how reliable it is; the timeline — when it started, what
changed around then; the evidence gathered, quoted rather than summarised
(log lines, stack traces, query results, metric shifts). Where a number or a
frequency is known, give it.

Every line here is something someone saw. Inferences, causes, and suspicions
belong below the blind read — a conclusion smuggled in here defeats the whole
brief.»

## The blind read

Write this down now, before reading anything past this heading:

1. Your reading of what is happening, in two or three sentences.
2. The two or three causes you would rank as most likely, most likely first.
3. For each, the cheapest observation that would separate it from the others.

Report it verbatim in your output. Whether it matches what follows is the most
valuable thing this round produces, and it is unrecoverable once you have read
on.

## What we concluded

«The hypothesis this session arrived at, stated as the causal chain it claims:
X happens, which causes Y, which is why we see Z. Then the evidence that
supports each link, and — the line most worth writing — **what we never
checked**: the links believed rather than observed, the alternatives dropped
early, the tools we didn't have. State it as a belief with its grounds, not as
a finding.»

## What we propose to do about it

«The fix or change this session would ship, and where it sits: at the cause, at
a link in the chain, or at the symptom. Say which — aiming at a link is a
legitimate choice, and naming it as one is what makes it reviewable.»

## Read these, in this order

«Ordered reading list with absolute paths: the code on the failing path first,
then the docs carrying the invariants it depends on, then any rulebook this
session is working under — a house guide, a project doc the user handed over —
so the voice works to that bar rather than its own defaults. The voice reads
them itself — never restate their content here.»

## Evaluate — the cause first, then the fix

- **Does the evidence carry the claim?** Take the causal chain link by link:
  which links are observed, which are inferred, and does any inferred link have
  a plausible alternative that the evidence does not exclude?
- **The falsifying observation.** Name the cheapest thing we could look at that
  would show the hypothesis is wrong — a query, a log line, a one-off script, a
  targeted test. Where nothing available could separate this cause from its
  alternatives, say that plainly: an unfalsifiable diagnosis is a finding
  whatever else is true.
- **What else produces these symptoms?** The alternatives that fit the observed
  evidence and were not ruled out, each with what would separate it from ours.
- **Only then, the fix.** Is it aimed at the cause, at a link, or at the
  symptom, and is that the right altitude given what you concluded above? A fix
  correctly aimed at a wrong cause is the expensive failure this round exists
  to prevent, so say so before discussing its execution. Where the fix commits
  a module shape or an interface, skim the `## The bar` of
  `~/.config/lessons/codebase-design/deep-modules.md` and judge it in that
  vocabulary — depth, seam placement, illegal states.

## Output

1. **The blind read** — items 1–3, verbatim.
2. **The cause** — confirmed / not carried by the evidence / a different cause
   you would back, with the evidence for your verdict. State this before
   anything about the fix.
3. **The falsifying observation** — concrete enough to run: the query, the log
   to grep, the test to write.
4. **Alternatives not excluded**, each with what would separate it. "None" is a
   real answer.
5. **The fix** — right altitude or wrong, and the smallest change consistent
   with the cause you back.

Be specific and terse; no praise padding.

Design analysis only — do not change any code.
