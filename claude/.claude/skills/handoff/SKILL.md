---
name: handoff
description: Wrap up a session into a baton for the next one — an optional doc pass, the session's transferable lessons, and a HANDOFF.md kickstart at the repo root.
user-invocable: true
disable-model-invocation: true
argument-hint: [optional: the next session's goal, e.g. "next: wire the retry path" — or "nothing queued"]
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git branch:*), Bash(git merge-base:*), Bash(git check-ignore:*), Bash(git rev-parse:*), Read, Write, Edit, Glob, Grep, Agent
---

# Hand off the session

You're ending a working session. The docs keep the project's durable mental model, but what only this session holds — where the work stopped, the dead-ends, the next move — evaporates when it closes. This skill writes that baton: `HANDOFF.md` at the repo root (the worktree root, `git rev-parse --show-toplevel`), a brief the user feeds into the next session's first prompt.

**Defer to the project first.** If the repo ships its own handoff skill scoped to this work (check `.claude/skills/`), its process is authoritative — run it, and add only what it lacks: if it presents a kickstart without persisting it, write that kickstart into `HANDOFF.md` too.

## 1 — Gate: does this session earn a baton?

A manufactured handoff sends the next session down a road nobody planned. `$ARGUMENTS` may already name the next goal — that answers this gate. Otherwise classify the ending:

- **Thread continues** — work unfinished, or a known next milestone → full handoff: steps 2–5.
- **Stopped mid-task** — context or time ran out before the work landed → the baton is the most valuable thing you can leave. Run steps 3–5 now and fold the doc pass into the baton's first moves.
- **Work landed, nothing queued** — an isolated fix or feature, done and verified → ask the user one question: *anything queued for the next session, or doc pass only?* If nothing's queued, run step 2 alone; and if a `HANDOFF.md` from an earlier session survives, propose deleting it — a stale baton is worse than none.

## 2 — Doc pass

The docs are the durable memory; the baton only bridges sessions. If the branch changed anything doc-worthy, run the project's own update-docs skill or `documentation-standards.md` (the global `/update-docs` standards when the project has neither). Skip when a doc pass already ran this session, or the diff is implementation-level.

**Timing rule:** the doc pass needs only the diff; the baton needs this session's memory. When the window is already deep — you'd hesitate to re-read the overlapping docs end-to-end — write the baton first and make "run the doc pass" the kickstart's opening move, so it executes in a fresh window.

Done when docs are updated, or the skip is named ("deferred to next session" / "implementation-level").

## 3 — Harvest what only this session knows

The diff shows what changed. Collect what it can't show:

- Decisions made and the alternatives they beat.
- Dead-ends — approaches tried and abandoned, and why. A fresh session re-attempts these first unless told.
- What proved harder or subtler than the plan assumed; invariants the work established that the next change must not break.
- Verification state — what was tested, what was merely written.

Keep a lesson only if you can say why you believe it and how sure you are. A session that taught nothing transferable gets a baton of state + next move and nothing else — the honesty floor cuts both ways.

## 4 — Write `HANDOFF.md`

At the repo root, overwriting any previous one. Address it to the next session's agent — the user pastes or `@`-mentions it in the first prompt, so it must stand alone:

```markdown
# Handoff — <one-line goal> (<date>)

> Suggested first prompt for the next session:
> /<onboarding-skill> <topic args> — then read HANDOFF.md at the repo root
> before starting work; it carries the previous session's state and lessons.

You are picking up work from a previous session. Docs and code are the truth;
this file is the bridge. Where they disagree, trust the docs and code.

## Where things stand
Branch, committed vs uncommitted, verified vs merely written.

## Lessons and dead-ends
From step 3, each with its why. If none: "No transferable lessons — state only."

## First moves
1. Read: <the 2–4 files this task hinges on, one line of why each>
2. Skills: <the project skills this work runs through beyond onboarding,
   e.g. log-reading or repro/verify helpers — omit the line when none apply>
3. Verify for yourself: <the 1–3 claims most likely to bite if taken on faith>
4. Before writing code: state the plan in your own words and flag anything
   that contradicts this file.
```

If the project has no onboarding skill, the suggested first prompt names the docs to read instead. Point rather than pre-chew — a baton that hands the next session answers instead of pointers robs it of the verification that would make them its own. Reference rather than duplicate: anything already captured in an artifact — the docs the doc pass just updated, specs, issues, commits, diffs — is cited by path or URL, never restated; the baton carries only what lives nowhere else. Redact secrets before writing — keys, tokens, pasted credentials or log lines carrying them — the file outlives the session and becomes part of another agent's prompt. Keep it under ~150 lines.

Handoffs are session-local unless the project deliberately archives them: if `git check-ignore HANDOFF.md` reports it unignored, append `HANDOFF.md` to the file at `git rev-parse --git-path info/exclude` (local ignore — touches nothing tracked). A project that keeps dated records may also archive a copy there.

## 5 — Close

Show the user the suggested-first-prompt line from the file and a two-line summary of what the baton carries. Handed off means: the user can start the next session with a single paste.
