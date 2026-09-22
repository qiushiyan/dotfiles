## Pickup gate — design

**The problem is on trial, not just the approach.** This brief carries a
symptom, a framing, and a proposed approach that nobody outside the writing
session has judged. The first turn is an analysis pass that reasons from
the code as it is rather than from the brief's assumptions, and attacks all
three: the framing may be redefined.

The packet has two readers, in this order. First the user, who wrote or
accepted this brief days ago, has run other tracks since, and opens the
packet having lost the thread — it is their first look at this work since
then, and it has to re-ground them before it asks anything of them. Second
the `/consult` round that usually follows, which takes the packet as its
input and shapes its own brief from it. Write for the first reader; the
second reads through them.

**Read only; write nothing into the worktree.** Run existing commands,
tests, and queries freely; scratch files go to the scratchpad. A claim
that needs a test that does not exist yet stays `Unverified` and names the
test — the build turn writes it. After the project onboarding the pointer
names, run `brief drift <slug>` before any other read: a claim the drift
shows moved is checked against the moved code; a brief instruction the
drift makes moot is named as such rather than followed.

Return this shape, in about 1,000 words. Section 1 is prose; elsewhere the
`·` and `|` mark slots, and each slot is filled with a clause the user can
follow, never a label.

```markdown
## 1. Where we are
<the re-grounding: what this part of the product does and for whom · what is broken or wanted, and why it matters now · what has already landed toward it · what this session is for — plain sentences, as to a colleague back from two weeks away; a PR number or doc section only as a pointer after the plain sentence; a term the brief coined is re-introduced before it is used>
Framing: holds | redefined — <what the code and evidence say the problem is, and where the brief was off>

## 2. Premises checked
- <the one premise that, false, means the approach no longer solves the stated problem — one of the brief's load-bearing claims, or unlisted> · Held — <evidence> | Falsified — <what is true instead> | Unverified — <what would settle it>
- <each remaining `## At pickup` claim, at its named source> · …
- Cause on trial <only when the brief inferred its cause rather than traced it; this line records what your read did to each link>: observed — <what a user or a log saw, quoted; "nothing on record" when the brief argues from a class> · claimed chain — <X causes Y, which is why we see Z> · each link Held | Falsified | Unverified at its source · alternative cause the evidence leaves open — <cause> | none

## 3. Pressure test
- User: <strongest objection from what the user sees, waits for, or must understand> | None found
- Structure: <the change is absorbed by the current design | accreted onto it | blocked by it — and the preparatory reshape, if the foundation fights the change> · <strongest objection> | None found
- Proof: <the observation, available today, that would show the approach worked> | ran — <what it showed> | none named — not testable yet

## 4. Risk accounting
<for each of hot path · user-driven surface · core execution logic the change touches: what runs differently, what holds the risk down, why it is worth it — or one line saying it touches none>

## 5. End state
<the shape this part of the system is headed for — the initiative's sequence doc where it records one, else what section 2's facts imply — in a sentence or two> · <one reshape away | a different system> · <what the recommendation does toward it> | the current structure is that shape | not established — <what the checks left unverified>

## 6. Countershape, trade-off, recommendation
<one genuinely different shape that answers the strongest objection — or "the proposal survived: <why the objections leave it standing>" | "the proposal is moot — <the premise that fell>" | "no countershape — section 2 fixed the shape at <seam>; what is open is <scope or sequence>"; the moot and no-countershape verdicts drop the comparison line>
<proposal vs countershape on the root problem and on user / structure / risk cost; a hybrid only where a changed shape removes the strongest objection — removing it by deferring a part is sequence, for the line below>
Recommendation: <the shape> — accepts <the trade-off> · <"a judgment call" where it genuinely is one> · <one PR, or the sequence, under the project's milestone rule where one exists> | none — the brief closes: <what answered it, and where the record goes>

## 7. Decisions and parked unknowns
Decision needed: <a product fork, in the form below> | none
Parked: <an unresolved technical fact that does not change the direction, with its working answer> | none

