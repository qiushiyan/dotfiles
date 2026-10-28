# The revision pass

Run this over every model-facing surface a session touched before shipping,
or over every line of the files you were pointed at. The rules it checks
against are in [SKILL.md](SKILL.md).

1. **Sort by reader.** Tag each surface: the model acting, a judge, or a
   human. Human-facing text is ordinary writing and stays out. Read each
   instruction with a concrete input in the reader's hands: what does each
   sentence change? Translate requests addressed to the author into the
   reader's goal or constraints. Keep a template's hedge, which covers many
   instances and breaks when "fixed" to one, and keep text quoted from a
   vendor guide as tested.
2. **Sweep for stale text.** Diff the touched surfaces, or read their last
   commit. Grep the repo for every name the diff removed or renamed, and for
   every file that points at a touched surface. After a behavior change, the
   worst defect is usually there, not in the file you were pointed at.
3. **Cut before you add.** Remove mechanism narration ("this works by…"),
   incident narration (the ticket, the session, who hit it), procedure the
   model would derive, checks it performs unprompted, duplicates, rules for
   failures never seen, unearned emphasis, and no-ops. Mark a doubtful no-op
   for step 5. Where a fact wears a plumbing costume, keep the fact:

   <example type="avoid">
   The way this works: each worker runs in its own background session spawned over RPC, and results arrive as follow-up messages on the event bus, so don't block waiting on them. (A worker turn can take several minutes.)
   </example>

   <example>
   A worker turn takes several minutes, so send one complete request rather than a stream of small ones, and keep working elsewhere while it runs.
   </example>

   Fold a review finding in by rewriting the sentence it corrects, not by
   appending a clause. If the surface still grows, pay for it with a cut
   elsewhere.
4. **Name the defects** in what remains. Each finding names one below, or
   the rule it breaks.
   - *prose doing code's job:* a rule a hook or check could enforce, or a
     fact the system holds that the reader is told to go find.
   - *hook before anchor:* opens on a mechanism, a trap, or a count, not on
     the task and what done looks like.
   - *builder's frame:* the situation is posed in the terms of the system
     you built, or asks what the reader's input cannot show.
   - *no checkable done:* a step without a done condition, or parsed output
     without an exact contract.
   - *bare rule:* a rule whose missing reason or exception would change
     what the reader does; a rule a capable model reads correctly is not
     one.
   - *sprawl:* a body past its budget, a sentence carrying stacked
     qualifications, or a description doing the body's work.
   - *flat hierarchy:* layers rendered as one paragraph, bullets that run to
     paragraphs, or a header every few sentences that invents a hierarchy.
   - *lookup as a grid:* a table whose rows are independent entries; use a
     list with a bold label per entry.
   - *buried instruction:* a rule the reader needs at the end sits in the
     middle; move it there, or repeat it there on purpose.
   - *familiar-term leak:* an internal or coined name where the field has a
     word.
   - *negation as the lever:* the rule is carried by what not to do.
   - *rule–example conflict:* the example wins, so fix it first.
   - *stale cache:* restates a `--help`, a config, a listing, or a number
     that changes.
   - *conflicting rules:* state the rule once with its exception folded in.
   - *config-conditional prose:* a mode branched in the text of an assembled
     prompt, instead of in the code that assembles it.
   - *unearned certainty:* a claim its layer could not observe.
   - *buried outcome:* a report that opens on process, not the outcome.
   - *opaque returns:* ids without meaning, failures without a next action.
5. **Verify and record.** Check each claim about a mechanism at its source,
   and say in the commit what you verified. Read each touched file once
   more, whole and cold. Use a cold reader with a concrete scenario where a
   no-op or a route is in doubt. Name the deliberate keeps (a sanctioned
   echo, a load-bearing hedge, an earned `never`) with their reasons, in the
   commit or the evidence log, so the next pass does not undo them.

Done when a cold reader knows from the first lines what each surface is and
what to do, every keep has its reason, every claim was verified, pinned, or
marked unverified, and each surface is shorter than before unless a named gap was
filled.
