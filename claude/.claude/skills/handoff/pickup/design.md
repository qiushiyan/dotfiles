## Pickup gate — design

**The problem is on trial, not just the approach.** This brief carries a
symptom, a framing, and a proposed approach that nobody outside the writing
session has judged. The first turn is an analysis pass — no code changes,
the worktree left as `brief start` placed it — that reasons holistically,
grounded in the code as it is rather than in the brief's assumptions, and
attacks all three: the framing may be redefined. It ends on a read-only
packet for the user and for `/consult`.

Read `brief drift` first. A claim the drift shows moved is checked against
the moved code; a brief instruction the drift makes moot is named as such
rather than followed.

Return exactly this shape (the packet fits in ~80 lines — a section that
needs more has not found its strongest point yet):

```markdown
## 1. Problem in plain terms
<who is affected · what fails · the goal beneath the brief's framing — in your own words, from what you read>
Framing: holds | redefined — <what the code and evidence say the problem is, and where the brief was off>

## 2. Premises checked
- <the load-bearing premise, listed by the brief or not> · Held — <evidence> | Falsified — <what is true instead> | Unverified — <what would settle it>
- <each `## At pickup` claim, at its named source> · …

## 3. Pressure test
- User: <strongest objection from what the user sees, waits for, or must understand> | None found
- Structure: <the change is absorbed by the current design | accreted onto it | blocked by it — and the preparatory reshape, if the foundation fights the change> · <strongest objection> | None found
- Proof: <the observation, available today, that would show the approach worked> | none named — not testable yet

## 4. Risk accounting
<for each of hot path · user-driven surface · core execution logic the change touches: what runs differently, what holds the risk down, why it is worth it — or one line saying it touches none>

## 5. Countershape, trade-off, recommendation
<one genuinely different shape that answers the strongest objection — or "the proposal survived: <why the objections leave it standing>">
<proposal vs countershape on the root problem and on user / structure / risk cost; a hybrid only where it removes the strongest objection>
Recommendation: <the shape> — accepts <the trade-off> · <"a judgment call" where it genuinely is one>

## 6. Decisions and parked unknowns
Decision needed: <a product fork, in the form below> | none
Parked: <an unresolved technical fact that does not change the direction, with its working answer> | none
```

### How each section earns its place

**Read the code before restating the problem.** Trace the real data and
control flow, note the constraints that exist and why, and cite the files
and functions you read — without this, "first principles" is guessing.
Section 1 is written from that reading, in your own words, for a reader who
no longer remembers this brief. When the code and evidence contradict the
brief, the restatement follows the code and names where the brief was off:
that redefinition is what this gate exists to allow. Push back on the
framing where it seems off, and follow the reframe if it moves.

**Check premises at their source, in this order of strength:** run the
command or query · read the symbol · read the record · the brief's word.
Wherever your take rests on inference rather than something you actually
read, go read it. `Unverified` is a finding, not a failure: it names the
missing evidence and stays unverified until that evidence exists.
Production claims take production evidence; when getting it would be its
own investigation, say so rather than infer it.

**Structure: is this a local change the design absorbs, or is the design
in the way?** When the foundation fights the change, preparatory
refactoring — *make the change easy, then make the easy change* — beats
another patch: reshape the foundation first so the feature becomes a
natural addition. That is earned only when the structure genuinely blocks
the goal, never license to rewrite what merely looks imperfect; back a
"structurally wrong" call with the code and name its cost.

**Proof is the recipe's last step.** An approach with no observable
success available today — no predicate that is red now and would go green,
no measurement, no user-visible before/after — is not yet testable, and
that is itself the strongest objection for section 5 to answer.

**Risk is not lines changed** — an internal refactor can be large and
inert. It is whether the change lands on the **hot path** (code that runs
on every request, render, or token), on a **surface the user sees or drives
often**, or inside a **core feature's execution logic**. For each it
touches: what actually runs differently, what holds the risk down (coverage
that already exists, a flag or fallback, a signal that would catch a
regression), and — where the risk is real — why it is worth taking. Ground
each claim in the code you read: "adds a branch that only runs in the error
path" is an answer, "overhead is minimal" is not. This is an accounting,
not a veto — a controlled risk on the hot path is fine, an unexamined one
is not.

**One countershape here; the design space belongs to the consult.** The
proposal is the brief's `## At pickup` approach block — the bet, what it
optimizes for, what it accepts, and the evidence that would change it.
Sketch one approach that makes a genuinely different bet from it — a
contained change against a structural one, a different seam, a different
owner of the state — so the two stress-test each other rather than one
standing in as a strawman for a choice already made. Weigh them by how
fully each solves the root problem, never by how little it disturbs;
combine the best of both where a hybrid removes the strongest objection,
and reject a hybrid that merely sums both costs. The recommendation is a
position — `/consult` is dispatched *from* it, never toward it — and where
the choice is genuinely a judgment call, say so instead of forcing a
verdict.

**Route every question you are tempted to ask into one of three lanes:**

- **Product or direction forks** — real decisions with live options that
  are the user's (intent, priorities, UX, scope). These are section 6's
  *Decision needed*, in the form below. None is a fine answer.
- **Implementation details** — yours. Decide, record the choice in the
  packet, continue.
- **Technical unknowns that do not change the direction** — section 6's
  *Parked*, each with your working answer; the consult or a review round
  resolves them. Omit the list when it is empty.

Write each fork as if briefing a CEO who decides from your words alone,
not from the code or the session behind them: why it matters now, what it
means in plain product terms, the options with what each implies for the
real user, and your recommendation. Before sending, check each against:
could they decide from this text alone?

<example>
**Q2 — When a schedule import partially fails, do we save the good rows or reject the file?** This decides what a user sees after uploading a 500-task file with 3 bad rows. Save-partial gets them working immediately but they may not notice the 3 missing tasks; reject-whole is safe but turns one typo into a blocked afternoon. Recommendation: save-partial with a banner naming the failed rows — the blocked afternoon is the worse failure.
</example>

Done when every premise carries one of the three verdicts, every
perspective carries an objection or `None found`, the risk accounting names
each of the three surfaces it touches or says it touches none, and section 5
ends on a recommendation with its trade-off. End by offering `/consult`
with sections 1–5 as its brief; it performs the multi-approach exploration
and settles the direction. Stop after this response — implementation
begins once that direction is accepted.
