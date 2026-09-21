# The spec bar

The writing standard [write-spec](SKILL.md) step 2 holds the document to.
Write for two models that hold none of this conversation: a cold validator
judging the design, and the implementing session rereading the spec after
compaction. They need to reconstruct the problem, the intended outcome, the
binding decisions with their reasons, the evidence those decisions rest on,
and the shape to build. A section earns its place by changing an
implementation choice or by making one judgeable. The session's journey
(consult rounds, the scope cut's history, decision logs, review records)
stays out; each
decision's reason and the evidence behind it stay in.

Done when the summary alone re-grounds a cold reader, every design-changing
premise carries its evidence or a settled fallback, every rule has one home,
and every cited path and heading resolves. The examples below are adapted
from shipped specs; their names and numbers illustrate a form and say
nothing about the project at hand.

## Read these first

They are the vocabulary the spec's decisions are made in. A normal run reads
most of them; trim only for a genuinely contained change.

- `~/.config/lessons/codebase-design/deep-modules.md` — depth, seams, the
  deletion test, illegal states. Read closely.
- `~/.config/lessons/codebase-design/design-it-twice.md` — read before the
  Design section.
- `~/.config/lessons/codebase-design/deepening.md` — when the change
  restructures an existing cluster or crosses a seam you don't own.
- `~/.config/lessons/codebase-design/composition.md` — whenever the change
  extends existing code: how the new shape joins the old one.
- `~/.config/lessons/testing/tdd-loop.md` and
  `~/.config/lessons/testing/mocking-and-fixtures.md` — skim `## The bar` of
  each. Which behaviours matter is a product call to surface.
- `~/.config/lessons/collaboration/tenets.md` — the form a tenet takes.

## The document's shape

The headings, in order: Summary, Intent, Tenets, Behaviour, Design,
Verification, Delivery. Five of them are authorities, each for one kind
of statement; the Summary re-grounds, and the Tenets carry Intent's
cross-cutting constraints as their own section. A section a written
project rule requires (a status header, an As built record) is added at
the kind it belongs to; nothing else about the shape comes from the
project.

- **Intent** — goals and non-goals, with the Tenets right after them: the
  cross-cutting constraints the build holds to.
- **Behaviour** — what a person observes, situation by situation.
- **Design** — ownership, interfaces, wiring, and the premises they rest on.
- **Verification** — how each obligation will be observed.
- **Delivery** — phases where order matters, gates, and open decisions.

A rule and its reason live in one home. The summary, a sketch, or a test may
restate the headline, and says which section it points at; none redefines
the rule. A rule stated in three places drifts until the build finds the
contradiction.

### The summary, first

Open with a labelled block under a `## Summary` heading, ahead of the five
sections, that re-grounds a model reading cold: one complete short sentence
per line, selective about what it keeps, with a
blank line between the groups so the eye finds the state, the change, the
edges and the pointers without reading every line. Keep any exception that
changes the build and any dependency still outstanding. Point at the
sections that own the detail. A prose summary of the same content hides the exceptions and the
dependencies inside its sentences.

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

### Intent

Goals say what is true once this lands. Non-goals name what is deliberately
left out, each with its reason, and this is where deferred work lives so it
never reads as undecided. Distinguish the existing behaviour from the
proposed one wherever the difference explains the change. Where the change
introduces something a person could mistake for an existing concept, say
whether it extends that concept or stands apart from it, and why.

**Tenets** are the few cross-cutting invariants the build holds to when the
sections run out of instructions, in the form the tenets lesson defines,
each closing with what holds it: the mechanism in § Design that makes it
hard to break, or the numbered obligation in § Verification that would
catch the break. An invariant with neither is a wish: the writer strikes
it, or moves it beside the seam it describes with the observation that
would show it broken. They have one
`## Tenets` section, placed right after Intent; a validation round revises
it in place, and the reason a tenet was struck lives in that round's
synthesis, not here. A rule that binds one behaviour or one seam is not a
tenet; it lives beside that behaviour or seam.

<example>
One resolution of the configuration serves every reader, over each reader
resolving from the same inputs: two resolvers agree until the day one of
them gains an input. Held by: the factory closes over the value the CLI
resolved (§ Design — Wiring) and obligation 2.
</example>

### Behaviour

Describe the situations that change a person's experience. For each: what
they see today, what they see after, the mechanism in one line pointing at
the Design view that owns it, and what happens if the failure recurs. Name what the person sees separately
from what the model or the system receives. A before/after flow earns its
place only where a route changes; a sequence only where order changes the
outcome.

<example>
Situation: a script's output exceeds the bound before `| head -40` trims it.

Today: the model receives forty plausible lines and exit code 0. The planner
may get an answer computed from incomplete data and never know.

After: the model-facing result opens with an INCOMPLETE notice that names
the bound and how much was retained, and tells the model to say so or to
narrow the command. The planner then sees a qualified answer or a retry,
not a confident answer from a partial read.

Mechanism: the limit event reaches the tool result outside stdout and
stderr, so the failing command cannot delete it (§ Design — Wiring). What
the planner sees depends on the model following the notice; § Verification
holds the eval that checks it does.

If it recurs: every affected result carries the notice. The model can print
less, or write to a file and read a slice. A second truncated result does
not become usable evidence because the command exited 0.
</example>

### Design

Name the owner of each responsibility and how every affected caller reaches
it. A proposed owner must be able to reach the dependency its job needs
through an allowed import or interface, without dragging a layer across a
boundary. Say whether the existing code is
a base this extends or a structure that blocks the design, and scope the
opening reshape when it blocks.

Give the views that settle the design, and only those:

- **Structure** — each changed responsibility, its owner, and the
  invariant that owner protects, closing with what holds that invariant:
  the mechanism, or the obligation by number, as a tenet's held-by line
  does. An invariant with neither is struck or demoted to a sentence about
  today. Then the file it lives in today where one exists, and a proposed
  placement last, as a sketch. A file list with no responsibilities beside
  it is what the build copies when it copies the wrong thing.
- **API** — what a caller writes, the distinctions callers rely on, and the
  legal states the surface must express. Walk the real inputs through the
  proposed representation and through the state table; a state the sketch
  cannot represent is a design gap, not a build detail. States go in a
  table, one row per state with when it is entered, when it is left, and
  who writes it: an empty cell is visible, a state missing from a comma
  list is not, and an input that lands in no row is the state you missed.
- **Wiring** — the changed paths: what each boundary knows, what survives a
  retry, and where failure goes. Describe today's path in `Today:` lines,
  each read from the file it names while writing, and the proposed path in
  `After:` lines; the build re-reads every `Today:` line at its path before
  building on it, so a wrong one costs minutes rather than a review round.

Behaviours, ownership, invariants, and the distinctions callers rely on
bind. Proposed symbol names and file placement are sketches the build may
change for a stated reason; the build reports a changed realization apart
from a behaviour it did not build. A sentence that describes what the code
does now is an observation and carries the path it was read at; a sentence
about what it will do is a design.

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
  Retention check, then the fallback to a full build. Owner: the eager
    planner. Protects: a reused send never references bytes the store has
    dropped. Held by: selection returns the artifact and the planner proves
    retention before planning (obligation 4). Today in
    `packages/loopy-master-host/src/loopy_stage_pool_client_data.ts`.

API — what a caller writes:
  selectActiveClientDataArtifact({ workspaceId, planHash, storeFingerprint })
    → { kind: 'artifact', artifact } | { kind: 'absent' } | { kind: 'store-mismatch', artifact }

Binding distinctions:
  The eager planner rebuilds the corpus on absent and on store-mismatch alike.
  The lazy resolver reports the two separately, because a misconfigured store
  must not look like a missing artifact.
  Selection makes no retention request; the lazy read path stays free of network calls.

Legal states of a publication row:

  | state     | entered when                                    | left when                                                  | written by      |
  | --------- | ----------------------------------------------- | ---------------------------------------------------------- | --------------- |
  | pending   | the planner records the plan hash               | the build finishes (published) or fails (failed)           | the planner     |
  | published | the artifact's bytes are retained in the store  | the fingerprint changes (stale) or retention drops (absent) | the publisher   |
  | stale     | the store fingerprint no longer matches         | never; a new plan writes a new row                         | the lazy reader |
  | failed    | the build fails                                 | never; the next send writes a new row                      | the planner     |
  | absent    | retention drops the bytes                       | never; the row is deleted with the artifact                | retention       |

Wiring — the changed path:
  Today: the eager planner builds the corpus on every send and never asks
    whether one is already published (`loopy_stage_pool_client_data.ts`,
    `planClientDataStaging`).
  Today: the lazy resolver reads the newest published row and trusts it
    (`client_data_resolver.ts`, `resolveClientData`).
  After: the eager planner enumerates the corpus once, derives both
    identities, asks selection, proves retention on the returned artifact,
    and only then plans a reused send. Any uncertain answer (no row,
    retention unknown, a throw) takes the full build, so the worst case is
    today's send. A retry re-enters at selection with nothing carried over.
  After: a failure in the reuse probe falls back to the full build; the full
    build keeps its ordinary failure semantics. Reuse is advisory.
</example>

**Design it twice** before you commit a shape, as the lesson teaches: two or
three shapes different in kind, each constraint written first, compared on
depth, locality and seam placement. The document carries the winner and a
short note of the rejected shapes whose rejection still constrains the build,
each with the constraint it optimized and the one line that lost it.

**Premises.** Separate a decision from its basis and from what is still
unverified. A decision is settled or proposed. Its basis is measured,
established from source, inferred, or assumed. For each premise the design
depends on, keep enough evidence beside the decision to judge what was
established without rerunning it; a proposed check is not evidence, and an
unverified premise the design turns on keeps the spec from being ready.

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
wrong assumption changes a number and not the shape:

<example>
Decision: the output bound is 32 MiB. Proposed.
Basis — assumed: no legitimate script in the 30-day fleet read piped more than 8 MiB.
Outstanding verification: the p99 of piped output over that window, from the tool-call rollup.
Fallback: raise the bound to the measured p99 plus margin, capped at the 256 MiB
the shell already allows. The notice, the refusal and the recovery path are the
same at any bound; only the number moves. A p99 above the cap means the bound
cannot hold the fleet, and the premise becomes blocking.
</example>

A premise with no fallback that preserves the design is a gate, not an
assumption: it is settled in this run, or the spec reports it as blocking
with its owner. A spike that fails is recorded in the `/spike` skill's form,
with the observation that decided it.

### Verification

Number the obligations. For each: the behaviour it verifies, the
observation boundary, what must stay real, and what may be substituted with
the claim the substitute can and cannot prove. The numbers are what a
held-by line and the build's report point at. Open the section with one
line addressed to the build, since the spec is the one document the build
reads, asking for each obligation answered by number with its definitions
in the line, as the example opens. An obligation
that vanishes without an answer is the failure the numbering exists to
make visible. Verify that the fixtures and runners you prescribe are
reachable from a build session. A regression the validation asked for is an obligation here,
stated without the round that asked; the build enumerates the cases.

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

### Delivery

State the PR boundary always, and the phases only where order matters; the reasoning
behind one PR in one session is in [SKILL.md](SKILL.md) § Scope. A check
whose failure would change the design belongs before the spec is ready, not
in a first phase of the build.

An open question names the unresolved choice, its consequence, the
recommendation, who decides, and exactly which work waits on it. A settled
exclusion belongs in non-goals with its reason. A technical unknown belongs
beside its premise with the check or fallback that resolves it; Delivery
may point at a blocking premise and name its owner, and the spec is not
ready while it stands.

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
  rule's home finds it by the sentence that states it; a sentence carrying
  three rules in nested clauses hides two of them, and a paragraph that
  runs past a screen is a list or a section in disguise. Name the
  component, the state or the operation instead of the shorthand the
  session coined; a term stays when it gives the reader a resolvable name
  the project already uses.

  <example type="avoid">
  Ask the artifact leg first, fall to the cache path on any uncertain answer.
  </example>

  <example>
  First look for a published corpus artifact that matches the current
  publication plan and the configured store. The eager planner then checks
  that the artifact's bytes are still retained. If either answer is
  uncertain, rebuild the corpus from source.
  </example>

- **Current, searchable names.** Point at source with a path and a
  line-sized description; introduce a proposed name once, where it is
  defined, and use it unchanged afterwards.
- **Structure that reads in plain source.** A heading per reader question,
  a list for independent entries, numbered steps only where order matters,
  a table only where the reader compares the same attributes across rows.
- **Present state and proposed state stay distinct.** Describe the existing
  system as it is; label proposed behaviour as unbuilt.
- **Measurements keep their scope.** A number carries its date, window,
  population and limits, in the premise it supports.
- **References resolve.** Every cited path to existing source and every
  `§ Heading` exists at the revision the spec names; a proposed placement
  is labelled as a sketch and is not a citation.

## Before you finish

- **Hunt the rabbit holes.** Walk the approach end to end for an unproven
  technical claim, a design problem the spec gestures at, or an
  interdependency that reads simpler than it is. Solve each where it lives,
  cut it into non-goals with its reason, or, for a product choice, open it
  in Delivery with its owner. A named hazard is not closed by naming it, and
  a proposed guard is not closed until its mechanism is shown to hold.
- **Readiness.** Every design-changing premise carries evidence or a
  fallback that preserves the design. What remains for the build verifies
  the implementation or calibrates within the agreed design; it does not
  choose the foundation.
- **Leave out what isn't yours to pin.** Full code bodies, per-case test
  enumeration, line-level edit plans, call-site rename inventories, doc
  update plans, commit order, and time estimates belong to the build. Domain
  and interface vocabulary is the spec's to fix. A sentence a model or a
  judge will read is bound by what it must state and what it must not name;
  the build writes it under the prompt-engineering rulebook. A sentence
  written out verbatim here is a premise, run against a real record before
  the spec is called settled, because a copied sentence ships as written.
- **Strip the journey**, as the opening says: consult job names, rounds,
  finding counts and dispositions leave the spec; each decision keeps its
  reason and its evidence. The job names belong in the report.
- **Revise by replacement.** A correction rewrites the sentence at the
  rule's home and the old sentence goes; a clause appended beside it is
  how a spec ends up saying one thing twice. Missing content, a state, an
  owner or an obligation, is added at the section that owns it.
- **Measure the document**, then reread it once as one whole:
  `scripts/spec-stats.py <spec>` prints words per section, sentence length
  and whether the summary is a labelled block; `scripts/check-refs.sh
  <spec>` lists the cited repository paths and `§ Heading` references it
  recognises that do not resolve in the working tree; a clean run means no
  detected misses, and a path outside the repository or in an unusual form
  is checked by hand. Read a sentence past forty words for a second claim,
  and a section that grew by half through the checks for a rule stated
  twice; the number is the cue, the reading is the judgment.
- **Run the project's own checks** from its documentation bindings.
