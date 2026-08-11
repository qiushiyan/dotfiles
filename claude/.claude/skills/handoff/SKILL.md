---
name: handoff
description: Wrap up a session into a baton for the next one — an optional doc pass, the session's harvest (lessons and friction), and a handoff file named for the next session's branch that *is* its first prompt, ready to paste into a fresh worktree — or back into this one, in review posture, when the branch isn't ready to merge.
disable-model-invocation: true
argument-hint: [optional: the next session's goal, e.g. "next: wire the retry path", "review posture: not merging yet" — or "nothing queued"]
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git branch:*), Bash(git merge-base:*), Bash(git worktree list:*), Bash(bash ~/.claude/skills/handoff/handoff-path.sh:*), Bash(date:*), Bash(pbcopy:*), Read, Write, Edit, Glob, Grep, Agent
---

# Hand off the session

You're ending a working session. The docs keep the project's durable mental model, but what only this session holds — where the work stopped, the dead-ends, the next move — evaporates when it closes. This skill writes that baton: a handoff file under `~/dev/.handoffs/`, filed by project and named for where the work is going next.

**The file is a prompt, not a report.** The next session starts in a *fresh worktree* — or, in review posture, right back in this one. The user pastes this file's contents as that session's opening message — so every line you write is read as an instruction addressed to the agent receiving it.

**Defer to the project first.** If the repo ships its own handoff skill scoped to this work (check `.claude/skills/`), its process is authoritative — run it, and add only what it lacks: if it presents a kickstart without persisting it, write that kickstart into the `~/dev/.handoffs/` baton too.

## 1 — Gate: does this session earn a baton?

A manufactured handoff sends the next session down a road nobody planned. `$ARGUMENTS` may already name the next goal — that answers this gate. Otherwise classify the ending:

- **Thread continues** — work unfinished, or a known next milestone → full handoff: steps 2–5.
- **Stopped mid-task** — context or time ran out before the work landed → the baton is the most valuable thing you can leave. Run steps 3–5 now and fold the doc pass into the baton's first moves.
- **Done but not trusted** — the work is "complete" but the user's verdict is that it doesn't merge yet — edge cases kept surfacing after earlier "done" claims — and the next session re-reviews this branch's work before any merge → full handoff: steps 2–5 in **review posture** (step 4 defines it).
- **Work landed, nothing queued** — an isolated fix or feature, done and verified → ask the user one question: *anything queued for the next session, or doc pass only?* If nothing's queued, run step 2 alone. Step 4 names each baton for what it sends the next session to, so landing this branch spends the baton that spawned it: check both names the convention can produce for the branch you're on — `<branch>` and, when that session was a review, `review-<branch>` — and propose deleting whichever exists. A stale baton is worse than none. When the whole folder has gone that way — several batons written across a busy week that nobody can now place — `/handoff-sweep` is the pass that reads them together and reconciles them against the repo; this skill writes one baton and cannot see the folder around it.

Review posture is entered on the user's verdict — `$ARGUMENTS` or the session saying the branch isn't ready — never on your own read of the work. A clean ending with a natural next goal is a forward handoff: write it, no question. When the ending shows the *done but not trusted* signature but the verdict was never spoken — a large or bumpy branch, bugs found after green claims, no merge decision stated — settle the gate with one question: *merging this and moving on, or holding it for a review session?*

## 2 — Doc pass

The docs are the durable memory; the baton only bridges sessions. If the branch changed anything doc-worthy, run the project's own update-docs skill or `documentation-standards.md` (the global `/update-docs` standards when the project has neither). Skip when a doc pass already ran this session, or the diff is implementation-level.

**Timing rule:** the doc pass needs only the diff; the baton needs this session's memory. When the window is already deep — you'd hesitate to re-read the overlapping docs end-to-end — write the baton first and make "run the doc pass" the prompt's opening move, so it executes in a fresh window.

Done when docs are updated, or the skip is named ("deferred to next session" / "implementation-level").

## 3 — Harvest what only this session knows