## Next move
<the consult you recommend and its mode — approach when the mechanism is traced and the shape is open, diagnosis when the cause is still a belief — with the one question the round would buy and, where a fork is open, the option the round should assume until the user answers it> | none — the brief closes, and the closing record is <where>
```

### How each section earns its place

**Read the code before writing section 1.** Trace the real data and
control flow, note the constraints that exist and why, and cite the files
and functions you read. Then write the re-grounding for the user, in their
register, before the technical restatement: the vocabulary you built while
reading is yours, not theirs. When the code and evidence contradict the
brief, the restatement follows the code and names where the brief was off —
that redefinition is what this gate exists to allow, and when the framing
moves, say so in the first line.

<example type="avoid">
#5753, #5784 and #5872 fixed the mechanisms and landed the composed witnesses, but nothing has run them: the four twin cases, the fleet predicates the two 08-25 specs owe, and the closing-read lines in §M7 are all still open.
</example>

<example>
Loopy can edit wiki pages from inside a run. On pool-served workspaces three things went wrong in late August: an agent's edit saved but a person with the page open never saw it appear; an access grant approved mid-run never reached the running session; two writers could mint the same block id and corrupt the page. Three PRs fixed the mechanisms, each with a browser test that proves it (#5753, #5784, #5872). None of those tests has yet been run against the deployed system — this session runs them and records what they show, so the status ledger closes on evidence rather than on the specs' word.
</example>

**Check premises at their source, in this order of strength:** run the
command or query · read the symbol · read the record · the brief's word.
`Unverified` is a finding, not a failure: it names the missing evidence and
stays unverified until that evidence exists. Production claims take
production evidence; when getting it would be its own investigation, say
so rather than infer it. A spec's `Today:` lines, the sentences in its
Structure and Wiring that describe the code as it is, are premises for
this check: read each at the path it names before building on it.

**A cause still believed goes on trial; a cause read from the code is a
premise like any other.** When the brief's fix rests on a cause nobody has
traced to its lines — inferred from an incident, a log, a timeline —
separate what was observed from what was inferred, test each link of the
claimed chain at its source, and name the alternative cause the evidence
has not ruled out; the countershape in section 6 is then the fix at a
different link, and the consult is diagnosis mode. When the mechanism is
traced and you can point at it, the cause is checked in the ordinary
premise line and the consult is approach mode: the shape of the fix is
what is open.

**Structure: is this a local change the design absorbs, or is the design
in the way?** When the foundation fights the change, preparatory
refactoring — *make the change easy, then make the easy change* — beats
another patch; back a "structurally wrong" call with the code and name its
cost.

**Proof is the recipe's last step.** An approach with no observable
success available today — no predicate that is red now and would go green,
no measurement, no user-visible before/after — is not yet testable, and
that is itself the strongest objection for section 6 to answer.

**Risk is not lines changed** — an internal refactor can be large and
inert. What holds the risk down is coverage that already exists, a flag or
fallback, or a signal that would catch a regression. "Adds a branch that
only runs in the error path" is an answer; "overhead is minimal" is not.
This is an accounting, not a veto.

**Section 5 is the end state; section 6 holds one countershape; the
design space belongs to the consult.** The end state is where this part
of the system is headed, and it is usually already written: a live
initiative records it in its sequence doc, which the onboarding read
reaches through the brief's `paths:`. Quote it from there. Where nothing
is recorded, section 2's facts may imply one — a measurement, a falsified
premise, a mechanism read from the code — and where they do not, the slot
says so; an end state invented to fill the slot is worse than none. A
sentence or two, not a design: it orients the recommendation, so a local
fix is chosen knowing what it defers rather than because the brief's frame
stopped at the local fix. Precedence with section 1: a fact that changes
what the brief's problem *is* redefines the framing there; a fact that
leaves the brief's problem standing and shows a larger one beside it is
named here, the recommendation stays on the brief's question, and whether
this session turns to the larger problem is a scope fork for section 7 —
the user's to decide.

<example>
## 5. End state
The capacity initiative's next milestone records it: the process that coordinates every run does no heavy work on its own thread. Today that thread still hashes and assembles each unpacked file on a cold claim, in slices of a few milliseconds · one reshape away · this brief's lever closes with nothing to build; the unpack share is that milestone's question, and section 7 asks whether this session takes it up.
</example>

<example>
## 5. End state
The current structure is that shape: one serializer behind one versioned header, every writer inside it. The change flips a default inside that structure.
</example>

The proposal is the brief's `## At pickup` approach block. Sketch one
approach that makes a genuinely different bet from it — a contained change
against a structural one, the shape that makes the problem's class
disappear rather than this instance, a different seam, a different owner
of the state — so the two stress-test each other. A smaller slice, a split
into more PRs or a reordering is a sequencing question, not a countershape:
it settles nothing about the shape, and it goes on the recommendation line
under the project's milestone rule where one exists — an initiative's
sequence doc, or the project handoff skill's next-milestone review. Weigh
proposal and countershape by how fully each solves the root problem;
combine them where a hybrid removes the strongest objection. When the
proposal wins, one clause says why the cheaper shape does not — that
clause is what shows a structural change earns its cost at the current
scale. The recommendation is the step the
evidence in hand supports, said with the end state it faces; the consult
is dispatched from it, and where the choice is genuinely a judgment call,
say so.

**Route every question you are tempted to ask into one of three lanes:**

- **Product or direction forks** — real decisions with live options that
  are the user's (intent, priorities, UX, scope). These are section 7's
  *Decision needed*. None is a fine answer, and an open fork does not
  block the consult: name the option the round should assume.
- **Implementation details** — yours. Decide, record the choice in the
  packet, continue.
- **Technical unknowns that do not change the direction** — section 7's
  *Parked*, each with your working answer; the consult or a review round
  resolves them. Omit the list when it is empty.

Write each fork as if briefing a CEO who decides from your words alone,
not from the code or the session behind them: why it matters now, what it
means in plain product terms, the options with what each implies for the
real user, and your recommendation. A term section 1 did not introduce is
introduced again where the user must act on it — a question, the
recommendation — since the vocabulary sections 2–6 built is yours, and a
line that leans on it comes back as "what does this mean?" instead of a
decision.

<example>
**Q2 — When a schedule import partially fails, do we save the good rows or reject the file?** This decides what a user sees after uploading a 500-task file with 3 bad rows. Save-partial gets them working immediately but they may not notice the 3 missing tasks; reject-whole is safe but turns one typo into a blocked afternoon. Recommendation: save-partial with a banner naming the failed rows — the blocked afternoon is the worse failure.
</example>

Done when section 1 would re-ground the user without the brief in front
of them, every slot in sections 2–7 carries its verdict or its `none`, and
the next move names a consult with its mode and question, or the close. Stop after this
response — implementation begins once the direction is accepted.
