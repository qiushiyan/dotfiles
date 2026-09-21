# The spec bar

The standard [write-spec](SKILL.md) step 2 holds the document to. Two
models read the spec with none of this conversation: a cold validator
judging the design, and the implementing session rebuilding its whole
mental model after compaction. Give them the problem, the intended outcome,
each binding decision with its reason and its evidence, and the shape to
build. A section earns its place by changing an implementation choice or
making one judgeable. The journey that produced the spec, consult rounds,
the scope cut's history, decision logs, stays out; each decision's reason
and evidence stay in.

Done when the summary alone re-grounds a cold reader, every design-changing
premise carries evidence or a fallback that preserves the design, every
rule has one home, and every cited path and heading resolves. The examples
are adapted from shipped specs: they show a form, not the project at hand.

## Read first

The vocabulary the spec's decisions are made in; trim only for a genuinely
contained change.

- `~/.config/lessons/codebase-design/deep-modules.md` — depth, seams, the
  deletion test, illegal states.
- `~/.config/lessons/codebase-design/design-it-twice.md` — before the
  Design section.
- `~/.config/lessons/codebase-design/deepening.md` — when the change
  restructures a cluster or crosses a seam you don't own.
- `~/.config/lessons/codebase-design/composition.md` — when the change
  extends existing code.
- `~/.config/lessons/testing/tdd-loop.md` and
  `~/.config/lessons/testing/mocking-and-fixtures.md` — `## The bar` of
  each.
- `~/.config/lessons/collaboration/tenets.md` — the form a tenet takes.

## Shape

The headings, in order: Summary, Intent, Tenets, Behaviour, Design,
Verification, Delivery. Each is the one home for one kind of statement:

- **Summary** re-grounds a cold reader.
- **Intent** — goals and non-goals; **Tenets** — the cross-cutting
  invariants the build holds to.
- **Behaviour** — what a person observes, situation by situation.
- **Design** — ownership, interfaces, wiring, and the premises they rest on.
- **Verification** — how each obligation is observed.
- **Delivery** — the PR boundary, phases where order matters, open
  decisions.

A section a written project rule requires (a status header, an As built
record) joins at the kind it belongs to; nothing else about the shape comes
from the project. A rule and its reason live in one home. The summary, a
sketch or a test may restate the headline, pointing at the section that
owns it; a rule stated in three places drifts until the build finds the
contradiction.

## Summary

A labelled block: one short complete sentence per line, a blank line
between the groups, so the eye finds the state, the change, the edges and
the pointers without reading every line. Keep every exception that changes
the build and every dependency still outstanding; prose hides both inside
its sentences.

<example>
Current: Loopy runs model-written shell scripts inside pool workers.
Failure: oversized piped output exhausts a worker's heap, and the resumed turn can repeat the command and lose the next worker too.
Failure: truncated output can reach the model with exit code 0 and look complete.

Goal: a command that overruns fails honestly, and the worker and the conversation survive.
Change: the text-to-bytes conversion is repaired.
Change: the output bound is lowered, and the truncation notice travels outside the streams.
Recovery: the resumed model is told what failed, and an identical command is refused once.

Boundary: synchronous printing can still stall a worker, and the heap ceiling is unchanged.
Risk: a lower bound may reject legitimate file writes; which constructs the bound charges is measured before the bound is chosen.
Open: which repeated worker losses end the run early is the owner's call.

Where: § Behaviour describes the six situations; § Design carries the mechanism and its evidence; § Delivery holds the open call.
</example>

## Intent and tenets

Goals say what is true once this lands. Non-goals name what is left out,
each with its reason; deferred work lives here so it never reads as
undecided. Where the change introduces something a person could mistake
for an existing concept, say whether it extends that concept or stands
apart, and why.

Tenets are the few invariants that hold when the sections run out of
instructions, in the tenets lesson's form, each closing with what holds
it: the mechanism in § Design that makes it hard to break, or the numbered
obligation in § Verification that catches the break. An invariant with
neither is a wish: strike it, or demote it to a sentence about today beside
the seam it describes, with the observation that would show it broken. A
rule binding one behaviour or one seam lives beside that behaviour or
seam. A validation round revises the section in place; the reason a tenet
was struck belongs to that round's synthesis.

