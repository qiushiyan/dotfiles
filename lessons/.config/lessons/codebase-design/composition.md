# Composition

How modules stack into call paths, and how a change joins the paths already there. It assumes the vocabulary of [deep-modules.md](deep-modules.md): **module**, **interface**, **seam**, **depth**. That lesson judges one module against its callers. This one judges the path *between* modules, and the shape a change leaves behind.

The unit is not a function. It is the route a real request takes from entry to effect, the layers it crosses, and what each crossing costs the next reader.

**Both tenses.** Read forward, it decides how a new module should meet the ones already there. Read backward, it judges whether a shipped change was absorbed or bolted on. The instruments are the same; sections say which tense they mean where it matters.

## The bar

- **Trace one real path before judging anything.** Follow a request the design exists to serve, entry to effect, and name what each hop *adds*: a decision, a translation, an invariant, an effect. A hop that adds nothing is the finding, and the finding is the hop, not its contents. On a shipped change, trace the code; on a proposed one, trace the path a caller *will* take, which is the cheapest moment to find a hop nobody can justify.
- **Adjacent layers speak different abstractions.** Where a caller and its callee share the same nouns and a near-identical signature, one of them is not a layer. Each hop changes what the vocabulary is *about*.
- **Judge the join, not the addition.** Did the concepts already there absorb the new case, or did it get its own path beside them: a flag, a wrapper, a parallel function, a second mechanism answering the same question? Working code that accreted still failed.
- **Price the next change.** If the next case of the same kind would again need edits in the same N places, the change amplified instead of absorbing. The reshape moves the knowledge to one home; the patch schedules the next patch.
- **Count concepts, not lines.** The strongest move in either tense *deletes* a concept: a mode, a flag, a layer, a state, a whole path. A restructuring that only moves code is worth much less.
- **Keep strong coupling short.** The harder a change in one place forces a matching change elsewhere (**connascence**), the closer the two must live. That coupling inside one module is fine; across a seam it is the finding, and what crosses a seam uses the weakest form that works.
- **Special cases stay out of general mechanisms.** A parameter threaded down a chain so one distant caller behaves differently is the general mechanism learning about a special one. What only one caller knows, that caller keeps.
- **The reshape must pay for itself.** A finding that asks for a general mechanism before the second real caller exists is the additive bias one altitude up. Name the caller that exists today, or file the observation as one.

## The trace

Before forming an opinion, pick the one path the change exists to serve and write it as hops, `entry → … → effect`, one line per hop saying what it adds. Then read it four ways:

1. **Hops that add nothing.** A **pass-through** calls the next thing with a signature nearly identical to its own. It cost a reader a file jump and taught nothing. Remove the hop; don't justify it.
2. **Hops that add the same thing twice.** The same validation, defaulting, retry or error-wrapping at two altitudes. Two owners means neither can be trusted, and both drift.
3. **Arguments that survive hops untouched.** A **pass-through variable** exists because something deeper needs it, so every layer it crosses must know its callee's callee. A handful of them usually means a seam is in the wrong place.
4. **The shape of the path.** Does it descend, each hop more specific or steadily more general? Or does it **oscillate**: policy, mechanism, policy again, three altitudes deciding the same thing? Oscillation is where layering is decorative.

A change that adds a hop to an existing path owes an answer to what the hop adds. A change that adds a *second* path to the same effect owes an answer to why the first could not carry it.

**Tracing a path that does not exist yet.** None of this needs a diff. Write the hops your design proposes, from the call a caller will make to the effect it wants, and read them the same four ways. Two failures show here and almost nowhere else: a caller made to learn a hop it should never hear of (the pass-through variable, visible in the signature before any code exists), and a layer added because the design felt like it needed one. A hop deleted on a whiteboard costs nothing; deleted after it ships, it costs a migration.

## How a change joins

Three shapes. The middle one passes tests and passes review.

**Integrated**: the existing concepts stretched to hold the new case. The diff mostly edits code that was already there, and what a reader must know stays flat or shrinks. This is the target, and it is usually the larger diff.

**Accreted**: the new case got its own route beside the old one, such as a boolean parameter, a branch at the top, a wrapper, or a sibling function with `2`, `New` or `Ex` in its name. Each accretion is defensible and locally minimal; the concept count still went up by one, for every later reader. It is the default under time pressure, and nothing about it *looks* wrong, so a reviewer must look for it on purpose.

