# Prompt design patterns

Satellite of `tabtype/CLAUDE.md`. `tabtype/WORKFLOW.md` owns which snippet
fits which moment; this page owns why they are shaped as they are.

## What a snippet carries

Where a skill owns the procedure, the snippet is the sentence that starts it,
and it carries what is costly to say exactly each time:

```text
the entry   → the slash command, the voice or the mode
the pointer → the path of the skill or rulebook to read
the stop    → where the turn ends and whose decision comes next
```

A snippet that restates a skill's discipline is a second home that drifts, so
it names the skill's own term and leaves the rest there: `spike-check` and
`review-verify` name the spike skill's design and verification moments. Where
a snippet departs from the skill it says so in words, as `spike-check` does
when it asks for every assumption the approach fails without, against the
skill's default of the costliest one.

`think-holistic` has no skill behind it, so it carries its whole method.

`tabtype/EVIDENCE.md` holds the usage counts a removal or an addition is
argued from: which snippets sessions expand, which phrases are typed by hand
instead, and what the next pass compares.

## Analysis and questions

`think-holistic` fights a cold start: read the code, reframe the problem,
compare approaches that differ in kind, then account for hot-path and
user-surface risk. Its reply is one write-up that leads with the problem and
the recommended direction; questions travel in it with recommendations, and
the analysis proceeds on those.

Questions route by ownership:

```text
product/direction fork                 → ask the user, with recommendation
implementation choice                  → decide and record
technical unknown that preserves shape → park for consultation, with working answer
```

`elaborate-questions` rewrites a weak question so the user can decide without
reading the code. The parked list is what `consult-then-build` puts on trial.

## Stop conditions

The consult and build entries are told apart by where the turn ends:

```text
consult-codex      → at the synthesis; the user decides what follows
consult-then-build → at the finished build, unless the round leaves what a default cannot settle
implement-spec     → at the finished build
implement-now      → at the finished build, or at a settled decision the code proves wrong
```

`consult-then-build` stops for an unresolved disagreement with the voice, a
problem the voice replaced or found unsupported, or a new fork that is
expensive to undo. A question the user left unanswered takes the agent's
default: stopping on those is the failure the snippet exists to prevent.

## The session board reads the opening

`claude-steps` recognises a pasted snippet by the opening of its text, its
first 80 characters, in the files its `snippets` key names: the global
config and planlab's `.tabtype.local.toml`. It groups keys under the labels
in `claude-steps/.config/claude-steps/config.toml`, where both are set.

- **A reworded opening** drops the match for sessions that pasted the earlier
  text; an edit past the opening drops none.
- **A removed or renamed key** leaves its old name in a label, where it
  matches nothing.
- **A project's file** is read only once it is named there, and a paste is a
  step only under a label that lists its key: add a project's file and its
  keys together.
- **A slash-led snippet** arrives one of two ways, and the snippet does not
  choose which. As its command, it is seen as the skill's run as well as the
  paste. Wrapped by Claude Code as pasted text, the command does not run and
  the model calls the skill itself. The board shows the paste either way.
- **Each machine's board** reads that machine's copy of a project's file.