<example>
One resolution of the configuration serves every reader, over each reader
resolving from the same inputs: two resolvers agree until the day one of
them gains an input. Held by: the factory closes over the value the CLI
resolved (§ Design — Wiring) and obligation 2.
</example>

## Behaviour

One situation per heading, for each change to what a person experiences:
what they see today, what they see after, the mechanism in one line
pointing at the Design view that owns it, and what happens if the failure
recurs. Keep what the person sees apart from what the model or the system
receives. A before/after flow earns its place where a route changes; a
sequence where order changes the outcome.

<example>
Situation: a script's output exceeds the bound before `| head -40` trims it.

Today: the model receives forty plausible lines and exit code 0. The planner
may get an answer computed from incomplete data and never know.

After: the model-facing result opens with an INCOMPLETE notice that names
the bound and how much was retained, and tells the model to say so or to
narrow the command. The planner sees a qualified answer or a retry.

Mechanism: the limit event reaches the tool result outside stdout and
stderr, so the failing command cannot delete it (§ Design — Wiring). What
the planner sees depends on the model following the notice; obligation 5
holds the eval that checks it does.

If it recurs: every affected result carries the notice. The model can print
less, or write to a file and read a slice. A second truncated result does
not become usable evidence because the command exited 0.
</example>

## Design

Name the owner of each responsibility and how every affected caller
reaches it, through an allowed import or interface, without dragging a
layer across a boundary. Say whether the existing code is a base this
extends or a structure that blocks the design, and scope the opening
reshape when it blocks. Give the views that settle the design, and only
those:

- **Structure** — each changed responsibility, its owner, the invariant
  the owner protects, and what holds that invariant: the mechanism, or the
  obligation by number, as a tenet's held-by line does, under the tenet
  rule. Then the file it lives in today, and a proposed placement last, as
  a sketch.
- **API** — what a caller writes, the distinctions callers rely on, and
  the legal states in a table: one row per state with when it is entered,
  when it is left, and who writes it. Walk the real inputs through the
  table: an input that lands in no row is the state you missed.
- **Wiring** — the changed paths: what each boundary knows, what survives
  a retry, where failure goes. `Today:` lines describe the path as it is,
  each read from the file it names while writing, since the build re-reads
  every one at its path before building on it. `After:` lines describe the
  proposed path.

Behaviours, ownership, invariants and the distinctions callers rely on
bind. Symbol names and file placement are sketches the build may change
for a stated reason, reported apart from a behaviour it did not build.

<example>
The change: a workspace's published document corpus is reused on the first
send instead of after a later send re-verifies it. Two callers read the
artifact: the eager planner at dispatch time and the lazy resolver at the
read point.

Structure — responsibilities:
  The corpus's durable identity, now including the tree layout. Owner: the
    corpus module. Protects: two sends with the same plan and store resolve
    the same artifact. Held by: the identity is derived, never stored
    (obligation 1). Today in `packages/loopy-master-host/src/workspace_corpus.ts`.
  One artifact-selection rule, shared by both callers. Owner: a publication
    module both callers import. Protects: the eager planner and the lazy
    resolver never disagree about which artifact is current. Held by: both
    import the one function and no other selector exists (obligation 2).
    New; sketched as `client_data_publication.ts` beside the corpus.

API — what a caller writes:
  selectActiveClientDataArtifact({ workspaceId, planHash, storeFingerprint })
    → { kind: 'artifact', artifact } | { kind: 'absent' } | { kind: 'store-mismatch', artifact }

Binding distinctions:
  The eager planner rebuilds the corpus on absent and on store-mismatch alike.
  The lazy resolver reports the two separately, because a misconfigured store
  must not look like a missing artifact.
  Selection makes no retention request; the lazy read path stays free of network calls.

