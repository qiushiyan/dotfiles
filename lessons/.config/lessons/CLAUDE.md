# Lessons — and how they relate to Claude Code skills

This directory holds **lessons**: personally adapted, consolidated reference docs
on engineering methodology (module design + test discipline). They were derived
from Claude Code skills but are **not** skills themselves. This file explains the
distinction; `README.md` is the consumption contract and reading roadmap.

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
