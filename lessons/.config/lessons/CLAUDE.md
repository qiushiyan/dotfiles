# Lessons — and how they relate to Claude Code skills

This directory holds **lessons**: owned reference docs on engineering method
(module design, test discipline, cross-agent review). They are not skills.
This file says how to write and keep them; `README.md` is the consumption
contract and reading roadmap.

## Skill vs lesson

- **A skill** (`~/.claude/skills/…`) is invokable: Claude loads its
  `SKILL.md` to do a task.
- **A lesson** is plain markdown with no `SKILL.md`. Snippets and the
  dispatch briefs cite it by path, and the agent they brief reads it. Nothing
  loads it automatically.

A lesson is one home per concept, so a snippet cites a short, stable reading
arc instead of a sprawl of skill files. The snippets carry the arc; the
lessons carry the depth.

`collaboration/` has a second origin: the twin review prompts of greenflag and
the dispatch skills, not upstream skills. `SYNTHESIS.md` records that
comparison, including the asymmetries between the two products that must not
be "fixed" toward each other. It is maintainer-only: never vendored, never
read by an agent. Read it before editing either side's review, consult or
delegate prompts.

## What a lesson carries

A skill says what to **do now**; a lesson says what is **true durably**. When
adapting a skill, strip what belongs to one harness, session or interlocutor:

- **Borrowed interaction model** ("confirm with the user", "get approval on
  the plan"). A lesson may reach a headless agent, or one forbidden to ask.
  Say who owns the choice instead: a product call is surfaced and waited on; a
  technical call is decided and recorded.
- **Tool coupling** ("spawn three sub-agents with the Agent tool"). Name the
  property the tool supplies, such as independent, unanchored exploration,
  and keep the mechanics to a parenthetical.
- **Procedure residue**: numbered steps whose order is the harness's. Keep a
  sequence only where the order is intrinsic (write the new tests *before*
  deleting the old ones); otherwise state the principle and let the reader
  order it.
- **Restatement**: one rule at the bar, again in its section, again in a
  sibling. Give it a name that carries it in one token (the *two-adapter
  rule*, the *deletion test*, a *change detector*) and cite the name after.
- **Prohibition as the lever**: a stack of "don't". State the path to take;
  keep a "never" for a hard rule a positive phrasing would blur (*never
  refactor while RED*).

What stays is the idea in the reader's working vocabulary: named terms, a
skimmable `## The bar` on top that holds each rule whole (reviewers read only
the bar), and anti-examples (`Rejected framings`, `_Avoid_:` lists, good/bad
pairs), which hold where a reader's habit would otherwise win. Give a reason
where the reader would otherwise misapply the rule, as `composition.md` does
for "refactor it later". A reason that only restates the rule is a no-op.

## Revising a lesson

- Read `/prompt-engineering` first. A lesson is prompt surface, but it stays
  descriptive, never a manual.
- **Every line names what it prevents.** Delete a sentence, list or diagram
  that restates the one above it; do not trim its words.
- **Verify before you "fix".** Check an API claim against current docs, not
  memory: `vitest.md`'s `aroundEach` looks invented and is real (Vitest
  4.1). Deleting correct content costs more than keeping a weak line.
- **Keep every named term and heading consumers cite**, or rename it
  everywhere: grep this tree, `~/dotfiles/claude/.claude/skills`, the tabtype
  snippets, and `~/dev/greenflag/snippets`.
- **Provenance stays below the fold.** The closing `> _Lesson · …_` line is the
  maintainer's diff anchor, not the reader's opening.
- **Size.** `skill-sync --check` records every lesson at its word count and
  fails growth. An addition pays with a cut, or the record in
  `skill-budget.yaml` is raised by hand with a comment saying why.

## Lineage

Forked from [mattpocock/skills](https://github.com/mattpocock/skills) (the TDD
and codebase-architecture skills), consolidated into `codebase-design/` and
`testing/`, and tuned for headless agents. They replace the retired standalone
`tdd` and `improve-codebase-architecture` skills. `.upstream/` mirrors the
pinned upstream files; `.upstream/PINNED.txt` holds the pin, how to refresh
it, and the verdicts on each reviewed delta. Each lesson's provenance line
names its source files.

## Consumers

- `~/dotfiles/tabtype` snippets cite these paths literally; tabtype has no
  token expansion, so a snippet that quotes a lesson is re-pasted after an
  edit.
- `~/dev/greenflag` vendors a frozen snapshot into `greenflag/lessons/` and
  cites it through a `{{lessons_dir}}` token. Refresh it with
  `pnpm vendor-lessons` there.
- The `review`, `consult` and `delegate` skills cite these paths; the
  dispatched voice reads the live files.

**A new lesson needs a citation, not just a copy.** Only a snippet citing its
path makes an agent read it. Add it to the roadmap in `README.md`, the topic
`README.md`, and every snippet that should hand it over (in greenflag, the
`{{lessons_dir}}` lines in `snippets/*.toml`: makers read deeply, reviewers
skim the bar).
