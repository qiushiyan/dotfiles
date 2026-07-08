# Lessons — and how they relate to Claude Code skills

This directory holds **lessons**: personally adapted, consolidated reference docs
on engineering methodology (module design + test discipline). They were derived
from Claude Code skills but are **not** skills themselves. This file explains the
distinction and how to keep it; `README.md` is the consumption contract and
reading roadmap.

## Skill vs lesson

- **Claude Code skills** (`~/.claude/skills/…`) are *invokable*: Claude loads a
  `SKILL.md` on its own judgment to do a task. Third-party skills (e.g. the
  mattpocock methodology skills) install here as-is.
- **Lessons** (here) are *not* invokable and carry no `SKILL.md`. They are plain
  markdown my **prompt snippets** cite by path — pasted into a coding agent at
  technical-design time, never auto-loaded.

A lesson is the *consolidated, owned* form of a methodology I want a snippet to
hand an agent: forked from the original skills, then merged into one home per
concept so a snippet cites a short, stable reading arc instead of a sprawl of
skill files. The snippets carry the arc; the lessons carry the depth.

## Adapting a skill into a lesson

A skill tells an agent what to **do now**; a lesson tells it what is **true
durably**. Converting one strips everything belonging to a particular harness,
session, or interlocutor — what remains is the idea and its reason, which is what
generalizes to situations the original author never enumerated.

Five things a skill carries that a lesson must not:

- **Borrowed interaction model** — "confirm with the user", "get approval on the
  plan", "show this, then proceed". A snippet may hand the lesson to a headless
  agent with no user, and to one whose harness forbids asking. Replace with *who
  owns the choice*: a product call gets surfaced and waited on; a technical call
  gets decided and recorded.
- **Tool coupling** — "spawn three sub-agents with the Agent tool". Name the
  property the tool supplies (independent, unanchored exploration) and demote the
  mechanics to a parenthetical.
- **Procedure residue** — a `## Process` of numbered steps whose order is the
  harness's rather than the idea's. Keep a sequence only where the order is
  intrinsic (write the new tests *before* deleting the old ones); otherwise state
  the principle and let the reader sequence it.
- **Restatement** — the same rule at the bar, again in its section, again in a
  sibling file. Collapse it into a named term that carries it in one token (the
  *two-adapter rule*, the *deletion test*, a *change detector*) and reference the
  name thereafter.
- **Prohibition as the lever** — a stack of "don't". Prompt the positive path so
  the banned move is never spoken; keep a "never" only where the rule is hard and
  a positive phrasing would be vaguer (*never refactor while RED*).

What a lesson keeps, and a skill often lacks: the **why** under each rule (a
reason generalizes where a bare rule invites creative violation), the
**vocabulary** of leading words the reader thinks with, **anti-examples**
(`Rejected framings`, the glossary's `_Avoid_:` lists, good/bad pairs), and a
skimmable `## The bar` on top with the depth beneath it.

## Revising a lesson

- **Provenance below the fold.** The `> _Lesson · …_` line is a maintainer's
  upstream diff anchor, not what a working agent should read first.
- **Verify before you "fix".** Check a factual API claim against current docs,
  not memory — `vitest.md`'s `aroundEach` reads like a hallucination and is real
  (Vitest 4.1). Deleting correct content is the costlier error.
- **Hunt no-ops sentence by sentence.** A diagram or list restating the sentence
  above it is load without signal; delete the sentence rather than trim its words.
- Read `/prompt-engineering` (model-facing text) and `/writing-great-skills`
  (structure, leading words, progressive disclosure) before a revision pass. Both
  apply — a lesson is prompt surface — but neither licenses turning a lesson into
  a manual. It stays descriptive.

## Lineage

Forked from [mattpocock/skills](https://github.com/mattpocock/skills) (the TDD
and codebase-architecture skills), consolidated into two topics
(`codebase-design/`, `testing/`), and headless-tuned. They supersede the
standalone `tdd` and `improve-codebase-architecture` Claude Code skills, which
are retired. The pristine upstream is pinned in `.upstream/` as the diff baseline
— see `README.md` for the upstream-sync steps and each lesson's provenance line.

## Consumers

- `~/dotfiles/tabtype` — snippets cite these paths **literally** (tabtype has no
  token expansion).
- `~/dev/duet` — vendors a frozen snapshot into `duet/lessons/` and cites it
  through a `{{lessons_dir}}` token, so it ships self-contained in the package.

Both are kept in sync by hand: edit a lesson here, then re-paste (tabtype) or
`pnpm vendor-lessons` (duet).

**A new lesson needs a citation, not just a copy.** Vendoring ships the file;
only a snippet citing its path makes an agent read it. Adding one means: the
roadmap table in `README.md`, the topic `README.md`, and every snippet that
should hand it over (duet: the `{{lessons_dir}}` lines across `snippets/*.toml`,
where the makers read it deeply and the reviewers skim its bar as a lens).