Legal states of a publication row:

  | state     | entered when                                   | left when                                                   | written by      |
  | --------- | ---------------------------------------------- | ----------------------------------------------------------- | --------------- |
  | pending   | the planner records the plan hash              | the build finishes (published) or fails (failed)            | the planner     |
  | published | the artifact's bytes are retained in the store | the fingerprint changes (stale) or retention drops (absent) | the publisher   |
  | stale     | the store fingerprint no longer matches        | never; a new plan writes a new row                          | the lazy reader |
  | failed    | the build fails                                | never; the next send writes a new row                       | the planner     |
  | absent    | retention drops the bytes                      | never; the row is deleted with the artifact                 | retention       |

Wiring — the changed path:
  Today: the eager planner builds the corpus on every send and never asks
    whether one is already published (`loopy_stage_pool_client_data.ts`,
    `planClientDataStaging`).
  Today: the lazy resolver reads the newest published row and trusts it
    (`client_data_resolver.ts`, `resolveClientData`).
  After: the eager planner enumerates the corpus once, derives both
    identities, asks selection, proves retention on the returned artifact,
    and only then plans a reused send. Any uncertain answer takes the full
    build, so the worst case is today's send. A retry re-enters at
    selection with nothing carried over.
  After: a failure in the reuse probe falls back to the full build, which
    keeps its ordinary failure semantics. Reuse is advisory.
</example>

**Design it twice.** Two or three shapes different in kind, each
constraint written first, compared on depth, locality and seam placement.
The document carries the winner and, for each rejected shape whose
rejection still constrains the build, the constraint it optimised and the
one line that lost it.

**Premises.** Separate each decision from its basis and from what is still
unverified. A decision is settled or proposed; its basis is measured,
established from source, inferred, or assumed. Keep enough evidence beside
the decision to judge what was established without rerunning it, and say
what it does not establish. A proposed check is not evidence.

<example>
Decision: repair the text-to-bytes conversion before relying on any output bound. Settled.

Basis — measured, 2026-09-17, branch `fix/worker-liveness-heap-deaths` at 099b2e1b1e.
Claim: the conversion amplifies piped text enough to exhaust the worker heap.
Ran: the real sandbox with the built agent library and the vendored shell 3.4.2,
Node 24.15, default 4,288 MB heap, on a laptop.
Input: 96 MiB through `| head -40 | wc -c`, once as text and once from a file.
Result: heap growth of +3,263 MB for text and −1 MB for the file path; the
isolated converter measured 33 heap bytes per input byte.
Establishes: amplification on the text conversion path.
Does not establish: a safe 32 MiB bound, coverage of the capture path, or the latency after the fix.
Reproduction: the harness command was not retained; the numbers stand as observed and cannot be rerun as written.
</example>

An assumed premise names a fallback that keeps the design standing, so a
wrong assumption moves a number and not the shape:

<example>
Decision: the output bound is 32 MiB. Proposed.
Basis — assumed: no legitimate script in the 30-day fleet read piped more than 8 MiB.
Outstanding verification: the p99 of piped output over that window, from the tool-call rollup.
Fallback: raise the bound to the measured p99 plus margin, capped at the 256 MiB
the shell already allows. The notice, the refusal and the recovery path are the
same at any bound; only the number moves. A p99 above the cap means the bound
cannot hold the fleet, and the premise becomes blocking.
</example>

A premise with no fallback that preserves the design is a gate: settled in
this run, or reported as blocking with its owner. A spike that fails is
recorded in the `/spike` skill's form, with the observation that decided
it.

## Verification

Open with the example's first line, as written, since the spec is the one
document the build reads and that line defines the answers it gives. Then
number the obligations. For
each: the behaviour it verifies, the observation boundary, what stays real,
what may be substituted and what the substitute can and cannot prove, and
whether the fixtures and runners are reachable from a build session. The
numbers are what a held-by line and the build's report point at; an
obligation that vanishes without an answer is the failure the numbering
makes visible. A regression the validation asked for is an obligation here,
stated without the round that asked.

<example>
The build reports each obligation below by number: pinned, a test that
goes red when the behaviour is removed; nominal, a test that exists but
would stay green; or skipped, with the reason.

