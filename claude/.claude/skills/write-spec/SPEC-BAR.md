# The spec bar

The writing standard [write-spec](SKILL.md) step 2 holds the document to:
what to read first, the document's shape, the target shape, and the finish
checks. A human reads the spec later to understand the change: tight prose
beats exhaustive sections, and every section earns its place.

## Read these first

Scale the reading to where the change's novelty lives — a contained
behavioral change may need only the testing bars; a restructure needs all
four design lessons. If a path is missing, ask rather than guessing.

**Read closely.** The spec decides module structure, interfaces, and where
seams fall; these are the vocabulary those decisions are made in.

- `~/.config/lessons/codebase-design/deep-modules.md` — deep modules, seams,
  the deletion test, illegal states.
- `~/.config/lessons/codebase-design/design-it-twice.md` — how to arrive at
  an interface instead of settling for the first one. Read it when you write
  the target-shape section.
- `~/.config/lessons/codebase-design/deepening.md` — read it when the change
  restructures an existing cluster, or leans on a dependency across a seam
  you don't own: its dependency categories decide whether a seam needs a port
  at all.
- `~/.config/lessons/codebase-design/composition.md` — the path *between*
  modules: what each hop in a call chain adds, whether adjacent layers change
  the abstraction, and whether a new case gets absorbed by the concepts
  already there or accretes beside them. Read it whenever this change extends
  existing code — it decides how the new shape wires into the old one, which
  is the half of the target shape a spec most often leaves implicit.

**Skim the `## The bar` at the top of each of these.** You decide *which*
behaviors matter and what gets faked where; the depth below the bar belongs
to the build.

- `~/.config/lessons/testing/tdd-loop.md` — behavior through interfaces.
  Which behaviors matter is a product call to surface, not to assume.
- `~/.config/lessons/testing/mocking-and-fixtures.md` — mock only at
  boundaries. A mock of your own module is a design signal: fix the interface
  here rather than plan a mock later.

## The document's shape

The spec runs top-down, product to technical, each tier at its own altitude.

**A leader-facing summary, first.** Report the change the way you'd report it
to your leader:

- What we're adding or fixing, in product terms — the feature, the bug, the
  problem it solves.
- The approach we're taking, and the scope of the change.
- The boundary once it lands: what's fixed, what isn't, and what's explicitly
  deferred (one line why each).
- Risks to existing users — the hot path, surfaces they drive often,
  core-feature logic — and what holds each down; one line if the change
  touches none.

Technical detail earns a place here only where it makes the problem or the
solution easier to grasp. Someone who reads nothing else should still know
what they're getting and not getting.

**Product sections** — the goals, the user-facing behaviors, the non-goals.
Distinguish current from desired (what's preserved versus what's changing),
and name the coupling decision: an extension of an existing concept, or
intentionally independent?

A before/after view of the changed flow often makes the change crisp — adapt
the format (tree, prose, diagram) to what fits. Small is enough:

    Current:  submit → validate → save → confirm
    Desired:  submit → validate → save → fire webhook → confirm
                                         (new; failure retries, never blocks confirm)

**Technical sections** — the shape of the build:

- *Module boundaries and seams* — which modules own the change, the interface
  each presents, and where the seam falls.
- *The foundation decision* — is the existing code a base this extends
  cleanly, or a structure that blocks the design you actually want? If it
  blocks, scope a bounded reshaping as the opening move — sized to this
  feature, not a module rewrite — and name what you're deliberately leaving
  alone.
- *The target shape* — the envisioned end-state; the next section says how.
- *Test standards* — the behaviors that must be tested, and for each the
  strategy: through which interface, what gets faked at which boundary, plus
  the gotchas worth flagging. What to test and how to think about testing it —
  the build enumerates the cases.

## The target shape

When the change reshapes structure or grows a surface, give the target shape
its own section — the envisioned end-state, in the same before → after
register. Include only the views where the change actually lives: a contained
bug fix may need none; an SDK or a structural refactor may earn all three.
This is the spec's highest-value handoff — the implementing session deepens
the shape you propose instead of redrawing it.

- **File/module structure** — where the pieces live once this lands: a
  directory tree with one-line roles, each entry a domain concept (a state, a
  kind of data, a responsibility), not a layer of plumbing. The structure is
  the spec's domain model made visible.
- **Public API or syntax** — what a caller writes once this exists: the
  exported functions, the config shape, the command line. The surface a user
  touches, never the bodies behind it.
- **Integration wiring** — how the new piece connects to what exists, and how
  data and control flow through the changed system: who calls it, what it
  replaces, which seams it plugs into. Prose or a diagram, with
  implementation anchors (modules, functions, files) attached to the flow
  rather than carrying it.

Sketches stay small — the shape, not the build:

    Structure — after:
      src/export/
        index.ts    # the one entry: exportReport()
        csv.ts      # CSV rendering — format quirks live here
        pdf.ts      # PDF rendering

    API — what a caller writes:
      exportReport(report, { format: "csv" })
      (one deep entry point — not exportCsv / exportPdf / exportXlsx each exported)

Shape all three with a deep-module mindset: small surfaces concentrating
complexity behind them, the domain's states and data carved so wrong ones are
hard to express, seams few and narrow rather than many and chatty. Mark them
as the *envisioned* shape, not a contract — the build may drift for stated
reasons when the code teaches better, never silently.

**Design it twice before you commit.** Your first interface idea is rarely
your best, and the shape you settle here is the shape the build deepens. Run
the exercise as `design-it-twice.md` teaches — sketch shapes different in
kind, each constraint written down first and worked in isolation, compared
on depth, locality, and seam placement.

What lands in the document is the winner, not the menu: the chosen structure /
API / wiring, plus a short **Shapes considered** note — the constraint each
alternative optimized and the one-line reason it lost, in that same
vocabulary. Two or three lines, not three sections. It pays for itself twice:
a reviewer can check whether the shape was *chosen* or merely *first*, and
the build knows why *not* the other shape, so it doesn't quietly re-derive it.

## Before you finish

**Be concrete, not vague.** Vague verbs — improve, enhance, polish, better,
optimize, streamline — name a *direction*, not a *decision*; they quietly
defer the real choice to implementation, which defeats the point of writing a
spec. Say what changes: the specific behavior, state, or outcome that
differs, and the rule or shape that produces it. "Improve error handling" →
"on a failed webhook, retry with backoff, then surface a dismissible banner
instead of failing silently."

**Leave out what isn't yours to pin.** Two kinds. Details the code hasn't
taught us yet — full code bodies, per-case test enumeration and fixtures,
line-level edit plans, exhaustive call-site rename inventories, doc-update
plans, commit order — belong to the build; the
spec owes the *what*, the *why*, and the *shape*. (Domain and interface
vocabulary is the spec's to fix — what gets excluded is the per-call-site
mechanics of applying it.) And time or effort estimates ("2 days", "~3
hours") describe the work no better than the work itself does. Phases are
fine; a precise commit order is not. Code appears only as the target shape's
surface sketches.

**Hunt the rabbit holes.** Walk the approach end to end looking for what
could quietly eat the build: a technical unknown nobody has proven, a design
problem the spec gestures at but doesn't solve, an interdependency that reads
simpler than it is. Solve each here, cut it out of scope explicitly, or name
it in the open questions. An unnamed hole doesn't disappear — it resurfaces
mid-build as a stall or a silent wrong turn.