**Layered over**: a new mechanism for new code while the old one stays for old code, so the codebase holds two answers to one question and the reader must learn which is live where. This is the **lava layer**, the worst of the three, because both answers are load-bearing and neither is complete. The finding names the skipped migration and its real scope. A change that genuinely cannot finish the migration says so on the record.

**Drift** is a decision the original design never anticipated but does not contradict; **erosion** violates it. Drift is a note; erosion is a defect, and silent erosion is worse than loud.

## Vocabulary

Named shapes, so a finding fits in one token. The first five are Ousterhout's red flags, the next three Fowler's smells, then Page-Jones's coupling metric.

**Pass-through method**: a hop that does little but call the next thing with a similar signature. Interface with no functionality behind it. Fowler's **middle man** is the same shape at class scale.

**Pass-through variable**: a parameter carried through layers that don't use it, to reach something deeper. A context object beats threading it; a seam in the right place beats both.

**Special-general mixture**: a general mechanism carrying code for one particular use of it, so a change to the use case forces a change to the mechanism.

**Information leakage**: the same design knowledge (a format, an order, a default, an encoding) in two modules that must agree. Two places that change together are one module with a seam through the middle.

**Temporal decomposition**: modules carved by *when* they run rather than *what they know*, so the call chain becomes the design and each stage encodes its successor's needs. Common in pipelines built a step at a time.

**Change amplification**: one design decision that needs edits in many places. Fowler's **shotgun surgery** is how it looks in a diff. Its mirror, **divergent change**, is one module edited for many unrelated reasons. Both mean responsibilities are split along the wrong axis.

**Message chain**: a caller navigating `a.b().c().d()` to reach something three objects away, binding itself to structure it doesn't own. Ask the first object for the answer, not the route.

**Connascence** _(Page-Jones)_: coupling where a change in one element forces a change in another. Graded by **strength** (roughly weakest to strongest: name, type, position, meaning, algorithm, execution order, timing, identity), **locality** (how far apart the two live) and **degree** (how many elements share it). Two rules carry most of the value: minimize connascence across a seam, and the further apart two things are, the weaker the form between them must be. Use it instead of "these modules are too entangled".

**Speculative generality**: the anti-finding. An abstraction, port, plug-in point or config knob for a caller that does not exist. A composition finding must not create one.

## Why accretion is the default

A patch is proposed against the code as it stands, and that code is the strongest argument that its shape is right. Adding a branch keeps every caller working, touches the fewest lines and reviews fastest. Its cost is paid later, by readers, in concepts to hold and places to look, and the diff does not show it.

Review misses it for the same reason: a defect announces itself as a failure, and accretion announces itself as *working*. So walk the trace deliberately, and on small contained fixes most of all, since nobody thinks to walk those and a bolt-on hides best there.

At design time the pull is the same and yielding costs less. The shape that would accrete is the easiest to draw, because it leaves every existing box untouched. Before the code exists, integrating and accreting cost the same.

The counterweight is the last bar bullet, and it is not optional. People overlook subtractive changes, so the reshape a review proposes should *remove* a concept; one that only adds a layer of generality is the same bias with better vocabulary.

## Rejected framings

- **"More layers is better structure."** A layer earns its place by changing the abstraction. A stack of pass-throughs is worse than the direct call it replaced.
- **"Coupling is bad."** Coupling is inevitable and often right. What can be judged is its strength against its distance, which is why connascence, not a coupled/decoupled binary, is the working vocabulary.
- **"Refactor it later."** A deferred composition finding is the lava layer's first step: the second mechanism has shipped, and the migration that was cheap while the change was open is not cheap again.
- **"It passes, so the shape is fine."** Behaviour and composition are separate verdicts, and approval needs both.

---

> _Lesson · codebase-design. New 2026-08 for the `/review` composition axis, generalized to design time 2026-08-19 once `/consult` and the spec-stage snippets began citing it. Synthesizes Ousterhout's red flags (APOSD ch. 19) and layer/abstraction rule, Fowler's cross-module smells (shotgun surgery, divergent change, middle man, message chains), Page-Jones's connascence, and the architecture-erosion literature (drift vs erosion; Hadlow's lava-layer anti-pattern). No upstream skill baseline._