The diff shows what changed. The harvest collects what it can't show, in two halves — what the session learned, and what it fought.

**Lessons** — conclusions the next session should inherit:

- Decisions made and the alternatives they beat.
- Dead-ends — approaches tried and abandoned, and why. A fresh session re-attempts these first unless told.
- Invariants the work established that the next change must not break.
- Verification state — what was tested, what was merely written.

**Friction** — where the work actually hurt, mined now because the wrap-up is what glosses it: fixes that took several attempts, code re-read repeatedly before it could be trusted, wrong turns, assumptions that broke, places too many cases had to be held in mind at once. Make one call per point: **essential** — the problem is genuinely that hard — or **accidental** — the current design manufactured the struggle. Essential friction joins the lessons ("harder than it looks, and why"). Accidental friction is a design signal: name the concrete struggle and the reshape that would have dissolved it. You built what you're now judging, so hand the next session the case, not the verdict.

Done when every kept lesson carries why you believe it and how sure you are, and every friction point carries its essential-or-accidental call — a session that taught nothing and fought nothing gets a baton of state + next move and nothing else; the honesty floor cuts both ways.

## 4 — Write the baton

The helper prints the file to write and creates its folder — batons are grouped by project:

```sh
bash ~/.claude/skills/handoff/handoff-path.sh <slug>
```

**`<slug>` is the branch the next session will work on**, not the one this session worked on. Today's branch is merged or nearly so, so a baton named for it is filed under work that's already over — and the next worktree's name, the one thing you'd have to open the file to find, stays hidden. Named forward, the filename is already the argument step 5 hands over: one token for the baton, the branch, and the worktree.

Write it as you'd write the branch, because it is the branch. The repo's own convention (`git branch`, `git worktree list`) sets the shape — including a `feat/`-style prefix where that's the convention, which nests the baton exactly as it nests the worktree — and within that: lowercase kebab, 2–4 words, naming the outcome the next session is heading for. `retry-backoff-ceiling`, `pty-harness`, `steer-render-split`. Today's branch plus a suffix (`-followup`, `-part-2`, a trailing date) names the road behind instead, and a worktree's name is the first thing its session reads.

A same-named file is an earlier baton for this same goal — overwrite it. Two *live* batons colliding means one slug is too vague; sharpen it.

The first line is the invocation the paste fires; everything under it is context riding along with it:

```markdown
/<onboarding-skill> <the next session's goal in a phrase, with its 2–3 strands>

anchor: <date> · <default-branch> `<sha>` · claims rest on <the PRs, branches
or changes whose state this brief assumes>

You are picking up work from a previous session. Docs and code are the truth;
this brief is the bridge. Where they disagree, trust the docs and code.

## Where things stand

Branch and base, committed vs uncommitted, in-review vs merged, verified vs
merely written — and the branch this work continues on, with its base.

## Lessons, dead-ends, and friction

From step 3, each with its why. Accidental friction lands as the struggle plus
the reshape it points at — a case for the next session to weigh, not a verdict
to execute. If none: "No transferable lessons — state only."

## First moves

1. Drift check, before the reads: `git log <sha>..<default-branch> --oneline --
   <the paths this brief names>`, then account for everything the anchor lists
   in one line each — its state now, what landed in those paths since the
   anchor, and which of this brief's instructions the drift makes moot.
2. Read: <the 2–4 files this task hinges on, one line of why each>
3. Skills: <the project skills this work runs through beyond onboarding,
   e.g. log-reading or repro/verify helpers — omit the line when none apply>
4. Verify for yourself: <the 1–3 claims most likely to bite if taken on faith>
5. Before writing code: state the plan in your own words and flag anything
   that contradicts this brief. Route questions that arise: product/direction
   forks to the user, each in plain product terms with options, implications,
   and your recommendation; technical unknowns recorded with your working
   answer for a later consult round rather than asked.
```

Write it to survive the paste:

