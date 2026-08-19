# Composition

How modules stack into call paths, and how a change joins the ones already there. Assumes the vocabulary in [deep-modules.md](deep-modules.md) — **module**, **interface**, **seam**, **depth**. That lesson judges one module against its callers; this one judges the path *between* modules, and the shape a change leaves behind when it is done.

The unit here is not a function. It is the route a real request takes from entry to effect, the layers it crosses, and what each crossing costs the next person to read it.

**Both tenses.** Read forward, it decides how a new module should meet the ones already there — the question behind any public interface. Read backward, it judges whether a change that already exists was absorbed or bolted on. The instruments are the same; only whether the path is proposed or shipped changes, and each section below says which reading it is describing when the two differ.

## The bar

Skim these as a lens; the sections below carry the why.

- **Trace one real path before judging anything.** Follow a request the design exists to serve, entry to effect, and name what each hop *adds* — a decision, a translation, an invariant, an effect. A hop that adds nothing is the finding, and the finding is the hop, not its contents. On a shipped change you trace the code; on a proposed one you trace the path a caller *will* take, which is the cheapest moment to discover a hop nobody can justify.
- **Adjacent layers speak different abstractions.** Where a caller and its callee share the same nouns and a near-identical signature, one of the two is not a layer. Every hop should change what the vocabulary is *about*, not restate it one frame down.
- **Judge the join, not the addition.** Ask of every change: did the concepts already there absorb the new case, or did it get its own path beside them — a flag, a wrapper, a parallel function, a second mechanism answering the same question? Working code that accreted still failed.
- **Price the next change, not this one.** If the following case of the same kind would again require edits in the same N places, the change amplified instead of absorbing. The reshape moves the knowledge to one home; the patch schedules the next patch.
- **Count concepts, not lines.** The strongest move available in either tense is the one that *deletes* a concept — a mode, a flag, a layer, a state, a whole path. A restructuring that only moves code is worth much less than one that leaves fewer things to know.
- **Keep strong coupling short.** The harder a change in one place forces a matching change elsewhere (**connascence**), the closer the two must live. That coupling inside one module is fine; the same coupling across a seam is the finding, and what crosses a seam should use the weakest form that works.
- **Special cases stay out of general mechanisms.** A parameter threaded down a chain so one distant caller behaves differently is the general mechanism learning about a special one. What only one caller knows, that caller keeps.
- **The reshape must pay for itself.** A composition finding that asks for a general mechanism before the second real caller exists is the additive bias one altitude up. Name the caller that exists today, or file the observation and say it is one.

## The trace

The instrument. Before forming any opinion, pick the single path the change exists to serve and write it out as hops — `entry → … → effect` — one line each for what that hop adds. Then read the trace four ways:

1. **Hops that add nothing.** A **pass-through**: it invokes the next thing with a signature nearly identical to its own. It cost a reader a file jump and bought them no knowledge. The fix is to remove the hop, not to justify it.
2. **Hops that add the same thing twice.** The same validation, defaulting, retry, or error-wrapping at two altitudes. Somebody must own it; two owners means neither can be trusted and both will drift.
3. **Arguments that survive hops untouched.** A **pass-through variable** exists only because something deeper needs it, and every layer it crosses is a module forced to know its callee's callee. A handful of them is the usual tell that a seam is in the wrong place.
4. **The shape of the path itself.** Does it descend — each hop more specific, or steadily more general — or does it **oscillate**: policy, mechanism, policy again, decisions made at three different altitudes about the same thing? Oscillation is where layering is decorative.

Two questions a change owes the trace. Adding a hop to an existing path owes an answer to what the hop adds. Adding a *second* path to the same effect owes an answer to why the first one could not carry it.

**Tracing a path that does not exist yet.** Nothing above needs a diff. Write the hops your design proposes — the call a caller will actually make, through each layer, to the effect it wants — and read them the same four ways. Two failures surface here and almost nowhere else: an interface whose caller must learn a hop it should never have heard of (the pass-through variable, visible in the signature before a line is written), and a layer added because the design felt like it needed one, which is the pass-through you get to delete for free. A hop deleted on a whiteboard costs nothing; the same hop deleted after it ships costs a migration.

## How a change joins

Three shapes, worth naming because the middle one passes tests and passes review.

**Integrated** — the existing concepts stretched to hold the new case. The diff mostly edits code that was already there, and the number of things a reader must know is flat or lower. This is the target, and it is usually the larger diff.

**Accreted** — the new case got its own route beside the old one: a boolean parameter, a branch at the top, a wrapper, a sibling function with `2` or `New` or `Ex` in its name. Every accretion is individually defensible and locally minimal; the cost is that the concept count went up by one and lands on every later reader. This is the default outcome of a change made under time pressure, which is why a reviewer has to look for it deliberately — nothing about it *looks* wrong.

