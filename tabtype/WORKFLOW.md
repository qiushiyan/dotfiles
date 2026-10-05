# TabType workflow

The skill-based loop in `docs/doc-loop.md` owns the checkpoints of a change:
`/consult`, `/spike`, `/write-spec`, `/review`. The snippets in
`tabtype/.config/tabtype/config.toml` are the user's entries into that loop,
plus the prompts for the moments no skill covers. The config owns the keys and
their text; this page owns which entry fits which moment; `tabtype/DESIGN.md`
explains their shape.

## 1. Frame the problem

`think-holistic` asks for an analysis in one write-up: the problem restated, a
recommended direction, the decisions that are the user's, and the technical
unknowns parked for a consult. `elaborate-questions` re-asks an agent's
questions when they cannot be decided without the session behind them.

## 2. Settle the direction

The consult entries differ in where they stop:

```text
consult-codex      → /consult on the direction; the synthesis comes back to the user
consult-then-build → /consult, then the build, stopping only for what a default cannot settle
```

`spike-check` comes before a build when the approach rests on an assumption
nobody has run.

## 3. Build

```text
implement-spec → from a settled spec on disk
implement-now  → from decisions settled in the conversation
```

## 4. Review

`review-verify` starts `/review` and spends the wait re-proving the intended
behavior. `prompt-check` follows a session that touched model-facing text.

## Project-local entries

A project's `.tabtype.local.toml` binds the same moments to its own skills:
planlab's `loopy-review-verify` shadows `review-verify` with the
`pl-loopy-verify` rig. The file is gitignored in its project, so each
machine's checkout carries its own copy and an edit on one does not reach the
other.
