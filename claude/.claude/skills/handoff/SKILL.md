---
name: handoff
description: Wrap up a session into a baton for the next one — an optional doc pass, the session's transferable lessons, and a dated handoff file in ~/dev/.handoffs that *is* the next session's first prompt, ready to paste into a fresh worktree — or back into this one, in review posture, when the branch isn't ready to merge.
disable-model-invocation: true
argument-hint: [optional: the next session's goal, e.g. "next: wire the retry path", "review posture: not merging yet" — or "nothing queued"]
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git branch:*), Bash(git merge-base:*), Bash(git worktree list:*), Bash(date:*), Bash(mkdir:*), Bash(pbcopy:*), Read, Write, Edit, Glob, Grep, Agent
---

# Hand off the session

You're ending a working session. The docs keep the project's durable mental model, but what only this session holds — where the work stopped, the dead-ends, the next move — evaporates when it closes. This skill writes that baton: a handoff file in the central `~/dev/.handoffs/` folder.

**The file is a prompt, not a report.** The next session starts in a *fresh worktree* — or, in review posture, right back in this one. The user pastes this file's contents as that session's opening message — so every line you write is read as an instruction addressed to the agent receiving it.

**Defer to the project first.** If the repo ships its own handoff skill scoped to this work (check `.claude/skills/`), its process is authoritative — run it, and add only what it lacks: if it presents a kickstart without persisting it, write that kickstart into the `~/dev/.handoffs/` baton too.

## 1 — Gate: does this session earn a baton?

A manufactured handoff sends the next session down a road nobody planned. `$ARGUMENTS` may already name the next goal — that answers this gate. Otherwise classify the ending:

- **Thread continues** — work unfinished, or a known next milestone → full handoff: steps 2–5.
- **Stopped mid-task** — context or time ran out before the work landed → the baton is the most valuable thing you can leave. Run steps 3–5 now and fold the doc pass into the baton's first moves.
- **Done but not trusted** — the work is "complete" but the user's verdict is that it doesn't merge yet — edge cases kept surfacing after earlier "done" claims — and the next session re-reviews this branch's work before any merge → full handoff: steps 2–5 in **review posture** (step 4 defines it).
- **Work landed, nothing queued** — an isolated fix or feature, done and verified → ask the user one question: *anything queued for the next session, or doc pass only?* If nothing's queued, run step 2 alone; and if `~/dev/.handoffs/` holds an earlier baton for this branch, propose deleting it — a stale baton is worse than none.

Review posture is entered on the user's verdict — `$ARGUMENTS` or the session saying the branch isn't ready — never on your own read of the work. A clean ending with a natural next goal is a forward handoff: write it, no question. When the ending shows the *done but not trusted* signature but the verdict was never spoken — a large or bumpy branch, bugs found after green claims, no merge decision stated — settle the gate with one question: *merging this and moving on, or holding it for a review session?*

## 2 — Doc pass

The docs are the durable memory; the baton only bridges sessions. If the branch changed anything doc-worthy, run the project's own update-docs skill or `documentation-standards.md` (the global `/update-docs` standards when the project has neither). Skip when a doc pass already ran this session, or the diff is implementation-level.

**Timing rule:** the doc pass needs only the diff; the baton needs this session's memory. When the window is already deep — you'd hesitate to re-read the overlapping docs end-to-end — write the baton first and make "run the doc pass" the prompt's opening move, so it executes in a fresh window.

Done when docs are updated, or the skip is named ("deferred to next session" / "implementation-level").

## 3 — Harvest what only this session knows

The diff shows what changed. Collect what it can't show:

- Decisions made and the alternatives they beat.
- Dead-ends — approaches tried and abandoned, and why. A fresh session re-attempts these first unless told.
- What proved harder or subtler than the plan assumed; invariants the work established that the next change must not break.
- Verification state — what was tested, what was merely written.

Done when every kept lesson carries why you believe it and how sure you are — and a session that taught nothing transferable gets a baton of state + next move and nothing else; the honesty floor cuts both ways.