- **Line 1 carries the invocation.** No title heading above it — a heading on line 1 makes the paste inert prose. Where the project has no onboarding skill, line 1 is a plain directive naming the docs to read instead.
- **Every path is repo-relative.** The next session lives in a different worktree; an absolute path into this one dangles. Cite files, specs, PRs and issues by repo-relative path or URL.
- **Refer to it as "this brief", never as a file.** The next session receives this text as its prompt, not as a file to open.

**The anchor dates the baton; the drift check spends it.** A baton is read a day or a week later, across sibling work its author never saw, so it carries the means to date itself: the write date, the default branch and its sha at writing (`git log -1 --format=%h <default-branch>` — discover the branch name rather than assuming one, `git branch -r` shows `origin/HEAD`), and the PRs, branches or changes whose state its claims rest on. First moves then opens on that diff and ends on which of the brief's own instructions the drift makes moot — the question "trust the docs and code" never asks, because an instruction that shipped in the meantime contradicts nothing in the tree. When the project's baton folder already holds siblings, add `cluster:` for the workstream and `blocked-by:` / `collides-with:` for the batons this one must not run before or beside; with no siblings they are load for nothing.

Point rather than pre-chew — a baton that hands the next session answers instead of pointers robs it of the verification that would make them its own. The rule binds the *design* as well as the facts: carry the goal, the constraints, and the evidence this session paid for, and leave the shape of the fix to the session that will own it. Where you do sketch one, mark it as a sketch and say what it has not answered — an approach written in as a requirement spends the next session's judgement before it starts, and it is written most confidently by the session least able to test it. Reference rather than duplicate: anything already captured in an artifact — the docs the doc pass just updated, specs, issues, commits, diffs — is cited, never restated; the baton carries only what lives nowhere else. Redact secrets before writing — keys, tokens, pasted credentials or log lines carrying them — this text becomes another agent's prompt. Keep it under ~150 lines.

**Review posture** (the gate's *done but not trusted* ending) hands the branch to its reviewer, not its continuer. Same file, same rules, four deltas:

- The slug is `review-<this-branch>` — what's ahead is a verdict on this branch, not a new worktree, so the filename names the review instead of a destination. The opening paragraph pins the next session to **this same branch in this same worktree** — the branch merges only after the review passes, so no new branch or worktree gets created. Worktree-local artifacts (gitignored scripts, scratch harnesses) are citable here: the next session can reach them.
- A posture block sits right under it, naming why trust broke — the concrete edge cases and bugs the user found after earlier "done" claims — and setting the stance: the next session treats each conclusion, this brief's included, as a claim to re-verify, and reads the accreted fixes adversarially — assume they hide more seams.
- "Where things stand" carries the **review surface**: the mechanisms and workarounds this branch accreted, one line each, mechanism → home file — the shape to review, not re-derive. Verification state is claims, not facts: suite numbers come with "re-run before trusting".
- Line 1's goal names the review; unless `$ARGUMENTS` sets its own agenda, it carries the standing one — does the accretion compose or hide seams; what to extract and where the seams go; why the suite stayed green over the escaped edge cases, and the harness that would catch that class. First moves offers the user `/review` — a cold dispatched read to ride beside the session's own.

Done when the baton passes the cold-paste test: the invocation sits on line 1, every pointer resolves from inside the receiving worktree, nothing in it depends on this session or this file existing, it dates itself with an anchor the receiving session can diff from, and the filename names where the next session goes — the worktree to create, or the review to run when the posture is review.

## 5 — Close

Run `pbcopy <` the path step 4 wrote, then show the user, together:

- the path (their re-copy command),
- a two-line summary of what the baton carries,
- and the ready command they run before pasting. The branch is not a fresh
  suggestion to invent here — step 4 already chose it, and it is the slug:

  ```sh
  gwt <slug> <base>
  ```

  `gwt` places the worktree, seeds its gitignored files, and cds there — so no
  worktree path gets hardcoded here.

  In review posture there is no branch to create — the next session opens in
  this same worktree, so the ready command is the paste alone.

Handed off means: one paste, next session running.