**Layered over** — a new mechanism introduced for new code while the old one stays for old code, so the codebase now holds two answers to the same question and the reader must learn which is live where. The **lava layer**: worst of the three, because both are load-bearing and neither is complete. The finding names the migration that was skipped and its real scope; a change that genuinely cannot finish the migration says so on the record rather than leaving the next reader to discover the second answer by accident.

The distinction the architecture literature draws is useful here: **drift** is a decision the original design never anticipated but does not contradict; **erosion** is one that violates it. Drift is a note; erosion is a defect, and a range that erodes silently is worse than one that erodes loudly.

## Vocabulary

Named shapes, so a finding can be stated in one token instead of a paragraph. The first five are Ousterhout's red flags, the next three Fowler's smells, then Page-Jones's coupling metric.

**Pass-through method** — a hop that does little but call the next thing with a similar signature. Interface complexity with no functionality behind it. Fowler's **middle man** is the same shape at class scale.

**Pass-through variable** — a parameter carried through layers that do not use it, present only to reach something deeper. A context object beats threading it; a seam in the right place beats both.

**Special-general mixture** — a general-purpose mechanism carrying code for one particular use of it. Creates leakage in both directions: changing the use case forces changes to the mechanism.

**Information leakage** — the same design knowledge (a format, an order, a default, an encoding) living in two modules that must agree. Two places that change together are one module with a seam through the middle of it.

**Temporal decomposition** — modules carved by *when* they run rather than by *what they know*, so the call chain becomes the design and each stage encodes its successor's needs. Common in pipelines assembled a step at a time.

**Change amplification** — one design decision that requires edits in many places. Fowler's **shotgun surgery** is what it looks like from the diff; its mirror, **divergent change**, is one module edited for many unrelated reasons, and both say responsibilities are split along the wrong axis.

**Message chain** — a caller navigating `a.b().c().d()` to reach something three objects away, binding itself to a structure it does not own. Ask the first object for the answer instead of for the route.

**Connascence** _(Page-Jones)_ — any coupling where a change in one element forces a change in another, graded by **strength** (how hard it is to change together — name, type, position, meaning, algorithm, execution order, timing, identity, roughly weakest to strongest), **locality** (how far apart the two live), and **degree** (how many elements share it). Two rules carry most of the value: minimize connascence that crosses a seam, and the further apart two things are, the weaker the form between them must be. It is the precise vocabulary for "these modules are too entangled" — use it instead.

**Speculative generality** — the anti-finding. An abstraction, a port, a plug-in point, or a config knob built for a caller that does not exist. A composition finding must not create one.

## Why accretion is the default

A patch is proposed against the code as it stands, and the code as it stands is the strongest available argument that its shape is correct. Adding a branch keeps every existing caller working, touches the fewest lines, reviews fastest, and is the honest local optimum for the person holding the ticket. Nothing in the change itself signals the cost, because the cost is paid by later readers in a currency the diff does not show — concepts to hold, paths to check, places to look.

Reviews miss it for a matching reason. Defects announce themselves as failures; accretion announces itself as *working*, and the reviewer who accepts the implementation's framing will find only better ways to spend the branch. So the trace has to be walked deliberately, and on the small contained fixes most of all — those are the ranges nobody thinks to walk, and the ones where a bolt-on hides best.

At design time the same pull is there and the cost of yielding is lower, which is the whole argument for spending the trace early: the shape that would accrete is also the shape that is easiest to draw, because it leaves every existing box on the diagram untouched. Choosing the join before the code exists is the one point where integrating and accreting cost the same.

The counterweight is the last bar bullet, and it is not optional. People systematically overlook subtractive changes, so the reshape a review proposes should be the one that *removes* a concept; a proposal that only adds a layer of generality is the same bias with better vocabulary.

## Rejected framings

- **"More layers is better structure."** A layer earns its place by changing the abstraction. Counting them measures nothing; a stack of pass-throughs is worse than the direct call it replaced.
- **"Coupling is bad."** Coupling is inevitable and often correct. What is judgeable is its strength against its distance — which is why connascence, not a coupling/decoupling binary, is the working vocabulary.
- **"Refactor it later."** A composition finding deferred is the lava layer's first step: the second mechanism has now shipped, and the migration that was cheap while the change was open is not cheap again.
- **"It passes, so the shape is fine."** Behaviour and composition are independent verdicts. Approval is earned by both.

---

> _Lesson · codebase-design. New 2026-08 for the `/review` composition axis, generalized to design time 2026-08-19 once `/consult` and the spec-stage snippets began citing it. Synthesizes Ousterhout's red flags (APOSD ch. 19) and layer/abstraction rule, Fowler's cross-module smells (shotgun surgery, divergent change, middle man, message chains), Page-Jones's connascence, and the architecture-erosion literature (drift vs erosion; Hadlow's lava-layer anti-pattern). No upstream skill baseline._