## 4 — Write the baton

To `~/dev/.handoffs/<date>-<branch>-handoff.md` — date from `date +%F`, branch from `git branch --show-current` with any `/` replaced by `-`; `mkdir -p` the folder first, and overwrite a same-named file. The first line is the invocation the paste fires; everything under it is context riding along with it:

```markdown
/<onboarding-skill> <the next session's goal in a phrase, with its 2–3 strands>

You are picking up work from a previous session (<date>). Docs and code are the
truth; this brief is the bridge. Where they disagree, trust the docs and code.

## Where things stand

Branch and base, committed vs uncommitted, in-review vs merged, verified vs
merely written — and the branch this work continues on, with its base.

## Lessons and dead-ends

From step 3, each with its why. If none: "No transferable lessons — state only."

## First moves

1. Read: <the 2–4 files this task hinges on, one line of why each>
2. Skills: <the project skills this work runs through beyond onboarding,
   e.g. log-reading or repro/verify helpers — omit the line when none apply>
3. Verify for yourself: <the 1–3 claims most likely to bite if taken on faith>
4. Before writing code: state the plan in your own words and flag anything
   that contradicts this brief.
```

Write it to survive the paste:

- **Line 1 carries the invocation.** No title heading above it — a heading on line 1 makes the paste inert prose. Where the project has no onboarding skill, line 1 is a plain directive naming the docs to read instead.
- **Every path is repo-relative.** The next session lives in a different worktree; an absolute path into this one dangles. Cite files, specs, PRs and issues by repo-relative path or URL.
- **Refer to it as "this brief", never as a file.** The next session receives this text as its prompt, not as a file to open.

Point rather than pre-chew — a baton that hands the next session answers instead of pointers robs it of the verification that would make them its own. Reference rather than duplicate: anything already captured in an artifact — the docs the doc pass just updated, specs, issues, commits, diffs — is cited, never restated; the baton carries only what lives nowhere else. Redact secrets before writing — keys, tokens, pasted credentials or log lines carrying them — this text becomes another agent's prompt. Keep it under ~150 lines.

**Review posture** (the gate's *done but not trusted* ending) hands the branch to its reviewer, not its continuer. Same file, same rules, four deltas:

- The opening paragraph pins the next session to **this same branch in this same worktree** — the branch merges only after the review passes, so no new branch or worktree gets created. Worktree-local artifacts (gitignored scripts, scratch harnesses) are citable here: the next session can reach them.
- A posture block sits right under it, naming why trust broke — the concrete edge cases and bugs the user found after earlier "done" claims — and setting the stance: the next session treats each conclusion, this brief's included, as a claim to re-verify, and reads the accreted fixes adversarially — assume they hide more seams.
- "Where things stand" carries the **review surface**: the mechanisms and workarounds this branch accreted, one line each, mechanism → home file — the shape to review, not re-derive. Verification state is claims, not facts: suite numbers come with "re-run before trusting".
- Line 1's goal names the review; unless `$ARGUMENTS` sets its own agenda, it carries the standing one — does the accretion compose or hide seams; what to extract and where the seams go; why the suite stayed green over the escaped edge cases, and the harness that would catch that class. First moves offers the user `/review` — a cold dispatched read to ride beside the session's own.

Done when the baton passes the cold-paste test: the invocation sits on line 1, every pointer resolves from inside the receiving worktree, and nothing in it depends on this session or this file existing.

## 5 — Close

Run `pbcopy < ~/dev/.handoffs/<file>`, then show the user, together:

- the path (their re-copy command),
- a two-line summary of what the baton carries,
- and a suggested branch for the next session — named for the baton's goal,
  not for today's branch, in this repo's own style (`git branch --show-current`
  and `git worktree list` show the convention) — as the ready command the user
  runs before pasting:

  ```sh
  git worktree add <worktrees-path>/<suggested-branch> -b <suggested-branch>
  ```

  In review posture there is no branch to suggest — the next session opens in
  this same worktree, so the ready command is the paste alone.

Handed off means: one paste, next session running.
