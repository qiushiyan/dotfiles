---
name: update-docs
description: Use when the user wants docs updated to reflect recent or shipped changes, e.g. "sync docs".
---

# Update the docs

Leave the project's docs so a capable reader, human or agent, holds the
system's present design: what it is for, how its parts relate, the
constraints that bite, and why it is shaped this way. Code, config, and
`--help` carry the rest. Done is the doc edits committed with the change,
each touched doc read whole and no longer than it needs to be, and a report.

The standard is the repo's own `documentation-standards.md` (anywhere under
`docs/`) with its bindings, or `~/dotfiles/docs/documentation-standards.md`
where the repo has none. Read it before writing.

## Scope

- **A change landed:** diff the working tree against the merge-base with
  the default branch, so committed and uncommitted work both count; for a
  merged branch, diff the merge. Read every doc the change overlaps, whole.
- **The user asks to reshape** ("simplify the docs", "set up a lean docs
  tree"): the scope is the docs they name, not the diff.
- **An implementation-level change** (a fix, a refactor, tests): say no doc
  needs an edit, and stop.

## Writing

Docs grow one sync at a time, and each addition looks small where it lands:
most past passes here left the docs longer, and the user has asked for
"concise", "high level", "bare minimum" again and again. So fold a new fact
into the section that owns it, cut what the change made stale or what code
now says, and prefer a short worked command over prose describing it. A doc
that grew needs a reason in the report.

## Authority

Make the reshapes the change calls for without asking: fold a shipped spec
into the doc that owns it and prune the spec, add or remove a `CLAUDE.md` or
`AGENTS.md` line the change makes true or stale, create a doc a new
subsystem needs, merge or split docs. The commit is the undo, so report each
one. Ask first only where docs and code disagree on the design itself, since
the user decides whether the doc or the code is wrong. A repo's own bindings
that require asking win.

## Before committing

Stage the docs, then run `scripts/doc-check` from this skill's directory
inside the repo, passing the bindings' live-doc pathspecs as separate
arguments when they differ from `docs/`, `CLAUDE.md`, and `AGENTS.md`. It
prints each doc's growth and the standard's check hits, broken `§`
references included. Fix each hit or say why it stands, then re-read every
changed doc as one narrative.

If the project has an onboarding or bootstrap skill, check that its routing
still reaches any doc you created, renamed, or removed.

## Report

What changed in which doc and why; each doc that grew and why; the reshapes
you made; what you left alone and why.