3. Obligation: the section read model implements § Behaviour — Focus.
Observe: the public section view computed from a card's recorded turns and
state transitions.
Real: the production read-model function and the domain types.
Fixtures: valid recorded turns suffice for this pure transformation.
Persistence claims additionally use records written through the real store,
as `services/steward/src/kernel/store/store.*.test.ts` already does under the
package's `vitest run`.
Reachable: that suite ran green from this checkout in this session. Production
rows were not reachable from this session's environment and are not a prerequisite.
Limit: synthetic records do not establish the shape of historical production data.
</example>

## Delivery

State the PR boundary always, and phases only where order matters
([SKILL.md](SKILL.md) § Scope has the reasoning). A check whose failure
would change the design belongs before the spec is ready, not in a first
phase of the build. An open question names the choice, its consequence,
the recommendation, who decides, and exactly which work waits on it. A
settled exclusion is a non-goal; a technical unknown sits beside its
premise with the check or fallback that resolves it.

<example>
Choice: after two worker losses on one step, stop only on proven heap exhaustion,
or also on repeated unexpected losses that left no fatal report?
Consequence: stop some recoverable runs earlier, or leave some repeated failures
retrying until the ordinary budget expires.
Recommendation: count repeated unexpected losses after the model was warned, and
exclude exits the system requested.
Owner: the product owner; this changes the worker-liveness policy.
Waits on it: the run-ending policy. The conversion repair and the truncation
notice proceed independently.
</example>

## Writing rules

- **One claim per sentence, one topic per paragraph.** A reader hunting a
  rule finds it by the sentence that states it. Name the component, the
  state or the operation rather than the shorthand the session coined; a
  term stays when the project already uses it.

  <example type="avoid">
  Ask the artifact leg first, fall to the cache path on any uncertain answer.
  </example>

  <example>
  First look for a published corpus artifact that matches the current
  publication plan and the configured store. The eager planner then checks
  that the artifact's bytes are still retained. If either answer is
  uncertain, rebuild the corpus from source.
  </example>

- **Present and proposed stay distinct.** A sentence about what the code
  does now is an observation and carries the path it was read at; a
  sentence about what it will do is a design, labelled unbuilt.
- **Numbers keep their scope**: date, window, population and limits, in
  the premise they support.
- **References resolve.** Every cited path and `§ Heading` exists at the
  revision the spec names; a proposed placement is labelled a sketch and
  is not a citation. Introduce a proposed name once, where it is defined,
  and use it unchanged afterwards.
- **Structure that reads in plain source.** A heading per reader question,
  a list for independent entries, numbered steps only where order matters,
  a table only where the reader compares the same attributes across rows.

## Before you finish

- **Hunt the rabbit holes.** Walk the approach end to end for an unproven
  technical claim, a design problem the spec gestures at, or an
  interdependency that reads simpler than it is. Solve each where it
  lives, cut it into non-goals with its reason, or open it in Delivery
  with its owner. A named hazard is not closed by naming it, and a
  proposed guard is not closed until its mechanism is shown to hold.
- **Leave the build what is the build's:** code bodies, per-case test
  enumeration, edit plans, rename inventories, doc update plans, commit
  order, estimates. Domain and interface vocabulary is the spec's to fix.
  A sentence a model or a judge will read is described by what it must
  state and must not name; the build writes it under the prompt-engineering
  rulebook. A sentence written out verbatim here ships as written, so it is
  a premise, run against a real record first.
- **Strip the journey**: job names, rounds, finding counts and
  dispositions leave the spec and go in the report.
- **Revise by replacement.** A correction rewrites the sentence at the
  rule's home and the old sentence goes; missing content is added at the
  section that owns it.
- **Measure, then reread once as one whole.** In this skill's directory,
  `scripts/spec-stats.py <spec>` prints words per section, sentence lengths and the summary
  block's shape; `scripts/check-refs.sh <spec>` lists the cited paths and
  `§ Heading` references it recognises that do not resolve, and a clean
  run means no detected misses. Read a sentence past forty words for a
  second claim, and a section that grew by half through the checks for a
  rule stated twice: the number is the cue, the reading is the judgment.
- **Run the project's own checks**, the ones its documentation entry point
  names.
